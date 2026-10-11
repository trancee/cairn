#!/usr/bin/env bash
set -euo pipefail
if [ "${GITHUB_ACTIONS:-}" != true ]; then
  echo 'FAIL: resource probes require the authorized hosted job environment' >&2
  exit 2
fi
test "$(id -u)" -eq 0
test "$#" -ge 1
test "$#" -le 2
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
    if ! hdiutil detach "$volume"; then
      result=1
      echo 'DIAGNOSTIC: failed scratch detach; open-file holder PIDs and command names only'
      "$python" -I -c \
        'import subprocess, sys; subprocess.run(["/usr/sbin/lsof", "-nP", "-Fpc", "+D", sys.argv[1]], timeout=15, check=True)' \
        "$volume" || echo 'DIAGNOSTIC: open-file holder collection failed'
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
hdiutil create -size 256m -fs HFS+ -type UDIF -volname cairn-benign-scratch "$image"
hdiutil attach -nobrowse -mountpoint "$volume" "$image"
mounted=1
diskutil enableOwnership "$volume"
dscl . -create "/Users/$user"
created=1
dscl . -create "/Users/$user" UniqueID "$uid"
dscl . -create "/Users/$user" PrimaryGroupID 20
dscl . -create "/Users/$user" UserShell /usr/bin/false
dscl . -create "/Users/$user" NFSHomeDirectory "$volume"
dscl . -create "/Users/$user" AuthenticationAuthority ';DisabledUser;'
chown "$uid:20" "$volume"
chmod 0700 "$volume"
"$python" -B -m unittest discover -s "$scripts" -p 'test_uid_supervisor.py'
mkdir "$work/inputs"
mkdir "$work/proof-output"
chmod 0700 "$work/proof-output"
"$python" -I "$scripts/probe-pf.py" "$work/proof-output/pf.log"
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
image="$work/build-scratch.dmg"
hdiutil create -size 8g -fs HFS+ -type UDIF -volname cairn-build-scratch "$image"
"$python" -I "$scripts/reserve-build-image.py" "$image"
hdiutil attach -nobrowse -mountpoint "$volume" "$image"
mounted=1
diskutil enableOwnership "$volume"
chown "$uid:20" "$volume"
chmod 0700 "$volume"
"$python" -I "$scripts/check-build-scratch.py" "$image" "$volume"
cp "$scripts/probe-pf.py" "$work/inputs/probe-pf.py"
chmod 0644 "$work/inputs/probe-pf.py"
"$python" -I "$scripts/probe-pf.py" "$work/proof-output/sandbox-pf.log" \
  "$volume" "$work/inputs" "$work/build.sb"
if [ "$#" -eq 2 ]; then
  tools=$2
  test "$tools" = /opt/cairn-apple-tools
  test "$(stat -f %u "$tools")" -eq 0
  sudo -n -u "$user" /bin/test -x "$tools/rust/bin/rustc"
  cp "$scripts/probe-toolchains.sh" "$work/inputs/probe-toolchains.sh"
  chmod 0644 "$work/inputs/probe-toolchains.sh"
  "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/toolchains.log" \
    /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
    -D PRIVATE_IPC=true -f "$work/build.sb" \
    /bin/bash "$work/inputs/probe-toolchains.sh" "$tools"
  "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/fixture-targets.log" \
    /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
    -D PRIVATE_IPC=true -f "$work/build.sb" \
    /usr/bin/env JAVA_HOME="$tools/daemon-jdk" GRADLE_USER_HOME="$volume/gradle" \
    GRADLE_DAEMON_BIND_ADDRESS=127.0.0.2 \
    /bin/bash "$tools/check-fixture-targets.sh" "$tools" "$python"
  "$python" -I "$scripts/check-build-scratch.py" "$image" "$volume"
  "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/cargo-inputs.log" \
    /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
    -D PRIVATE_IPC=false -f "$work/build.sb" \
    /bin/bash "$tools/check-cargo-inputs.sh" "$tools"
  "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/native-tool.log" \
    /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
    -D PRIVATE_IPC=false -f "$work/build.sb" \
    /bin/bash "$tools/check-native-tool.sh" "$tools"
  "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/native-compilation.log" \
    /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
    -D PRIVATE_IPC=false -f "$work/build.sb" \
    /bin/bash "$tools/check-native-compilation.sh" "$tools"
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
  for target in ios_arm64 ios_simulator_arm64; do
    "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/native-linkage-$target.log" \
      /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
      -D PRIVATE_IPC=false -f "$work/build.sb" \
      /bin/bash "$tools/check-native-linkage.sh" "$tools" "$target"
  done
  "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/allocator-inputs.log" \
    /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
    -D PRIVATE_IPC=false -f "$work/build.sb" \
    /usr/bin/env PATH="$tools/rust/bin:/usr/bin:/bin" \
    CARGO_HOME="$volume/cargo-offline" CARGO_NET_OFFLINE=true \
    CARGO_TARGET_DIR="$volume/cargo-metadata-target" \
    "$python" -I "$tools/inspect-allocator-inputs.py" "$tools"
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
  "$python" -I "$scripts/uid-supervisor.py" --seconds 600 --diagnose-after 540 \
    "$work/proof-output/fixture-install-bindgen.log" \
    /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
    -D PRIVATE_IPC=true -f "$work/build.sb" \
    /bin/bash "$tools/check-fixture-bindings.sh" "$tools" :sdk:installBindgen
  "$python" -I "$scripts/uid-supervisor.py" --seconds 300 "$work/proof-output/fixture-bindings.log" \
    /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
    -D PRIVATE_IPC=true -f "$work/build.sb" \
    /bin/bash "$tools/check-fixture-bindings.sh" "$tools" :sdk:buildBindings
  "$python" -I "$scripts/uid-supervisor.py" --seconds 300 "$work/proof-output/fixture-jvm.log" \
    /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
    -D PRIVATE_IPC=true -f "$work/build.sb" \
    /bin/bash "$tools/check-fixture-bindings.sh" "$tools" :consumer:interopSmoke
  "$python" -I "$scripts/uid-supervisor.py" --seconds 60 "$work/proof-output/fixture-tasks.log" \
    /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
    -D PRIVATE_IPC=true -f "$work/build.sb" \
    /bin/bash "$tools/check-fixture-bindings.sh" "$tools" :sdk:tasks
  for task in :sdk:compileKotlinIosArm64 :sdk:compileKotlinIosSimulatorArm64 \
    :sdk:compileNativeMainKotlinMetadata; do
    "$python" -I "$scripts/uid-supervisor.py" --seconds 300 \
      "$work/proof-output/fixture-native-${task##*:}.log" \
      /usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume" \
      -D PRIVATE_IPC=true -f "$work/build.sb" \
      /bin/bash "$tools/check-fixture-bindings.sh" "$tools" "$task"
  done
fi
"$python" -I "$scripts/launch-probes.py" "$work" "$scripts" "$python" \
  | tee "$output/dedicated-sandbox.log"
"$python" -I "$scripts/check-build-scratch.py" "$image" "$volume"
