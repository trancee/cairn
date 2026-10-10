#!/usr/bin/env python3
"""Check whether Darwin's address-space limit actually rejects allocation."""

import resource
import sys


limit = 32 * 1024**2
resource.setrlimit(resource.RLIMIT_AS, (limit, limit))
print(f"PROBE: requested RLIMIT_AS={limit} bytes", flush=True)
print(f"PROBE: RLIMIT_AS aliases RLIMIT_RSS={resource.RLIMIT_AS == resource.RLIMIT_RSS}",
      flush=True)
try:
    allocation = bytearray(64 * 1024**2)
except MemoryError:
    print("PASS: allocation beyond requested process memory limit rejected")
else:
    print(f"FAIL: allocated {len(allocation)} bytes beyond requested memory limit",
          flush=True)
    sys.exit(1)
