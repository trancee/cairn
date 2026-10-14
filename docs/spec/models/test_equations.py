from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from equations.signature import EQUATIONS, lean_correspondence, reviewed_signature
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
        self.distribution = Path(temporary.name)
        source = Path(__file__).resolve().parent
        for path in source.rglob("*.py"):
            target = self.distribution / path.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
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


if __name__ == "__main__":
    unittest.main()
