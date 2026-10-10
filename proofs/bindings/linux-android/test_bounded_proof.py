import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class BoundedProofTest(unittest.TestCase):
    def test_exact_budget_is_retained_and_mirrored(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "proof.log"

            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("bounded-proof.py")),
                 "--limit", "16", str(output), sys.executable, "-c",
                 "import sys; sys.stdout.write('x' * 16)"],
                capture_output=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(output.read_bytes(), b"x" * 16)
            self.assertEqual(result.stdout, b"x" * 16)

    def test_child_failure_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "proof.log"

            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("bounded-proof.py")),
                 str(output), sys.executable, "-c", "raise SystemExit(7)"],
                capture_output=True,
            )

            self.assertEqual(result.returncode, 7)

    def test_overflow_fails_without_retaining_more_than_budget(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "proof.log"

            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("bounded-proof.py")),
                 "--limit", "16", str(output), sys.executable, "-c",
                 "import sys; sys.stdout.write('x' * 17)"],
                capture_output=True,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"proof output exceeded", result.stderr)
            self.assertLessEqual(output.stat().st_size, 16)


if __name__ == "__main__":
    unittest.main()
