import contextlib
import hashlib
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path


spec = importlib.util.spec_from_file_location(
    "functional_simulator", Path(__file__).with_name("run-functional-simulator.py")
)
simulator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simulator)


class FunctionalPayloadTest(unittest.TestCase):
    def create_payload(self, directory, executable="CairnSimulatorSmoke.kexe"):
        payload = Path(directory)
        binary = payload / executable
        binary.write_bytes(b"checksum validation fixture")
        (payload / "revision.txt").write_text("a" * 40 + "\n")
        digest = hashlib.sha256(binary.read_bytes()).hexdigest()
        (payload / "payload.sha256").write_text(
            f"{digest}  {executable}\n"
        )
        return payload

    def test_verified_same_revision_payload_is_selected(self):
        with tempfile.TemporaryDirectory() as directory:
            payload = self.create_payload(directory)

            binary = simulator.verify_payload(payload, "a" * 40)

            self.assertEqual(binary, payload / "CairnSimulatorSmoke.kexe")

    def test_root_sdk_test_payload_is_selected_by_its_declared_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            payload = self.create_payload(directory, "CairnSdkTest.kexe")

            binary = simulator.verify_payload(payload, "a" * 40, "CairnSdkTest.kexe")

            self.assertEqual(binary, payload / "CairnSdkTest.kexe")

    def test_payload_must_carry_the_declared_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            payload = self.create_payload(directory, "CairnSdkTest.kexe")

            with self.assertRaisesRegex(SystemExit, "FAIL: functional payload file set mismatch"):
                simulator.verify_payload(payload, "a" * 40)

    def test_undeclared_executable_names_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            payload = self.create_payload(directory, "other.kexe")

            with self.assertRaisesRegex(SystemExit, "FAIL: functional payload executable not allowed"):
                simulator.verify_payload(payload, "a" * 40, "other.kexe")

    def test_launch_phases_use_evidence_based_budgets_and_report_elapsed_time(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "payload").mkdir()
            payload = self.create_payload(Path(directory) / "payload")
            calls = []

            def operating_system(command, **options):
                calls.append((command, options["timeout"]))
                if command[0] == "/usr/bin/xcrun":
                    return subprocess.CompletedProcess(command, 0, stdout="/simctl\n")
                if "create" in command:
                    return subprocess.CompletedProcess(command, 0, stdout="64445669-fe0b-4170-a787-c568494f418e\n")
                return subprocess.CompletedProcess(command, 0)

            output = io.StringIO()
            environment = {"GITHUB_ACTIONS": "true", "GITHUB_SHA": "a" * 40, "HOME": directory, "TMPDIR": directory}
            with mock.patch.object(simulator.subprocess, "run", side_effect=operating_system), \
                    mock.patch.dict(os.environ, environment), \
                    mock.patch.object(sys, "argv", ["run", str(payload), str(Path(directory) / "work")]), \
                    contextlib.redirect_stdout(output):
                simulator.main()

        budgets = {command[3]: timeout for command, timeout in calls if command[0] == "/simctl"}
        self.assertEqual(budgets, {"create": 120, "boot": 30, "bootstatus": 300, "spawn": 180})
        for phase in budgets:
            self.assertRegex(output.getvalue(), rf"(?m)^TIMING: {phase} [0-9]+\.[0-9] s of {budgets[phase]} s$")

    def test_invalid_payload_fails_before_execution(self):
        def oversize(payload):
            with (payload / "CairnSimulatorSmoke.kexe").open("r+b") as binary:
                binary.truncate(128 * 1024 * 1024 + 1)

        cases = {
            "corruption": lambda payload: (payload / "CairnSimulatorSmoke.kexe").write_bytes(b"changed"),
            "missing": lambda payload: (payload / "CairnSimulatorSmoke.kexe").unlink(),
            "wrong-revision": lambda payload: (payload / "revision.txt").write_text("b" * 40 + "\n"),
            "outside-path": lambda payload: (payload / "payload.sha256").write_text("a" * 64 + "  ../secret\n"),
            "extra-file": lambda payload: (payload / "unexpected").touch(),
            "symlink": lambda payload: (
                (payload / "CairnSimulatorSmoke.kexe").rename(payload / "outside"),
                (payload / "CairnSimulatorSmoke.kexe").symlink_to(payload / "outside"),
                (payload / "outside").unlink(),
            ),
            "oversized": oversize,
        }
        for name, mutate in cases.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                payload = self.create_payload(directory)
                mutate(payload)

                with self.assertRaisesRegex(SystemExit, "FAIL: functional payload"):
                    simulator.verify_payload(payload, "a" * 40)


if __name__ == "__main__":
    unittest.main()
