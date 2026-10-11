#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -eq 0
test "$#" -eq 1
output=$1
test -d "$output"
scripts="$(cd "$(dirname "$0")" && pwd -P)"
python="$(xcrun --find python3)"
anchor="com.apple/cairn-$(uuidgen)"
token=
loaded=0
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
cat > "$output/pf-rules" <<'RULES'
pass out quick on lo0 inet proto { tcp, udp } from any to 127.0.0.0/8 user 59000 tag CAIRN_PROBE no state
pass out quick on lo0 inet6 proto { tcp, udp } from any to ::1 user 59000 tag CAIRN_PROBE no state
block return out quick proto { tcp, udp } all user 59000 label "cairn-external"
pass in quick on lo0 proto { tcp, udp } all user 59000 tagged CAIRN_PROBE no state
block return in quick proto { tcp, udp } all tagged CAIRN_PROBE label "cairn-cross-uid"
block return in quick proto { tcp, udp } all user 59000 label "cairn-inbound"
RULES
/sbin/pfctl -n -a "$anchor" -f "$output/pf-rules"
/sbin/pfctl -a "$anchor" -f "$output/pf-rules"
loaded=1
/sbin/pfctl -E > "$output/pf-enable" 2>&1
token="$(sed -n 's/^Token : \([0-9][0-9]*\)$/\1/p' "$output/pf-enable")"
test -n "$token"
"$python" -I "$scripts/probe-pf.py" "$output/pf.log"
/sbin/pfctl -a "$anchor" -vvsr > "$output/pf-counters"
cat "$output/pf-counters"
echo 'PASS: candidate PF socket controls; broader network acceptance remains gated'
