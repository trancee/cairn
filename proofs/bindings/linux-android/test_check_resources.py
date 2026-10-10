import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class ResourceCheckTest(unittest.TestCase):
    def check(self, profile, observation):
        with tempfile.TemporaryDirectory() as directory:
            snapshot = Path(directory) / "snapshot.json"
            snapshot.write_text(json.dumps(observation))
            return subprocess.run(
                [sys.executable, str(Path(__file__).with_name("check-resources.py")),
                 profile, "--snapshot", str(snapshot)],
                text=True, capture_output=True,
            )

    def test_unlimited_memory_is_rejected(self):
        observation = {
            "memory.max": "max",
            "memory.swap.max": "0",
            "pids.max": "256",
            "cpu.max": "400000 100000",
            "rlimit_cpu": [600, 600],
            "rlimit_fsize": [2147483648, 2147483648],
            "rlimit_core": [0, 0],
        }
        with tempfile.TemporaryDirectory() as directory:
            snapshot = Path(directory) / "snapshot.json"
            snapshot.write_text(json.dumps(observation))

            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("check-resources.py")),
                 "build", "--snapshot", str(snapshot)],
                text=True, capture_output=True,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("memory.max", result.stderr)

    def test_profiles_accept_exact_limits_and_reject_each_mismatch(self):
        for profile, memory, cpu, size in (
            ("build", "12884901888", 600, 2147483648),
            ("runtime", "6442450944", 240, 21474836480),
        ):
            observation = {
                "memory.max": memory, "memory.swap.max": "0", "pids.max": "256",
                "cpu.max": "400000 100000", "rlimit_cpu": [cpu, cpu],
                "rlimit_fsize": [size, size], "rlimit_core": [0, 0],
            }
            with self.subTest(profile=profile):
                result = self.check(profile, observation)
                self.assertEqual(result.returncode, 0, result.stderr)
            for key in observation:
                with self.subTest(profile=profile, mismatch=key):
                    invalid = dict(observation)
                    invalid[key] = "max"
                    result = self.check(profile, invalid)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(key, result.stderr)

    def test_missing_or_malformed_observations_fail(self):
        for observation in ({}, [], {"memory.max": "max"}):
            with self.subTest(observation=observation):
                result = self.check("build", observation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("FAIL: resource limits:", result.stderr)


if __name__ == "__main__":
    unittest.main()
