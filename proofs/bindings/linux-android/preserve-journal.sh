#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run on Fedora as root with the proof clone stopped' >&2
  exit 2
fi
if [ "$#" -gt 1 ]; then
  echo 'Usage: preserve-journal.sh [canonical|bounded]' >&2
  exit 2
fi
case "${1:-}" in
  '') name=cairn-proof-offline; output=/var/lib/cairn-proof-evidence/protected-replay-journal ;;
  canonical) name=cairn-proof-canonical; output=/var/lib/cairn-proof-evidence/canonical-replay-journal ;;
  bounded) name=cairn-proof-bounded; output=/var/lib/cairn-proof-evidence/bounded-replay-journal-live-verified ;;
  *) echo 'Unknown proof selection' >&2; exit 2 ;;
esac
directory="/var/lib/libvirt/images/$name"
test "$(virsh -c qemu:///system domstate "$name")" = 'shut off'
command -v guestfish >/dev/null
test ! -e "$output"
umask 077
install -d -o root -g root -m 0700 "$output"
sha256sum --check "$directory/base.sha256"
sha256sum "$directory/base.qcow2" "$directory/run.qcow2" > "$output/images-before.sha256"
stat -c '%u:%g %a %n' "$directory/base.qcow2" "$directory/run.qcow2" \
  > "$output/image-permissions-before.txt"
# The appliance has no network enabled; guest filesystems are not host-mounted.
LIBGUESTFS_BACKEND=direct timeout 300 guestfish --ro --format=qcow2 -a "$directory/run.qcow2" -i \
  copy-out /var/log/journal "$output"
if [ "$name" = cairn-proof-bounded ]; then
  LIBGUESTFS_BACKEND=direct timeout 300 guestfish --ro --format=qcow2 -a "$directory/run.qcow2" -i \
    copy-out /var/lib/cairn-proof-logs "$output"
  (
    cd "$output/cairn-proof-logs"
    for log in replay-*.log; do
      test -f "$log"
      test "$(stat -c %s "$log")" -le 67108864
      # The saved checksum refers to the original guest path.
      expected=$(awk '{print $1}' "$log.sha256")
      printf '%s  %s\n' "$expected" "$log" | sha256sum --check
      for marker in \
        'PASS: effective build cgroup and inherited resource limits' \
        'PASS: effective runtime cgroup and inherited resource limits' \
        'PASS: cold disposable guest build and fresh Android runtime'; do
        grep -F "$marker" "$log"
      done
    done
  )
fi
journalctl --directory="$output/journal" --no-pager -o short-monotonic \
  --unit=cairn-disposable-boot-proof.service > "$output/boot-proof.txt"
grep -F 'PASS: cold disposable guest build and fresh Android runtime' \
  "$output/boot-proof.txt"
if [ "$name" = cairn-proof-canonical ] || [ "$name" = cairn-proof-bounded ]; then
  journalctl --directory="$output/journal" --no-pager -o short-monotonic |
    grep -F \
      -e 'PASS: source/configuration and downloaded dependency inputs are read-only' \
      -e 'PASS: complete input mapping resolves to canonical read-only objects; project shells writable' \
      -e 'PASS: canonical input manifest unchanged after build' > "$output/input-probes.txt"
  for marker in \
    'PASS: source/configuration and downloaded dependency inputs are read-only' \
    'PASS: complete input mapping resolves to canonical read-only objects; project shells writable' \
    'PASS: canonical input manifest unchanged after build'; do
    grep -F "$marker" "$output/input-probes.txt"
  done
  sha256sum "$output/input-probes.txt" > "$output/input-probes.sha256"
fi
sha256sum --check "$output/images-before.sha256"
stat -c '%u:%g %a %n' "$directory/base.qcow2" "$directory/run.qcow2" \
  > "$output/image-permissions-after.txt"
cmp "$output/image-permissions-before.txt" "$output/image-permissions-after.txt"
sha256sum "$output/boot-proof.txt" > "$output/boot-proof.sha256"
echo "PASS: read-only proof journal preserved at $output"
