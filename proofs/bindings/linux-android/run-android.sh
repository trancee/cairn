#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ "$1" != emulator-5554 ]; then
  echo 'Usage: bash run-android.sh emulator-5554 (dedicated API 26 x86_64 AVD)' >&2
  exit 2
fi
serial="$1"
adb=/opt/cairn-toolchains/android-sdk/platform-tools/adb
fixture=/srv/cairn-generator-scratch/android-interop
saved="$HOME/cairn-emulator/artifacts"

test "$(timeout 10s "$adb" -s "$serial" get-state </dev/null)" = device
test "$(timeout 10s "$adb" -s "$serial" shell -T getprop sys.boot_completed \
  </dev/null | tr -d '\r')" = 1
test "$(timeout 10s "$adb" -s "$serial" shell -T getprop ro.build.version.sdk \
  </dev/null | tr -d '\r')" = 26
test "$(timeout 10s "$adb" -s "$serial" shell -T getprop ro.product.cpu.abi \
  </dev/null | tr -d '\r')" = x86_64

install -d -m 0700 "$saved"
sudo install -o builder -g builder -m 0600 \
  "$fixture/androidConsumer/build/outputs/apk/debug/androidConsumer-debug.apk" \
  "$saved/androidConsumer-debug.apk"
sha256sum "$saved/androidConsumer-debug.apk"

# Replacement is limited to this owned smoke package on the dedicated AVD.
timeout 60s "$adb" -s "$serial" install --user 0 -r \
  "$saved/androidConsumer-debug.apk" </dev/null
timeout 10s "$adb" -s "$serial" shell -T \
  pm path --user 0 ch.trancee.cairn.consumer </dev/null

if ! timeout 60s "$adb" -s "$serial" shell -T \
  am instrument --user 0 -w -r \
  ch.trancee.cairn.consumer/.SmokeInstrumentation \
  </dev/null > "$saved/android-instrumentation.txt" 2>&1; then
  cat "$saved/android-instrumentation.txt"
  exit 1
fi
cat "$saved/android-instrumentation.txt"
grep -Fx 'INSTRUMENTATION_CODE: -1' "$saved/android-instrumentation.txt"
grep -F 'PASS: Android value, boundary, typed error and object lifetime' \
  "$saved/android-instrumentation.txt"
if grep -Eq 'INSTRUMENTATION_FAILED|INSTRUMENTATION_ABORTED|shortMsg=' \
  "$saved/android-instrumentation.txt"; then
  echo 'Instrumentation reported failure' >&2
  exit 1
fi
echo 'PASS: packaged Android FFI executed on API 26 x86_64'
