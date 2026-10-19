#!/usr/bin/env bash
set -euo pipefail
if [ "${GITHUB_ACTIONS:-}" != true ]; then
  echo 'FAIL: resource probes require the authorized hosted job environment' >&2
  exit 2
fi
test "$(id -u)" -eq 0
test "$#" -eq 1 || test "$#" -eq 3
output=$1
test -d "$output"
scripts="$(cd "$(dirname "$0")" && pwd -P)"
python=$(xcrun --find python3)
if [ "${CAIRN_PF_ACTIVE:-}" != true ]; then
  exec /bin/bash "$scripts/run-pf-probes.sh" /bin/bash "$scripts/run-resource-probes.sh" "$@"
fi
user=cairnbenignprobe
uid=59000
test "$(dscl . -list /Users UniqueID | awk '$2 == 59000 {print $1}' | wc -l)" -eq 0
if dscl . -read "/Users/$user" >/dev/null 2>&1; then
  echo 'FAIL: dedicated probe account already exists' >&2
  exit 1
fi
work=$(mktemp -d /private/tmp/cairn-resource-XXXXXXXX)
volume="$work/scratch"
image="$work/scratch.dmg"
created=0
mounted=0
finish() {
  result=$?
  trap - EXIT
  if [ "$created" -eq 1 ]; then
    if ! dscl . -delete "/Users/$user"; then result=1; fi
  fi
  if [ "$mounted" -eq 1 ]; then
    if ! "$python" -I "$scripts/detach-scratch.py" "$volume" "$image"; then
      result=1
    fi
  fi
  echo "DIAGNOSTIC: hosted-only resource fixture retained at $work"
  exit "$result"
}
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
chmod 0755 "$work"
mkdir "$volume"
boundary=true
plan=
if [ "$#" -eq 3 ]; then
  plan=$("$python" -I "$scripts/cell-plan.py" "$3")
  case "$(printf '%s\n' "$plan" | sed -n 2p)" in
    boundary-probes=true) ;;
    boundary-probes=false) boundary=false ;;
    *) echo 'FAIL: cell plan has no boundary-probe decision' >&2; exit 2 ;;
  esac
fi
dscl . -create "/Users/$user"
created=1
dscl . -create "/Users/$user" UniqueID "$uid"
dscl . -create "/Users/$user" PrimaryGroupID 20
dscl . -create "/Users/$user" UserShell /usr/bin/false
dscl . -create "/Users/$user" NFSHomeDirectory "$volume"
dscl . -create "/Users/$user" AuthenticationAuthority ';DisabledUser;'
mkdir "$work/inputs"
mkdir "$work/proof-output"
chmod 0700 "$work/proof-output"
cp "$scripts/probe.py" "$work/inputs/probe.py"
cp "$scripts/build.sb" "$work/build.sb"
printf 'benign sentinel\n' > "$work/host-sentinel"
printf 'benign unlisted host data\n' > "$work/host-unlisted"
chmod 0755 "$work/inputs"
chmod 0644 "$work/inputs/probe.py" "$work/build.sb" "$work/host-sentinel" "$work/host-unlisted"
cat > "$work/command.sh" <<'COMMAND'
#!/usr/bin/env bash
set -euo pipefail
exec "$3" -I "$2/uid-supervisor.py" --seconds 30 "$1/proof-output/sandbox.log" \
  /usr/bin/sandbox-exec -D "INPUTS=$1/inputs" -D "SCRATCH=$1/scratch" \
  -D "SENTINEL=$1/host-sentinel" -D PRIVATE_IPC=false -f "$1/build.sb" \
  "$3" -I "$1/inputs/probe.py" "$1/scratch" "$1/inputs" "$1/host-sentinel" "$4" "$5" --build-limits
