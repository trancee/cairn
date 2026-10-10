#!/usr/bin/env python3
"""Verify whole-VM RAM and swap observations; not a process-memory control."""

import re
import subprocess
import sys


limit = 7 * 1024**3
memory = int(subprocess.check_output(["/usr/sbin/sysctl", "-n", "hw.memsize"], text=True))
swap = subprocess.check_output(["/usr/sbin/sysctl", "-n", "vm.swapusage"], text=True).strip()
print(f"PROBE: whole-VM RAM={memory} bytes; candidate ceiling={limit} bytes", flush=True)
print(f"PROBE: swap {swap}", flush=True)
if not 0 < memory <= limit:
    print("FAIL: observed VM RAM does not match the seven GiB candidate ceiling", flush=True)
    sys.exit(1)
match = re.search(r"total = ([0-9.]+)M", swap)
if not match or float(match.group(1)) != 0:
    print("FAIL: zero-swap VM memory policy not established", flush=True)
    sys.exit(1)
print("PASS: whole-VM RAM matches candidate envelope; swap disabled", flush=True)
    sys.exit(1)
