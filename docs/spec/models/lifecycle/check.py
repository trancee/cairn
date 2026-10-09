"""Rebuild source projection and kernel-check its lifecycle certificates."""

import argparse
from collections import Counter
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from projection import ProjectionError, lean_certificate, project_export

AUDITED_THEOREMS = {
    "Lifecycle": (
        "resume_serialized", "lock_stage_order", "initial_resume_serialized",
        "two_starts_executable",
    ),
    "Refinement": (
        "linear_step_simulates", "step_records_actions",
        "projected_trace_simulates", "projected_serialization",
    ),
    "Composition": (
        "all_pairs_serialized", "global_linear_step",
        "fresh_creation_preserves_existing", "global_fresh_pair",
        "global_stutter", "stutter_records_no_actions",
    ),
}


def run(command: list[str], *, env: dict | None = None, timeout: int = 120) -> str:
    result = subprocess.run(
        command, text=True, capture_output=True, env=env, timeout=timeout,
    )
    if result.returncode:
        raise RuntimeError(
            f"command failed ({result.returncode}): {' '.join(command)}\n"
            f"{result.stdout}\n{result.stderr}"
        )
    return result.stdout


def check_axioms(output: str, required: tuple[str, ...] = ()) -> None:
    allowed = {"propext", "Classical.choice", "Quot.sound"}
    reports = re.findall(
        r"'([^']+)' (?:depends on axioms: \[([^\]]*)\]|does not depend on any axioms)",
        output,
    )
    if not reports:
        raise RuntimeError("missing Lean theorem axiom report")
    names = [name for name, _ in reports]
    missing = set(required) - set(names)
    if missing:
        raise RuntimeError(f"missing Lean theorem axiom reports: {sorted(missing)}")
    if len(names) != len(set(names)):
        raise RuntimeError("duplicate Lean theorem axiom report")
    for _, report in reports:
        axioms = {name.strip() for name in report.split(",") if name.strip()}
        if not axioms <= allowed:
            raise RuntimeError(f"unexpected theorem axioms: {sorted(axioms - allowed)}")


def check_tamarin_version(output: str) -> None:
    if not re.search(r"\btamarin-prover 1\.12\.0,", output):
        raise RuntimeError(f"expected Tamarin 1.12.0; got {output.strip()}")
    if not re.search(r"^Maude version 3\.5\.1\s*$", output, re.M):
        raise RuntimeError(f"expected Maude 3.5.1; got {output.strip()}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lean", default="lean", help="pinned Lean executable")
    arguments = parser.parse_args()
    here = Path(__file__).resolve().parent
    pin = (here / "lean-toolchain").read_text().strip().split(":v")[-1]
    try:
        version = run([arguments.lean, "--version"])
        if not re.search(rf"\bversion {re.escape(pin)}(?:,|\))", version):
            raise RuntimeError(f"expected Lean {pin}; got {version.strip()}")
        prover = run(["tamarin-prover", "--version"])
        check_tamarin_version(prover)
        run([sys.executable, "-m", "unittest", "discover", "-s", str(here), "-p", "test_*.py"])
        expanded = run(["tamarin-prover", "--parse-only", str(here.parent / "ratchet.spthy")])
        rows = project_export(expanded)
        with tempfile.TemporaryDirectory(prefix="cairn-lifecycle-") as temporary:
            build = Path(temporary)
            env = {**os.environ, "LEAN_PATH": str(build)}
            for module in ("Lifecycle", "Refinement", "Composition"):
                output = run([
                    arguments.lean, "-DwarningAsError=true",
                    "-o", str(build / f"{module}.olean"), str(here / f"{module}.lean"),
                ], env=env)
                check_axioms(output, tuple(f"Cairn.{name}" for name in AUDITED_THEOREMS[module]))
                print(output.strip())
            certificate = build / "ProjectedRules.lean"
            certificate.write_text(lean_certificate(rows))
            run([arguments.lean, "-DwarningAsError=true", str(certificate)], env=env)
        digest = hashlib.sha256(expanded.encode()).hexdigest()
        print(f"Lean {pin}; expanded theory SHA-256: {digest}")
        print(f"Checked {len(rows)} rule projections: {dict(Counter(row.action for row in rows))}")
        print("PASS: inductive lifecycle, token simulation, event recording, source projection")
        print("Trust boundary: Tamarin export + Python projection + Lean kernel; not a Tamarin replay.")
        return 0
    except (OSError, RuntimeError, ProjectionError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
