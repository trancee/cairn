#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run the real filesystem-boundary test as root on a disposable Linux guest' >&2
  exit 2
fi
script="$(cd "$(dirname "$0")" && pwd)/bounded-evidence.sh"
test_root=$(mktemp -d /var/lib/cairn-evidence-test-XXXXXXXX)
echo "Synthetic test evidence retained: $test_root"

bash "$script" "$test_root/capacity" python3 -c '
import os
capacity = os.statvfs(".")
size = capacity.f_blocks * capacity.f_frsize
assert 0 < size <= 1024**3, f"Evidence filesystem exceeds 1 GiB: {size}"
print(f"PASS: evidence filesystem capacity {size} bytes")
'
grep -Fx COMPLETE "$test_root/capacity.status"
test "$(stat -c %s "$test_root/capacity.ext4")" -eq 1073741824
if mountpoint -q "$test_root/capacity"; then
  echo 'FAIL: successful command left evidence mounted' >&2
  exit 1
fi

if bash "$script" "$test_root/overflow" python3 -c '
import os
from pathlib import Path
Path("partial.txt").write_text("retained before overflow\n")
with open("too-large.bin", "wb") as output:
    os.posix_fallocate(output.fileno(), 0, 1024**3 + 1)
' > "$test_root/overflow-command.log" 2>&1; then
  echo 'FAIL: oversized evidence allocation succeeded' >&2
  exit 1
fi
grep -F 'No space left on device' "$test_root/overflow-command.log"
grep -Fx 'INCOMPLETE: command failed (1)' "$test_root/overflow.status"
test "$(stat -c %s "$test_root/overflow.ext4")" -eq 1073741824
if mountpoint -q "$test_root/overflow"; then
  echo 'FAIL: failed command left evidence mounted' >&2
  exit 1
fi
mount -o loop,ro,noload,nosuid,nodev,noexec "$test_root/overflow.ext4" "$test_root/overflow"
if ! grep -Fx 'retained before overflow' "$test_root/overflow/partial.txt"; then
  umount "$test_root/overflow"
  echo 'FAIL: partial evidence was not retained' >&2
  exit 1
fi
umount "$test_root/overflow"

if bash "$script" "$test_root/child-failure" bash -c 'exit 7'; then
  echo 'FAIL: child error became successful extraction' >&2
  exit 1
else
  result=$?
  test "$result" -eq 7
fi
grep -Fx 'INCOMPLETE: command failed (7)' "$test_root/child-failure.status"

before=$(sha256sum "$test_root/capacity.ext4" "$test_root/capacity.status")
if bash "$script" "$test_root/capacity" bash -c 'touch changed'; then
  echo 'FAIL: existing evidence reused' >&2
  exit 1
fi
test "$before" = "$(sha256sum "$test_root/capacity.ext4" "$test_root/capacity.status")"
echo 'PASS: capacity, overflow, preserved partial evidence, child failure and exclusive creation'

bash "$script" --profile appliance "$test_root/appliance" python3 -c '
import os
state = os.statvfs(".")
capacity = state.f_blocks * state.f_frsize
assert 0 < capacity <= 4 * 1024**3, capacity
assert capacity > 3 * 1024**3, capacity
print(f"PASS: appliance scratch capacity {capacity} bytes")
'
test "$(stat -c %s "$test_root/appliance.ext4")" -eq 4294967296

bash "$script" --profile store "$test_root/store" python3 -c '
import os
state = os.statvfs(".")
capacity = state.f_blocks * state.f_frsize
assert 7 * 1024**3 < capacity <= 8 * 1024**3, capacity
print(f"PASS: aggregate store capacity {capacity} bytes")
'
test "$(stat -c %s "$test_root/store.ext4")" -eq 8589934592
