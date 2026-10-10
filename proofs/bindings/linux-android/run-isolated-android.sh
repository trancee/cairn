#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
  echo 'Usage: sudo bash run-isolated-android.sh' >&2
  exit 2
fi
seed=/opt/cairn-binding-seeds/fresh-api26-avd
runtime=/home/builder/cairn-disposable-runtime
evidence=/opt/cairn-binding-seeds/disposable-runtime-proof
(cd "$seed" && sha256sum --check SHA256SUMS)
if [ -e "$runtime" ]; then
  echo 'Disposable runtime path already exists; refusing concurrent reuse' >&2
  exit 2
fi
install -d -o root -g root -m 0700 /var/lib/cairn-runtime-proof
image=$(mktemp /var/lib/cairn-runtime-proof/runtime-XXXXXXXX.ext4)
mounted=0
cleanup_disk() {
  if [ "$mounted" = 1 ]; then
    install -d -o root -g root -m 0755 "$evidence"
    for log in isolated-emulator.log isolated-instrumentation.txt; do
      if [ -f "$runtime/artifacts/$log" ]; then
        install -o root -g root -m 0644 "$runtime/artifacts/$log" "$evidence/$log"
      fi
    done
    umount "$runtime" || return
  fi
  rmdir "$runtime"
  rm -- "$image"
}
trap cleanup_disk EXIT
truncate -s 16G "$image"
mkfs.ext4 -q -m 0 "$image"
install -d -o root -g root -m 0755 "$runtime"
mount -o loop,nosuid,nodev "$image" "$runtime"
mounted=1
chown builder:builder "$runtime"
chmod 0700 "$runtime"
cp -a --sparse=always "$seed/avd" "$runtime/avd"
chown -R builder:builder "$runtime/avd"
sed -i "s|^path=.*|path=$runtime/avd/cairn-api26-x86_64.avd|" \
  "$runtime/avd/cairn-api26-x86_64.ini"
install -d -o builder -g builder -m 0700 "$runtime/artifacts" \
  "$runtime/tmp" "$runtime/var-tmp"
install -o builder -g builder -m 0600 \
  /srv/cairn-generator-scratch/android-interop/androidConsumer/build/outputs/apk/debug/androidConsumer-debug.apk \
  "$runtime/artifacts/androidConsumer-debug.apk"

systemd-run --unit=cairn-isolated-android-proof --wait --pipe --collect \
  -p User=builder -p Group=builder -p SupplementaryGroups=kvm \
  -p ProtectSystem=strict -p ProtectHome=tmpfs \
  -p "BindPaths=$runtime $runtime/tmp:/tmp $runtime/var-tmp:/var/tmp" \
  -p "ReadWritePaths=$runtime /tmp /var/tmp" \
  -p PrivateNetwork=yes \
  -p NoNewPrivileges=yes -p 'CapabilityBoundingSet=' \
  -p RestrictNamespaces=yes -p RestrictSUIDSGID=yes \
  -p ProtectKernelTunables=yes -p ProtectKernelModules=yes \
  -p ProtectControlGroups=yes -p ProtectProc=invisible \
  -p 'TemporaryFileSystem=/run:ro' -p InaccessiblePaths=/dev/shm \
  -p DevicePolicy=closed -p 'DeviceAllow=/dev/kvm rw' \
  -p 'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6' \
  -p MemoryMax=6G -p MemorySwapMax=0 -p TasksMax=256 \
  -p CPUQuota=400% -p RuntimeMaxSec=300 -p TimeoutStopSec=20 \
  -p LimitCPU=240 -p LimitFSIZE=20G -p LimitCORE=0 \
  /usr/bin/env -i \
    PATH=/usr/bin:/bin LANG=C.UTF-8 \
    HOME="$runtime" ANDROID_USER_HOME="$runtime" \
    ANDROID_AVD_HOME="$runtime/avd" \
    ANDROID_HOME=/opt/cairn-toolchains/android-sdk \
  /bin/bash -se <<'RUN'
set -euo pipefail
sdk="$ANDROID_HOME"
/usr/bin/python3 /opt/cairn-binding-seeds/final-image-inputs-e75437d/check-resources.py runtime
adb="$sdk/platform-tools/adb"
serial=emulator-5554
test -r /dev/kvm && test -w /dev/kvm
/usr/bin/python3 - <<'DISK'
import errno
import os

