#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2
tools=$1
python=$2
fixture="$HOME/fixture-targets"
/bin/bash "$tools/create-plugin-project.sh" "$tools" "$fixture"
export PATH="$tools/rust/bin:$PATH"
export CARGO_HOME="$HOME/cargo"
export CARGO_TARGET_DIR="$HOME/cargo-target"
export KONAN_DATA_DIR="$HOME/konan"
export GRADLE_RO_DEP_CACHE="$tools/gradle-dependencies"
test -d "$GRADLE_RO_DEP_CACHE/modules-2"
result=0
"$tools/gradle/bin/gradle" -p "$fixture" --offline --no-daemon --console=plain --stacktrace \
  -Djava.net.preferIPv4Stack=true -PcairnProofPlatform=apple \
  -Porg.gradle.java.installations.paths="$tools/compiler-jdk" \
  -Porg.gradle.java.installations.auto-download=false \
  --init-script "$tools/assert-apple-targets.gradle" \
  --init-script "$tools/resolve-apple-inputs.gradle" cairnResolveAppleInputs \
  > "$HOME/fixture-targets.log" 2>&1 || result=$?
cat "$HOME/fixture-targets.log"
if [ "$result" -ne 0 ]; then exit "$result"; fi
grep -F 'PASS: effective Apple SDK targets' "$HOME/fixture-targets.log"
"$python" -I -c '
import os
from pathlib import Path
artifacts = list((Path(os.environ["GRADLE_USER_HOME"]) / "caches").rglob(
    "instrumented-kotlin-gradle-plugin-2.4.20-gradle96.jar"))
if not artifacts:
    raise SystemExit("FAIL: instrumented Kotlin plugin artifact missing")
for artifact in artifacts:
    size = artifact.stat().st_size
    if not 64 * 1024**2 < size <= 128 * 1024**2:
        raise SystemExit(f"FAIL: instrumented Kotlin plugin size {size} outside expected budget")
    print(f"PASS: instrumented Kotlin plugin {size} bytes within 128 MiB file ceiling")
'
echo 'PASS: offline Apple plugin configuration; no binding build tasks requested'
