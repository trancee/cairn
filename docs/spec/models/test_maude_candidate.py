"""Fail-closed candidate rollout at the existing guarded-command seam."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from equations.maude_candidate import NATIVE_DIRECTORY, source_identity
from equations.maude_runner import GuardError, run_guarded_tamarin


class CandidateCommandTests(unittest.TestCase):
    def run_report(self, source_field=""):
        with tempfile.TemporaryDirectory() as temporary:
            candidate = (Path(temporary) / "candidate").resolve()
            candidate.write_text(f"#!{sys.executable}\nprint('3.5.1')\n")
            candidate.chmod(0o755)
            tamarin = Path(temporary) / "tamarin-prover"
            tamarin.write_text(
                f"#!{sys.executable}\nimport os\nfrom pathlib import Path\n"
                "Path(os.environ['CAIRN_MAUDE_GUARD_REPORT']).write_text("
                f"'{{\"event\":\"version\",\"pid\":1337{source_field}}}\\n')\n"
                f"print('candidate-selected' if '--with-maude={candidate}' in "
                "__import__('sys').argv else 'legacy-selected')\n",
            )
            tamarin.chmod(0o755)

            with patch.dict(os.environ, {"CAIRN_MAUDE_GUARD_CANDIDATE": str(candidate)}):
                return run_guarded_tamarin([str(tamarin), "--fixture"], 30)

    def test_candidate_cannot_claim_success_without_its_source_identity(self):
        with self.assertRaisesRegex(GuardError, "source identity"):
            self.run_report()

    def test_candidate_with_current_source_identity_is_selected_explicitly(self):
        output = self.run_report(f',"source_id":"{source_identity()}"')

        self.assertEqual(output.strip(), "candidate-selected")

    def test_stale_candidate_cannot_establish_proof_success(self):
        with self.assertRaisesRegex(GuardError, "stale native boundary source identity"):
            self.run_report(f',"source_id":"{"0" * 64}"')

    def test_malformed_candidate_identity_cannot_establish_proof_success(self):
        for field in ('[]', 'true', 'null', '0', '"short"', f'"{"A" * 64}"'):
            with self.subTest(field=field), self.assertRaisesRegex(GuardError, "source identity"):
                self.run_report(f',"source_id":{field}')

    def test_invalid_candidate_configuration_cannot_fall_back_to_python(self):
        with tempfile.TemporaryDirectory() as temporary:
            not_executable = Path(temporary) / "not-executable"
            not_executable.write_text("not an executable\n")
            cases = ("", "relative", temporary, str(not_executable), str(Path(temporary) / "missing"))
            for selected in cases:
                with self.subTest(selected=selected), patch.dict(
                    os.environ, {"CAIRN_MAUDE_GUARD_CANDIDATE": selected},
                ), self.assertRaisesRegex(GuardError, "native guard candidate"):
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