state = os.statvfs(os.environ["HOME"])
capacity = state.f_blocks * state.f_frsize
assert 0 < capacity <= 16 * 1024**3, capacity
probe = os.path.join(os.environ["HOME"], "disk-capacity-probe")
try:
    with open(probe, "wb") as output:
        try:
            os.posix_fallocate(output.fileno(), 0, capacity + state.f_frsize)
        except OSError as error:
            if error.errno != errno.ENOSPC:
                raise
        else:
            raise SystemExit("Filesystem allocation exceeded its capacity")
finally:
    os.unlink(probe)
print(f"PASS: disposable AVD/artifact/temp filesystem capacity {capacity} bytes")
DISK
/usr/bin/python3 - <<'NETWORK'
from pathlib import Path
import errno
import socket

assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}
for line in Path("/proc/net/route").read_text().splitlines()[1:]:
    fields = line.split()
    assert fields[1] != "00000000", "IPv4 default route present"
for line in Path("/proc/net/ipv6_route").read_text().splitlines():
    fields = line.split()
    is_default = fields[0] == "0" * 32 and fields[1] == "00"
    is_reject = int(fields[8], 16) & 0x200
    assert not is_default or is_reject, "Usable IPv6 default route present"
try:
    with socket.create_connection(("192.0.2.1", 443), timeout=1):
        raise SystemExit("External test address unexpectedly reachable")
except OSError as error:
    if error.errno != errno.ENETUNREACH:
        raise
NETWORK
echo 'PASS: private runtime network has only loopback and no default routes'

emulator_pid=
cleanup() {
  if [ -n "$emulator_pid" ]; then
    kill "$emulator_pid" 2>/dev/null || true
    wait "$emulator_pid" 2>/dev/null || true
  fi
  "$adb" kill-server </dev/null
}
trap cleanup EXIT
"$sdk/emulator/emulator" -avd cairn-api26-x86_64 \
  -port 5554 -accel on -no-window -no-audio -no-snapshot \
  -gpu swiftshader -memory 2048 -cores 2 \
  > "$HOME/artifacts/isolated-emulator.log" 2>&1 &
emulator_pid=$!
echo 'PROOF: waiting for Android transport'
if ! timeout 120s "$adb" -s "$serial" wait-for-device </dev/null; then
  cat "$HOME/artifacts/isolated-emulator.log" >&2
  exit 1
fi
echo 'PROOF: Android transport connected; waiting for boot completion'
ready=0
for attempt in $(seq 1 60); do
  if test "$(timeout 5s "$adb" -s "$serial" shell -T \
    getprop sys.boot_completed </dev/null | tr -d '\r')" = 1; then
    ready=1
    break
  fi
  kill -0 "$emulator_pid"
  sleep 2
done
test "$ready" = 1
echo 'PROOF: Android boot completion observed; checking SDK and ABI'
test "$(timeout 10s "$adb" -s "$serial" shell -T \
  getprop ro.build.version.sdk </dev/null | tr -d '\r')" = 26
test "$(timeout 10s "$adb" -s "$serial" shell -T \
  getprop ro.product.cpu.abi </dev/null | tr -d '\r')" = x86_64
packages=$(timeout 10s "$adb" -s "$serial" shell -T \
  pm list packages --user 0 ch.trancee.cairn.consumer </dev/null)
if printf '%s\n' "$packages" | grep -Fxq 'package:ch.trancee.cairn.consumer'; then
  echo 'Smoke package already installed in fresh AVD' >&2
  exit 1
fi
echo 'PROOF: fresh package state verified; installing APK'
timeout 60s "$adb" -s "$serial" install --user 0 \
  "$HOME/artifacts/androidConsumer-debug.apk" </dev/null
timeout 60s "$adb" -s "$serial" shell -T \
  am instrument --user 0 -w -r ch.trancee.cairn.consumer/.SmokeInstrumentation \
  </dev/null > "$HOME/artifacts/isolated-instrumentation.txt" 2>&1
cat "$HOME/artifacts/isolated-instrumentation.txt"
grep -Fx 'INSTRUMENTATION_CODE: -1' "$HOME/artifacts/isolated-instrumentation.txt"
grep -F 'PASS: Android value, boundary, typed error and object lifetime' \
  "$HOME/artifacts/isolated-instrumentation.txt"
if grep -Eq 'INSTRUMENTATION_FAILED|INSTRUMENTATION_ABORTED|shortMsg=' \
  "$HOME/artifacts/isolated-instrumentation.txt"; then
  echo 'Instrumentation reported failure' >&2
  exit 1
fi
echo 'PASS: Android FFI executed without external runtime networking'
RUN
