#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ] || [ "$#" -lt 2 ]; then
  echo 'Usage: sudo bash extract-with-scratch.sh OUTPUT COMMAND [ARG...]' >&2
  exit 2
fi
output=$1
shift
scripts="$(cd "$(dirname "$0")" && pwd)"
store=/var/lib/cairn-proof-evidence/bounded-store
mountpoint -q "$store"
test "$(dirname "$output")" = "$store"
scratch="$store/appliance-$(cat /proc/sys/kernel/random/uuid)"
if bash "$scripts/bounded-evidence.sh" --profile appliance "$scratch" \
  /usr/bin/env TMPDIR="$scratch" LIBGUESTFS_TMPDIR="$scratch" \
  LIBGUESTFS_CACHEDIR="$scratch" \
  /bin/bash "$scripts/bounded-evidence.sh" "$output" "$@"; then
  grep -Fx COMPLETE "$scratch.status"
  if mountpoint -q "$scratch"; then
    echo 'FAIL: appliance scratch still mounted; retaining image' >&2
    exit 1
  fi
  rm -- "$scratch.ext4" "$scratch.status"
  rmdir "$scratch"
  echo 'PASS: disposable appliance scratch removed after successful extraction'
else
  result=$?
  echo 'FAIL: appliance scratch and partial extraction retained inside aggregate store' >&2
  exit "$result"
fi
