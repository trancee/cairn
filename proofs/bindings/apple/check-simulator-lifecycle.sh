#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
python=$1
simctl=$(/usr/bin/xcrun --find simctl)
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
