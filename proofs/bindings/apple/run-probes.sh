#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
test "$#" -eq 1
output=$1
test ! -e "$output"
umask 077
mkdir "$output"
output="$(cd "$output" && pwd -P)"
scripts="$(cd "$(dirname "$0")" && pwd -P)"
python=$(xcrun --find python3)
mkdir "$output/inputs" "$output/scratch"
cp "$scripts/probe.py" "$output/inputs/probe.py"
printf 'benign sentinel\n' > "$output/host-sentinel"
{
  sw_vers
  xcodebuild -version
  uname -m
  df -h "$output"
} > "$output/environment.txt"
cat > "$output/command.sh" <<'COMMAND'
#!/usr/bin/env bash
set -euo pipefail
exec /usr/bin/env -i PATH=/usr/bin:/bin HOME="$1/scratch" TMPDIR="$1/scratch" \
  /usr/bin/sandbox-exec -D "INPUTS=$1/inputs" -D "SCRATCH=$1/scratch" \
  -D "SENTINEL=$1/host-sentinel" -f "$2/probe.sb" \
  "$3" -I "$1/inputs/probe.py" "$1/scratch" "$1/inputs" "$1/host-sentinel"
COMMAND
if bash "$output/command.sh" "$output" "$scripts" "$python" > "$output/probe.log" 2>&1; then
  cat "$output/probe.log"
else
  result=$?
  cat "$output/probe.log" >&2
  echo 'FAIL: Apple probe incomplete; diagnostics retained' >&2
  exit "$result"
fi
test "$(stat -f %z "$output/probe.log")" -le 1048576
(cd "$output" && shasum -a 256 environment.txt probe.log > SHA256SUMS)
