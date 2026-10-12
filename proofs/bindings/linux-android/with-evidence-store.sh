#!/usr/bin/env bash
set -euo pipefail

store=/var/lib/cairn-proof-evidence/bounded-store
scripts="$(cd "$(dirname "$0")" && pwd)"
if [ "$(id -u)" -ne 0 ] || [ "$#" -eq 0 ]; then
  echo 'Usage: sudo bash with-evidence-store.sh COMMAND [ARG...]' >&2
  exit 2
fi
if [ ! -e "$store.ext4" ]; then
  if [ ! -d "$(dirname "$store")" ]; then
    mkdir -m 0700 "$(dirname "$store")"
  fi
  bash "$scripts/bounded-evidence.sh" --profile store "$store" \
    /bin/bash -c 'printf "cairn bounded evidence store\n" > store.identity'
fi
grep -Fx COMPLETE "$store.status"
test "$(stat -c '%u:%g %a %s' "$store.ext4")" = '0:0 600 8589934592'
if mountpoint -q "$store"; then
  echo 'FAIL: evidence store already mounted; refusing concurrent work' >&2
  exit 2
fi
mount -o loop,nosuid,nodev,noexec "$store.ext4" "$store"
finish() {
  result=$?
  trap - EXIT
  if ! umount "$store"; then
    echo 'FAIL: evidence store could not be unmounted' >&2
    exit 1
  fi
  exit "$result"
}
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
grep -Fx 'cairn bounded evidence store' "$store/store.identity"
(
  cd "$store"
  "$@"
)
