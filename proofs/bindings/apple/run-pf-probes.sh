#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -eq 0
test "$#" -ge 1
output="$(mktemp -d /private/tmp/cairn-pf-XXXXXXXX)"
anchor="com.apple/cairn-$(uuidgen)"
token=
loaded=0
alias_added=0
finish() {
  result=$?
  trap - EXIT
  if [ "$loaded" -eq 1 ]; then
    if ! /sbin/pfctl -a "$anchor" -vvsr > "$output/pf-counters"; then result=1; fi
    cat "$output/pf-counters"
    if ! /sbin/pfctl -a "$anchor" -F rules; then result=1; fi
  fi
  if [ -n "$token" ]; then
    if ! /sbin/pfctl -X "$token"; then result=1; fi
  fi
  if [ -f "$output/pf-enable" ]; then
    if ! rm "$output/pf-enable"; then result=1; fi
  fi
  if [ "$alias_added" -eq 1 ]; then
    if ! /sbin/ifconfig lo0 -alias 127.0.0.2; then result=1; fi
  fi
  if ! /sbin/pfctl -sr > "$output/pf-main-after"; then result=1; fi
  if ! cmp "$output/pf-main-before" "$output/pf-main-after"; then result=1; fi
  echo "DIAGNOSTIC: named PF anchor cleanup result $result"
  exit "$result"
}
/sbin/pfctl -sr > "$output/pf-main-before"
grep -F 'anchor "com.apple/*"' "$output/pf-main-before"
/sbin/pfctl -a "$anchor" -sr > "$output/pf-anchor-before"
test ! -s "$output/pf-anchor-before"
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
/sbin/ifconfig lo0 > "$output/loopback-before"
if grep -Eq 'inet 127\.0\.0\.2[[:space:]]' "$output/loopback-before"; then
  echo 'FAIL: private loopback alias already exists' >&2
  exit 1
fi
/sbin/ifconfig lo0 alias 127.0.0.2 netmask 255.255.255.255
alias_added=1
cat > "$output/pf-rules" <<'RULES'
block return out quick on lo0 inet proto { tcp, udp } from any to 127.0.0.2 user != 59000 label "cairn-private-origin"
block return in quick on lo0 inet proto { tcp, udp } from any to 127.0.0.2 user != 59000 label "cairn-private-destination"
block return in quick on lo0 inet proto { tcp, udp } from 127.0.0.2 to any user != 59000 label "cairn-private-source"
pass in quick on lo0 inet proto { tcp, udp } from any to 127.0.0.2 user 59000 no state
pass in quick on lo0 inet proto { tcp, udp } from 127.0.0.2 to any user 59000 no state
block return in quick proto { tcp, udp } all user 59000 label "cairn-inbound"
pass out quick on lo0 inet proto { tcp, udp } from any to 127.0.0.2 user 59000 no state
pass out quick on lo0 inet proto { tcp, udp } from 127.0.0.2 to 127.0.0.0/8 user 59000 no state
block return out quick proto { tcp, udp } all user 59000 label "cairn-external"
RULES
/sbin/pfctl -n -a "$anchor" -f "$output/pf-rules"
/sbin/pfctl -a "$anchor" -f "$output/pf-rules"
loaded=1
/sbin/pfctl -E > "$output/pf-enable" 2>&1
token="$(sed -n 's/^Token : \([0-9][0-9]*\)$/\1/p' "$output/pf-enable")"
test -n "$token"
CAIRN_PF_ACTIVE=true "$@"
/sbin/pfctl -a "$anchor" -vvsr > "$output/pf-counters"
cat "$output/pf-counters"
echo 'PASS: candidate PF socket controls; broader network acceptance remains gated'
