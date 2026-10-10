#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run on Fedora as root after cleanly shutting down cairn-prep' >&2
  exit 2
fi
export LC_ALL=C
if [ "$#" -gt 1 ]; then
  echo 'Usage: create-offline-clone.sh [canonical|bounded|retention|retention-v2|retention-v3|retention-v4]' >&2
  exit 2
fi
case "${1:-}" in
  '') name=cairn-proof-offline ;;
  canonical) name=cairn-proof-canonical ;;
  bounded) name=cairn-proof-bounded ;;
  retention) name=cairn-proof-retention ;;
  retention-v2) name=cairn-proof-retention-v2 ;;
  retention-v3) name=cairn-proof-retention-v3 ;;
  retention-v4) name=cairn-proof-retention-v4 ;;
  *) echo 'Unknown proof selection' >&2; exit 2 ;;
esac
directory="/var/lib/libvirt/images/$name"
source=/var/lib/libvirt/images/cairn-prep/prep.qcow2
test "$(virsh -c qemu:///system domstate cairn-prep)" = 'shut off'
test ! -e "$directory"
if virsh -c qemu:///system dominfo "$name" >/dev/null 2>&1; then
  echo 'Proof domain already exists; refusing reuse' >&2
  exit 2
fi
install -d -o root -g qemu -m 0750 "$directory"
virsh -c qemu:///system dumpxml --inactive cairn-prep > "$directory/preparation.xml"
qemu-img convert -p -f qcow2 -O qcow2 "$source" "$directory/base.qcow2"
qemu-img check "$directory/base.qcow2"
chown root:qemu "$directory/base.qcow2"
chmod 0640 "$directory/base.qcow2"
qemu-img create -f qcow2 -F qcow2 -b "$directory/base.qcow2" "$directory/run.qcow2"
chown root:qemu "$directory/run.qcow2"
chmod 0660 "$directory/run.qcow2"
if [[ "$name" = cairn-proof-retention* ]]; then
  fallocate -l 1073741824 "$directory/proof-logs.ext4"
  mkfs.ext4 -q -m 0 -L CAIRN_PROOF_LOGS "$directory/proof-logs.ext4"
  chown root:qemu "$directory/proof-logs.ext4"
  chmod 0660 "$directory/proof-logs.ext4"
fi
python3 - "$directory" "$name" <<'XML'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

directory = Path(sys.argv[1])
root = ET.parse(directory / "preparation.xml").getroot()
root.attrib.pop("id", None)
root.find("name").text = sys.argv[2]
for child in list(root):
    if child.tag in {"uuid", "genid", "seclabel"}:
        root.remove(child)
devices = root.find("devices")
disks = [node for node in devices.findall("disk") if node.get("device") == "disk"]
assert len(disks) == 1
disk = disks[0]
disk.find("source").attrib = {"file": str(directory / "run.qcow2")}
for existing in list(disk.findall("backingStore")):
    disk.remove(existing)
backing = ET.SubElement(disk, "backingStore", {"type": "file"})
ET.SubElement(backing, "format", {"type": "qcow2"})
base = ET.SubElement(backing, "source", {"file": str(directory / "base.qcow2")})
ET.SubElement(base, "seclabel", {"model": "dac", "relabel": "no"})
ET.SubElement(backing, "backingStore")
if sys.argv[2] in {"cairn-proof-retention", "cairn-proof-retention-v2", "cairn-proof-retention-v3", "cairn-proof-retention-v4"}:
    logs = ET.SubElement(devices, "disk", {"type": "file", "device": "disk"})
    ET.SubElement(logs, "driver", {"name": "qemu", "type": "raw"})
    ET.SubElement(logs, "source", {"file": str(directory / "proof-logs.ext4")})
    ET.SubElement(logs, "target", {"dev": "vdb", "bus": "virtio"})
for child in list(devices):
    if child.tag in {"interface", "filesystem", "channel", "hostdev"}:
        devices.remove(child)
    elif child.tag == "disk" and child.get("device") == "cdrom":
        devices.remove(child)
    elif child.tag in {"serial", "console"}:
        child.attrib.pop("tty", None)
        for source in list(child.findall("source")):
            child.remove(source)
for parent in root.iter():
    for alias in list(parent.findall("alias")):
        parent.remove(alias)
assert not devices.findall("interface")
assert not devices.findall("filesystem")
ET.ElementTree(root).write(directory / "proof.xml", encoding="unicode")
XML
chmod 0600 "$directory/"*.xml
restorecon -RF "$directory"
sha256sum "$directory/base.qcow2" > "$directory/base.sha256"
virsh -c qemu:///system define --validate "$directory/proof.xml"
# The base is an independent conversion, not the original prep disk.
virsh -c qemu:///system start cairn-prep
echo 'Original preparation guest restarted; starting networkless proof clone'
if [[ "$name" = cairn-proof-retention* ]]; then
  virsh -c qemu:///system start "$name" --paused
  test "$(stat -c '%U:%G %a' "$directory/base.qcow2")" = 'root:qemu 640'
  sha256sum --check "$directory/base.sha256"
  runuser -u qemu -- python3 - "$directory/base.qcow2" <<'DENIAL'
import errno
import os
import sys
try:
    descriptor = os.open(sys.argv[1], os.O_WRONLY)
except OSError as error:
    if error.errno != errno.EACCES:
        raise
else:
    os.close(descriptor)
    raise SystemExit("FAIL: QEMU can open the base for writing")
print("PASS: paused retention clone base write denied")
DENIAL
  virsh -c qemu:///system resume "$name"
  virsh -c qemu:///system console "$name"
else
  virsh -c qemu:///system start "$name" --console
fi
