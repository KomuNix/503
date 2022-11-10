{ config, pkgs, ... }:

let
  cachex_index = pkgs.stdenv.mkDerivation {
    pname = "cachex_index";
    version = "latest";
    src = builtins.fetchurl {
      url = "https://raw.githubusercontent.com/KomuNix/503/bc863b06f988f0a0fda72402888e78da5f8c6318/cachex/cachex_index.html";
      sha256 = "8c249b1ca0094468463599be8590cdef88f313738e6693aa39a1d5999490f7e8";
    };

    phases = "installPhase";
    installPhase = ''
      mkdir -p $out
      cp $src $out/index.html
    '';
  };
in
{
  services.nginx.virtualHosts."cache.komunix.org" = {
    root = "${cachex_index}";
  };
}
