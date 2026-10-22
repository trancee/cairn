#!/usr/bin/env python3
"""Generate the committed X-Wing draft-11 vectors from two independent oracles.

Usage: python3 generate.py DRAFT_11_TXT OUTPUT_JSON

DRAFT_11_TXT is https://www.ietf.org/archive/id/draft-connolly-cfrg-xwing-kem-11.txt.
Inputs are the three Appendix C cases plus deterministic SHAKE256-derived
seeds. BoringSSL and CIRCL each run in a digest-pinned container at a pinned
revision; every output field must be byte-identical between them, and the
Appendix C cases must match the draft. Requires Docker.
"""

import hashlib
import json
import subprocess
import sys
from pathlib import Path

DRAFT_SHA256 = "1353f61f0d706199d86b6802eab83cabbb5195b2d99fb35bca20f5e4f83db786"
IMAGE = "golang:1.25-bookworm@sha256:3b4a11519ad929d1e1d261a12cff056f0c85b735253d7d861346b9c6f8b36437"
BORINGSSL = "4f3b183c5d4a8f8fcaba4c0ab4435df181df6978"
CIRCL = "v1.6.5"
DERIVED_CASES = 29
FIELDS = ["pk", "ct", "ss", "dk_m", "sk_x"]
HERE = Path(__file__).resolve().parent

BORINGSSL_SCRIPT = f"""set -eu
apt-get update -qq >/dev/null && apt-get install -y -qq cmake ninja-build >/dev/null
git clone -q https://boringssl.googlesource.com/boringssl /work/boringssl
git -C /work/boringssl checkout -q {BORINGSSL}
cmake -S /work/boringssl -B /work/build -GNinja -DCMAKE_BUILD_TYPE=Release >/dev/null
ninja -C /work/build crypto >/dev/null
g++ -std=c++17 -O1 -I/work/boringssl/include -I/work/boringssl /gen/gen.cc \
  /work/build/libcrypto.a -lpthread -o /work/gen
/work/gen
"""

CIRCL_SCRIPT = """set -eu
cp -r /gen /work && cd /work
go mod verify >/dev/null
go run .
"""


def appendix_c(text):
    start = text.index("\nAppendix C.  Test vectors")
    end = text.index("\nAppendix D.", start)
    cases, current, key = [], None, None
    for line in text[start:end].splitlines()[3:]:
        if line.startswith(("Connolly, et al.", "Internet-Draft")) or "\f" in line:
            continue
        parts = line.split()
        if not parts:
            continue
        if parts[0] in {"seed", "sk", "pk", "eseed", "ct", "ss"} and not line.startswith(" "):
            key = parts[0]
            if key == "seed":
                current = {}
                cases.append(current)
            current[key] = "".join(parts[1:])
        else:
            current[key] += "".join(parts)
    assert len(cases) == 3 and all(c["seed"] == c["sk"] for c in cases)
    return cases


def shake(label, index, length):
    return hashlib.shake_256(label + index.to_bytes(4, "big")).hexdigest(length)


def run(name, script, mount, stdin):
    result = subprocess.run(
        ["docker", "run", "--rm", "-i", "-v", f"{mount}:/gen:ro", IMAGE, "sh", "-c", script],
        input=stdin, capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        raise SystemExit(f"{name} generator failed:\n{result.stderr}")
    rows = [dict(zip(FIELDS, line.split())) for line in result.stdout.splitlines()]
    return rows


def main():
    draft, output = map(Path, sys.argv[1:3])
    raw = draft.read_bytes()
    if hashlib.sha256(raw).hexdigest() != DRAFT_SHA256:
        raise SystemExit("draft-11 checksum mismatch")
    reference = appendix_c(raw.decode())
    inputs = [{"seed": c["seed"], "eseed": c["eseed"]} for c in reference]
    inputs += [
        {
            "seed": shake(b"cairn/x-wing-draft-11/seed/", i, 32),
            "eseed": shake(b"cairn/x-wing-draft-11/eseed/", i, 64),
        }
        for i in range(DERIVED_CASES)
    ]
    stdin = "".join(f"{case['seed']} {case['eseed']}\n" for case in inputs)
    boringssl = run("BoringSSL", BORINGSSL_SCRIPT, HERE / "boringssl", stdin)
    circl = run("CIRCL", CIRCL_SCRIPT, HERE / "circl", stdin)
    assert len(boringssl) == len(circl) == len(inputs)
    if boringssl != circl:
        raise SystemExit("BoringSSL and CIRCL disagree")
    for case, row in zip(reference, boringssl):
        assert all(case[key] == row[key] for key in ("pk", "ct", "ss")), "Appendix C mismatch"
    for case, row in zip(inputs, boringssl):
        expanded = hashlib.shake_256(bytes.fromhex(case["seed"])).hexdigest(96)
        assert row["sk_x"] == expanded[128:], "SHAKE256 expansion mismatch"
    document = {
        "algorithm": "X-Wing",
        "specification": "draft-connolly-cfrg-xwing-kem-11",
        "draftSha256": DRAFT_SHA256,
        "generators": {
            "boringssl": f"https://boringssl.googlesource.com/boringssl/+/{BORINGSSL}",
            "circl": f"github.com/cloudflare/circl@{CIRCL}",
            "image": IMAGE,
        },
        "notes": [
            "Cases 0-2 are draft-11 Appendix C; the rest use seeds and eseeds "
            "SHAKE256-derived from labelled 32-bit indices.",
            "dk_m is the NIST-format ML-KEM-768 decapsulation key and sk_x the "
            "X25519 secret from expandDecapsulationKey(seed); both oracles agree.",
            "Only well-formed inputs; low-order X25519 behaviour differs between "
            "the oracles and is tested separately.",
        ],
        "tests": [
            {"tcId": i, "source": "draft-11 Appendix C" if i < 3 else "derived", **case, **row}
            for i, (case, row) in enumerate(zip(inputs, boringssl))
        ],
    }
    output.write_text(json.dumps(document, indent=2) + "\n")


if __name__ == "__main__":
    main()
