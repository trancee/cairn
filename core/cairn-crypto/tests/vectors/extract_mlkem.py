#!/usr/bin/env python3
"""Extract ML-KEM-768 groups from pinned NIST FIPS 203 ACVP fixtures.

Usage: python3 extract_mlkem.py upstream-directory output-directory

The upstream directory must contain ML-KEM-keyGen-FIPS203/ and
ML-KEM-encapDecap-FIPS203/, each holding prompt.json and expectedResults.json
from ACVP-Server commit 975de31eb83d87039ec88934fdc47d8c312b892d,
gen-val/json-files/. Output mirrors that layout with only ML-KEM-768 groups.
"""

import hashlib
import json
import sys
from pathlib import Path

UPSTREAM = {
    "ML-KEM-keyGen-FIPS203": {
        "prompt.json": "3f9ce34f6c836c77958bad2729e837c3b213f44ac36c3065976e7acca6389523",
        "expectedResults.json": "a253d0ad91c95ebea5b409673defef0aa49d65d4ed72286399e2e798ddf073a4",
    },
    "ML-KEM-encapDecap-FIPS203": {
        "prompt.json": "998e22dfb12efb14ce9fdff911ca634b13612819a1806f25da69adba7e16db91",
        "expectedResults.json": "9089ec6ff2424da9f2782b89b2f831a329a3e28d6e5e24b802b78ff36ac61cdf",
    },
}
EXPECTED_CASES = {"ML-KEM-keyGen-FIPS203": 25, "ML-KEM-encapDecap-FIPS203": 55}


def main():
    source, destination = map(Path, sys.argv[1:3])
    for corpus, files in UPSTREAM.items():
        for name, digest in files.items():
            if hashlib.sha256((source / corpus / name).read_bytes()).hexdigest() != digest:
                raise SystemExit(f"{corpus}/{name}: upstream checksum mismatch")
        prompt = json.loads((source / corpus / "prompt.json").read_text())
        expected = json.loads((source / corpus / "expectedResults.json").read_text())
        groups = [g for g in prompt["testGroups"] if g["parameterSet"] == "ML-KEM-768"]
        assert sum(len(g["tests"]) for g in groups) == EXPECTED_CASES[corpus]
        identifiers = {g["tgId"] for g in groups}
        results = [g for g in expected["testGroups"] if g["tgId"] in identifiers]
        assert {g["tgId"] for g in results} == identifiers
        (destination / corpus).mkdir(parents=True, exist_ok=True)
        for name, document, selected in [
            ("prompt.json", prompt, groups),
            ("expectedResults.json", expected, results),
        ]:
            output = {k: v for k, v in document.items() if k != "testGroups"}
            output["testGroups"] = selected
            (destination / corpus / name).write_text(json.dumps(output, indent=2) + "\n")


if __name__ == "__main__":
    main()
