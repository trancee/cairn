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
canonical=/opt/cairn-binding-seeds/final-image-inputs-e75437d/canonical-inputs
(cd "$canonical" && sha256sum --quiet --check SHA256SUMS)
bindings=()
for input in settings.gradle.kts build.gradle.kts gradle.properties \
  sdk/build.gradle.kts sdk/rust consumer/build.gradle.kts consumer/src \
  androidConsumer/build.gradle.kts androidConsumer/src; do
  bindings+=(-p "BindReadOnlyPaths=$canonical/fixture/$input:$source_directory/$input")
done
bindings+=(
  -p "BindReadOnlyPaths=$canonical/cargo/registry:/srv/cairn-generator-scratch/fixture-cargo/registry"
  -p "BindReadOnlyPaths=$canonical/gradle/caches/modules-2/files-2.1:/srv/cairn-generator-scratch/kmp-gradle-cache/caches/modules-2/files-2.1"
)

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
  -p "ReadOnlyPaths=$canonical" \
  "${bindings[@]}" \
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
/usr/bin/python3 /opt/cairn-binding-seeds/final-image-inputs-e75437d/check-resources.py build

/usr/bin/python3 - <<'PROBE'
import errno
import os
from pathlib import Path

canonical = Path("/opt/cairn-binding-seeds/final-image-inputs-e75437d/canonical-inputs")
workspace = Path.cwd()
mounts = {
    line.split()[4]: line.split()[5].split(",")
    for line in Path("/proc/self/mountinfo").read_text().splitlines()
}
mapped = [
    (canonical / "fixture" / name, workspace / name)
    for name in [
        "settings.gradle.kts", "build.gradle.kts", "gradle.properties",
        "sdk/build.gradle.kts", "sdk/rust", "consumer/build.gradle.kts",
        "consumer/src", "androidConsumer/build.gradle.kts", "androidConsumer/src",
    ]
]
mapped += [
    (canonical / "cargo/registry", Path("/srv/cairn-generator-scratch/fixture-cargo/registry")),
    (canonical / "gradle/caches/modules-2/files-2.1",
     Path("/srv/cairn-generator-scratch/kmp-gradle-cache/caches/modules-2/files-2.1")),
]
for original, mounted in mapped:
    if not os.path.samefile(original, mounted):
        raise SystemExit(f"Input does not resolve to canonical object: {mounted}")
    covering = max(
        (mount for mount in mounts if mounted == Path(mount) or Path(mount) in mounted.parents),
        key=len,
    )
    if "ro" not in mounts[covering]:
        raise SystemExit(f"Canonical input mount is writable: {mounted}")
for project in [workspace, workspace / "sdk", workspace / "consumer", workspace / "androidConsumer"]:
    if not os.access(project, os.W_OK):
        raise SystemExit(f"Disposable project shell is not writable: {project}")
for directory in [
    canonical / "fixture", canonical / "cargo/registry",
    canonical / "gradle/caches/modules-2/files-2.1",
]:
    try:
        descriptor = os.open(directory / ".cairn-write-probe", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except OSError as error:
        if error.errno not in (errno.EROFS, errno.EACCES):
            raise
    else:
        os.close(descriptor)
        raise SystemExit(f"Canonical namespace permits additions: {directory}")

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
        if error.errno not in (errno.EROFS, errno.EACCES):
            raise
    else:
        raise SystemExit(f"Input is writable: {path}")
print("PASS: source/configuration and downloaded dependency inputs are read-only")
print("PASS: complete input mapping resolves to canonical read-only objects; project shells writable")
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
(cd "$canonical" && sha256sum --quiet --check SHA256SUMS)
echo 'PASS: canonical input manifest unchanged after build'
