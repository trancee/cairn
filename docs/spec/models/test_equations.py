from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

from equations.signature import EQUATIONS, lean_correspondence, reviewed_signature
from equations.maude_native import source_identity, source_inputs
from replay import ReplayError


SOURCE = """theory Equations
begin
builtins: natural-numbers
functions: ext/2, flip/1, fst/1, h/1, kdec/2, kdf/3, kem/2, mac/2,
  pair/2, pk/1, roleA/0, roleB/0, sdec/2, senc/2, snd/1
equations:
  flip(roleA) = roleB,
  flip(roleB) = roleA,
  fst(<x.1,x.2>) = x.1,
  snd(<x.1,x.2>) = x.2,
  kdec(kem(ss,pk(dk)),dk) = ss,
  sdec(senc(x.1,x.2),x.2) = x.1
tactic: example
end
"""

REPORT_GROUPS = {
    "termination": (
        "natural_ac_preserves_weight", "message_ac_preserves_weight",
        "primitive_rewrite_decreases_weight", "rewrite_decreases_weight",
        "modulo_ac_rewrite_decreases_weight", "modulo_ac_termination",
    ),
    "coherence": (
        "modulo_ac_matching_coherence", "matching_primitive_modulo_ac",
        "matching_rewrite_modulo_ac", "matching_termination", "matching_rewrite_ac_coherent",
    ),
    "boundedness": (
        "matching_steps_transitive", "matching_steps_context", "normalized_substitution_bound",
    ),
    "confluence": (
        "matching_local_confluence", "matching_steps_do_not_increase_weight", "matching_confluence",
    ),
    "convergence": (
        "normal_ac_invariant", "matching_steps_ac_coherent", "matching_normal_forms_unique",
        "modulo_ac_steps_matching", "modulo_ac_confluence",
    ),
    "query-image": (
        "native_natural_round_trip", "native_message_round_trip",
        "native_natural_encoding_injective", "native_message_encoding_injective",
    ),
    "native-algebra": (
        "native_natural_recognition", "native_message_recognition",
        "native_natural_ac_preservation", "native_message_ac_preservation",
        "native_natural_ac_reflection", "native_message_ac_reflection",
        "native_ac_natural_image", "native_ac_message_image",
        "native_primitive_preservation", "native_rewrite_preservation",
        "native_rewrite_decode", "native_rewrite_image", "native_rewrite_reflection",
        "native_modulo_ac_preservation", "native_modulo_ac_decode", "native_modulo_ac_reflection",
        "native_matching_preservation", "native_matching_realization",
    ),
    "substitution": (
        "native_natural_substitution", "native_message_substitution",
        "native_natural_substitution_image", "native_message_substitution_image",
        "native_ac_substitution", "native_rewrite_substitution",
    ),
    "framing": (
        "native_framed_ac", "native_framed_rewrite", "native_framed_substitution",
    ),
    "relabeling": (
        "native_ac_relabeling", "native_rewrite_relabeling", "native_modulo_ac_relabeling",
    ),
    "kind": (
        "native_kind_round_trip", "native_kind_abstraction_injective",
        "native_kind_substitution", "native_kind_framed_substitution",
        "native_kind_ac_reflection", "native_kind_rewrite_reflection",
        "native_kind_modulo_ac_reflection", "native_kind_framed_ac", "native_kind_framed_rewrite",
        "native_kind_modulo_ac_decode", "native_kind_termination",
    ),
    "sorted-matching": (
        "native_sorted_matching_preservation", "native_sorted_rewrite_modulo_ac",
        "native_sorted_rewrite_decode", "native_sorted_kind_framed_rewrite",
        "native_sorted_proper_termination", "native_sorted_kind_termination",
    ),
    "sorted-convergence": (
        "native_sorted_ac_coherent", "native_sorted_steps_preservation", "native_sorted_steps_decode",
        "native_sorted_normal_iff", "native_sorted_normal_ac_invariant", "native_sorted_confluence",
        "native_sorted_normal_forms_unique", "native_sorted_normalized_substitution_bound",
    ),
    "sorted-query-bound": (
        "native_sorted_steps_transitive", "native_sorted_steps_context",
        "native_sorted_query_substitution_bound",
    ),
}


