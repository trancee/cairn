#!/usr/bin/env bash
set -euo pipefail
test "$(id -u)" -eq 0
python3 - <<'NETWORK'
from pathlib import Path
assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}
NETWORK
saved=/opt/cairn-binding-seeds/final-image-inputs-e75437d
mountpoint -q /var/lib/cairn-proof-logs
python3 - <<'CAPACITY'
import os
state = os.statvfs("/var/lib/cairn-proof-logs")
capacity = state.f_blocks * state.f_frsize
assert 0 < capacity <= 1024**3, capacity
print(f"PASS: authoritative guest proof-log filesystem capacity {capacity} bytes")
CAPACITY
install -d -m 0755 /run/systemd/journald.conf.d
cat > /run/systemd/journald.conf.d/zz-cairn-proof.conf <<'JOURNAL'
[Journal]
Storage=volatile
RuntimeMaxUse=64M
RuntimeMaxFileSize=8M
ForwardToSyslog=no
JOURNAL
systemd-analyze cat-config systemd/journald.conf | python3 -c '
import configparser
import sys
configuration = configparser.ConfigParser(strict=False)
configuration.read_string(sys.stdin.read())
assert configuration.get("Journal", "Storage") == "volatile"
assert not configuration.getboolean("Journal", "ForwardToSyslog")
print("PASS: effective journal configuration is volatile without syslog forwarding")
'
bash "$saved/stop-and-mask-units.sh" syslog.socket rsyslog.service logrotate.timer logrotate.service
systemctl restart systemd-journald.service
echo 'PASS: proof logs authoritative; system diagnostics volatile; persistent duplicates disabled'