COMMAND
chmod 0644 "$work/command.sh"
if [ "$boundary" = true ]; then
  hdiutil create -size 256m -fs HFS+ -type UDIF -volname cairn-benign-scratch "$image"
  hdiutil attach -nobrowse -mountpoint "$volume" "$image"
  mounted=1
  diskutil enableOwnership "$volume"
  chown "$uid:20" "$volume"
  chmod 0700 "$volume"
  "$python" -B -m unittest discover -s "$scripts" -p 'test_uid_supervisor.py'
  "$python" -I "$scripts/probe-pf.py" "$work/proof-output/pf.log"
  cp "$scripts/probe-resources.py" "$work/probe-resources.py"
  chmod 0644 "$work/probe-resources.py"
  if sudo -u "$user" /usr/bin/env -i PATH=/usr/bin:/bin HOME="$volume" TMPDIR="$volume" \
    "$python" -I "$work/probe-resources.py" "$volume" 2>&1 | tee "$output/resources.log"; then
    echo 'PASS: hosted-only resource probes completed'
  else
    result=$?
    cat "$output/resources.log" >&2
    exit "$result"
  fi
  hdiutil detach "$volume"
  mounted=0
else
  echo 'INFO: boundary probes run in the parallel isolation cell'
fi
image="$work/build-scratch.dmg"
hdiutil create -size 8g -fs HFS+ -type UDIF -volname cairn-build-scratch "$image"
"$python" -I "$scripts/reserve-build-image.py" "$image"
hdiutil attach -nobrowse -mountpoint "$volume" "$image"
mounted=1
diskutil enableOwnership "$volume"
chown "$uid:20" "$volume"
chmod 0700 "$volume"
"$python" -I "$scripts/check-build-scratch.py" "$image" "$volume"
if [ "$boundary" = true ]; then
  cp "$scripts/probe-pf.py" "$work/inputs/probe-pf.py"
  chmod 0644 "$work/inputs/probe-pf.py"
  "$python" -I "$scripts/probe-pf.py" "$work/proof-output/sandbox-pf.log" \
    "$volume" "$work/inputs" "$work/build.sb"
