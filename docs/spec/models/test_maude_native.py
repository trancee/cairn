"""Fail-closed native default at the existing guarded-command seam."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from equations.maude_native import NATIVE_DIRECTORY, source_identity
from equations.maude_runner import GuardError, run_guarded_tamarin


class NativeCommandTests(unittest.TestCase):
    def run_report(self, source_field="", *, use_default=False):
        with tempfile.TemporaryDirectory() as temporary:
            proxy = (Path(temporary) / "release" / "cairn-maude-proxy").resolve()
            proxy.parent.mkdir()
            proxy.write_text(f"#!{sys.executable}\nprint('3.5.1')\n")
            proxy.chmod(0o755)
            tamarin = Path(temporary) / "tamarin-prover"
            tamarin.write_text(
                f"#!{sys.executable}\nimport os\nfrom pathlib import Path\n"
                "Path(os.environ['CAIRN_MAUDE_GUARD_REPORT']).write_text("
                f"'{{\"event\":\"version\",\"pid\":1337{source_field}}}\\n')\n"
                f"print('compiled-selected' if '--with-maude={proxy}' in "
                "__import__('sys').argv else 'legacy-selected')\n",
            )
            tamarin.chmod(0o755)

            with patch.dict(os.environ, {"CARGO_TARGET_DIR": temporary}):
                return run_guarded_tamarin(
                    [str(tamarin), "--fixture"], 30, proxy=None if use_default else proxy,
                )

    def test_default_route_uses_the_source_identified_compiled_guard(self):
        output = self.run_report(f',"source_id":"{source_identity()}"', use_default=True)

        self.assertEqual(output.strip(), "compiled-selected")

    def test_native_guard_cannot_claim_success_without_its_source_identity(self):
        with self.assertRaisesRegex(GuardError, "source identity"):
            self.run_report()

    def test_native_guard_with_current_source_identity_is_selected_explicitly(self):
        output = self.run_report(f',"source_id":"{source_identity()}"')

        self.assertEqual(output.strip(), "compiled-selected")

    def test_stale_native_guard_cannot_establish_proof_success(self):
        with self.assertRaisesRegex(GuardError, "stale native boundary source identity"):
            self.run_report(f',"source_id":"{"0" * 64}"')

    def test_malformed_native_identity_cannot_establish_proof_success(self):
        for field in ('[]', 'true', 'null', '0', '"short"', f'"{"A" * 64}"'):
            with self.subTest(field=field), self.assertRaisesRegex(GuardError, "source identity"):
                self.run_report(f',"source_id":{field}')

    def test_invalid_explicit_guard_cannot_fall_back_to_the_default(self):
        with tempfile.TemporaryDirectory() as temporary:
            not_executable = Path(temporary) / "not-executable"
            not_executable.write_text("not an executable\n")
            cases = ("", "relative", temporary, str(not_executable), str(Path(temporary) / "missing"))
            for selected in cases:
                with self.subTest(selected=selected), self.assertRaisesRegex(
                    GuardError, "native guard",
                ):
                    run_guarded_tamarin(["tamarin-prover", "--version"], 30, proxy=Path(selected))

    def test_invalid_default_target_cannot_claim_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            for target, reason in (("", "CARGO_TARGET_DIR.*empty"), (temporary, "unavailable")):
                with self.subTest(target=target), patch.dict(
                    os.environ, {"CARGO_TARGET_DIR": target},
                ), self.assertRaisesRegex(GuardError, reason):
                    run_guarded_tamarin(["tamarin-prover", "--version"], 30)

    def test_unreadable_source_inputs_are_controlled_command_failures(self):
        for error in (OSError("fixture"), UnicodeError("fixture")):
            with self.subTest(error=type(error).__name__), patch.object(
                Path, "read_bytes", side_effect=error,
            ), self.assertRaisesRegex(GuardError, "source identity inputs unavailable"):
                self.run_report()

    def test_unavailable_inventory_output_is_a_controlled_build_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "missing" / "output"

            result = subprocess.run(
                [sys.executable, str(NATIVE_DIRECTORY / "inventory.py"), str(output)],
                text=True, capture_output=True, timeout=5,
            )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("FAIL: native guard inventory", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
