#!/usr/bin/env python3
"""Live socket controls for the approved disposable hosted PF experiment."""

import os
from pathlib import Path
import socket
import subprocess
import sys


def child(address, port):
    with socket.socket() as server:
        server.bind(("127.0.0.2", 0))
        server.listen(1)
        with socket.create_connection(server.getsockname(), timeout=2):
            pass
        connection, _ = server.accept()
        connection.close()
        print(f"reverse-ready={server.getsockname()[1]}", flush=True)
        server.settimeout(2)
        try:
            connection, _ = server.accept()
        except socket.timeout:
            print("PASS: other UID cannot reach dedicated private listener", flush=True)
        else:
            connection.close()
            raise SystemExit("FAIL: other UID reached dedicated private listener")
    with socket.socket(type=socket.SOCK_DGRAM) as receiver:
        receiver.bind(("0.0.0.0", 0))
        receiver.settimeout(2)
        with socket.socket(type=socket.SOCK_DGRAM) as sender:
            sender.settimeout(2)
            sender.sendto(b"same-uid", ("127.0.0.2", receiver.getsockname()[1]))
            payload, peer = receiver.recvfrom(32)
            if payload != b"same-uid":
                raise SystemExit("FAIL: same-UID UDP payload did not match")
            print(f"DIAGNOSTIC: private UDP sender address {peer[0]}", flush=True)
            receiver.sendto(b"reply", peer)
            if sender.recv(32) != b"reply":
                raise SystemExit("FAIL: same-UID UDP reply did not match")
    print("PASS: same-UID TCP and wildcard-bound UDP loopback work", flush=True)
    for name, endpoint in (
        ("cross-UID loopback", ("127.0.0.1", int(port))),
        ("cross-UID private loopback", ("127.0.0.2", int(port))),
        ("external", (address, 443)),
    ):
        try:
            with socket.create_connection(endpoint, timeout=2):
                pass
        except (OSError, TimeoutError) as error:
            print(f"PASS: {name} TCP rejected ({type(error).__name__})", flush=True)
        else:
            raise SystemExit(f"FAIL: {name} TCP was allowed")
    try:
        with socket.create_connection(
            ("127.0.0.1", int(port)), timeout=2, source_address=("127.0.0.2", 0),
        ):
            pass
    except OSError as error:
        print(f"PASS: private-source cross-UID TCP rejected ({type(error).__name__})", flush=True)
    else:
        raise SystemExit("FAIL: private-source cross-UID TCP was allowed")


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
        root_server.bind(("0.0.0.0", 0))
        root_server.listen(8)
        with socket.create_connection(("127.0.0.1", root_server.getsockname()[1]), timeout=2):
            pass
        connection, _ = root_server.accept()
        connection.close()
        print("PASS: root external and cross-UID loopback controls connect", flush=True)
        command = [sys.executable, "-I", str(scripts / "probe-pf.py")]
        if len(sys.argv) == 5:
            scratch, inputs, profile = sys.argv[2:]
            command = [
                "/usr/bin/sandbox-exec", "-D", f"INPUTS={inputs}",
                "-D", f"SCRATCH={scratch}", "-D", "PRIVATE_IPC=true", "-f", profile,
                sys.executable, "-I", str(Path(inputs) / "probe-pf.py"),
            ]
        with subprocess.Popen([
            sys.executable, "-I", str(scripts / "uid-supervisor.py"),
            "--seconds", "15", str(output), *command, "--child", address,
            str(root_server.getsockname()[1]),
        ], stdout=subprocess.PIPE, text=True) as process:
            try:
                for line in process.stdout:
                    print(line, end="", flush=True)
                    if line.startswith("reverse-ready="):
                        private_port = int(line.strip().split("=")[1])
                        try:
                            with socket.create_connection(("127.0.0.2", private_port), timeout=1):
                                pass
                        except OSError as error:
                            print(f"PASS: reverse cross-UID TCP rejected "
                                  f"({type(error).__name__})", flush=True)
                        else:
                            raise RuntimeError("FAIL: root reached dedicated private listener")
                return process.wait(timeout=5)
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=15)


if __name__ == "__main__":
    sys.exit(main())
