#!/usr/bin/env python3
"""Back every logical byte of a fresh hosted scratch image with file storage."""

import os
import stat
import sys
from pathlib import Path


def main():
    if os.geteuid() != 0 or os.environ.get("GITHUB_ACTIONS") != "true" or len(sys.argv) != 2:
        raise SystemExit("FAIL: scratch allocation requires the disposable hosted root fixture")
    path = Path(sys.argv[1])
    metadata = path.lstat()
    if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0
            or metadata.st_nlink != 1 or not 8 * 1024**3 <= metadata.st_size < 9 * 1024**3):
        raise SystemExit("FAIL: expected a fresh unshared root-owned 8 GiB image")
    with path.open("r+b", buffering=0) as image:
        if os.fstat(image.fileno()).st_ino != metadata.st_ino:
            raise SystemExit("FAIL: scratch image identity changed")
        offset = 0
        while offset < metadata.st_size:
            image.seek(offset)
            chunk = image.read(min(32 * 1024**2, metadata.st_size - offset))
            if not chunk:
                raise SystemExit("FAIL: scratch image ended before its declared size")
            image.seek(offset)
            if image.write(chunk) != len(chunk):
                raise SystemExit("FAIL: scratch image allocation produced a short write")
            offset += len(chunk)
        os.fsync(image.fileno())
        allocated = os.fstat(image.fileno()).st_blocks * 512
        if allocated < metadata.st_size:
            raise SystemExit(f"FAIL: image allocation {allocated} is below logical size")
    print(f"PASS: scratch image fully backed by {allocated} allocated bytes", flush=True)


if __name__ == "__main__":
    main()
