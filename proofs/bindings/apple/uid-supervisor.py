#!/usr/bin/env python3
"""Supervise a command belonging to the disposable hosted probe account."""

import argparse
import os
import pwd
import resource
import signal
import subprocess
import sys
import time
from pathlib import Path


def launch_child(command):
    if os.geteuid() != 0 or os.environ.get("GITHUB_ACTIONS") != "true" or not command:
        raise SystemExit("FAIL: child setup requires the hosted root supervisor")
    account = pwd.getpwnam("cairnbenignprobe")
    if account.pw_uid != 59000 or account.pw_gid != 20 or account.pw_shell != "/usr/bin/false":
        raise SystemExit("FAIL: child account identity does not match")
    for limit, value in (
        (resource.RLIMIT_CPU, 900), (resource.RLIMIT_NPROC, 128),
        (resource.RLIMIT_FSIZE, 64 * 1024**2), (resource.RLIMIT_CORE, 0),
    ):
        resource.setrlimit(limit, (value, value))
    os.setgroups([])
    os.setgid(account.pw_gid)
    os.setuid(account.pw_uid)
    os.execvpe(command[0], command, {
        "PATH": "/usr/bin:/bin", "HOME": account.pw_dir,
        "TMPDIR": account.pw_dir, "LANG": "en_US.UTF-8",
    })


def account_processes(uid):
    result = subprocess.run(
        ["/bin/ps", "-axo", "uid=,pid="],
        check=True, capture_output=True, text=True, timeout=5,
    )
    return {int(pid) for owner, pid in (line.split() for line in result.stdout.splitlines())
            if int(owner) == uid}


def cleanup_account(uid):
    deadline = time.monotonic() + 10
    force_after = time.monotonic() + 2
    while True:
        processes = account_processes(uid)
        if not processes:
            print("PASS: dedicated UID has no remaining processes", flush=True)
            return
        if time.monotonic() >= deadline:
            raise RuntimeError("FAIL: dedicated UID cleanup deadline exceeded")
        selected_signal = signal.SIGKILL if time.monotonic() >= force_after else signal.SIGTERM
        for process_id in processes:
            if process_id not in account_processes(uid):
                continue
            try:
                os.kill(process_id, selected_signal)
            except ProcessLookupError:
                print("INFO: owned process exited before cleanup signal", flush=True)
        time.sleep(0.05)


def interrupted(number, _frame):
    raise InterruptedError(number, "Hosted supervisor interrupted")


def main():
    if sys.argv[1:2] == ["--child"]:
        launch_child(sys.argv[2:])
        return 1
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
    if account_processes(account.pw_uid):
        parser.error("Dedicated probe UID already has processes; refusing to launch or clean them")
    output_directory = Path(arguments.output).parent.stat()
    if output_directory.st_uid != 0 or output_directory.st_mode & 0o077:
        parser.error("Proof output requires a root-owned private directory")
    for number in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
        signal.signal(number, interrupted)
    collector = Path(__file__).parent.parent / "linux-android" / "bounded-proof.py"
    process = subprocess.Popen([
        sys.executable, str(collector), "--seconds", str(arguments.seconds),
        arguments.output, sys.executable, "-I", str(Path(__file__).resolve()),
        "--child", *arguments.command,
    ], start_new_session=True)
    try:
        return process.wait()
    except InterruptedError as error:
        print(f"FAIL: hosted supervisor interrupted by signal {error.errno}", file=sys.stderr)
        return 128 + error.errno
    finally:
        for number in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
            signal.signal(number, signal.SIG_IGN)
        try:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=12)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
        finally:
            cleanup_account(account.pw_uid)


if __name__ == "__main__":
    sys.exit(main())
