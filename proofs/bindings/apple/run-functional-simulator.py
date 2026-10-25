#!/usr/bin/env python3
"""Functional-only CoreSimulator proof on a fresh GitHub-hosted VM."""

import argparse
import hashlib
import json
import os
import re
import subprocess
import time
import uuid
from pathlib import Path


EXECUTABLES = ("CairnSimulatorSmoke.kexe", "CairnSdkTest.kexe")
# Hosted runs took up to 154 s for create+boot+bootstatus and 6-49 s for spawn, with create
# exceeding 30 s and spawn 60 s in about a quarter of runs. The step's 480 s bound still caps the total.
BUDGETS = {"create": 120, "boot": 30, "bootstatus": 300, "spawn": 180}


def launch_phase(command, phase, *arguments, **options):
    started = time.monotonic()
    try:
        return subprocess.run([*command, phase, *arguments], check=True,
                              timeout=BUDGETS[phase], **options)
    finally:
        print(f"TIMING: {phase} {time.monotonic() - started:.1f} s of {BUDGETS[phase]} s", flush=True)


def verify_payload(payload, revision, executable=EXECUTABLES[0]):
    if executable not in EXECUTABLES:
        raise SystemExit("FAIL: functional payload executable not allowed")
    expected = {executable, "payload.sha256", "revision.txt"}
    if not payload.is_dir() or payload.is_symlink() or {
        item.name for item in payload.iterdir()
    } != expected:
        raise SystemExit("FAIL: functional payload file set mismatch")
    for name in expected:
        item = payload / name
        maximum = 128 * 1024 * 1024 if name.endswith(".kexe") else 128
        if item.is_symlink() or not item.is_file() or not 0 < item.stat().st_size <= maximum:
            raise SystemExit("FAIL: functional payload file type/size mismatch")
    if not re.fullmatch(r"[0-9a-f]{40}", revision) or (
        payload / "revision.txt"
    ).read_bytes() != (revision + "\n").encode():
        raise SystemExit("FAIL: functional payload source revision mismatch")
    manifest = (payload / "payload.sha256").read_bytes()
    match = re.fullmatch(rb"([0-9a-f]{64})  " + re.escape(executable.encode()) + rb"\n", manifest)
    if not match:
        raise SystemExit("FAIL: functional payload checksum manifest mismatch")
    binary = payload / executable
    digest = hashlib.sha256()
    with binary.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest().encode() != match[1]:
        raise SystemExit("FAIL: functional payload executable checksum mismatch")
    return binary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cleanup", action="store_true")
    parser.add_argument("--executable", choices=EXECUTABLES, default=EXECUTABLES[0])
    parser.add_argument("payload", type=Path)
    parser.add_argument("work", type=Path)
    arguments = parser.parse_args()
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.getuid() == 0:
        parser.error("Functional simulator proof requires the hosted non-root runner")
    environment = {
        key: os.environ[key] for key in ("HOME", "TMPDIR")
    }
    environment.update(PATH="/usr/bin:/bin", LANG="en_US.UTF-8")
    binary = None
    if not arguments.cleanup:
        binary = verify_payload(
            arguments.payload, os.environ.get("GITHUB_SHA", ""), arguments.executable,
        )
    simctl = subprocess.run(
        ["/usr/bin/xcrun", "--find", "simctl"], check=True,
        capture_output=True, text=True, timeout=10, env=environment,
    ).stdout.strip()
    device_set = arguments.work / "devices"
    identity_file = arguments.work / "device-id"
    command = [simctl, "--set", str(device_set)]

    # Hosted CoreSimulator can take tens of seconds to answer after a run.
    def devices(timeout=60):
        result = subprocess.run(
            [*command, "list", "devices", "--json"], check=True,
            capture_output=True, text=True, timeout=timeout, env=environment,
        )
        return [device for group in json.loads(result.stdout)["devices"].values()
                for device in group]

    if arguments.cleanup:
        if not identity_file.exists():
            if device_set.exists() and devices():
                raise SystemExit("FAIL: functional device set has an unrecorded device")
            print("INFO: no functional device identity recorded; no device selected for cleanup")
            return
        device_id = str(uuid.UUID(identity_file.read_text().strip()))
        selected = [device for device in devices() if device["udid"].lower() == device_id]
        if len(selected) != 1 or selected[0]["name"] != "cairn-functional-smoke":
            raise SystemExit("FAIL: functional cleanup device identity mismatch")
        if selected[0]["state"] != "Shutdown":
            subprocess.run([*command, "shutdown", device_id], check=True,
                           timeout=30, env=environment)
        subprocess.run([*command, "delete", device_id], check=True,
                       timeout=15, env=environment)
        if any(device["udid"].lower() == device_id for device in devices(30)):
            raise SystemExit("FAIL: functional device survived deletion")
        print("PASS: exact functional simulator shutdown/deletion verified")
        return

    if arguments.work.exists():
        parser.error("Functional work directory must be new")
    arguments.work.mkdir(mode=0o700)
    device_set.mkdir(mode=0o700)
    binary.chmod(0o500)
    result = launch_phase(
        command, "create", "cairn-functional-smoke",
        "com.apple.CoreSimulator.SimDeviceType.iPhone-17",
        "com.apple.CoreSimulator.SimRuntime.iOS-26-4",
        capture_output=True, text=True, env=environment,
    )
    device_id = str(uuid.UUID(result.stdout.strip()))
    identity_file.write_text(device_id + "\n")
    launch_phase(command, "boot", device_id, "--arch=arm64", env=environment)
    launch_phase(command, "bootstatus", device_id, env=environment)
    print("PASS: exact normal-user functional ARM64 bootstatus completed", flush=True)
    launch_phase(command, "spawn", "--standalone", device_id, str(binary), env=environment)
    verify_payload(arguments.payload, os.environ.get("GITHUB_SHA", ""), arguments.executable)
    print("PASS: delivered generated simulator consumer exited successfully", flush=True)


if __name__ == "__main__":
    main()
