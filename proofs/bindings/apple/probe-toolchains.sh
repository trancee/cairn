#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
export JAVA_HOME="$tools/daemon-jdk"
export GRADLE_USER_HOME="$HOME/gradle"
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
"$tools/gradle/bin/gradle" --offline --no-daemon --console=plain --stacktrace help
echo 'PASS: trusted empty Gradle help under sandbox; no fixture or plugin compilation'
