#!/usr/bin/env python3
"""Live socket controls for the approved disposable hosted PF experiment."""

import os
from pathlib import Path
import socket
import subprocess
import sys


def child(address, port):
    with socket.socket() as server:
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        with socket.create_connection(server.getsockname(), timeout=2):
            pass
    with socket.socket(type=socket.SOCK_DGRAM) as receiver:
        receiver.bind(("0.0.0.0", 0))
        receiver.settimeout(2)
        with socket.socket(type=socket.SOCK_DGRAM) as sender:
            sender.sendto(b"same-uid", ("127.0.0.1", receiver.getsockname()[1]))
        if receiver.recv(32) != b"same-uid":
            raise SystemExit("FAIL: same-UID UDP payload did not match")
    print("PASS: same-UID TCP and wildcard-bound UDP loopback work", flush=True)
    for name, endpoint in (
        ("cross-UID loopback", ("127.0.0.1", int(port))),
        ("external", (address, 443)),
    ):
        try:
            with socket.create_connection(endpoint, timeout=2):
                pass
        except (OSError, TimeoutError) as error:
            print(f"PASS: {name} TCP rejected ({type(error).__name__})", flush=True)
        else:
            raise SystemExit(f"FAIL: {name} TCP was allowed")


def main():
    if sys.argv[1:2] == ["--child"]:
        child(*sys.argv[2:])
        return 0
    if os.geteuid() != 0 or os.environ.get("GITHUB_ACTIONS") != "true":
        raise SystemExit("FAIL: PF probes require disposable hosted root")
    scripts = Path(__file__).parent
    output = Path(sys.argv[1])
    address = socket.getaddrinfo("github.com", 443, socket.AF_INET, socket.SOCK_STREAM)[0][4][0]
    with socket.create_connection((address, 443), timeout=5):
        pass
    with socket.socket() as root_server:
        root_server.bind(("127.0.0.1", 0))
        root_server.listen(8)
        with socket.create_connection(root_server.getsockname(), timeout=2):
            pass
        connection, _ = root_server.accept()
        connection.close()
        print("PASS: root external and cross-UID loopback controls connect", flush=True)
        return subprocess.call([
            sys.executable, "-I", str(scripts / "uid-supervisor.py"),
            "--seconds", "15", str(output), sys.executable, "-I",
            str(scripts / "probe-pf.py"), "--child", address,
            str(root_server.getsockname()[1]),
        ])


if __name__ == "__main__":
    sys.exit(main())
