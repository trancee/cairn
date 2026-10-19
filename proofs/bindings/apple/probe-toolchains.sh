#!/usr/bin/env bash
set -euo pipefail
test "$#" -ge 1
test "$#" -le 2
tools=$1
selection=true
if [ "$#" -eq 2 ]; then
  test "$2" = --startup-only
  selection=false
fi
export JAVA_HOME="$tools/daemon-jdk"
export GRADLE_USER_HOME="$HOME/gradle"
export GRADLE_DAEMON_BIND_ADDRESS=127.0.0.2
mkdir "$GRADLE_USER_HOME"
"$tools/rust/bin/rustc" --version --verbose
"$tools/rust/bin/cargo" --version
"$tools/daemon-jdk/bin/java" -version
"$tools/compiler-jdk/bin/java" -version
"$tools/gradle/bin/gradle" --offline --no-daemon --version
echo 'PASS: trusted tool version startup under sandbox'
mkdir "$HOME/empty-gradle-project"
cd "$HOME/empty-gradle-project"
printf "rootProject.name = 'cairn-empty-isolation-probe'\n" > settings.gradle
"$tools/gradle/bin/gradle" --offline --no-daemon --console=plain --stacktrace \
  -Djava.net.preferIPv4Stack=true help
echo 'PASS: trusted empty Gradle help under sandbox; no fixture or plugin compilation'
if [ "$selection" = true ]; then
  /bin/bash "$tools/check-fixture-selection.sh" "$tools"
else
  echo 'INFO: fixture selection is probed in the parallel isolation cell'
fi
