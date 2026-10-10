#!/usr/bin/env python3
"""Require the approved fixed, fully backed hosted build scratch boundary."""

import os
import stat
import sys
from pathlib import Path


def main():
    if os.geteuid() != 0 or os.environ.get("GITHUB_ACTIONS") != "true" or len(sys.argv) != 3:
        raise SystemExit("FAIL: build scratch check requires the hosted root fixture")
    image, volume = map(Path, sys.argv[1:])
    image_metadata = image.stat()
    capacity = os.statvfs(volume)
    filesystem_bytes = capacity.f_blocks * capacity.f_frsize
    budget = 8 * 1024**3
    if image_metadata.st_size != budget or not 0 < filesystem_bytes <= budget:
        raise SystemExit(f"FAIL: scratch image/capacity {image_metadata.st_size}/"
                         f"{filesystem_bytes} does not satisfy the 8 GiB ceiling")
    if (image_metadata.st_uid != 0 or image_metadata.st_nlink != 1 or image.is_symlink()
            or not stat.S_ISREG(image_metadata.st_mode)):
        raise SystemExit("FAIL: build scratch image must be an unshared root-owned regular file")
    if image_metadata.st_blocks * 512 < image_metadata.st_size:
        raise SystemExit("FAIL: build scratch image is not fully allocated")
    if volume.stat().st_uid != 59000 or volume.stat().st_mode & 0o077:
        raise SystemExit("FAIL: build scratch must be private to the dedicated UID")
    print(f"PASS: 8 GiB fixed scratch capacity {filesystem_bytes}; "
          f"fully allocated image {image_metadata.st_size} bytes", flush=True)


if __name__ == "__main__":
    main()
