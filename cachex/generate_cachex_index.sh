#!/usr/bin/env bash

export cache_dir=${komunix_cache_dir:="/var/nix-cache"}
export timestamp=$(date +%s)

export usage=$(df -h $cache_dir | tail -n1)
export total_cache=$(find $cache_dir -type f | wc -l)

envsubst < index.html.tpl > index.html
