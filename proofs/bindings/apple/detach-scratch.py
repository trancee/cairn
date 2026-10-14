"""Detach an owned resource-fixture volume without trusting diagnostic success."""

import json
import plistlib
import re
import subprocess
import sys
import time
from xml.parsers.expat import ExpatError


class DiagnosticError(ValueError):
    pass


def remaining_seconds(deadline: float) -> float:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise DiagnosticError("diagnostic-deadline-exhausted")
    return remaining


def owned_image_entities(inventory: object, image: str, volume: str) -> tuple[list[str], list[str]]:
    if not isinstance(inventory, dict) or not isinstance(inventory.get("images"), list):
        raise DiagnosticError("invalid-image-inventory")
    matches = [
        entry for entry in inventory["images"]
        if isinstance(entry, dict) and entry.get("image-path") == image
    ]
    if not matches:
        raise DiagnosticError("owned-image-not-attached")
    if len(matches) != 1:
        raise DiagnosticError("ambiguous-owned-image")
    entities = matches[0].get("system-entities")
    if not isinstance(entities, list) or not entities:
        raise DiagnosticError("invalid-owned-image-entities")
    devices, mounts, whole_disks = [], [], set()
    for entity in entities:
        if not isinstance(entity, dict) or not isinstance(entity.get("dev-entry"), str):
            raise DiagnosticError("invalid-owned-image-device")
        device = entity["dev-entry"]
        match = re.fullmatch(r"(/dev/disk[0-9]+)(?:s[0-9]+)*", device)
        if match is None or device in devices:
            raise DiagnosticError("invalid-owned-image-device")
        whole_disks.add(match.group(1))
        devices.append(device)
        mount = entity.get("mount-point")
        if mount not in (None, "", volume):
            raise DiagnosticError("unexpected-owned-image-mount")
        if mount == volume:
            mounts.append(volume)
    if len(whole_disks) != 1:
        raise DiagnosticError("ambiguous-owned-image-devices")
    return devices, mounts


def print_holder_fields(output: str) -> None:
    if any(
        not re.fullmatch(r"p[0-9]+", line)
        and not (line.startswith("c") and len(line) > 1 and line[1:].isprintable())
        for line in output.splitlines()
    ):
        raise DiagnosticError("invalid-holder-fields")
    print(output, end="")


def detach_scratch(volume: str, image: str) -> int:
    if not re.fullmatch(r"/private/tmp/cairn-resource-[A-Za-z0-9]+/scratch", volume):
        print("FAIL: invalid owned scratch volume", file=sys.stderr)
        return 1
    directory = volume.rsplit("/", 1)[0]
    if image not in (directory + "/scratch.dmg", directory + "/build-scratch.dmg"):
        print("FAIL: invalid owned scratch image", file=sys.stderr)
        return 1
    try:
        detached = subprocess.run(["/usr/bin/hdiutil", "detach", "-verbose", volume])
    except OSError as error:
        print(f"FAIL: scratch detach command unavailable: {type(error).__name__}", file=sys.stderr)
    else:
        if detached.returncode == 0:
            return 0
        print("FAIL: scratch detach failed", file=sys.stderr)
    metadata_deadline = time.monotonic() + 5
    try:
        result = subprocess.run(
            ["/usr/sbin/diskutil", "info", "-plist", volume],
            capture_output=True, check=True, timeout=remaining_seconds(metadata_deadline),
        )
        information = plistlib.loads(result.stdout)
        if not isinstance(information, dict):
            raise ValueError("invalid disk information")
        state = {
            key: information.get(key) for key in
            ("DeviceIdentifier", "ParentWholeDisk", "Mounted", "MountPoint", "Ejectable")
        }
        for key, value in state.items():
            expected_type = bool if key in ("Mounted", "Ejectable") else str
            if value is not None and not isinstance(value, expected_type):
                raise ValueError("invalid disk information field")
        print("DIAGNOSTIC: scratch detach state " + json.dumps(state))
    except (
        OSError, subprocess.SubprocessError, ValueError, plistlib.InvalidFileException, ExpatError,
    ) as error:
        print(f"DIAGNOSTIC: scratch detach state unavailable: {type(error).__name__}", file=sys.stderr)
    devices = []
    try:
        inventory = subprocess.run(
            ["/usr/bin/hdiutil", "info", "-plist"],
            capture_output=True, check=True, timeout=remaining_seconds(metadata_deadline),
        )
        devices, mounts = owned_image_entities(plistlib.loads(inventory.stdout), image, volume)
        print("DIAGNOSTIC: owned scratch image devices " + json.dumps(devices))
        print("DIAGNOSTIC: owned scratch image reported mount points " + json.dumps(mounts))
    except (
        OSError, subprocess.SubprocessError, ValueError, plistlib.InvalidFileException, ExpatError,
    ) as error:
        reason = str(error) if isinstance(error, DiagnosticError) else type(error).__name__
        print(f"DIAGNOSTIC: owned scratch image unavailable: {reason}", file=sys.stderr)
    print("DIAGNOSTIC: failed scratch detach; open-file holder PIDs and command names only")
    holder_deadline = time.monotonic() + 15
    for label, selection in (
        ("scratch filesystem", ["+f", "--", volume]),
        ("owned scratch image/device", ["--", image, *devices]),
    ):
        print(f"DIAGNOSTIC: {label} holder identities")
        try:
            holders = subprocess.run(
                ["/usr/sbin/lsof", "-nP", "-Fpc", *selection],
                capture_output=True, text=True, check=False,
                timeout=remaining_seconds(holder_deadline),
            )
            print_holder_fields(holders.stdout)
            if holders.returncode:
                raise DiagnosticError("holder-query-nonzero")
        except (OSError, subprocess.SubprocessError, UnicodeError, ValueError) as error:
            reason = str(error) if isinstance(error, DiagnosticError) else type(error).__name__
            print(f"DIAGNOSTIC: open-file holder collection failed: {reason}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: detach-scratch.py VOLUME IMAGE")
    raise SystemExit(detach_scratch(sys.argv[1], sys.argv[2]))
