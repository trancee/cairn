#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
  echo 'Usage: bash build-offline.sh' >&2
  exit 2
fi
source_directory="$(cd "$(dirname "$0")" && pwd)"
if [ "$source_directory" != /srv/cairn-generator-scratch/android-interop ]; then
  echo 'Deploy this fixture to /srv/cairn-generator-scratch/android-interop first' >&2
  exit 2
fi

for directory in .gradle .kotlin build sdk/build consumer/build androidConsumer/build; do
  sudo install -d -o cairn-build -g cairn-build -m 0755 "$source_directory/$directory"
done

sudo systemd-run --unit=cairn-binding-proof-build \
  --wait --pipe --collect \
  -p User=cairn-build -p Group=cairn-build \
  -p ProtectSystem=strict -p ProtectHome=yes \
  -p PrivateNetwork=yes -p PrivateDevices=yes \
  -p NoNewPrivileges=yes -p 'CapabilityBoundingSet=' \
  -p RestrictNamespaces=yes -p RestrictSUIDSGID=yes \
  -p ProtectKernelTunables=yes -p ProtectKernelModules=yes \
  -p ProtectControlGroups=yes -p ProtectProc=invisible \
  -p 'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6' \
  -p 'TemporaryFileSystem=/run:ro' \
  -p InaccessiblePaths=/dev/shm \
  -p ReadWritePaths=/srv/cairn-generator-scratch \
  -p "ReadOnlyPaths=$source_directory/settings.gradle.kts $source_directory/build.gradle.kts $source_directory/gradle.properties $source_directory/sdk/build.gradle.kts $source_directory/sdk/rust $source_directory/consumer/build.gradle.kts $source_directory/consumer/src $source_directory/androidConsumer/build.gradle.kts $source_directory/androidConsumer/src /srv/cairn-generator-scratch/fixture-cargo/registry /srv/cairn-generator-scratch/kmp-gradle-cache/caches/modules-2/files-2.1" \
  -p "ReadWritePaths=$source_directory/.gradle $source_directory/.kotlin $source_directory/build $source_directory/sdk/build $source_directory/consumer/build $source_directory/androidConsumer/build" \
  -p MemoryMax=12G -p MemorySwapMax=0 \
  -p TasksMax=256 -p CPUQuota=400% \
  -p RuntimeMaxSec=900 -p TimeoutStopSec=10 \
  -p LimitCPU=600 -p LimitFSIZE=2G -p LimitCORE=0 \
  /usr/bin/env -i \
    PATH=/opt/cairn-toolchains/rust-1.97.1/bin:/usr/bin:/bin \
    JAVA_HOME=/opt/cairn-toolchains/jdk-25.0.4.1 \
    'JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=/srv/cairn-generator-scratch -Duser.home=/srv/cairn-generator-scratch' \
    ANDROID_HOME=/opt/cairn-toolchains/android-sdk \
    ANDROID_USER_HOME=/srv/cairn-generator-scratch/android-user \
    HOME=/srv/cairn-generator-scratch \
    TMPDIR=/srv/cairn-generator-scratch \
    GRADLE_USER_HOME=/srv/cairn-generator-scratch/kmp-gradle-cache \
    CARGO_HOME=/srv/cairn-generator-scratch/fixture-cargo \
    CARGO_NET_OFFLINE=true CARGO_BUILD_JOBS=4 \
    LANG=C.UTF-8 \
  /bin/bash -se <<'BUILD'
set -euo pipefail
mkdir -p "$ANDROID_USER_HOME"
cd /srv/cairn-generator-scratch/android-interop

/usr/bin/python3 - <<'PROBE'
import errno
from pathlib import Path

inputs = [
    Path("settings.gradle.kts"),
    Path("build.gradle.kts"),
    Path("gradle.properties"),
    Path("sdk/build.gradle.kts"),
    Path("sdk/rust/Cargo.lock"),
    Path("sdk/rust/src/lib.rs"),
    Path("consumer/build.gradle.kts"),
    Path("consumer/src/jvmMain/kotlin/Smoke.kt"),
    Path("androidConsumer/build.gradle.kts"),
    Path("androidConsumer/src/main/AndroidManifest.xml"),
]
for directory in [
    "/srv/cairn-generator-scratch/fixture-cargo/registry/src",
    "/srv/cairn-generator-scratch/fixture-cargo/registry/cache",
    "/srv/cairn-generator-scratch/fixture-cargo/registry/index",
    "/srv/cairn-generator-scratch/kmp-gradle-cache/caches/modules-2/files-2.1",
]:
    inputs.append(next(path for path in Path(directory).rglob("*") if path.is_file()))
for path in inputs:
    try:
        with path.open("ab"):
            pass
    except OSError as error:
        if error.errno != errno.EROFS:
            raise
    else:
        raise SystemExit(f"Input is writable: {path}")
print("PASS: source/configuration and downloaded dependency inputs are read-only")
PROBE

/opt/cairn-toolchains/gradle-9.7.0/bin/gradle \
  --offline --no-daemon --max-workers=2 --console=plain --rerun-tasks \
  :consumer:interopSmoke :sdk:bundleAndroidMainAar :androidConsumer:assembleDebug

unzip -Z1 sdk/build/libs/sdk-jvm.jar |
  grep -Fx 'linux-x86-64/libcairn_binding_smoke.so'
aar=sdk/build/outputs/aar/sdk.aar
apk=androidConsumer/build/outputs/apk/debug/androidConsumer-debug.apk
unzip -Z1 "$aar" > "$TMPDIR/binding-aar-entries.txt"
unzip -Z1 "$apk" > "$TMPDIR/binding-apk-entries.txt"
for abi in arm64-v8a x86_64; do
  grep -Fx "jni/$abi/libcairn_binding_smoke.so" "$TMPDIR/binding-aar-entries.txt"
  for library in libcairn_binding_smoke.so libuniffi_runtime.so libjnidispatch.so; do
    grep -Fx "lib/$abi/$library" "$TMPDIR/binding-apk-entries.txt"
  done
done
sha256sum "$aar" "$apk"
echo 'PASS: offline JVM calls and Android debug packaging'
BUILD
