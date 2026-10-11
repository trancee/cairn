#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2
python=$1
simctl=$(/usr/bin/xcrun --find simctl)
if [ "$2" = boot ]; then
  "$python" -I -c '
import json, pathlib, subprocess, sys, uuid
simctl, home = sys.argv[1:]
device = str(uuid.UUID(pathlib.Path(home, "simulator-lifecycle-device").read_text().strip()))
command = [simctl, "--set", str(pathlib.Path(home, "simulator-devices"))]
try:
    subprocess.run([*command, "boot", device, "--arch=arm64"], check=True, timeout=15)
    subprocess.run([*command, "bootstatus", device], check=True, timeout=25)
    result = subprocess.run([*command, "list", "devices", "--json"],
                            check=True, capture_output=True, text=True, timeout=5)
    matches = [item for group in json.loads(result.stdout)["devices"].values()
               for item in group if item["udid"].lower() == device]
    if len(matches) != 1 or matches[0]["state"] != "Booted":
        raise SystemExit("FAIL: trusted simulator did not reach Booted state")
    print("PASS: trusted ARM64 simulator booted; no app installed or generated calls", flush=True)
finally:
    subprocess.run([*command, "shutdown", device], check=True, timeout=10)
    print("PASS: trusted simulator shutdown command completed", flush=True)
' "$simctl" "$HOME"
  exit 0
fi
test "$2" = create
device=$("$simctl" --set "$HOME/simulator-devices" create cairn-trusted-lifecycle \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17 \
  com.apple.CoreSimulator.SimRuntime.iOS-26-4)
"$python" -I -c '
import pathlib, sys, uuid
device = str(uuid.UUID(sys.argv[1]))
pathlib.Path(sys.argv[2]).write_text(device + "\n")
' "$device" "$HOME/simulator-lifecycle-device"
"$simctl" --set "$HOME/simulator-devices" list devices --json \
  > "$HOME/simulator-lifecycle-created.json"
"$python" -I -c '
import json, sys
with open(sys.argv[1]) as source:
    devices = json.load(source)["devices"]
matches = [device for group in devices.values() for device in group
           if device["udid"].lower() == sys.argv[2].lower()]
if len(matches) != 1 or matches[0]["state"] != "Shutdown":
    raise SystemExit("FAIL: newly created trusted simulator is not uniquely shut down")
print("PASS: trusted scratch simulator created in Shutdown state; no boot or app")
' "$HOME/simulator-lifecycle-created.json" "$device"
