"""Real native phase/process profiles without another full-export screening pair."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from equations.maude_native import source_identity
from equations.maude_runner import GuardError, boundary_complete
from check_process import FLAGS
from native_profile import phase_records
from test_maude_boundary import NATIVE_MODULE, native_stream


class CompiledProfileTests(unittest.TestCase):
    proxy: Path

    def test_linux_process_profile_is_diagnostic_and_observes_the_real_guard(self):
        environment = dict(os.environ)
        environment.pop("CAIRN_MAUDE_BINARY", None)

        result = subprocess.run(
            [sys.executable, str(Path(__file__).with_name("experiment.py")),
             "--proxy", str(self.proxy), "--workload", "full-export",
             "--rounds", "1", "--profile-linux", "--profile-tamarin", "--profile-native"],
            text=True, capture_output=True, env=environment, timeout=270,
        )

        if sys.platform != "linux":
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("process profiling requires native Linux", result.stderr)
            return
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        report = json.loads(result.stdout)
        self.assertFalse(report["budget_checked"])
        self.assertFalse(report["budget_passed"])
        runtime_profiles = report["tamarin_runtime_profiles"]
        self.assertEqual(set(runtime_profiles), {"baseline", "compiled_guard"})
        for samples in runtime_profiles.values():
            runtime, = samples
            self.assertEqual(len(runtime["executable_sha256"]), 64)
            self.assertGreater(int(runtime["numeric_fields"]["n_capabilities"]), 0)
            self.assertGreater(float(runtime["numeric_fields"]["total_cpu_seconds"]), 0)
        phases = report["native_phase_profiles"]
        self.assertEqual(phases["baseline"][0]["processes"], [])
        for samples in phases.values():
            self.assertGreater(samples[0]["driver_thread_cpu_nanoseconds"], 0)
        self.assertTrue(any(
            process["phases"]["query_validation"]["calls"] > 0
            for process in phases["compiled_guard"][0]["processes"]
        ))
        profiles = report["native_process_profiles"]
        self.assertEqual(set(profiles), {"baseline", "compiled_guard"})
        self.assertEqual(profiles["baseline"][0]["processes"], [])
        guarded, = profiles["compiled_guard"]
        self.assertGreaterEqual(guarded["sampler_cpu_seconds"], 0)
        self.assertTrue(guarded["processes"])
        self.assertTrue(any(
            process["last_observed_user_clock_ticks"]
            + process["last_observed_system_clock_ticks"] > 0
            for process in guarded["processes"]
        ))
        for process in guarded["processes"]:
            self.assertGreaterEqual(process["last_observed_cpu_nanoseconds"], 0)
            self.assertGreater(process["samples"], 0)
        print("PASS: diagnostic-only native Linux process profile " + json.dumps(report))

    def test_native_phase_profile_is_complete_before_shutdown_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / "phases"
            journal = Path(temporary) / "events"
            environment = dict(
                os.environ, CAIRN_MAUDE_PHASE_REPORT=str(report),
                CAIRN_MAUDE_GUARD_REPORT=str(journal),
            )
            environment.pop("CAIRN_MAUDE_BINARY", None)

            result = subprocess.run(
                [str(self.proxy), *FLAGS],
                input=NATIVE_MODULE + "reduce tamXCroleA .\n" * 128,
                text=True, capture_output=True, env=environment, timeout=30,
            )

            if sys.platform != "linux":
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("CPU profiling requires 64-bit native Linux", result.stderr)
                self.assertFalse(report.exists())
                return
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(result.stdout.count("result Msg: tamXCroleA"), 128)
            self.assertTrue(boundary_complete(journal, source_id=source_identity()))
            profile, = phase_records(report.read_bytes())
            self.assertGreater(profile["interactive_cpu_nanoseconds"], 0)
            self.assertEqual(profile["phases"]["query_validation"]["calls"], 128)
            self.assertEqual(profile["phases"]["journal"]["calls"], 256)

    @unittest.skipUnless(sys.platform == "linux", "native CPU profiling is Linux-only")
    def test_bad_phase_destinations_reject_without_blocking_or_overwriting(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / "target"
            target.write_bytes(b"unchanged fixture")
            link, fifo = root / "link", root / "fifo"
            link.symlink_to(target)
            os.mkfifo(fifo)
            for destination in (Path("relative-profile"), link, fifo, root):
                environment = dict(os.environ, CAIRN_MAUDE_PHASE_REPORT=str(destination))
                environment.pop("CAIRN_MAUDE_BINARY", None)
                environment.pop("CAIRN_MAUDE_GUARD_REPORT", None)
                with self.subTest(kind=destination.name):
                    result = subprocess.run(
                        [str(self.proxy), *FLAGS], input=NATIVE_MODULE,
                        text=True, capture_output=True, env=environment, timeout=5,
                    )

                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertIn("native evidence report", result.stderr)
                    self.assertNotIn("panicked", result.stderr)
            self.assertEqual(target.read_bytes(), b"unchanged fixture")

    @unittest.skipUnless(sys.platform == "linux", "native CPU profiling is Linux-only")
    def test_phase_output_capacity_failure_cannot_complete_lifecycle(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / "phases"
            journal = Path(temporary) / "events"
            environment = dict(
                os.environ, CAIRN_MAUDE_PHASE_REPORT=str(report),
                CAIRN_MAUDE_GUARD_REPORT=str(journal),
            )
            environment.pop("CAIRN_MAUDE_BINARY", None)
            driver = (
                "import os, resource, signal, sys; "
                "signal.signal(signal.SIGXFSZ, signal.SIG_IGN); "
                "resource.setrlimit(resource.RLIMIT_FSIZE, (512, 512)); "
                "os.execv(sys.argv[1], sys.argv[1:])"
            )

            result = subprocess.run(
                [sys.executable, "-c", driver, str(self.proxy), *FLAGS],
                input=NATIVE_MODULE + "reduce tamXCroleA .\n",
                text=True, capture_output=True, env=environment, timeout=10,
            )

            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("native evidence report", result.stderr)
            self.assertNotIn("panicked", result.stderr)
            self.assertEqual(report.stat().st_size, 512)
            with self.assertRaises(GuardError):
                boundary_complete(journal, source_id=source_identity())

    @unittest.skipUnless(sys.platform == "linux", "native CPU profiling is Linux-only")
    def test_profiled_validation_failure_cannot_emit_successful_phase_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / "phases"
            with patch.dict(os.environ, CAIRN_MAUDE_PHASE_REPORT=str(report)):
                result = native_stream(
                    NATIVE_MODULE + "reduce tamXCroleA .\n",
                    "result Pub: tamXCroleA\nMaude> ", proxy=self.proxy,
                )

            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertNotIn("result Pub:", result.stdout)
            self.assertEqual(report.read_bytes(), b"")
