#!/usr/bin/env bash
set -euo pipefail
scripts="$(cd "$(dirname "$0")" && pwd)"
if [ "$(id -u)" -ne 0 ]; then
  echo 'Run disk-identity tests as root on a disposable Linux guest' >&2
  exit 2
fi
work=$(mktemp -d /var/lib/cairn-log-identity-test-XXXXXXXX)
fallocate -l 1073741824 "$work/logs.ext4"
mkfs.ext4 -q -m 0 -L CAIRN_PROOF_LOGS "$work/logs.ext4"
device=$(losetup --find --show "$work/logs.ext4")
second=
cleanup() {
  if [ -n "$second" ]; then
    losetup -d "$second"
  fi
  if [ -n "$device" ]; then
    losetup -d "$device"
  fi
}
trap cleanup EXIT
actual=$(bash "$scripts/resolve-proof-log-disk.sh")
test "$actual" = "$device"
echo 'PASS: proof-log identity resolves independently of vda/vdb enumeration'
fallocate -l 67108864 "$work/wrong-size.ext4"
mkfs.ext4 -q -m 0 -L CAIRN_PROOF_LOGS "$work/wrong-size.ext4"
second=$(losetup --find --show "$work/wrong-size.ext4")
if bash "$scripts/resolve-proof-log-disk.sh"; then
  echo 'FAIL: ambiguous labelled disks were accepted' >&2
  exit 1
fi
losetup -d "$device"
device=
if bash "$scripts/resolve-proof-log-disk.sh"; then
  echo 'FAIL: wrong-size labelled disk was accepted' >&2
  exit 1
fi
losetup -d "$second"
second=
if bash "$scripts/resolve-proof-log-disk.sh"; then
  echo 'FAIL: missing labelled disk was accepted' >&2
  exit 1
fi
echo 'PASS: ambiguous, wrong-size and missing proof-log disks fail closed'
