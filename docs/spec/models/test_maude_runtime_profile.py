"""Numeric RTS parsing, private process ownership and diagnostic CLI controls."""

import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from equations.maude_native import NATIVE_DIRECTORY
from replay import run

sys.path.insert(0, str(NATIVE_DIRECTORY))

from tamarin_profile import (
    MAXIMUM_STATISTICS_BYTES, REQUIRED_FIELDS, RuntimeProfileError,
    TamarinRuntimeProfile, numeric_statistics,
)


def statistics_bytes(pairs=None):
    values = [(name, "1") for name in sorted(REQUIRED_FIELDS)]
    return b"omitted command header [not statistics]\n" + repr(
        values if pairs is None else pairs,
    ).encode()


class RuntimeStatisticsTests(unittest.TestCase):
    def test_numeric_fields_preserve_actual_mut_keys_and_trailing_spaces_only(self):
        pairs = [(name, "1") for name in sorted(REQUIRED_FIELDS)]
        pairs.extend([("sparks_dud ", "0"), ("gen_0_cpu_seconds", "0.000001")])

        result = numeric_statistics(statistics_bytes(pairs))

        self.assertEqual(result, dict(pairs))
        self.assertIn("mut_cpu_seconds", result)
        self.assertNotIn("mutator_cpu_seconds", result)
        self.assertNotIn("omitted command header", repr(result))

    def test_malformed_truncated_oversized_and_non_ascii_statistics_fail_closed(self):
        cases = (
            b"", b"x" * (MAXIMUM_STATISTICS_BYTES + 1), b"\xff",
            b"no statistics list", b"[", b"[]", b"{}",
            b"[('field', '1')]\ntrailing text", b"[" * 2000,
            b"[('field',)]", b"[['field', '1']]" * 8,
        )
        for data in cases:
            with self.subTest(prefix=data[:25]):
                with self.assertRaises(RuntimeProfileError):
                    numeric_statistics(data)

    def test_missing_duplicate_and_invalid_fields_are_typed_redacted_failures(self):
        valid = [(name, "1") for name in sorted(REQUIRED_FIELDS)]
        cases = [
            valid[:-1], [*valid, valid[0]], [*valid, None],
            [*valid, ("field", 1)], [*valid, (True, "1")],
            [*valid, ("field\npayload", "1")], [*valid, ("f" * 81, "1")],
        ]
        for value in ("NaN", "Infinity", "-1", "1_000", "1e9999", "9" * 81, "payload"):
            cases.append([*valid, ("field", value)])
        for pairs in cases:
            with self.subTest(last=pairs[-1]):
                with self.assertRaises(RuntimeProfileError) as raised:
                    numeric_statistics(statistics_bytes(pairs))
                self.assertNotIn("payload", str(raised.exception))

    def test_capabilities_and_tasks_require_positive_integers(self):
        for name in ("n_capabilities", "task_count"):
            for value in ("0", "1.0", "1e1"):
                pairs = [(field, value if field == name else "1") for field in REQUIRED_FIELDS]
                with self.subTest(name=name, value=value):
                    with self.assertRaisesRegex(RuntimeProfileError, "capability or task"):
                        numeric_statistics(statistics_bytes(pairs))


class RuntimeProfileProcessTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.executable = Path(self.temporary.name) / "tamarin-prover"
        self.executable.write_text(
            f"#!{sys.executable}\n"
            "import os, pathlib, sys, time\n"
            f"data = {statistics_bytes()!r}\n"
            "arguments = sys.argv[1:]\n"
            "assert arguments[-4] == '+RTS'\n"
            "assert arguments[-2:] == ['--machine-readable', '-RTS']\n"
            "statistics = pathlib.Path(arguments[-3][2:])\n"
            "mode = arguments[0]\n"
            "if mode == '--hang':\n"
            "    time.sleep(30)\n"
            "if mode == '--fifo':\n"
            "    os.mkfifo(statistics)\n"
            "elif mode == '--directory':\n"
            "    statistics.mkdir()\n"
            "elif mode == '--symlink':\n"
            "    target = statistics.with_suffix('.target')\n"
            "    target.write_bytes(data)\n"
            "    statistics.symlink_to(target)\n"
            "elif mode == '--oversized':\n"
            "    statistics.write_bytes(b'x' * 200001)\n"
            "elif mode != '--missing':\n"
            "    statistics.write_bytes(b'[' if mode == '--malformed' else data)\n"
            "backend = next((item.split('=', 1)[1] for item in arguments\n"
            "                if item.startswith('--with-maude=')), 'maude')\n"
            "errors = (f\"maude tool: '{backend}'\\n checking version: 3.5.1. OK.\\n\"\n"
            "          ' checking installation: OK.\\n')\n"
            "if mode == '--progress':\n"
            "    errors += ''.join('[Theory CairnRatchet] ' + stage + '\\n' for stage in\n"
            "        ('Theory loaded', 'Theory translated', 'Derivation checks started',\n"
            "         'Derivation checks ended'))\n"
            "if mode == '--unknown-stderr':\n"
            "    errors += 'omitted fixture diagnostic payload\\n'\n"
            "sys.stderr.write(errors)\n"
            "print('fixture export')\n"
            "raise SystemExit(1 if mode == '--failure' else 0)\n",
        )
        self.executable.chmod(0o700)
        self.environment = patch.dict(os.environ, {
            "PATH": self.temporary.name + os.pathsep + os.environ["PATH"], "GHCRTS": "",
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def collect(self, mode="--version", backend=None):
        with TamarinRuntimeProfile(backend) as profile:
            command = ["tamarin-prover", mode]
            if backend is not None:
                command.append("--with-maude=" + str(backend))
            output = run(profile.command(command), 5)
            report = profile.report()
            directory = profile.statistics.parent
        return output, report, directory

    def test_actual_launcher_preserves_output_and_collects_only_numeric_fields(self):
        output, report, directory = self.collect()

        self.assertEqual(output, "fixture export\n")
        self.assertEqual(report["numeric_fields"], {
            name: "1" for name in REQUIRED_FIELDS
        })
        self.assertEqual(
            report["executable_sha256"], hashlib.sha256(self.executable.read_bytes()).hexdigest(),
        )
        self.assertFalse(directory.exists())
        self.assertNotIn("omitted command header", repr(report))

    def test_guarded_banner_uses_the_selected_backend_without_retaining_arguments(self):
        backend = Path(self.temporary.name) / "native-guard"

        output, report, directory = self.collect(backend=backend)

        self.assertEqual(output, "fixture export\n")
        self.assertNotIn(str(backend), repr(report))
        self.assertFalse(directory.exists())

    def test_reviewed_pinned_theory_progress_is_not_a_runtime_failure(self):
        output, report, directory = self.collect("--progress")

        self.assertEqual(output, "fixture export\n")
        self.assertEqual(report["numeric_fields"]["n_capabilities"], "1")
        self.assertFalse(directory.exists())

    def test_missing_malformed_and_non_regular_statistics_fail_without_hanging(self):
        for mode in ("--missing", "--malformed", "--fifo", "--directory", "--symlink", "--oversized"):
            with self.subTest(mode=mode):
                with self.assertRaises((RuntimeProfileError, OSError)):
                    self.collect(mode)

    def test_failure_and_unrecognized_stderr_cannot_return_success_or_payloads(self):
        for mode in ("--failure", "--unknown-stderr"):
            with self.subTest(mode=mode):
                with self.assertRaises(RuntimeProfileError) as raised:
                    self.collect(mode)
                self.assertNotIn("fixture export", str(raised.exception))
                self.assertNotIn("diagnostic payload", str(raised.exception))

    def test_original_timeout_cleans_the_private_runtime_directory(self):
        with self.assertRaises(RuntimeProfileError) as raised:
            with TamarinRuntimeProfile() as profile:
                directory = profile.statistics.parent
                run(profile.command(["tamarin-prover", "--hang"]), 1)

        self.assertIn("timed out", str(raised.exception))
        self.assertFalse(directory.exists())

    def test_changed_executable_cannot_supply_a_runtime_report(self):
        with self.assertRaisesRegex(RuntimeProfileError, "executable changed"):
            with TamarinRuntimeProfile() as profile:
                run(profile.command(["tamarin-prover", "--version"]), 5)
                self.executable.write_text("changed executable")
                profile.report()

    def test_nonempty_runtime_override_is_rejected_without_exposing_it(self):
        with patch.dict(os.environ, GHCRTS="omitted runtime override"):
            with self.assertRaisesRegex(RuntimeProfileError, "GHCRTS") as raised:
                self.collect()
        self.assertNotIn("omitted runtime override", str(raised.exception))


class RuntimeProfileCommandTests(unittest.TestCase):
    def test_rts_profiling_rejects_acceptance_and_other_workloads_before_execution(self):
        cases = (
            ["--proxy", "/absent/native-guard"],
            ["--proxy", "/absent/native-guard", "--rounds", "1", "--workload", "startup"],
            ["--check-report", "/absent/report.json", "--rounds", "1"],
        )
        for arguments in cases:
            with self.subTest(arguments=arguments):
                result = subprocess.run(
                    [sys.executable, str(NATIVE_DIRECTORY / "experiment.py"),
                     *arguments, "--profile-tamarin"],
                    text=True, capture_output=True, timeout=5,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("requires one full-export screening pair", result.stderr)
                self.assertNotIn("Traceback", result.stderr)
