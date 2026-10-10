#!/usr/bin/env python3
"""Bounded benign checks under a dedicated hosted test UID."""

import errno
import os
from pathlib import Path
import resource
import signal
import subprocess
import sys


def main():
    scratch = Path(sys.argv[1])
    state = os.statvfs(scratch)
    capacity = state.f_blocks * state.f_frsize
    assert 0 < capacity <= 256 * 1024**2, capacity
    print(f"PASS: scratch filesystem capacity {capacity} bytes", flush=True)
    output = scratch / "capacity-probe"
    try:
        with output.open("wb", buffering=0) as stream:
            try:
                for _ in range(257):
                    stream.write(b"x" * 1024**2)
            except OSError as error:
                assert error.errno == errno.ENOSPC, error.errno
            else:
                raise SystemExit("FAIL: scratch capacity did not reject excess")
        print("PASS: scratch capacity exhaustion rejected", flush=True)
    finally:
        output.unlink()

    children = []
    resource.setrlimit(resource.RLIMIT_NPROC, (16, 16))
    try:
        for _ in range(17):
            try:
                children.append(subprocess.Popen(["/bin/sleep", "30"]))
            except OSError as error:
                assert error.errno == errno.EAGAIN, error.errno
                print("PASS: dedicated UID process limit rejected excess", flush=True)
                break
        else:
            raise SystemExit("FAIL: process limit did not reject excess")
    finally:
        for child in children:
            child.terminate()
        for child in children:
            child.wait(timeout=5)

    result = subprocess.run(
        [sys.executable, "-I", "-c",
         "import resource; resource.setrlimit(resource.RLIMIT_CPU, (2, 2));\n"
         "while True: pass"],
        timeout=15,
    )
    assert result.returncode in (-signal.SIGKILL, -signal.SIGXCPU), result.returncode
    print("PASS: per-process CPU limit terminated busy child", flush=True)
    print("PASS: benign disk/process/CPU probes; memory acceptance remains blocked")


if __name__ == "__main__":
    main()
