#!/usr/bin/env python3
"""Extract SHA2-384 single- or multi-expansion groups from pinned NIST KDA fixtures.

Usage: python3 extract_hkdf.py upstream-directory output-directory [multi]
The upstream directory must contain prompt.json and expectedResults.json
from ACVP-Server commit 975de31eb83d87039ec88934fdc47d8c312b892d,
gen-val/json-files/KDA-HKDF-Sp800-56Cr2.
"""

import hashlib
import json
import sys
from pathlib import Path


def main():
    source, destination = map(Path, sys.argv[1:3])
    multi = len(sys.argv) == 4 and sys.argv[3] == "multi"
    if len(sys.argv) > 3 and not multi:
        raise SystemExit("optional selection must be 'multi'")
    for name, digest in [
        ("prompt.json", "2d27b1b69549f383b7583700f7e0622b33debb254db37bf83eb524102a1e3d9c"),
        ("expectedResults.json", "de35a4b7b3bc795b9c1b7bba4a28407bcfe2941568d097eadf9de57ff2e76395"),
    ]:
        if hashlib.sha256((source / name).read_bytes()).hexdigest() != digest:
            raise SystemExit(f"{name}: upstream checksum mismatch")
    prompt = json.loads((source / "prompt.json").read_text())
    expected = json.loads((source / "expectedResults.json").read_text())
    groups = [
        group for group in prompt["testGroups"]
        if group.get(
            "kdfMultiExpansionConfiguration" if multi else "kdfConfiguration", {}
        ).get("hmacAlg") == "SHA2-384"
        and group["multiExpansion"] is multi
    ]
    assert len(groups) == 20
    assert sum(len(group["tests"]) for group in groups) == 100
    identifiers = {group["tgId"] for group in groups}
    selected_results = [
        group for group in expected["testGroups"] if group["tgId"] in identifiers
    ]
    assert {group["tgId"] for group in selected_results} == identifiers
    destination.mkdir(parents=True, exist_ok=True)
    for name, document, selected in [
        ("prompt.json", prompt, groups),
        ("expectedResults.json", expected, selected_results),
    ]:
        output = {key: value for key, value in document.items() if key != "testGroups"}
        output["testGroups"] = selected
        (destination / name).write_text(json.dumps(output, indent=2) + "\n")
        print(name, "upstream SHA-256", hashlib.sha256((source / name).read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