fi
if [ "$#" -eq 3 ]; then
  tools=$2
  scope=$3
  test "$tools" = /opt/cairn-apple-tools
  test "$(stat -f %u "$tools")" -eq 0
  sudo -n -u "$user" /bin/test -x "$tools/rust/bin/rustc"
  if [ "$(printf '%s\n' "$plan" | head -n 1)" = codeql=true ]; then
    test -d "$tools/codeql"
    cat "$work/build.sb" "$scripts/codeql-parent.sb" > "$work/codeql.sb"
    chmod 0644 "$work/codeql.sb"
  else
    test ! -e "$tools/codeql"
  fi
  cp "$scripts/probe-toolchains.sh" "$work/inputs/probe-toolchains.sh"
  chmod 0644 "$work/inputs/probe-toolchains.sh"
  echo "INFO: bounded cell scope $scope"
  for probe in $(printf '%s\n' "$plan" | tail -n +3); do
    case "$probe" in
    codeql-startup)
      codeql_result=0
      "$python" -I "$scripts/uid-supervisor.py" --seconds 300 "$work/proof-output/codeql-startup.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=true -f "$work/codeql.sb" \
        /bin/bash "$tools/check-codeql-startup.sh" "$tools" || codeql_result=$?
      if [ "$codeql_result" -ne 0 ]; then
        if [ -d "$volume/codeql-startup/database/log" ]; then
          ditto "$volume/codeql-startup/database/log" "$output/codeql-startup-logs"
          chown -R root:wheel "$output/codeql-startup-logs"
          chmod -R a+rX,a-w "$output/codeql-startup-logs"
        fi
        exit "$codeql_result"
      fi
      ;;
    toolchains|toolchain-startup)
      toolchain_mode=()
      if [ "$probe" = toolchain-startup ]; then toolchain_mode=(--startup-only); fi
      "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/toolchains.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=true -f "$work/build.sb" \
        /bin/bash "$work/inputs/probe-toolchains.sh" "$tools" ${toolchain_mode[@]+"${toolchain_mode[@]}"}
      ;;
    fixture-targets)
      "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/fixture-targets.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=true -f "$work/build.sb" \
        /usr/bin/env JAVA_HOME="$tools/daemon-jdk" GRADLE_USER_HOME="$volume/gradle" \
        GRADLE_DAEMON_BIND_ADDRESS=127.0.0.2 \
        /bin/bash "$tools/check-fixture-targets.sh" "$tools" "$python"
      "$python" -I "$scripts/check-build-scratch.py" "$image" "$volume"
      ;;
    cargo-inputs)
      "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/cargo-inputs.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=false -f "$work/build.sb" \
        /bin/bash "$tools/check-cargo-inputs.sh" "$tools"
      ;;
    native-tool)
      "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/native-tool.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=false -f "$work/build.sb" \
        /bin/bash "$tools/check-native-tool.sh" "$tools"
      ;;
    native-compilation)
      "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/native-compilation.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=false -f "$work/build.sb" \
        /bin/bash "$tools/check-native-compilation.sh" "$tools"
      ;;
    native-cinterop)
      cinterop_result=0
      "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/native-cinterop.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=false -f "$work/build.sb" \
        /bin/bash "$tools/check-native-cinterop.sh" "$tools" || cinterop_result=$?
      if [ "$cinterop_result" -ne 0 ]; then
        "$python" -I -c \
          'import subprocess; subprocess.run(["/usr/bin/log","show","--last","2m","--style","compact","--predicate","process == \"kernel\" AND eventMessage CONTAINS \"Sandbox\" AND (eventMessage CONTAINS \"xcrun(\" OR eventMessage CONTAINS \"xcodebuild(\" OR eventMessage CONTAINS \"java(\" OR eventMessage CONTAINS \"clang(\")"],timeout=15,check=True)' \
          || echo 'DIAGNOSTIC: targeted sandbox denial collection failed'
        exit "$cinterop_result"
      fi
      ;;
    native-linkage)
      for target in ios_arm64 ios_simulator_arm64; do
        "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/native-linkage-$target.log" \
          /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
          -D PRIVATE_IPC=false -f "$work/build.sb" \
          /bin/bash "$tools/check-native-linkage.sh" "$tools" "$target"
      done
      ;;
    allocator-inputs)
      "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/allocator-inputs.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=false -f "$work/build.sb" \
        /usr/bin/env PATH="$tools/rust/bin:/usr/bin:/bin" \
        CARGO_HOME="$volume/cargo-offline" CARGO_NET_OFFLINE=true \
        CARGO_TARGET_DIR="$volume/cargo-metadata-target" \
        "$python" -I "$tools/inspect-allocator-inputs.py" "$tools"
      ;;
    fixture-rust)
      for target in aarch64-apple-darwin aarch64-apple-ios aarch64-apple-ios-sim; do
        "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/fixture-rust-$target.log" \
          /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
          -D PRIVATE_IPC=false -f "$work/build.sb" \
          /bin/bash "$tools/check-fixture-rust.sh" "$tools" "$target"
        "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/fixture-allocator-$target.log" \
          /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
          -D PRIVATE_IPC=false -f "$work/build.sb" \
          "$python" -I "$tools/inspect-fixture-artifacts.py" "$target"
      done
      ;;
    install-bindgen)
      "$python" -I "$scripts/uid-supervisor.py" --seconds 600 --diagnose-after 540 \
        "$work/proof-output/fixture-install-bindgen.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=true -f "$work/build.sb" \
        /bin/bash "$tools/check-fixture-bindings.sh" "$tools" :sdk:installBindgen
      ;;
    build-bindings)
      "$python" -I "$scripts/uid-supervisor.py" --seconds 300 "$work/proof-output/fixture-bindings.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=true -f "$work/build.sb" \
        /bin/bash "$tools/check-fixture-bindings.sh" "$tools" :sdk:buildBindings
      ;;
    jvm)
      jvm_command=("$tools/check-fixture-bindings.sh" "$tools" :consumer:interopSmoke)
      jvm_profile="$work/build.sb"
      if [ -d "$tools/codeql" ]; then
        jvm_command=("$tools/check-codeql-bindings.sh" "$tools")
        jvm_profile="$work/codeql.sb"
      fi
      "$python" -I "$scripts/uid-supervisor.py" --seconds 300 "$work/proof-output/fixture-jvm.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=true -f "$jvm_profile" \
        /bin/bash "${jvm_command[@]}"
      ;;
    codeql-analysis)
      analysis_result=0
      "$python" -I "$scripts/uid-supervisor.py" --seconds 300 \
        "$work/proof-output/codeql-analysis.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=false -f "$work/codeql.sb" \
        /bin/bash "$tools/check-codeql-analysis.sh" "$tools" "$python" || analysis_result=$?
      if [ "$analysis_result" -ne 0 ]; then
        if [ -d "$volume/codeql-analysis" ]; then
          ditto "$volume/codeql-analysis" "$output/codeql-failed-analysis"
          printf 'FAILED: strict CodeQL analysis exit %s\n' "$analysis_result" \
            > "$output/codeql-failed-analysis/status.txt"
          chown -R root:wheel "$output/codeql-failed-analysis"
          chmod -R a+rX,a-w "$output/codeql-failed-analysis"
        fi
        exit "$analysis_result"
      fi
      ditto "$volume/codeql-analysis" "$output/codeql-analysis"
      chown -R root:wheel "$output/codeql-analysis"
      chmod -R a+rX,a-w "$output/codeql-analysis"
      ditto "$volume/codeql-java" "$output/codeql-java"
      chown -R root:wheel "$output/codeql-java"
      chmod -R a+rX,a-w "$output/codeql-java"
      echo 'PASS: finalized Kotlin CodeQL database exported before scratch teardown'
      ;;
    native-binaries)
      "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/fixture-tasks.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=true -f "$work/build.sb" \
        /bin/bash "$tools/check-fixture-bindings.sh" "$tools" :sdk:tasks
      for task in :sdk:compileKotlinIosArm64 :sdk:compileKotlinIosSimulatorArm64 \
        :sdk:compileNativeMainKotlinMetadata :sdk:linkDebugFrameworkIosArm64 \
        :sdk:linkDebugFrameworkIosSimulatorArm64; do
        "$python" -I "$scripts/uid-supervisor.py" --seconds 300 \
          "$work/proof-output/fixture-native-${task##*:}.log" \
          /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
          -D PRIVATE_IPC=true -f "$work/build.sb" \
          /bin/bash "$tools/check-fixture-bindings.sh" "$tools" "$task"
      done
      "$python" -I "$scripts/uid-supervisor.py" --seconds 300 \
        "$work/proof-output/fixture-simulator-executable.log" \
        /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
        -D PRIVATE_IPC=true -f "$work/build.sb" \
        /bin/bash "$tools/check-fixture-bindings.sh" "$tools" :sdk:linkDebugExecutableIosSimulatorArm64
      binary="$volume/fixture-targets/sdk/build/bin/iosSimulatorArm64/debugExecutable/CairnSimulatorSmoke.kexe"
      test -f "$binary"
      test ! -L "$binary"
      test "$(stat -f %z "$binary")" -le 134217728
      mkdir -m 0755 "$output/simulator-payload"
      cp "$binary" "$output/simulator-payload/CairnSimulatorSmoke.kexe"
      cmp "$binary" "$output/simulator-payload/CairnSimulatorSmoke.kexe"
      chmod 0444 "$output/simulator-payload/CairnSimulatorSmoke.kexe"
      (cd "$output/simulator-payload" && shasum -a 256 CairnSimulatorSmoke.kexe > payload.sha256)
      chmod 0444 "$output/simulator-payload/payload.sha256"
      echo 'PASS: verified simulator executable exported before scratch teardown'
      ;;
    *)
      echo "FAIL: unplanned cell probe $probe" >&2
      exit 2
      ;;
    esac
  done
fi
if [ "$boundary" = true ]; then
  "$python" -I "$scripts/launch-probes.py" "$work" "$scripts" "$python" \
    | tee "$output/dedicated-sandbox.log"
fi
"$python" -I "$scripts/check-build-scratch.py" "$image" "$volume"
