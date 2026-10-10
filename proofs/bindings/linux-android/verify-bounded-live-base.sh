#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run on Fedora as root after authorized paused proof restart' >&2
  exit 2
fi
name=cairn-proof-bounded
directory=/var/lib/libvirt/images/cairn-proof-bounded
test "$(virsh -c qemu:///system domstate "$name")" = 'shut off'
sha256sum --check "$directory/base.sha256"
test "$(stat -c '%U:%G %a' "$directory/base.qcow2")" = 'root:qemu 640'
virsh -c qemu:///system start "$name" --paused
# Any failed check leaves the guest paused, before target-controlled execution.
test "$(virsh -c qemu:///system domstate "$name")" = paused
stat -c '%U:%G %a %n' "$directory/base.qcow2"
test "$(stat -c '%U:%G %a' "$directory/base.qcow2")" = 'root:qemu 640'
sudo -u qemu /usr/bin/python3 - <<'PROBE'
import errno
import os

path = "/var/lib/libvirt/images/cairn-proof-bounded/base.qcow2"
try:
    descriptor = os.open(path, os.O_WRONLY)
except OSError as error:
    if error.errno != errno.EACCES:
        raise
    print("PASS: QEMU cannot open bounded base for writing before guest execution")
else:
    os.close(descriptor)
    raise SystemExit("FAIL: bounded base writable; guest remains paused")
PROBE
sha256sum --check "$directory/base.sha256"
virsh -c qemu:///system resume "$name"
virsh -c qemu:///system console "$name"
