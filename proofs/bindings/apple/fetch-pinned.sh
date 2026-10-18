#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 3
url=$1
digest=$2
destination=$3
if ! [[ "$digest" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'FAIL: pinned archive digest must be lowercase SHA-256' >&2
  exit 2
fi
cache=${CAIRN_ARCHIVE_CACHE:-}
if [ -n "$cache" ] && [ -f "$cache/$digest" ]; then
  cp -c "$cache/$digest" "$destination"
else
  curl --fail --silent --show-error --location "$url" -o "$destination"
fi
# Cached and downloaded archives pass the same pinned checksum before use.
printf '%s  %s\n' "$digest" "$destination" | shasum -a 256 --check
if [ -n "$cache" ] && [ ! -e "$cache/$digest" ]; then
  mkdir -p "$cache"
  cp -c "$destination" "$cache/$digest"
fi
