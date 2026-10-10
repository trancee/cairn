#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run on Fedora as root after authorized proof-overlay disposal' >&2
  exit 2
fi
if [ "$#" -gt 1 ]; then
  echo 'Usage: dispose-overlay.sh [canonical]' >&2
  exit 2
fi
case "${1:-}" in
  '') name=cairn-proof-offline; evidence=/var/lib/cairn-proof-evidence/protected-replay-journal ;;
  canonical) name=cairn-proof-canonical; evidence=/var/lib/cairn-proof-evidence/canonical-replay-journal ;;
  *) echo 'Unknown proof selection' >&2; exit 2 ;;
esac
directory="/var/lib/libvirt/images/$name"
store=/var/lib/cairn-proof-evidence/bounded-store
if [ -e "$store.ext4" ]; then
  if ! mountpoint -q "$store"; then
    echo 'FAIL: open the bounded evidence store before disposal checks' >&2
    exit 2
  fi
  stored="$store/$(basename "$evidence")-volume"
  if [ -e "$stored.status" ]; then
    evidence="$stored"
    grep -Fx COMPLETE "$evidence.status"
    mountpoint -q "$evidence"
  fi
fi
if [ -e "$evidence-volume.status" ]; then
  evidence="$evidence-volume"
  grep -Fx COMPLETE "$evidence.status"
  if ! mountpoint -q "$evidence"; then
    echo 'FAIL: mount the complete bounded evidence volume before disposal checks' >&2
    exit 2
  fi
fi
test "$(virsh -c qemu:///system domstate "$name")" = 'shut off'
test -f "$directory/run.qcow2"
test ! -L "$directory/run.qcow2"
sha256sum --check "$evidence/boot-proof.sha256"
sha256sum --check "$evidence/images-before.sha256"
if [ "$name" = cairn-proof-canonical ]; then
  sha256sum --check "$evidence/input-probes.sha256"
  for marker in \
    'PASS: source/configuration and downloaded dependency inputs are read-only' \
    'PASS: complete input mapping resolves to canonical read-only objects; project shells writable' \
    'PASS: canonical input manifest unchanged after build'; do
    grep -F "$marker" "$evidence/input-probes.txt"
  done
fi
grep -F 'PASS: cold disposable guest build and fresh Android runtime' \
  "$evidence/boot-proof.txt"
virsh -c qemu:///system dumpxml --inactive "$name" \
  > "$evidence/domain-before-disposal.xml"
virsh -c qemu:///system undefine "$name"
rm -- "$directory/run.qcow2"
test ! -e "$directory/run.qcow2"
if virsh -c qemu:///system list --all --name | grep -Fx "$name"; then
  echo 'FAIL: proof domain still registered' >&2
  exit 1
fi
sha256sum --check "$directory/base.sha256"
echo 'PASS: authorized proof domain and overlay disposed; base and journal retained'
