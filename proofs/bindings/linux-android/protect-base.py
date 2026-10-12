#!/usr/bin/env python3
"""Prepare a DAC-only override for the dedicated offline proof base."""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def protect_base(root: ET.Element) -> None:
    directory = "/var/lib/libvirt/images/cairn-proof-offline"
    devices = root.find("devices")
    if root.findtext("name") != "cairn-proof-offline" or devices is None:
        raise ValueError("Expected the dedicated offline proof domain")
    if any(devices.findall(tag) for tag in ("interface", "filesystem", "hostdev", "channel")):
        raise ValueError("Unexpected networking, sharing or passthrough")
    disks = devices.findall("disk")
    if len(disks) != 1 or disks[0].get("device") != "disk":
        raise ValueError("Expected exactly one proof disk")
    disk = disks[0]
    source = disk.find("source")
    if source is None or source.get("file") != f"{directory}/run.qcow2":
        raise ValueError("Unexpected overlay path")
    if disk.find("backingStore") is not None:
        raise ValueError("Existing backing-store override requires explicit review")
    backing = ET.SubElement(disk, "backingStore", {"type": "file"})
    ET.SubElement(backing, "format", {"type": "qcow2"})
    base = ET.SubElement(backing, "source", {"file": f"{directory}/base.qcow2"})
    ET.SubElement(base, "seclabel", {"model": "dac", "relabel": "no"})
    ET.SubElement(backing, "backingStore")


if __name__ == "__main__":
    tree = ET.parse(sys.argv[1])
    protect_base(tree.getroot())
    with Path(sys.argv[2]).open("x", encoding="utf-8") as output:
        tree.write(output, encoding="unicode")
