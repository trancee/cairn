#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
python=$1
mkdir "$HOME/simulator-devices"
simctl=$(/usr/bin/xcrun --find simctl)
"$simctl" --set "$HOME/simulator-devices" list runtimes --json > "$HOME/simulator-runtimes.json"
"$python" -I -c '
import json, sys
with open(sys.argv[1]) as source:
    runtimes = json.load(source)["runtimes"]
available = [runtime for runtime in runtimes
             if runtime["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
             and runtime["isAvailable"]]
if not available:
    raise SystemExit("FAIL: no available iOS simulator runtime in isolated inventory")
for runtime in available:
    print("RUNTIME:", runtime["identifier"], runtime["version"])
' "$HOME/simulator-runtimes.json"
echo 'PASS: isolated simulator runtime inventory; no device boot or generated calls'
