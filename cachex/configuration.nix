{ config, pkgs, ... }:

let
  cachexDomain = "cache.komunix.org";
  fallbackUpstream = "cache.nixos.org";
  komunixServer = "komunix 0.66.6";

in

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "komunix";
  networking.networkmanager.enable = false;

  time.timeZone = "Asia/Jakarta";

  users.users.komunix = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];

    packages = with pkgs; [ ];
  };

  environment.systemPackages = with pkgs; [
    vim
    vnstat
    wget
    lsof
  ];

  services.openssh.enable = true;

  services.nginx = {
    enable = true;

    appendHttpConfig = ''
      proxy_cache_path /var/cache/nginx/verycache/ levels=1:2 keys_zone=verycache:100m max_size=10g inactive=365d use_temp_path=off;

      map $status $cache_header {
        200 "public";
        302 "public";
        default "no-cache";
      }
    '';

    virtualHosts."${cachexDomain}" = {

      listen = [
        { addr = "127.0.0.1"; port = 8080; }
      ];

      locations."/" = {
        root = "/srv/www/cachex_index";

        extraConfig = ''
                    expires max;

                    add_header Cache-Control $cache_header always;

          	        error_page 404 = @fallback;
        '';
      };

      locations."@fallback" = {
        proxyPass = "https://${fallbackUpstream}";

        extraConfig = ''
          	  proxy_cache verycache;
          	  proxy_cache_valid 200 302 60m;

                    expires max;

          	  add_header Cache-Control $cache_header always;
          	  add_header X-Komunix-Cache $upstream_cache_status always;
          	 '';
      };

      locations."= /nix-cache-info" = {
        proxyPass = "https://${fallbackUpstream}";

        extraConfig = ''
          	  proxy_cache verycache;
          	  proxy_cache_valid 200 302 60m;

                    expires max;

          	  add_header Cache-Control $cache_header always;
          	  add_header X-Komunix-Cache $upstream_cache_status always;
          	 '';
      };
    };
  };

  services.traefik = {
    enable = true;

    staticConfigOptions = {
      api.dashboard = false;

      accessLog = {
        filePath = "${config.services.traefik.dataDir}/logs/access.log";
        format = "json";
      };

      log = {
        filePath = "${config.services.traefik.dataDir}/logs/app.log";
        level = "DEBUG";
      };

      entryPoints = {
        http = {
          address = ":80";

          http.redirections.entryPoint = {
            to = "https";
            scheme = "https";
          };
        };

        https = {
          address = ":443";

          http.tls.certResolver = "letsencrypt";
        };
      };

      certificatesResolvers = {
        letsencrypt.acme = {
          email = "ssl@komunix.org";
          httpChallenge.entryPoint = "http";
        };
      };
    };

    dynamicConfigOptions = {
      http = {
        middlewares = {
          cachex_index = {
            headers.customResponseHeaders.server = "${komunixServer}";
          };

          cachex_fallback = {
            headers.customResponseHeaders."X-Komunix-Fallback-To" = "${fallbackUpstream}";
          };
        };

        routers = {
          cachex = {
            rule = "Host(`${cachexDomain}`) && PathPrefix(`/`)";
            service = "cachex_fallback";
            priority = 1;
            middlewares = [ "cachex_index" "cachex_fallback" ];
          };

          cachex_index = {
            rule = "Host(`${cachexDomain}`) && Path(`/`)";
            service = "cachex_index";
            priority = 1337;
            middlewares = [ "cachex_index" ];
          };
        };

        services = {
          cachex.loadBalancer.servers = [
            { url = "http://127.0.0.1:8080/"; }
          ];

          cachex_fallback.loadBalancer.servers = [
            { url = "http://127.0.0.1:8080/"; }
          ];

          cachex_index.loadBalancer.servers = [
            { url = "http://127.0.0.1:2022/"; }
          ];
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 0; to = 65535; }
  ];

  system.copySystemConfiguration = true;
  system.stateVersion = "22.05";
}

