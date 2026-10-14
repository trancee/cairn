"""Kernel-check the reviewed message rules' termination modulo sorted natural AC."""

import argparse
import hashlib
from pathlib import Path
import re
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from equations.signature import lean_correspondence, reviewed_signature
from proof_tools import check_axioms, check_tamarin_version
from replay import ReplayError, run


AUDITED_THEOREMS = (
    "natural_ac_preserves_weight",
    "message_ac_preserves_weight",
    "primitive_rewrite_decreases_weight",
    "rewrite_decreases_weight",
    "modulo_ac_rewrite_decreases_weight",
    "modulo_ac_termination",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lean", default="lean", help="pinned Lean executable")
    arguments = parser.parse_args()
    here = Path(__file__).resolve().parent
    try:
        pin_match = re.fullmatch(
            rb"leanprover/lean4:v([0-9]+\.[0-9]+\.[0-9]+)",
            (here.parent / "lifecycle/lean-toolchain").read_bytes().strip(),
        )
        if pin_match is None:
            raise ReplayError("invalid Lean toolchain pin")
        pin = pin_match[1].decode("ascii")
        version = run([arguments.lean, "--version"], 30)
        if not re.search(rf"\bversion {re.escape(pin)}(?:,|\))", version):
            raise ReplayError(f"expected Lean {pin}")
        check_tamarin_version(run(["tamarin-prover", "--version"], 30))
        expanded = run(["tamarin-prover", "--parse-only", str(here.parent / "ratchet.spthy")], 120)
        equations = reviewed_signature(expanded)
        with tempfile.TemporaryDirectory(prefix="cairn-equations-") as temporary:
            build = Path(temporary)
            environment = ["env", f"LEAN_PATH={build}"]
            output = run([
                *environment, arguments.lean, "-DwarningAsError=true",
                "-o", str(build / "Termination.olean"), str(here / "Termination.lean"),
            ], 120)
            check_axioms(
                output, tuple(f"Cairn.Equations.{name}" for name in AUDITED_THEOREMS),
            )
            certificate = build / "SourceEquations.lean"
            certificate.write_text(lean_correspondence(equations))
            run([*environment, arguments.lean, "-DwarningAsError=true", str(certificate)], 120)
        digest = hashlib.sha256(expanded.encode()).hexdigest()
        print(output.strip())
        print(f"Lean {pin}; expanded theory SHA-256: {digest}")
        print("PASS: all six source equations terminate in every message context modulo natural AC.")
        print("Scope: termination only; not confluence, AC coherence or a combined FVP certificate.")
        print("Trust boundary: Tamarin export + reviewed signature/translation + Lean kernel.")
        return 0
    except (OSError, RuntimeError, ReplayError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
