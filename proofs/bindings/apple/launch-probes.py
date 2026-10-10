#!/usr/bin/env python3
"""Own benign TCP/Unix fixtures while the sandbox probes run."""

from pathlib import Path
import socket
import subprocess
import sys


def main():
    output, scripts, python = sys.argv[1:4]
    address = str(Path(output) / "scratch" / "ipc.sock")
    if len(address.encode()) >= 104:
        raise SystemExit("FAIL: probe output path exceeds Unix socket path capacity")
    with socket.socket() as tcp, socket.socket(socket.AF_UNIX) as ipc:
        tcp.bind(("127.0.0.1", 0))
        tcp.listen(1)
        ipc.bind(address)
        ipc.listen(1)
        try:
            with socket.create_connection(tcp.getsockname()):
                pass
            with socket.socket(socket.AF_UNIX) as control:
                control.connect(address)
            print("PASS: unsandboxed TCP and Unix fixture controls connect", flush=True)
            return subprocess.call(
                ["/bin/bash", str(Path(output) / "command.sh"), output, scripts,
                 python, str(tcp.getsockname()[1]), address],
            )
        finally:
            Path(address).unlink()


if __name__ == "__main__":
    sys.exit(main())
