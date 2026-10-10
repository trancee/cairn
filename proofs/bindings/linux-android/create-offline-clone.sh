#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run on Fedora as root after cleanly shutting down cairn-prep' >&2
  exit 2
fi
export LC_ALL=C
name=cairn-proof-offline
directory=/var/lib/libvirt/images/cairn-proof-offline
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
python3 - "$directory" <<'XML'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

directory = Path(sys.argv[1])
root = ET.parse(directory / "preparation.xml").getroot()
root.attrib.pop("id", None)
root.find("name").text = "cairn-proof-offline"
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
virsh -c qemu:///system start "$name" --console
