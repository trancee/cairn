#!/usr/bin/env python3
"""Retain bounded proof output; fail instead of silently truncating."""

import argparse
import os
import selectors
import signal
import subprocess
import sys
import time


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=64 * 1024**2)
    parser.add_argument("--reserve", action="store_true")
    parser.add_argument("--seconds", type=float)
    parser.add_argument("output")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    arguments = parser.parse_args()
    if (arguments.limit <= 0 or not arguments.command or
            (arguments.seconds is not None and
             (not 0 < arguments.seconds < float("inf")))):
        parser.error("A positive limit and command are required")
    with open(arguments.output, "xb") as output:
        if arguments.reserve:
            try:
                os.posix_fallocate(output.fileno(), 0, arguments.limit)
            except OSError as error:
                print(f"FAIL: proof output budget reservation failed (errno {error.errno})",
                      file=sys.stderr)
                output.truncate(0)
                return 1
        with subprocess.Popen(
            arguments.command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            start_new_session=True,
        ) as process:
            retained = 0
            deadline = None if arguments.seconds is None else time.monotonic() + arguments.seconds
            selector = selectors.DefaultSelector()
            selector.register(process.stdout, selectors.EVENT_READ)
            try:
                while True:
                    if deadline is not None and time.monotonic() >= deadline:
                        print("FAIL: proof deadline exceeded", file=sys.stderr)
                        return 124
                    remaining_time = None if deadline is None else max(0, deadline - time.monotonic())
                    if not selector.select(remaining_time):
                        print("FAIL: proof deadline exceeded", file=sys.stderr)
                        return 124
                    chunk = os.read(process.stdout.fileno(), 65536)
                    if not chunk:
                        if deadline is None:
                            return process.wait()
                        try:
                            return process.wait(timeout=max(0, deadline - time.monotonic()))
                        except subprocess.TimeoutExpired:
                            print("FAIL: proof deadline exceeded", file=sys.stderr)
                            return 124
                    remaining = arguments.limit - retained
                    accepted = chunk[:remaining]
                    output.write(accepted)
                    output.flush()
                    sys.stdout.buffer.write(accepted)
                    sys.stdout.buffer.flush()
                    retained += len(accepted)
                    if len(chunk) > remaining:
                        print("FAIL: proof output exceeded its retention budget", file=sys.stderr)
                        return 1
            finally:
                selector.close()
                output.truncate(retained)
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()


if __name__ == "__main__":
    sys.exit(main())
