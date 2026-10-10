#!/usr/bin/env bash
set -euo pipefail
if [ "$(id -u)" -ne 0 ] || [ "$#" -eq 0 ]; then
  echo 'Usage: sudo bash stop-and-mask-units.sh UNIT [...]' >&2
  exit 2
fi
for unit in "$@"; do
  systemctl mask --runtime --now "$unit"
  active=$(systemctl show "$unit" -p ActiveState --value)
  if [ "$active" = failed ]; then
    echo "DIAGNOSTIC: preserving prior failure before disabling $unit" >&2
    systemctl show "$unit" -p ActiveState -p SubState -p Result >&2
    systemctl reset-failed "$unit"
    active=$(systemctl show "$unit" -p ActiveState --value)
  fi
  if [ "$active" != inactive ] ||
     [ ! -L "/run/systemd/system/$unit" ] ||
     [ "$(readlink "/run/systemd/system/$unit")" != /dev/null ]; then
    echo "FAIL: unit is not stopped and runtime-masked: $unit (active=$active)" >&2
    exit 1
  fi
done