class EquationSignatureTests(unittest.TestCase):
    def test_the_reviewed_sorted_signature_is_accepted(self):
        equations = reviewed_signature(SOURCE)

        self.assertEqual(set(equations), {
            "flip(roleA)=roleB", "flip(roleB)=roleA", "fst(<x.1,x.2>)=x.1",
            "snd(<x.1,x.2>)=x.2", "kdec(kem(ss,pk(dk)),dk)=ss",
            "sdec(senc(x.1,x.2),x.2)=x.1",
        })

    def test_an_unrepresented_message_function_is_rejected(self):
        source = SOURCE.replace("ext/2", "unrepresented/2")

        with self.assertRaisesRegex(ReplayError, "function signature"):
            reviewed_signature(source)

    def test_malformed_equations_have_a_typed_failure(self):
        source = SOURCE.replace("pk(dk)", "pk(dk")

        with self.assertRaisesRegex(ReplayError, "malformed canonical equations"):
            reviewed_signature(source)

    def test_quoted_text_cannot_supply_the_equation_declarations(self):
        source = f'"{SOURCE}"'

        with self.assertRaisesRegex(ReplayError, "builtin theory"):
            reviewed_signature(source)

    def test_an_additional_builtin_is_rejected(self):
        source = SOURCE.replace("builtins: natural-numbers", "builtins: natural-numbers, xor")

        with self.assertRaisesRegex(ReplayError, "builtin theory"):
            reviewed_signature(source)

    def test_missing_builtin_is_rejected(self):
        source = SOURCE.replace("builtins: natural-numbers\n", "")

        with self.assertRaisesRegex(ReplayError, "builtin theory"):
            reviewed_signature(source)

    def test_duplicate_builtin_is_rejected(self):
        source = SOURCE.replace(
            "builtins: natural-numbers", "builtins: natural-numbers\nbuiltins: natural-numbers",
        )

        with self.assertRaisesRegex(ReplayError, "builtin theory"):
            reviewed_signature(source)

    def test_a_changed_function_rank_is_rejected(self):
        source = SOURCE.replace("roleA/0", "roleA/1")

        with self.assertRaisesRegex(ReplayError, "function signature"):
            reviewed_signature(source)

    def test_an_excessive_arity_has_a_typed_failure(self):
        source = SOURCE.replace("roleA/0", "roleA/" + "9" * 5000)

        with self.assertRaisesRegex(ReplayError, "function signature"):
            reviewed_signature(source)

    def test_a_missing_function_is_rejected(self):
        source = SOURCE.replace("ext/2, ", "")

        with self.assertRaisesRegex(ReplayError, "function signature"):
            reviewed_signature(source)

    def test_a_duplicate_function_is_rejected(self):
        source = SOURCE.replace("ext/2", "h/1")

        with self.assertRaisesRegex(ReplayError, "function signature"):
            reviewed_signature(source)

    def test_private_function_attributes_are_rejected(self):
        source = SOURCE.replace("kem/2", "kem/2 [private]")

        with self.assertRaisesRegex(ReplayError, "function signature"):
            reviewed_signature(source)

    def test_missing_function_declaration_is_rejected(self):
        source = SOURCE[:SOURCE.index("functions:")] + SOURCE[SOURCE.index("equations:"):]

        with self.assertRaisesRegex(ReplayError, "function signature"):
            reviewed_signature(source)

    def test_duplicate_equations_are_rejected(self):
        source = SOURCE.replace("flip(roleA) = roleB,", "flip(roleA) = roleB, flip(roleA) = roleB,")

        with self.assertRaisesRegex(ReplayError, "equational theory"):
            reviewed_signature(source)

    def test_a_changed_equation_is_rejected(self):
        source = SOURCE.replace("flip(roleA) = roleB", "flip(roleA) = roleA")

        with self.assertRaisesRegex(ReplayError, "equational theory"):
            reviewed_signature(source)

    def test_missing_equations_are_rejected(self):
        source = SOURCE[:SOURCE.index("equations:")] + "tactic: example\nend\n"

        with self.assertRaisesRegex(ReplayError, "canonical equations"):
            reviewed_signature(source)

    def test_comments_cannot_supply_the_signature(self):
        source = f"/* {SOURCE} */"

        with self.assertRaisesRegex(ReplayError, "builtin theory"):
            reviewed_signature(source)

    def test_comments_do_not_change_the_reviewed_theory(self):
        source = SOURCE.replace("ext/2", "/* an ordinary free symbol */ ext/2")

        self.assertEqual(set(reviewed_signature(source)), EQUATIONS)

    def test_kem_correspondence_retains_the_repeated_key(self):
        certificate = lean_correspondence(("kdec(kem(ss,pk(dk)),dk)=ss", *(
            equation for equation in EQUATIONS if not equation.startswith("kdec")
        )))

        self.assertIn(
            "example (dk ss : MessageTerm) : PrimitiveRewrite "
            "(.binary .kdec (.binary .kem ss (.unary .pk dk)) dk) ss := .kdec",
            certificate,
        )

    def test_role_correspondence_keeps_message_sort_nullary_functions(self):
        certificate = lean_correspondence(tuple(sorted(EQUATIONS)))

        self.assertIn("PrimitiveRewrite (.unary .flip .roleA) .roleB := .flipA", certificate)
        self.assertIn("PrimitiveRewrite (.unary .flip .roleB) .roleA := .flipB", certificate)

    def test_correspondence_rejects_a_missing_equation(self):
        with self.assertRaisesRegex(ReplayError, "equational theory"):
            lean_correspondence(("flip(roleA)=roleB",))

    def test_correspondence_rejects_duplicate_equations(self):
        with self.assertRaisesRegex(ReplayError, "equational theory"):
            lean_correspondence(("flip(roleA)=roleB",) * 6)


class EquationCommandTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="cairn-equation-command-")
        self.addCleanup(temporary.cleanup)
        self.distribution = Path(temporary.name) / "docs/spec/models"
        source = Path(__file__).resolve().parent
        for path in source.rglob("*.py"):
            target = self.distribution / path.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
        for path in source_inputs():
            target = Path(temporary.name) / path.relative_to(source.parents[2])
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
        self.command = [sys.executable, str(self.distribution / "equations/termination.py")]

    def test_missing_toolchain_pin_reports_a_controlled_failure(self):
        result = subprocess.run(self.command, text=True, capture_output=True, timeout=30)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("FAIL:", result.stderr)
        self.assertIn("lean-toolchain", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertNotIn("PASS:", result.stdout)

    def test_malformed_toolchain_pins_are_rejected_before_running_tools(self):
        for content in (b"\xff", b"not-a-toolchain", b"leanprover/lean4:v"):
            with self.subTest(content=content):
                (self.distribution / "lifecycle/lean-toolchain").write_bytes(content)

                result = subprocess.run(self.command, text=True, capture_output=True, timeout=30)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertEqual(result.stderr.strip(), "FAIL: invalid Lean toolchain pin")
                self.assertNotIn("PASS:", result.stdout)

    def test_a_version_with_the_pinned_version_as_a_prefix_is_rejected(self):
        (self.distribution / "lifecycle/lean-toolchain").write_text(
            "leanprover/lean4:v4.34.1\n",
        )
        tool = self.distribution / "unsupported-lean"
        tool.write_text(
            f"#!{sys.executable}\nprint('Lean (version 4.34.10, unsupported)')\n",
        )
        tool.chmod(0o700)

        result = subprocess.run(
            [*self.command, "--lean", str(tool)], text=True, capture_output=True, timeout=30,
        )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(result.stderr.strip(), "FAIL: expected Lean 4.34.1")
        self.assertNotIn("PASS:", result.stdout)

    def run_with_axiom_reports(self, *groups):
        (self.distribution / "lifecycle/lean-toolchain").write_text(
            "leanprover/lean4:v4.34.1\n",
        )
        exporter = self.distribution / "tamarin-prover"
        version = "tamarin-prover 1.12.0,\nMaude version 3.5.1"
        exporter.write_text(
            f"#!{sys.executable}\nimport os, sys\nfrom pathlib import Path\n"
            "report = os.environ.get('CAIRN_MAUDE_GUARD_REPORT')\n"
            "if report:\n"
            "    Path(report).write_text("
            f"'{{\"event\":\"version\",\"pid\":1337,\"source_id\":\"{source_identity()}\"}}\\n')\n"
            f"print({version!r} if '--version' in sys.argv else {SOURCE!r})\n",
        )
        exporter.chmod(0o700)
        tool = self.distribution / "lean-audit-fixture"
        reports = "\n".join(
            f"'Cairn.Equations.{name}' does not depend on any axioms"
            for group in groups for name in REPORT_GROUPS[group]
        )
        tool.write_text(
            f"#!{sys.executable}\nimport sys\n"
            f"print('Lean (version 4.34.1, fixture)' if '--version' in sys.argv else {reports!r})\n",
        )
        tool.chmod(0o700)
        environment = {**os.environ, "PATH": f"{self.distribution}{os.pathsep}{os.environ['PATH']}"}

        return subprocess.run(
            [*self.command, "--lean", str(tool)], env=environment,
            text=True, capture_output=True, timeout=30,
        )

    def test_coherence_axiom_reports_are_required_before_success(self):
        result = self.run_with_axiom_reports("termination")

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("missing Lean theorem axiom reports:", result.stderr)
        self.assertIn("modulo_ac_matching_coherence", result.stderr)
        self.assertNotIn("PASS:", result.stdout)

    def test_boundedness_axiom_reports_are_required_before_success(self):
        result = self.run_with_axiom_reports("termination", "coherence")

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("missing Lean theorem axiom reports:", result.stderr)
        self.assertIn("normalized_substitution_bound", result.stderr)
        self.assertNotIn("PASS:", result.stdout)

    def test_confluence_axiom_reports_are_required_before_success(self):
        for groups, missing in (
            (("termination", "coherence", "boundedness"), "matching_local_confluence"),
            (("termination", "coherence", "boundedness", "confluence"), "modulo_ac_confluence"),
        ):
            with self.subTest(missing=missing):
                result = self.run_with_axiom_reports(*groups)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("missing Lean theorem axiom reports:", result.stderr)
                self.assertIn(missing, result.stderr)
                self.assertNotIn("PASS:", result.stdout)

    def test_query_image_axiom_reports_are_required_before_success(self):
        result = self.run_with_axiom_reports(
            "termination", "coherence", "boundedness", "confluence", "convergence",
        )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("missing Lean theorem axiom reports:", result.stderr)
        self.assertIn("native_message_round_trip", result.stderr)
        self.assertNotIn("PASS:", result.stdout)

    def test_native_algebra_axiom_reports_are_required_before_success(self):
        result = self.run_with_axiom_reports(
            "termination", "coherence", "boundedness", "confluence", "convergence", "query-image",
        )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("missing Lean theorem axiom reports:", result.stderr)
        self.assertIn("native_natural_recognition", result.stderr)
        self.assertNotIn("PASS:", result.stdout)

    def test_substitution_axiom_reports_are_required_before_success(self):
        result = self.run_with_axiom_reports(
            "termination", "coherence", "boundedness", "confluence", "convergence", "query-image",
            "native-algebra",
        )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("missing Lean theorem axiom reports:", result.stderr)
        self.assertIn("native_natural_substitution", result.stderr)
        self.assertNotIn("PASS:", result.stdout)

    def test_framing_axiom_reports_are_required_before_success(self):
        result = self.run_with_axiom_reports(
            "termination", "coherence", "boundedness", "confluence", "convergence", "query-image",
            "native-algebra", "substitution",
        )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("missing Lean theorem axiom reports:", result.stderr)
        self.assertIn("native_framed_ac", result.stderr)
        self.assertNotIn("PASS:", result.stdout)

    def test_kind_abstraction_axiom_reports_are_required_before_success(self):
        for additional, missing in (
            ((), "native_ac_relabeling"),
            (("relabeling",), "native_kind_round_trip"),
        ):
            with self.subTest(additional=additional):
                result = self.run_with_axiom_reports(
                    "termination", "coherence", "boundedness", "confluence", "convergence",
                    "query-image", "native-algebra", "substitution", "framing", *additional,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("missing Lean theorem axiom reports:", result.stderr)
                self.assertIn(missing, result.stderr)
                self.assertNotIn("PASS:", result.stdout)

    def test_sorted_matching_axiom_reports_are_required_before_success(self):
        result = self.run_with_axiom_reports(*(
            group for group in REPORT_GROUPS
            if group not in {"sorted-matching", "sorted-convergence"}
        ))

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("missing Lean theorem axiom reports:", result.stderr)
        self.assertIn("native_sorted_matching_preservation", result.stderr)
        self.assertNotIn("PASS:", result.stdout)

    def test_sorted_convergence_axiom_reports_are_required_before_success(self):
        result = self.run_with_axiom_reports(*(
            group for group in REPORT_GROUPS if group != "sorted-convergence"
        ))

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("missing Lean theorem axiom reports:", result.stderr)
        self.assertIn("native_sorted_ac_coherent", result.stderr)
        self.assertNotIn("PASS:", result.stdout)

    def test_all_required_axiom_reports_allow_success(self):
        result = self.run_with_axiom_reports(*REPORT_GROUPS)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS: proper-sort native matching", result.stdout)
        self.assertIn("PASS: guarded native query templates", result.stdout)
        self.assertNotIn("FAIL:", result.stderr)

    def test_sorted_query_bound_axiom_reports_are_required_before_success(self):
        result = self.run_with_axiom_reports(*(
            group for group in REPORT_GROUPS if group != "sorted-query-bound"
        ))

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("missing Lean theorem axiom reports:", result.stderr)
        self.assertIn("native_sorted_query_substitution_bound", result.stderr)
        self.assertNotIn("PASS:", result.stdout)


if __name__ == "__main__":
    unittest.main()
