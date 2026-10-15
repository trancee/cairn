"""Kernel-check typed convergence, boundedness and structural image correspondence."""

import argparse
import hashlib
from pathlib import Path
import re
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from equations.signature import lean_correspondence, reviewed_signature
from equations.maude_runner import run_guarded_tamarin
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
COHERENCE_THEOREMS = (
    "modulo_ac_matching_coherence",
    "matching_primitive_modulo_ac",
    "matching_rewrite_modulo_ac",
    "matching_termination",
    "matching_rewrite_ac_coherent",
)
BOUNDEDNESS_THEOREMS = (
    "matching_steps_transitive",
    "matching_steps_context",
    "normalized_substitution_bound",
)
CONFLUENCE_THEOREMS = (
    "matching_local_confluence",
    "matching_steps_do_not_increase_weight",
    "matching_confluence",
)
CONVERGENCE_THEOREMS = (
    "normal_ac_invariant",
    "matching_steps_ac_coherent",
    "matching_normal_forms_unique",
    "modulo_ac_steps_matching",
    "modulo_ac_confluence",
)
QUERY_IMAGE_THEOREMS = (
    "native_natural_round_trip",
    "native_message_round_trip",
    "native_natural_encoding_injective",
    "native_message_encoding_injective",
)
QUERY_RECOGNITION_THEOREMS = (
    "native_natural_recognition",
    "native_message_recognition",
)
QUERY_AC_THEOREMS = (
    "native_natural_ac_preservation",
    "native_message_ac_preservation",
    "native_natural_ac_reflection",
    "native_message_ac_reflection",
    "native_ac_natural_image",
    "native_ac_message_image",
)
QUERY_REWRITE_THEOREMS = (
    "native_primitive_preservation",
    "native_rewrite_preservation",
    "native_rewrite_decode",
    "native_rewrite_image",
    "native_rewrite_reflection",
    "native_modulo_ac_preservation",
    "native_modulo_ac_decode",
    "native_modulo_ac_reflection",
)
QUERY_MATCHING_THEOREMS = (
    "native_matching_preservation",
    "native_matching_realization",
)
QUERY_SUBSTITUTION_THEOREMS = (
    "native_natural_substitution",
    "native_message_substitution",
    "native_natural_substitution_image",
    "native_message_substitution_image",
    "native_ac_substitution",
    "native_rewrite_substitution",
)
QUERY_FRAMING_THEOREMS = (
    "native_framed_ac",
    "native_framed_rewrite",
    "native_framed_substitution",
)
QUERY_RELABELING_THEOREMS = (
    "native_ac_relabeling", "native_rewrite_relabeling", "native_modulo_ac_relabeling",
)
QUERY_KIND_THEOREMS = (
    "native_kind_round_trip", "native_kind_abstraction_injective",
    "native_kind_substitution", "native_kind_framed_substitution",
    "native_kind_ac_reflection", "native_kind_rewrite_reflection",
    "native_kind_modulo_ac_reflection", "native_kind_framed_ac", "native_kind_framed_rewrite",
    "native_kind_modulo_ac_decode", "native_kind_termination",
)
QUERY_SORTED_THEOREMS = (
    "native_sorted_matching_preservation", "native_sorted_rewrite_modulo_ac",
    "native_sorted_rewrite_decode", "native_sorted_kind_framed_rewrite",
    "native_sorted_proper_termination", "native_sorted_kind_termination",
)
QUERY_SORTED_CONVERGENCE_THEOREMS = (
    "native_sorted_ac_coherent", "native_sorted_steps_preservation", "native_sorted_steps_decode",
    "native_sorted_normal_iff", "native_sorted_normal_ac_invariant", "native_sorted_confluence",
    "native_sorted_normal_forms_unique", "native_sorted_normalized_substitution_bound",
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
        expanded = run_guarded_tamarin(
            ["tamarin-prover", "--parse-only", str(here.parent / "ratchet.spthy")], 120,
        )
        equations = reviewed_signature(expanded)
        with tempfile.TemporaryDirectory(prefix="cairn-equations-") as temporary:
            build = Path(temporary)
            environment = ["env", f"LEAN_PATH={build}"]
            outputs = []
            for module, theorems in (
                ("Termination", AUDITED_THEOREMS),
                ("Coherence", COHERENCE_THEOREMS),
                ("Boundedness", BOUNDEDNESS_THEOREMS),
                ("Confluence", CONFLUENCE_THEOREMS),
                ("Convergence", CONVERGENCE_THEOREMS),
                ("QueryImage", QUERY_IMAGE_THEOREMS),
                ("QueryRecognition", QUERY_RECOGNITION_THEOREMS),
                ("QueryAC", QUERY_AC_THEOREMS),
                ("QueryRewrite", QUERY_REWRITE_THEOREMS),
                ("QueryMatching", QUERY_MATCHING_THEOREMS),
                ("QuerySubstitution", QUERY_SUBSTITUTION_THEOREMS),
                ("QueryFraming", QUERY_FRAMING_THEOREMS),
                ("QueryRelabeling", QUERY_RELABELING_THEOREMS),
                ("QueryKind", QUERY_KIND_THEOREMS),
                ("QuerySorted", QUERY_SORTED_THEOREMS),
                ("QuerySortedConvergence", QUERY_SORTED_CONVERGENCE_THEOREMS),
            ):
                output = run([
                    *environment, arguments.lean, "-DwarningAsError=true",
                    "-o", str(build / f"{module}.olean"), str(here / f"{module}.lean"),
                ], 120)
                check_axioms(
                    output, tuple(f"Cairn.Equations.{name}" for name in theorems),
                )
                outputs.append(output.strip())
            for module in (
                "CoherenceCases", "BoundednessCases", "ConfluenceCases", "QueryImageCases",
                "QueryACCases", "QueryRewriteCases", "QuerySubstitutionCases", "QueryFramingCases",
                "QueryKindCases", "QuerySortedCases",
            ):
                run([
                    *environment, arguments.lean, "-DwarningAsError=true",
                    str(here / f"{module}.lean"),
                ], 120)
            certificate = build / "SourceEquations.lean"
            certificate.write_text(lean_correspondence(equations))
            run([*environment, arguments.lean, "-DwarningAsError=true", str(certificate)], 120)
        digest = hashlib.sha256(expanded.encode()).hexdigest()
        print("\n".join(outputs))
        print(f"Lean {pin}; expanded theory SHA-256: {digest}")
        print("PASS: all six source equations terminate in every message context modulo natural AC.")
        print("PASS: matching modulo AC is sound and B-coherent in the same typed message algebra.")
        print("PASS: normalized substitutions have a source-template-only normalization bound.")
        print("PASS: matching is confluent and quotient rewrite paths join modulo natural AC.")
        print("PASS: typed frozen-index encoding round-trips without variable/constant collisions.")
        print("PASS: the encoded image preserves/reflects structural AC and six-rule/context rewriting.")
        print("PASS: encoded quotient steps are realizable by typed matching modulo AC.")
        print("PASS: typed natural/message substitutions commute with encoding and preserve its image.")
        print("PASS: free tuple/Node framing is closed under structural AC, rewriting and typed substitution.")
        print("PASS: fresh/natural kind abstraction is injective and transports AC/rewrite image evidence.")
        print("PASS: proper-sort native matching transfers convergence and the source-template bound.")
        print("Scope: typed image algebra + enforced native stream membership; not a native FVP certificate.")
        print("Trust boundary: Tamarin/Maude + Rust stream guard + Python evidence/signature/translation + Lean kernel.")
        return 0
    except (OSError, RuntimeError, ReplayError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
