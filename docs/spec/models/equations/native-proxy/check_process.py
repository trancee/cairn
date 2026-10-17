"""Maintained native guard process/proof checks at the CLI/native-stream seam."""

import json
import math
import os
from pathlib import Path
import platform
import selectors
import subprocess
import sys
import tempfile
import time
import unittest

from equations.maude_native import source_identity
from equations.maude_runner import GuardError, boundary_complete, run_guarded_tamarin
from test_maude_boundary import NATIVE_MODULE, native_stream

FLAGS = ["-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"]


def read_until(descriptor: int, ending: bytes) -> bytes:
    result = bytearray()
    deadline = time.monotonic() + 5
    with selectors.DefaultSelector() as selector:
        selector.register(descriptor, selectors.EVENT_READ)
        while not result.endswith(ending):
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not selector.select(remaining):
                raise AssertionError("fixture did not reach its required stream state")
            chunk = os.read(descriptor, 8096)
            if not chunk:
                raise AssertionError("fixture closed before its required stream state")
            result.extend(chunk)
    return bytes(result)


class CompiledProcessTests(unittest.TestCase):
    proxy: Path

    def test_closed_backend_stderr_preserves_repeated_replies_and_teardown(self):
        result = native_stream(
            NATIVE_MODULE + "reduce tamXCroleA .\n" * 3,
            "result Msg: tamXCroleA\nMaude> ", proxy=self.proxy, close_errors=True,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertEqual(result.stdout.count("result Msg: tamXCroleA"), 3)

    def test_backend_stderr_diagnostic_cannot_forward_an_otherwise_valid_reply(self):
        result = native_stream(
            NATIVE_MODULE + "reduce tamXCroleA .\n",
            "result Msg: tamXCroleA\nMaude> ", proxy=self.proxy,
            startup_error="fixture backend diagnostic",
        )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("native process: stderr diagnostic", result.stderr)
        self.assertNotIn("result Msg:", result.stdout)

    def test_process_profiling_rejects_acceptance_and_other_workloads_before_execution(self):
        selections = [
            ["--proxy", str(self.proxy), "--rounds", "3"],
            ["--proxy", str(self.proxy), "--rounds", "1", "--workload", "startup"],
            ["--check-report", "absent-report.json", "--rounds", "1"],
            ["--compare-linux", "--rounds", "3"],
            ["--compare-linux", "--rounds", "1", "--workload", "startup"],
        ]
        cases = [(selection + ["--profile-linux"], "requires one full-export screening pair")
                 for selection in selections]
        cases.append((["--compare-linux", "--rounds", "1"], "requires one full-export screening pair"))
        if sys.platform != "linux" or platform.machine() != "x86_64":
            cases.append((
                ["--compare-linux", "--rounds", "1", "--profile-linux"],
                "comparison requires native Linux x86-64",
            ))
        for selection, reason in cases:
            with self.subTest(selection=selection):
                result = subprocess.run(
                    [sys.executable, str(Path(__file__).with_name("experiment.py")),
                     *selection],
                    text=True, capture_output=True, timeout=5,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(reason, result.stderr)

    def test_linux_process_profile_is_diagnostic_and_observes_the_real_guard(self):
        environment = dict(os.environ)
        environment.pop("CAIRN_MAUDE_BINARY", None)

        result = subprocess.run(
            [sys.executable, str(Path(__file__).with_name("experiment.py")),
             "--proxy", str(self.proxy), "--workload", "full-export",
             "--rounds", "1", "--profile-linux"],
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

    def test_screening_reports_waited_child_resources_without_acceptance(self):
        environment = dict(os.environ)
        environment.pop("CAIRN_MAUDE_BINARY", None)

        result = subprocess.run(
            [sys.executable, str(Path(__file__).with_name("experiment.py")),
             "--proxy", str(self.proxy), "--workload", "startup", "--rounds", "1"],
            text=True, capture_output=True, env=environment, timeout=30,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        report = json.loads(result.stdout)
        self.assertFalse(report["budget_checked"])
        self.assertFalse(report["budget_passed"])
        self.assertIn("waited_child_resources", report)
        self.assertEqual(set(report["waited_child_resources"]), {"baseline", "compiled_guard"})
        for label, samples in report["waited_child_resources"].items():
            with self.subTest(label=label):
                self.assertEqual(len(samples), 1)
                sample = samples[0]
                self.assertEqual(set(sample), {
                    "user_seconds", "system_seconds",
                    "voluntary_context_switches", "involuntary_context_switches",
                })
                for field in ("user_seconds", "system_seconds"):
                    self.assertIs(type(sample[field]), float)
                    self.assertTrue(math.isfinite(sample[field]) and sample[field] >= 0)
                for field in ("voluntary_context_switches", "involuntary_context_switches"):
                    self.assertIs(type(sample[field]), int)
                    self.assertGreaterEqual(sample[field], 0)
                self.assertGreater(sample["user_seconds"] + sample["system_seconds"], 0)

    def test_closed_consumer_rejects_stream_with_controlled_io_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / "events"
            environment = dict(os.environ, CAIRN_MAUDE_GUARD_REPORT=str(report))
            environment.pop("CAIRN_MAUDE_BINARY", None)
            with subprocess.Popen(
                [str(self.proxy), *FLAGS], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, env=environment,
            ) as process:
                process.stdout.close()
                process.stdout = None

                _, errors = process.communicate(
                    input=(NATIVE_MODULE + "reduce tamXCroleA .\n").encode(), timeout=10,
                )

            self.assertEqual(process.returncode, 1, repr(errors))
            self.assertIn(b"native process: I/O or version failure", errors)
            self.assertIn(b"native consumer closed its input", errors)
            self.assertNotIn(b"panicked", errors)
            with self.assertRaises(GuardError):
                boundary_complete(report, source_id=source_identity())

    def test_ready_stream_interrupt_closes_complete_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / "events"
            environment = dict(os.environ, CAIRN_MAUDE_GUARD_REPORT=str(report))
            environment.pop("CAIRN_MAUDE_BINARY", None)
            with subprocess.Popen(
                [str(self.proxy), *FLAGS], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, env=environment,
            ) as process:
                process.stdin.write((NATIVE_MODULE + "reduce tamXCroleA .\n").encode())
                process.stdin.flush()
                read_until(process.stdout.fileno(), b"result Msg: tamXCroleA\nMaude> ")

                process.terminate()
                output, errors = process.communicate(timeout=10)

            self.assertEqual(process.returncode, 0, repr(output + errors))
            self.assertEqual(errors, b"")
            self.assertTrue(boundary_complete(report, source_id=source_identity()))

    def test_pending_stream_interrupt_cannot_record_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Path(temporary) / "maude-fixture"
            fixture.write_text(
                f"#!{sys.executable}\nimport os, sys\n"
                "if '--version' in sys.argv:\n"
                "    print('3.5.1'); raise SystemExit(0)\n"
                "print('Maude> ', end='', flush=True)\n"
                "module = False\n"
                "for line in sys.stdin:\n"
                "    if line.startswith('fmod'):\n"
                "        module = True\n"
                "    elif module:\n"
                "        if line.strip() == 'endfm':\n"
                "            module = False\n"
                "            print('Maude> ', end='', flush=True)\n"
                "    elif line.startswith('set'):\n"
                "        print('Maude> ', end='', flush=True)\n"
                "    else:\n"
                "        os.write(int(os.environ['CAIRN_NATIVE_READY_FD']), b'Q')\n",
            )
            fixture.chmod(0o755)
            report = Path(temporary) / "events"
            read_fd, write_fd = os.pipe()
            environment = dict(
                os.environ, CAIRN_MAUDE_BINARY=str(fixture),
                CAIRN_MAUDE_GUARD_REPORT=str(report), CAIRN_NATIVE_READY_FD=str(write_fd),
            )
            try:
                with subprocess.Popen(
                    [str(self.proxy), *FLAGS], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE, env=environment, pass_fds=(write_fd,),
                ) as process:
                    process.stdin.write((NATIVE_MODULE + "reduce tamXCroleA .\n").encode())
                    process.stdin.flush()
                    read_until(read_fd, b"Q")

                    process.terminate()
                    output, errors = process.communicate(timeout=10)
            finally:
                os.close(read_fd)
                os.close(write_fd)

            self.assertEqual(process.returncode, 1, repr(output + errors))
            self.assertIn(b"native operation interrupted", errors)
            with self.assertRaises(GuardError):
                boundary_complete(report, source_id=source_identity())

    def test_invalid_invocations_and_installation_input_fail_closed(self):
        cases = (([], "reduce tamXCroleA .\n"), (["-batch"], ""), (["--unknown"], ""))
        for arguments, command in cases:
            environment = dict(os.environ)
            environment.pop("CAIRN_MAUDE_GUARD_REPORT", None)
            environment.pop("CAIRN_MAUDE_BINARY", None)
            with self.subTest(arguments=arguments):
                result = subprocess.run(
                    [str(self.proxy), *arguments], input=command, text=True,
                    capture_output=True, env=environment, timeout=5,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("unsupported", result.stderr)

    def test_real_tamarin_accepts_required_derivation_kind_export(self):
        model = Path(__file__).with_name("derivation.spthy")

        output = run_guarded_tamarin([
            "tamarin-prover", str(model), "--quit-on-warning",
            "--derivcheck-timeout=60", "--output-module=msr",
        ], 120, proxy=self.proxy)

        self.assertIn("rule (modulo E) Natural_Input:", output)

    def test_real_tamarin_normalization_witness_retains_verified_result(self):
        source = """theory CairnNativeBoundaryProbe
begin
builtins: hashing, symmetric-encryption, natural-numbers
functions: kdf/3, ext/2, mac/2, kem/2, kdec/2, pk/1, roleA/0, roleB/0, flip/1
equations: kdec(kem(ss,pk(dk)),dk) = ss, flip(roleA) = roleB, flip(roleB) = roleA
rule Emit:
  [Fr(~message)] --[Probe(flip(roleA))]-> [Out(~message)]
lemma normalization_witness: exists-trace
  "Ex #i. Probe(roleB) @i"
end
"""
        with tempfile.TemporaryDirectory() as temporary:
            model = Path(temporary) / "normalization.spthy"
            model.write_text(source)

            output = run_guarded_tamarin([
                "tamarin-prover", str(model), "--quit-on-warning", "--prove=normalization_witness",
            ], 60, proxy=self.proxy)

        self.assertIn("normalization_witness (exists-trace): verified", output)
