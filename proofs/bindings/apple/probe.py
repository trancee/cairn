#!/usr/bin/env python3
"""Benign enforcement probes; not a binding build or runner acceptance."""

import errno
from pathlib import Path
import resource
import socket
import subprocess
import sys


def denied(name, operation):
    try:
        operation()
    except OSError as error:
        if error.errno not in (errno.EPERM, errno.EACCES):
            raise
        print(f"PASS: {name}", flush=True)
    else:
        raise SystemExit(f"FAIL: {name} was allowed")


def main():
    scratch, inputs, sentinel = map(Path, sys.argv[1:4])
    denied("input mutation denied", lambda: (inputs / "write-probe").write_text("probe"))
    denied("host sentinel read denied", sentinel.read_bytes)
    with socket.socket() as connection:
        denied("network bind denied", lambda: connection.bind(("127.0.0.1", 0)))
    with socket.socket() as connection:
        denied("outbound TCP connect denied",
               lambda: connection.connect(("127.0.0.1", int(sys.argv[4]))))
    with socket.socket(socket.AF_UNIX) as connection:
        denied("Unix socket IPC denied", lambda: connection.connect(sys.argv[5]))
    escape = scratch / "input-escape"
    escape.symlink_to(inputs, target_is_directory=True)
    denied("scratch symlink input mutation denied",
           lambda: (escape / "symlink-write").write_text("probe"))
    read_escape = scratch / "sentinel-escape"
    read_escape.symlink_to(sentinel)
    denied("scratch symlink host read denied", read_escape.read_bytes)
    output = scratch / "allowed"
    output.write_text("scratch")
    assert output.read_text() == "scratch"
    print("PASS: assigned scratch writable", flush=True)
    child = subprocess.run(
        ["/bin/sh", "-c", 'printf probe > "$1"', "probe", str(inputs / "child-write")],
        capture_output=True,
    )
    assert child.returncode != 0, "child escaped input write denial"
    assert not (inputs / "child-write").exists()
    print("PASS: child inherits input write denial", flush=True)
    resource.setrlimit(resource.RLIMIT_FSIZE, (1024 * 1024, 1024 * 1024))
    with (scratch / "file-limit").open("wb", buffering=0) as stream:
        try:
            for _ in range(17):
                stream.write(b"x" * 65536)
        except OSError as error:
            assert error.errno == errno.EFBIG, error.errno
        else:
            raise SystemExit("FAIL: file limit did not reject excess")
    assert (scratch / "file-limit").stat().st_size <= 1024 * 1024
    print("PASS: one MiB per-file limit enforced", flush=True)
    print("PASS: benign Apple sandbox probes; full runner acceptance not established")


if __name__ == "__main__":
    main()
