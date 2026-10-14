"""Shared fail-closed toolchain and Lean axiom audits."""

import re


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
