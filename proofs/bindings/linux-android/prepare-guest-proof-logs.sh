#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run guest proof-log preparation as root in the new networkless clone' >&2
  exit 2
fi
python3 - <<'NETWORK'
from pathlib import Path
assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}
NETWORK
saved=/opt/cairn-binding-seeds/final-image-inputs-e75437d
image=$(bash "$saved/resolve-proof-log-disk.sh")
logs=/var/lib/cairn-proof-logs
if mountpoint -q "$logs"; then
  echo 'FAIL: guest proof-log volume already mounted' >&2
  exit 2
fi
umask 077
test "$(blockdev --getsize64 "$image")" -eq 1073741824
install -d -o root -g root -m 0700 "$logs"
mount -o nosuid,nodev,noexec "$image" "$logs"
chmod 0700 "$logs"
output="$logs/startup-$(cat /proc/sys/kernel/random/boot_id).log"
(cd "$saved" && sha256sum --check replay-scripts.sha256)
if python3 "$saved/bounded-proof.py" --reserve "$output" \
  /bin/bash "$saved/configure-guest-logging.sh"; then
  sha256sum "$output" > "$output.sha256"
else
  result=$?
  echo 'FAIL: guest logging setup failed; bounded startup record retained' >&2
  exit "$result"
fi
