#!/usr/bin/env bash
set -euo pipefail
mapfile -t devices < <(blkid -c /dev/null -t LABEL=CAIRN_PROOF_LOGS -o device)
if [ "${#devices[@]}" -ne 1 ]; then
  echo 'FAIL: exactly one labelled proof-log filesystem is required' >&2
  exit 2
fi
device=${devices[0]}
if [ "$(blkid -c /dev/null -s TYPE -o value "$device")" != ext4 ] ||
   [ "$(blockdev --getsize64 "$device")" -ne 1073741824 ]; then
  echo 'FAIL: labelled proof-log disk must be a 1 GiB ext4 filesystem' >&2
  exit 2
fi
printf '%s\n' "$device"
