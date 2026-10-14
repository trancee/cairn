"""Detach an owned resource-fixture volume without trusting diagnostic success."""

import json
import plistlib
import re
import subprocess
import sys
from xml.parsers.expat import ExpatError


def detach_scratch(volume: str) -> int:
    if not re.fullmatch(r"/private/tmp/cairn-resource-[A-Za-z0-9]+/scratch", volume):
        print("FAIL: invalid owned scratch volume", file=sys.stderr)
        return 1
    try:
        detached = subprocess.run(["/usr/bin/hdiutil", "detach", "-verbose", volume])
    except OSError as error:
        print(f"FAIL: scratch detach command unavailable: {type(error).__name__}", file=sys.stderr)
    else:
        if detached.returncode == 0:
            return 0
        print("FAIL: scratch detach failed", file=sys.stderr)
    try:
        result = subprocess.run(
            ["/usr/sbin/diskutil", "info", "-plist", volume],
            capture_output=True, check=True, timeout=5,
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
    print("DIAGNOSTIC: failed scratch detach; open-file holder PIDs and command names only")
    try:
        holders = subprocess.run(
            ["/usr/sbin/lsof", "-nP", "-Fpc", "+f", "--", volume],
            capture_output=True, text=True, check=True, timeout=15,
        )
        print(holders.stdout, end="")
    except (OSError, subprocess.SubprocessError, UnicodeError) as error:
        print(f"DIAGNOSTIC: open-file holder collection failed: {type(error).__name__}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: detach-scratch.py VOLUME")
    raise SystemExit(detach_scratch(sys.argv[1]))
