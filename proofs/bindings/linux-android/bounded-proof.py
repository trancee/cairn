#!/usr/bin/env python3
"""Retain bounded proof output; fail instead of silently truncating."""

import argparse
import os
import signal
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=64 * 1024**2)
    parser.add_argument("output")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    arguments = parser.parse_args()
    if arguments.limit <= 0 or not arguments.command:
        parser.error("A positive limit and command are required")
    with open(arguments.output, "xb") as output:
        with subprocess.Popen(
            arguments.command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            start_new_session=True,
        ) as process:
            retained = 0
            try:
                while chunk := process.stdout.read1(65536):
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
                return process.wait()
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()


if __name__ == "__main__":
    sys.exit(main())
