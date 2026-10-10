#!/usr/bin/env python3
"""Supervise a command belonging to the disposable hosted probe account."""

import argparse
import os
import pwd
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=float, default=30)
    parser.add_argument("output")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    arguments = parser.parse_args()
    if (os.geteuid() != 0 or os.environ.get("GITHUB_ACTIONS") != "true"
            or not arguments.command or not 0 < arguments.seconds < float("inf")):
        parser.error("Hosted root supervision requires a positive deadline and command")
    account = pwd.getpwnam("cairnbenignprobe")
    if account.pw_uid != 59000 or account.pw_gid != 20 or account.pw_shell != "/usr/bin/false":
        parser.error("Dedicated disabled-login probe account identity does not match")
    collector = Path(__file__).parent.parent / "linux-android" / "bounded-proof.py"
    return subprocess.call([
        sys.executable, str(collector), "--seconds", str(arguments.seconds),
        arguments.output, "/usr/bin/sudo", "-n", "-u", account.pw_name,
        "/usr/bin/env", "-i", "PATH=/usr/bin:/bin",
        f"HOME={account.pw_dir}", f"TMPDIR={account.pw_dir}", *arguments.command,
    ])


if __name__ == "__main__":
    sys.exit(main())
