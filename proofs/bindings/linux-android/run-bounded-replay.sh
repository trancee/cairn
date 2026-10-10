#!/usr/bin/env bash
set -euo pipefail

saved=/opt/cairn-binding-seeds/final-image-inputs-e75437d
logs=/var/lib/cairn-proof-logs
if [ "$(id -u)" -ne 0 ]; then
  echo 'Run trusted bounded replay supervisor as root' >&2
  exit 2
fi
install -d -o root -g root -m 0700 "$logs"
output="$logs/replay-$(cat /proc/sys/kernel/random/boot_id).log"
(cd "$saved" && sha256sum --check replay-scripts.sha256)
if python3 "$saved/bounded-proof.py" --reserve "$output" /bin/bash "$saved/replay-disposable-guest.sh"; then
  sha256sum "$output" > "$output.sha256"
else
  result=$?
  for unit in cairn-binding-proof-build.service cairn-isolated-android-proof.service; do
    if systemctl is-active --quiet "$unit"; then
      systemctl stop "$unit"
    fi
  done
  echo 'FAIL: bounded replay failed; logs retained, proof units stopped' >&2
  exit "$result"
fi
