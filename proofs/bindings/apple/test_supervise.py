import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class SupervisorTest(unittest.TestCase):
    def test_deadline_terminates_child_and_retains_partial_output(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "proof.log"

            result = subprocess.run(
                [sys.executable, str(Path(__file__).parent.parent / "linux-android" / "bounded-proof.py"),
                 "--seconds", "1", "--limit", "64", str(output),
                 sys.executable, "-u", "-c",
                 "import time; print('partial'); time.sleep(30)"],
                capture_output=True, timeout=10,
            )

            self.assertEqual(result.returncode, 124, result.stderr)
            self.assertEqual(output.read_bytes(), b"partial\n")
            self.assertIn(b"deadline exceeded", result.stderr)

    def test_deadline_still_applies_after_child_closes_output(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "proof.log"

            result = subprocess.run(
                [sys.executable, str(Path(__file__).parent.parent / "linux-android" / "bounded-proof.py"),
                 "--seconds", "1", str(output), sys.executable, "-c",
                 "import os,time; os.close(1); os.close(2); time.sleep(30)"],
                capture_output=True, timeout=10,
            )

            self.assertEqual(result.returncode, 124, result.stderr)
            self.assertEqual(output.read_bytes(), b"")

    def test_deadline_rejects_nonfinite_value_without_launching_child(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "proof.log"

            result = subprocess.run(
                [sys.executable, str(Path(__file__).parent.parent / "linux-android" / "bounded-proof.py"),
                 "--seconds", "nan", str(output), sys.executable, "-c", "print('unexpected')"],
                capture_output=True,
            )

            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
