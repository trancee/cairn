#!/usr/bin/env bash
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then
  echo 'Run synthetic retention composition tests as root on a disposable Linux guest' >&2
  exit 2
fi
scripts="$(cd "$(dirname "$0")" && pwd)"
store=/var/lib/cairn-proof-evidence/bounded-store
reservation_root=$(mktemp -d /var/lib/cairn-reservation-test-XXXXXXXX)
bash "$scripts/bounded-evidence.sh" "$reservation_root/evidence" \
  python3 -c '
import subprocess
import sys
from pathlib import Path
collector = sys.argv[1]
result = subprocess.run(
    [sys.executable, collector, "--reserve", "--limit", str(1024**3 + 1),
     "replay.log", sys.executable, "-c",
     "from pathlib import Path; Path(\"started\").touch()"],
    capture_output=True,
)
assert result.returncode != 0, result.stderr
assert b"budget reservation failed" in result.stderr, result.stderr
assert not Path("started").exists(), "Command ran without reserved output capacity"
assert Path("replay.log").stat().st_size == 0
print("PASS: replay reservation failure prevents command execution")
' "$scripts/bounded-proof.py"
bash "$scripts/with-evidence-store.sh" python3 -c '
import errno
import os
from pathlib import Path
probe = Path("aggregate-overflow-probe")
try:
    with probe.open("xb") as output:
        try:
            os.posix_fallocate(output.fileno(), 0, 8 * 1024**3 + 1)
        except OSError as error:
            assert error.errno == errno.ENOSPC, error
        else:
            raise AssertionError("Aggregate store exceeded its capacity")
finally:
    probe.unlink()
print("PASS: aggregate capacity exhaustion fails without eviction")
'
output="$store/synthetic-composition-$(cat /proc/sys/kernel/random/uuid)"
bash "$scripts/with-evidence-store.sh" /bin/bash "$scripts/extract-with-scratch.sh" \
  "$output" python3 -c '
import os
from pathlib import Path
temporary = os.environ["TMPDIR"]
assert os.environ["LIBGUESTFS_TMPDIR"] == temporary
assert os.environ["LIBGUESTFS_CACHEDIR"] == temporary
for path, limit in [(".", 1024**3), (temporary, 4 * 1024**3)]:
    state = os.statvfs(path)
    assert 0 < state.f_blocks * state.f_frsize <= limit, path
Path("marker.txt").write_text("bounded composition marker\n")
print("PASS: output and appliance scratch are on separate bounded filesystems")
'
bash "$scripts/with-evidence-store.sh" /bin/bash -se -- "$output" <<'CHECK'
set -euo pipefail
output=$1
grep -Fx COMPLETE "$output.status"
if compgen -G './appliance-*' >/dev/null; then
  echo 'FAIL: successful appliance scratch was retained' >&2
  exit 1
fi
mount -o loop,ro,noload,nosuid,nodev,noexec "$output.ext4" "$output"
trap 'umount "$output"' EXIT
grep -Fx 'bounded composition marker' "$output/marker.txt"
CHECK
if mountpoint -q "$store"; then
  echo 'FAIL: aggregate store remains mounted' >&2
  exit 1
fi
echo "PASS: composed retention output preserved at $output.ext4"
