#!/usr/bin/env python3
"""Extract the AES-256-GCM groups Cairn can execute from NIST CAVP GCMVS vectors.

Usage: python3 extract_gcm.py gcmtestvectors.zip output-directory

The archive is linked from the CAVP Block Cipher Modes page:
https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/mac/gcmtestvectors.zip
Only groups with Keylen = 256, IVlen = 96 and Taglen = 128 are kept; the
CryptoBackend API accepts exactly a 32-byte key, a 12-byte nonce and a
16-byte tag. Group headers and case text are copied unchanged.
"""

import hashlib
import re
import sys
import zipfile
from pathlib import Path

ARCHIVE_SHA256 = "f9fc479e134cde2980b3bb7cddbcb567b2cd96fd753835243ed067699f26a023"
MEMBERS = {
    "gcmEncryptExtIV256.rsp": ("4448b4998c3f58cd9f5542ddf7c573189a721ff3d3ac24cd5177bb4910a787f8", 375),
    "gcmDecrypt256.rsp": ("ed318735a517d5a85c82d2846c23dcf56e57a352fb0f0a163d9e7617a7bd12ad", 375),
}
HEADER = re.compile(r"^\[(\w+) = (\d+)\]$")


def select(text):
    lines = text.splitlines()
    preamble = []
    while lines and not lines[0].startswith("["):
        preamble.append(lines.pop(0))
    output = [line for line in preamble if line.startswith("#")]
    groups = []
    for line in lines:
        if HEADER.match(line) and (not groups or groups[-1][1]):
            groups.append(([], []))
        if HEADER.match(line):
            groups[-1][0].append(line)
        else:
            groups[-1][1].append(line)
    cases = 0
    for headers, body in groups:
        values = {HEADER.match(h).group(1): int(HEADER.match(h).group(2)) for h in headers}
        if set(values) != {"Keylen", "IVlen", "PTlen", "AADlen", "Taglen"}:
            raise SystemExit(f"unexpected group headers: {headers}")
        if (values["Keylen"], values["IVlen"], values["Taglen"]) != (256, 96, 128):
            continue
        if values["PTlen"] % 8 or values["AADlen"] % 8:
            raise SystemExit(f"bit-length case in selected group: {headers}")
        output += [""] + headers + body
        cases += sum(line.startswith("Count = ") for line in body)
    return "\n".join(output).rstrip("\n") + "\n", cases


def main():
    archive, destination = map(Path, sys.argv[1:3])
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise SystemExit("archive checksum mismatch")
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        for name, (digest, expected) in MEMBERS.items():
            raw = bundle.read(name)
            if hashlib.sha256(raw).hexdigest() != digest:
                raise SystemExit(f"{name} checksum mismatch")
            text, cases = select(raw.decode("ascii").replace("\r\n", "\n"))
            if cases != expected:
                raise SystemExit(f"{name}: expected {expected} cases, got {cases}")
            (destination / name).write_text(text)


if __name__ == "__main__":
    main()
