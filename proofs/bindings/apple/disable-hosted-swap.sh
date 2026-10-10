#!/usr/bin/env bash
set -euo pipefail
test "$(id -u)" -eq 0
test "${GITHUB_ACTIONS:-}" = true
service=system/com.apple.dynamic_pager
launchctl disable "$service"
if launchctl print "$service" >/dev/null 2>&1; then
  launchctl bootout "$service"
else
  echo 'DIAGNOSTIC: dynamic pager service was not loaded'
fi
launchctl print-disabled system | grep -F '"com.apple.dynamic_pager" => true'
if launchctl print "$service" >/dev/null 2>&1; then
  echo 'FAIL: dynamic pager remains loaded' >&2
  exit 1
fi
echo 'PASS: hosted dynamic pager disabled and unloaded; swap observation still required'
