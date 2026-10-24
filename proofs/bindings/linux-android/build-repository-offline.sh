#!/usr/bin/env bash
set -euo pipefail

# Builds and tests the root Gradle build from a source archive in a
# networkless sandbox, using only inputs from prepare-repository-inputs.sh.
if [ "$(id -u)" -ne 0 ]; then
  echo 'Run the repository build proof as root' >&2
  exit 2
fi
if [ "$#" -ne 2 ]; then
  echo 'Usage: sudo bash build-repository-offline.sh SOURCE_ARCHIVE LABEL' >&2
  exit 2
fi
source_archive=$(realpath "$1")
label=$2
case "$label" in
  *[!A-Za-z0-9._-]* | '' | .*) echo "Unsafe label: $label" >&2; exit 2 ;;
esac
inputs=/opt/cairn-binding-seeds/repository-inputs/$label
canonical="$inputs/canonical-inputs"
evidence=/var/lib/cairn-repository-proof/$label
scratch=/srv/cairn-repository-scratch
(cd "$inputs" && sha256sum --quiet --check SHA256SUMS)
(cd "$canonical" && sha256sum --quiet --check SHA256SUMS)
sha256sum "$source_archive"
if [ -e "$scratch" ]; then
  echo 'Repository scratch already exists; refusing retained-state build' >&2
  exit 2
fi
cleanup() {
  # Test results are evidence for both passing and failing runs.
  install -d -o root -g root -m 0755 "$evidence"
  (cd "$scratch/source" 2>/dev/null &&
    find . -path '*/build/test-results/*' -name '*.xml' -print0 |
    tar --null -T - -czf "$evidence/test-results.tar.gz") || true
  rm -rf -- "$scratch"
}
trap cleanup EXIT
install -d -o cairn-build -g cairn-build -m 0700 "$scratch"
install -d -o cairn-build -g cairn-build -m 0755 \
  "$scratch/source" "$scratch/home" "$scratch/cargo/registry" "$scratch/gradle-home" "$scratch/cargo-target"
runuser -u cairn-build -- tar -xzf - -C "$scratch/source" < "$source_archive"
runuser -u cairn-build -- tar -xzf - -C "$scratch/gradle-home" < "$inputs/gradle-metadata.tar.gz"
runuser -u cairn-build -- install -d "$scratch/gradle-home/caches/modules-2/files-2.1"

source="$scratch/source"
read_only=(settings.gradle.kts build.gradle.kts gradle.properties gradle rust-toolchain.toml core
  sdk/build.gradle.kts sdk/src app/build.gradle.kts app/src androidApp/build.gradle.kts androidApp/src)
bindings=(
  -p "BindReadOnlyPaths=$canonical/cargo/registry:$scratch/cargo/registry"
  -p "BindReadOnlyPaths=$canonical/gradle/files-2.1:$scratch/gradle-home/caches/modules-2/files-2.1"
)
for input in "${read_only[@]}"; do
  test -e "$source/$input"
  bindings+=(-p "BindReadOnlyPaths=$source/$input")
done

systemd-run --unit=cairn-repository-proof-build \
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
  -p "ReadWritePaths=$scratch" \
  -p "ReadOnlyPaths=$inputs" \
  "${bindings[@]}" \
  -p MemoryMax=12G -p MemorySwapMax=0 \
  -p TasksMax=256 -p CPUQuota=400% \
  -p RuntimeMaxSec=1800 -p TimeoutStopSec=10 \
  -p LimitCPU=3600 -p LimitFSIZE=2G -p LimitCORE=0 \
  /usr/bin/env -i \
    PATH=/opt/cairn-toolchains/rust-1.99.0/bin:/usr/bin:/bin \
    JAVA_HOME=/opt/cairn-toolchains/jdk-25.0.4.1 \
    "JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=$scratch/home -Duser.home=$scratch/home" \
    ANDROID_HOME=/opt/cairn-toolchains/android-sdk \
    ANDROID_USER_HOME="$scratch/home/android" \
    HOME="$scratch/home" TMPDIR="$scratch/home" LANG=C.UTF-8 \
    GRADLE_USER_HOME="$scratch/gradle-home" \
    CARGO_HOME="$scratch/cargo" CARGO_TARGET_DIR="$scratch/cargo-target" \
    CARGO_NET_OFFLINE=true CARGO_BUILD_JOBS=4 \
    SCRATCH="$scratch" \
  /bin/bash -se <<'BUILD'
set -euo pipefail
cd "$SCRATCH/source"
/usr/bin/python3 - <<'NETWORK'
from pathlib import Path

assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}
NETWORK
for input in settings.gradle.kts gradle/libs.versions.toml core/Cargo.lock sdk/src app/src androidApp/src \
  "$SCRATCH/cargo/registry" "$SCRATCH/gradle-home/caches/modules-2/files-2.1"; do
  if touch "$input/.cairn-write-probe" 2>/dev/null || { test -f "$input" && test -w "$input"; }; then
    echo "FAIL: input is writable: $input" >&2
    exit 1
  fi
done
echo 'PASS: networkless sandbox; source and downloaded inputs read-only'

/opt/cairn-toolchains/gradle-9.7.0/bin/gradle \
  --offline --no-daemon --max-workers=2 --console=plain --rerun-tasks --continue \
  -Pcairn.uniffi.bindgen=/opt/cairn-binding-seeds/ubique-1.3.2/bindgen \
  -Porg.gradle.java.installations.paths=/usr/lib/jvm/java-21-openjdk-amd64 \
  -Porg.gradle.java.installations.auto-download=false \
  -Pkotlin.compiler.execution.strategy=in-process \
  -PandroidAbis=x86_64,arm64-v8a \
  :sdk:jvmTest :sdk:koverVerify :androidApp:assembleDebug

apk=androidApp/build/outputs/apk/debug/androidApp-debug.apk
unzip -Z1 "$apk" > "$TMPDIR/apk-entries.txt"
for abi in arm64-v8a x86_64; do
  for library in libcairn_ffi.so libuniffi_runtime.so libjnidispatch.so; do
    grep -Fx "lib/$abi/$library" "$TMPDIR/apk-entries.txt"
  done
done
sha256sum "$apk"
echo 'PASS: offline JVM binding tests; Android debug packaging'
BUILD
install -d -o root -g root -m 0755 "$evidence"
install -o root -g root -m 0644 \
  "$scratch/source/androidApp/build/outputs/apk/debug/androidApp-debug.apk" "$evidence/androidApp-debug.apk"
(cd "$inputs" && sha256sum --quiet --check SHA256SUMS)
(cd "$canonical" && sha256sum --quiet --check SHA256SUMS)
echo "PASS: canonical inputs unchanged; APK retained at $evidence"
