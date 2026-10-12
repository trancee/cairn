#!/usr/bin/env bash
set -euo pipefail
test "$(id -u)" -eq 0
scripts="$(cd "$(dirname "$0")" && pwd)"
socket=/etc/systemd/system/cairn-synthetic-cutover.socket
service=/etc/systemd/system/cairn-synthetic-cutover.service
failed_service=/etc/systemd/system/cairn-synthetic-failed.service
address=/run/cairn-synthetic-cutover.sock
test ! -e "$socket" && test ! -L "$socket"
test ! -e "$service" && test ! -L "$service"
test ! -e "$address"
test ! -e "$failed_service" && test ! -L "$failed_service"
evidence=$(mktemp -d /var/lib/cairn-startup-capture-test-XXXXXXXX)
cleanup() {
  result=$?
  trap - EXIT
  systemctl stop cairn-synthetic-cutover.socket cairn-synthetic-cutover.service cairn-synthetic-failed.service || result=1
  if [ "$(systemctl show cairn-synthetic-failed.service -p ActiveState --value)" = failed ]; then
    systemctl reset-failed cairn-synthetic-failed.service || result=1
  fi
  systemctl unmask --runtime cairn-synthetic-cutover.socket cairn-synthetic-cutover.service cairn-synthetic-failed.service || result=1
  rm -- "$socket" "$service" "$failed_service"
  systemctl daemon-reload || result=1
  exit "$result"
}
trap cleanup EXIT
cat > "$socket" <<'SOCKET'
[Socket]
ListenStream=/run/cairn-synthetic-cutover.sock
RemoveOnStop=yes
SOCKET
cat > "$service" <<'SERVICE'
[Service]
ExecStart=/usr/bin/sleep infinity
SERVICE
cat > "$failed_service" <<'FAILED'
[Service]
Type=oneshot
ExecStart=/usr/bin/false
FAILED
systemctl daemon-reload
systemctl start cairn-synthetic-cutover.socket
python3 - <<'ACTIVATE'
import socket
with socket.socket(socket.AF_UNIX) as connection:
    connection.connect("/run/cairn-synthetic-cutover.sock")
ACTIVATE
systemctl start cairn-synthetic-cutover.service
systemctl is-active --quiet cairn-synthetic-cutover.socket cairn-synthetic-cutover.service
bash "$scripts/stop-and-mask-units.sh" cairn-synthetic-cutover.socket cairn-synthetic-cutover.service
test ! -e "$address"
echo 'PASS: socket-activated service and trigger stop together and remain runtime-masked'
if systemctl start cairn-synthetic-failed.service; then
  echo 'FAIL: synthetic failing service unexpectedly succeeded' >&2
  exit 1
fi
test "$(systemctl show cairn-synthetic-failed.service -p ActiveState --value)" = failed
python3 "$scripts/bounded-proof.py" --reserve "$evidence/startup.log" \
  /bin/bash "$scripts/stop-and-mask-units.sh" cairn-synthetic-failed.service
test -f "$evidence/startup.log"
grep -Fx 'ActiveState=failed' "$evidence/startup.log"
grep -Fx 'Result=exit-code' "$evidence/startup.log"
echo 'PASS: failed unit diagnostics captured before deliberate shutdown-state normalization'
if python3 "$scripts/bounded-proof.py" --reserve "$evidence/startup-failed.log" \
  /bin/bash "$scripts/stop-and-mask-units.sh"; then
  echo 'FAIL: missing unit argument unexpectedly accepted' >&2
  exit 1
else
  test "$?" -eq 2
fi
grep -F 'Usage:' "$evidence/startup-failed.log"
test "$(stat -c %s "$evidence/startup-failed.log")" -le 67108864
echo "PASS: successful and failed startup diagnostics retained at $evidence"
