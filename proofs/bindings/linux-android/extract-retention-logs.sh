#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
if [ "$(id -u)" -ne 0 ] || [ "$#" -ne 1 ]; then
  echo 'Usage: extract-retention-logs.sh retention|retention-v2|retention-v3|retention-v4 (inside bounded evidence volume)' >&2
  exit 2
fi
case "$1" in
  retention) name=cairn-proof-retention ;;
  retention-v2) name=cairn-proof-retention-v2 ;;
  retention-v3) name=cairn-proof-retention-v3 ;;
  retention-v4) name=cairn-proof-retention-v4 ;;
  *) echo 'FAIL: unknown retention clone' >&2; exit 2 ;;
esac
directory="/var/lib/libvirt/images/$name"
test "$(virsh -c qemu:///system domstate "$name")" = 'shut off'
mountpoint -q .
umask 077
sha256sum --check "$directory/base.sha256"
sha256sum "$directory/base.qcow2" "$directory/run.qcow2" "$directory/proof-logs.ext4" \
  > images-before.sha256
stat -c '%u:%g %a %n' "$directory/base.qcow2" "$directory/run.qcow2" "$directory/proof-logs.ext4" \
  > image-permissions-before.txt
LIBGUESTFS_BACKEND=direct timeout 300 guestfish --ro --format=raw \
  -a "$directory/proof-logs.ext4" -m /dev/sda tar-out / "$PWD/logs.tar"
mkdir -m 0700 cairn-proof-logs
tar --no-same-owner -xf logs.tar -C cairn-proof-logs
rm -- logs.tar
for log in cairn-proof-logs/replay-*.log; do
  test -f "$log"
  test "$(stat -c %s "$log")" -le 67108864
  expected=$(awk '{print $1}' "$log.sha256")
  printf '%s  %s\n' "$expected" "$log" | sha256sum --check
  if [ "$1" = retention-v4 ]; then
    startup="${log/replay-/startup-}"
    test -f "$startup"
    test "$(stat -c %s "$startup")" -le 67108864
    expected=$(awk '{print $1}' "$startup.sha256")
    printf '%s  %s\n' "$expected" "$startup" | sha256sum --check
    grep -F 'PASS: proof logs authoritative; system diagnostics volatile; persistent duplicates disabled' "$startup"
  fi
  for marker in \
    'PASS: effective build cgroup and inherited resource limits' \
    'PASS: effective runtime cgroup and inherited resource limits' \
    'PASS: cold disposable guest build and fresh Android runtime' \
    'PASS: authoritative guest proof-log filesystem capacity' \
    'PASS: proof logs authoritative' \
    'Android emulator version'; do
    grep -F "$marker" "$log"
  done
done
sha256sum --check images-before.sha256
stat -c '%u:%g %a %n' "$directory/base.qcow2" "$directory/run.qcow2" "$directory/proof-logs.ext4" \
  > image-permissions-after.txt
cmp image-permissions-before.txt image-permissions-after.txt
echo 'PASS: authoritative retention replay records extracted with image bytes/metadata unchanged'
