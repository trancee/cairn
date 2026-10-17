"""Maintained native guard CLI/native-stream checks."""

import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from equations.maude_native import source_identity
from equations.maude_runner import boundary_complete
from check_process import CompiledProcessTests
from check_profile import CompiledProfileTests
from test_maude_boundary import NATIVE_MODULE, native_stream


class CompiledStreamTests(unittest.TestCase):
    def test_recursive_executable_alias_is_rejected_before_native_startup(self):
        with tempfile.TemporaryDirectory() as temporary:
            alias = Path(temporary) / "alias"
            os.link(PROXY, alias)
            environment = dict(os.environ, CAIRN_MAUDE_BINARY=str(alias))
            environment.pop("CAIRN_MAUDE_GUARD_REPORT", None)

            result = subprocess.run(
                [str(PROXY), "--version"], text=True, capture_output=True,
                env=environment, timeout=5,
            )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("recursive executable", result.stderr)

    def test_variable_namespace_kind_and_variant_failures_reject_the_whole_reply(self):
        cases = (
            ("unify in MSG : x0:Msg =? x1:Msg .", "Unifier 1\nx0:Msg --> x1:Msg\n"),
            ("match in MSG : x0:Msg <=? x1:Msg .", "Matcher 1\nx0:Msg --> #1:Msg\n"),
            ("reduce x0:Msg .", "result Msg: #1:Msg\n"),
            ("unify in MSG : x0:Msg =? x1:Msg .",
             "Unifier 1\nx0:Msg --> #1:Msg\nx1:Msg --> %1:Msg\n"),
            ("unify in MSG : tamtplus(x0:Fresh,tamXCtone) =? tamtplus(x0:Fresh,tamXCtone) .",
             "Unifier 1\nx0:Fresh --> tamtplus(#1:Fresh,tamXCtone)\n"),
            ("unify in MSG : tamtplus(x0:Fresh,tamXCtone) =? tamtplus(x0:Fresh,tamXCtone) .",
             "Unifier 1\nx0:Fresh --> #1:[TOP]\n"),
            ("reduce tamtplus(x0:Fresh,tamXCtone) .",
             "result [TOP]: tamtplus(x0:Fresh,tamXCtone)\n"),
            ("reduce tamtplus(x0:Fresh,tamXCtone) .",
             "result TOP: tamtplus(x0:Fresh,tamXCtone)\n"),
            ("get variants in MSG : tamXCflip(x0:Msg) .",
             "Variant 1\nrewrites: 0\nMsg: tamXCflip(#1:Msg)\nx0:Msg --> #1:Msg\n"),
            ("get variants in MSG : tamXCflip(x0:Msg) .",
             "Variant 1\nMsg: tamXCflip(#1:Msg)\nNo more variants.\nrewrites: 0\n"),
            ("get variants in MSG : tamXCflip(x0:Msg) .",
             "Variant 2\nrewrites: 0\nMsg: tamXCroleA\nNo more variants.\nrewrites: 0\n"),
            ("get variants in MSG : tamXCflip(x0:Msg) .",
             "No more variants.\nrewrites: 0\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command, reply=reply):
                result = native_stream(NATIVE_MODULE + command + "\n", reply + "Maude> ", proxy=PROXY)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn("Unifier 1", result.stdout)
                self.assertNotIn("result TOP:", result.stdout)
                self.assertNotIn("Variant 1", result.stdout)

    def test_deep_framing_and_flat_natural_ac_remain_supported(self):
        message = "tamXCh(" * 2000 + "tamXCroleA" + ")" * 2000
        natural = "tamtplus(" + ",".join(["t(0)"] * 1000) + ")"
        term = f"list(cons({message},cons({natural},nil)))"

        result = native_stream(
            NATIVE_MODULE + f"reduce {term} .\n",
            f"result TOP: {term}\nMaude> ", proxy=PROXY,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"result TOP: {term}", result.stdout)

    def test_changed_equations_reject_the_whole_stream(self):
        module = NATIVE_MODULE.replace(
            "eq tamXCflip(tamXCroleA) = tamXCroleB",
            "eq tamXCflip(tamXCroleA) = tamXCroleA",
        )

        result = native_stream(
            module + "reduce tamXCflip(tamXCroleA) .\n",
            "result Msg: tamXCroleA\nMaude> ", proxy=PROXY,
        )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("native module: unreviewed", result.stderr)
        self.assertNotIn("result Msg:", result.stdout)

    def test_report_capacity_failure_is_controlled_and_rejects_the_stream(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = dict(os.environ, CAIRN_MAUDE_GUARD_REPORT=str(Path(temporary) / "events"))
            environment.pop("CAIRN_MAUDE_BINARY", None)
            driver = (
                "import os, resource, signal, sys; "
                "signal.signal(signal.SIGXFSZ, signal.SIG_IGN); "
                "resource.setrlimit(resource.RLIMIT_FSIZE, (512, 512)); "
                "os.execv(sys.argv[1], sys.argv[1:])"
            )

            result = subprocess.run(
                [sys.executable, "-c", driver, str(PROXY),
                 "-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"],
                input=NATIVE_MODULE + "reduce tamXCroleA .\n" * 512,
                text=True, capture_output=True, env=environment, timeout=30,
            )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("native evidence report", result.stderr)
        self.assertNotIn("panicked", result.stderr)

    def test_bad_later_solution_never_forwards_an_earlier_valid_solution(self):
        command = NATIVE_MODULE + "unify in MSG : x0:Pub =? p(0) .\n"
        reply = "Unifier 1\nx0:Pub --> p(0)\nUnifier 2\nx0:Pub --> tamXCroleA\nMaude> "

        result = native_stream(command, reply, proxy=PROXY)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn("Unifier 1", result.stdout)
        self.assertIn("incompatible sort", result.stderr)

    def test_rejected_queries_cannot_forward_a_native_result(self):
        commands = (
            "reduce 0 .", "reduce t(x0:Nat) .", "reduce p(01) .",
            "reduce tamtplus(tamXCroleA,tamXCtone) .",
            "reduce tamXCh(n(0)) .", "reduce x0:TOP .", "reduce #0:Msg .",
            "reduce tamXCh(p(0) .", "reduce tamXCh(p(0)) trailing .",
            "reduce tamXCunknown .", "reduce tamXCroleA\u00a0.",
            "unify in MSG : p(0) =? p(0) =? p(0) .",
            "reduce tamtplus(x0:Msg,tamXCtone) .",
            "reduce tamtplus(p(0),tamXCtone) .",
            "reduce tamtplus(tamXCh(f(0)),tamXCtone) .",
            "reduce tamtplus(list(nil),tamXCtone) .",
            "reduce tamXCh(list(cons(tamtplus(f(0),tamXCtone),nil))) .",
            "reduce tamtplus(x0:[TOP],tamXCtone) .", "reduce tamXCh(list(nil)) .",
        )
        for command in commands:
            with self.subTest(command=command):
                result = native_stream(NATIVE_MODULE + command + "\n", "result Msg: tamXCroleA\nMaude> ", proxy=PROXY)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn("result Msg:", result.stdout)
                self.assertNotIn("panicked", result.stderr)

    def test_rejected_bindings_and_solution_headers_reject_the_whole_reply(self):
        replies = (
            "Unifier 1\nx0:Pub --> p(1)\n", "Unifier 1\nx0:Pub --> x1:Pub\n",
            "\nUnifier 1\nx0:Pub --> tamXCroleA\n",
            "Unifier 1\nx0:Pub --> #0:TOP\n", "Unifier 1\nx1:Pub --> p(0)\n",
            "Unifier 1\nx0:Pub --> p(0)\nx0:Pub --> p(0)\n",
            "Unifier 1\nx0:Pub --> p(0)\nUnifier 3\nempty substitution\n",
            "Unifier 1\n", "No unifier.\nUnifier 1\nempty substitution\n",
            "Warning: ignored term\nNo unifier.\n",
        )
        for reply in replies:
            with self.subTest(reply=reply):
                result = native_stream(
                    NATIVE_MODULE + "unify in MSG : x0:Pub =? p(0) .\n",
                    reply + "Maude> ", proxy=PROXY,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn("Unifier 1", result.stdout)
                self.assertNotIn("No unifier.", result.stdout)

    def test_truncated_reply_and_shutdown_diagnostics_reject_the_stream(self):
        cases = (("result Msg: tamXCroleA\n", False, "premature EOF"),
                 ("result Msg: tamXCroleA\nMaude> ", True, "native shutdown"))
        for reply, shutdown_error, reason in cases:
            with self.subTest(reason=reason):
                result = native_stream(
                    NATIVE_MODULE + "reduce tamXCroleA .\n", reply,
                    shutdown_error=shutdown_error, proxy=PROXY,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(reason, result.stderr)

    def test_full_operation_evidence_reconciles_before_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / "events"
            environment = dict(os.environ, CAIRN_MAUDE_GUARD_REPORT=str(report))
            environment.pop("CAIRN_MAUDE_BINARY", None)

            result = subprocess.run(
                [str(PROXY), "-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"],
                input=NATIVE_MODULE + "reduce tamXCroleA .\n" * 512,
                text=True, capture_output=True, env=environment, timeout=30,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(result.stdout.count("result Msg: tamXCroleA"), 512)
            self.assertTrue(boundary_complete(report, source_id=source_identity()))
            self.assertEqual(report.read_text().count('"event": "accepted"'), 512)

    def test_non_regular_evidence_destination_fails_without_blocking(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / "events"
            os.mkfifo(report)
            environment = dict(os.environ, CAIRN_MAUDE_GUARD_REPORT=str(report))
            environment.pop("CAIRN_MAUDE_BINARY", None)

            result = subprocess.run(
                [str(PROXY), "--version"],
                text=True, capture_output=True, env=environment, timeout=5,
            )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("native evidence report", result.stderr)

    def test_all_real_operations_preserve_complete_native_replies(self):
        queries = (
            "reduce tamXCflip(tamXCroleA) .\n"
            "unify in MSG : tamXCpair(x0:Msg,p(0)) =? tamXCpair(t(0),x1:Pub) .\n"
            "match in MSG : list(cons(x0:Msg,nil)) <=? list(cons(tamXCroleA,nil)) .\n"
            "get variants in MSG : tamXCflip(x0:Msg) .\n"
        )
        environment = dict(os.environ)
        environment.pop("CAIRN_MAUDE_BINARY", None)
        environment.pop("CAIRN_MAUDE_GUARD_REPORT", None)

        result = subprocess.run(
            [str(PROXY), "-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"],
            input=NATIVE_MODULE + queries,
            text=True, capture_output=True, env=environment, timeout=30,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertIn("result Msg: tamXCroleB", result.stdout)
        self.assertIn("x0:Msg --> t(0)\nx1:Pub --> p(0)", result.stdout)
        self.assertIn("Matcher 1\nx0:Msg --> tamXCroleA", result.stdout)
        self.assertIn("Msg: tamXCflip(#1:Msg)", result.stdout)
        self.assertIn("No more variants.", result.stdout)

    def test_real_reduction_preserves_the_complete_native_reply(self):
        environment = dict(os.environ)
        environment.pop("CAIRN_MAUDE_BINARY", None)
        environment.pop("CAIRN_MAUDE_GUARD_REPORT", None)

        result = subprocess.run(
            [str(PROXY), "-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"],
            input=NATIVE_MODULE + "reduce tamXCflip(tamXCroleA) .\n",
            text=True, capture_output=True, env=environment, timeout=30,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertIn("result Msg: tamXCroleB", result.stdout)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proxy", type=Path, required=True)
    arguments, remaining = parser.parse_known_args()
    PROXY = arguments.proxy.resolve(strict=True)
    CompiledProcessTests.proxy = PROXY
    CompiledProfileTests.proxy = PROXY
    unittest.main(argv=[sys.argv[0], *remaining])
