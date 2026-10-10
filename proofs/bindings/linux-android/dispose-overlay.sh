#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run on Fedora as root after authorized proof-overlay disposal' >&2
  exit 2
fi
directory=/var/lib/libvirt/images/cairn-proof-offline
evidence=/var/lib/cairn-proof-evidence/protected-replay-journal
test "$(virsh -c qemu:///system domstate cairn-proof-offline)" = 'shut off'
test -f "$directory/run.qcow2"
test ! -L "$directory/run.qcow2"
sha256sum --check "$evidence/boot-proof.sha256"
sha256sum --check "$evidence/images-before.sha256"
grep -F 'PASS: cold disposable guest build and fresh Android runtime' \
  "$evidence/boot-proof.txt"
virsh -c qemu:///system dumpxml --inactive cairn-proof-offline \
  > "$evidence/domain-before-disposal.xml"
virsh -c qemu:///system undefine cairn-proof-offline
rm -- "$directory/run.qcow2"
test ! -e "$directory/run.qcow2"
if virsh -c qemu:///system list --all --name | grep -Fx 'cairn-proof-offline'; then
  echo 'FAIL: proof domain still registered' >&2
  exit 1
fi
sha256sum --check "$directory/base.sha256"
echo 'PASS: authorized proof domain and overlay disposed; base and journal retained'
