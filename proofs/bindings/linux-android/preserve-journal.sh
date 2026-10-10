#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run on Fedora as root with the proof clone stopped' >&2
  exit 2
fi
directory=/var/lib/libvirt/images/cairn-proof-offline
output=/var/lib/cairn-proof-evidence/protected-replay-journal
test "$(virsh -c qemu:///system domstate cairn-proof-offline)" = 'shut off'
command -v guestfish >/dev/null
test ! -e "$output"
umask 077
install -d -o root -g root -m 0700 "$output"
sha256sum --check "$directory/base.sha256"
sha256sum "$directory/base.qcow2" "$directory/run.qcow2" > "$output/images-before.sha256"
# The appliance has no network enabled; guest filesystems are not host-mounted.
timeout 300 guestfish --ro --format=qcow2 -a "$directory/run.qcow2" -i \
  copy-out /var/log/journal "$output"
journalctl --directory="$output/journal" --no-pager -o short-monotonic \
  --unit=cairn-disposable-boot-proof.service > "$output/boot-proof.txt"
grep -F 'PASS: cold disposable guest build and fresh Android runtime' \
  "$output/boot-proof.txt"
sha256sum --check "$output/images-before.sha256"
sha256sum "$output/boot-proof.txt" > "$output/boot-proof.sha256"
echo "PASS: read-only proof journal preserved at $output"
