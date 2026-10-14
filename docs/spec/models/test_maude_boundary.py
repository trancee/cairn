"""Behavior of the approved native command/reply image boundary."""

import os
from pathlib import Path
import subprocess
import sys
import shutil
import tempfile
import unittest

from equations.maude_image import BoundaryError, validate_query, validate_reply
from equations.maude_runner import GuardError, run_guarded_tamarin

NATIVE_MODULE = """set show command off .
set show timing off .
set show stats off .
fmod MSG is
  protecting NAT .
  sort Pub Fresh Msg Node TamNat TOP .
  subsort Pub < Msg .
  subsort Fresh < Msg .
  subsort TamNat < Msg .
  subsort Msg < TOP .
  subsort Node < TOP .
  op f : Nat -> Fresh .
  op p : Nat -> Pub .
  op c : Nat -> Msg .
  op n : Nat -> Node .
  op t : Nat -> TamNat .
  op list : TOP -> TOP .
  op cons : TOP TOP -> TOP .
  op nil : -> TOP .
  op tamXCtone : -> TamNat .
  op tamtplus : TamNat TamNat -> TamNat [comm assoc] .
  op tamXCext : Msg Msg -> Msg .
  op tamXCflip : Msg -> Msg .
  op tamXCfst : Msg -> Msg .
  op tamXCh : Msg -> Msg .
  op tamXCkdec : Msg Msg -> Msg .
  op tamXCkdf : Msg Msg Msg -> Msg .
  op tamXCkem : Msg Msg -> Msg .
  op tamXCmac : Msg Msg -> Msg .
  op tamXCpair : Msg Msg -> Msg .
  op tamXCpk : Msg -> Msg .
  op tamXCroleA : -> Msg .
  op tamXCroleB : -> Msg .
  op tamXCsdec : Msg Msg -> Msg .
  op tamXCsenc : Msg Msg -> Msg .
  op tamXCsnd : Msg -> Msg .
  eq tamXCflip(tamXCroleA) = tamXCroleB [variant] .
  eq tamXCflip(tamXCroleB) = tamXCroleA [variant] .
  eq tamXCfst(tamXCpair(x0:Msg,x1:Msg)) = x0:Msg [variant] .
  eq tamXCkdec(tamXCkem(x0:Msg,tamXCpk(x1:Msg)),x1:Msg) = x0:Msg [variant] .
  eq tamXCsdec(tamXCsenc(x0:Msg,x1:Msg),x1:Msg) = x0:Msg [variant] .
  eq tamXCsnd(tamXCpair(x0:Msg,x1:Msg)) = x1:Msg [variant] .
endfm
"""

def native_stream(
    command: str, reply: str, *, shutdown_error: bool = False,
) -> subprocess.CompletedProcess[str]:
    final_action = "continue" if shutdown_error else "raise SystemExit(0)"
    fake = f"""#!{sys.executable}
import signal, sys
if '--version' in sys.argv:
    print('3.5.1')
    raise SystemExit(0)
def shutdown(number, frame):
    print('fixture shutdown diagnostic', file=sys.stderr, flush=True)
    raise SystemExit(1)
if {shutdown_error!r}:
    signal.signal(signal.SIGTERM, shutdown)
print('Maude> ', end='', flush=True)
module = False
for line in sys.stdin:
    if line.startswith('fmod'):
        module = True
    elif module:
        if line.strip() == 'endfm':
            module = False
            print('Maude> ', end='', flush=True)
    elif line.startswith('set'):
        print('Maude> ', end='', flush=True)
    else:
        print({reply!r}, end='', flush=True)
        {final_action}
"""
    with tempfile.TemporaryDirectory() as temporary:
        executable = Path(temporary) / "maude-fixture"
        executable.write_text(fake)
        executable.chmod(0o755)
        environment = dict(os.environ, CAIRN_MAUDE_BINARY=str(executable))
        environment.pop("CAIRN_MAUDE_GUARD_REPORT", None)
        return subprocess.run(
            [sys.executable, str(Path(__file__).parent / "equations/maude_boundary.py"),
             "-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"],
            input=command, text=True, capture_output=True, env=environment, timeout=30,
        )


class NativeQueryBoundaryTests(unittest.TestCase):
    def test_importer_variable_namespaces_cannot_be_mixed_or_conflated(self):
        cases = (
            ("unify in MSG : x0:Msg =? x1:Msg .", "Unifier 1\nx0:Msg --> x1:Msg\n"),
            ("match in MSG : x0:Msg <=? x1:Msg .", "Matcher 1\nx0:Msg --> #1:Msg\n"),
            ("reduce x0:Msg .", "result Msg: #1:Msg\n"),
            ("unify in MSG : x0:Msg =? x1:Msg .",
             "Unifier 1\nx0:Msg --> #1:Msg\nx1:Msg --> %1:Msg\n"),
        )

        for command, reply in cases:
            query = validate_query(command)
            with self.subTest(command=command, reply=reply), self.assertRaisesRegex(
                BoundaryError, "variable namespace",
            ):
                validate_reply(query, reply)

    def test_rejected_query_shapes_never_enter_the_native_image(self):
        commands = (
            "reduce 0 .", "reduce t(x0:Nat) .", "reduce p(01) .",
            "reduce tamtplus(tamXCroleA,tamXCtone) .",
            "reduce tamXCh(n(0)) .", "reduce x0:TOP .",
            "reduce #0:Msg .", "reduce tamXCh(p(0) .",
            "reduce tamXCh(p(0)) trailing .", "reduce tamXCunknown .",
            "reduce tamXCroleA\u00a0.",
            "unify in MSG : p(0) =? p(0) =? p(0) .",
        )

        for command in commands:
            with self.subTest(command=command), self.assertRaises(BoundaryError):
                validate_query(command)

    def test_rejected_solution_shapes_invalidate_the_entire_reply(self):
        query = validate_query("unify in MSG : x0:Pub =? p(0) .")
        replies = (
            "Unifier 1\nx0:Pub --> p(1)\n",
            "Unifier 1\nx0:Pub --> x1:Pub\n",
            "Unifier 1\nx0:Pub --> #0:TOP\n",
            "Unifier 1\nx1:Pub --> p(0)\n",
            "Unifier 1\nx0:Pub --> p(0)\nx0:Pub --> p(0)\n",
            "Unifier 1\nx0:Pub --> p(0)\nUnifier 3\nempty substitution\n",
            "Unifier 1\nx0:Pub --> p(0)\nUnifier 2\nx0:Pub --> tamXCroleA\n",
            "Unifier 1\n", "No unifier.\nUnifier 1\nempty substitution\n",
            "Warning: ignored term\nNo unifier.\n",
        )

        for reply in replies:
            with self.subTest(reply=reply), self.assertRaises(BoundaryError):
                validate_reply(query, reply)

    def test_variant_exhaustion_and_metadata_are_mandatory(self):
        query = validate_query("get variants in MSG : tamXCflip(x0:Msg) .")
        replies = (
            "Variant 1\nrewrites: 0\nMsg: tamXCflip(#1:Msg)\nx0:Msg --> #1:Msg\n",
            "Variant 1\nMsg: tamXCflip(#1:Msg)\nNo more variants.\nrewrites: 0\n",
            "Variant 2\nrewrites: 0\nMsg: tamXCroleA\nNo more variants.\nrewrites: 0\n",
            "No more variants.\nrewrites: 0\n",
        )

        for reply in replies:
            with self.subTest(reply=reply), self.assertRaises(BoundaryError):
                validate_reply(query, reply)

    def test_deep_terms_and_flattened_natural_ac_remain_supported(self):
        message = "tamXCh(" * 2000 + "tamXCroleA" + ")" * 2000
        natural = "tamtplus(" + ",".join(["t(0)"] * 1000) + ")"
        query = validate_query(f"reduce list(cons({message},cons({natural},nil))) .")
        reply = f"result TOP: list(cons({message},cons({natural},nil)))\n"

        validate_reply(query, reply)

    def test_framing_beneath_a_message_function_rejects_the_whole_query(self):
        command = "reduce tamXCh(list(nil)) ."

        with self.assertRaisesRegex(BoundaryError, "message function.*operand sort"):
            validate_query(command)

    def test_an_unsorted_returned_binding_rejects_the_whole_reply(self):
        query = validate_query("unify in MSG : x0:Pub =? p(0) .")
        reply = "\nUnifier 1\nx0:Pub --> tamXCroleA\n"

        with self.assertRaisesRegex(BoundaryError, "binding.*sort"):
            validate_reply(query, reply)


class NativeStreamBoundaryTests(unittest.TestCase):
    def test_installation_probe_cannot_execute_other_commands_or_hide_backend_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / "maude-fixture"
            executable.write_text(
                f"#!{sys.executable}\nimport sys\n"
                "if '--version' in sys.argv:\n"
                "    print('3.5.1')\n"
                "else:\n"
                "    print('fixture diagnostic', file=sys.stderr)\n"
                "    raise SystemExit(1)\n",
            )
            executable.chmod(0o755)
            environment = dict(os.environ, CAIRN_MAUDE_BINARY=str(executable))
            environment.pop("CAIRN_MAUDE_GUARD_REPORT", None)

            for command in ("quit\n", "reduce tamXCroleA .\n"):
                with self.subTest(command=command):
                    result = subprocess.run(
                        [sys.executable, str(Path(__file__).parent / "equations/maude_boundary.py")],
                        input=command, text=True, capture_output=True, env=environment, timeout=5,
                    )

                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertIn("native installation", result.stderr)
                    self.assertNotIn("fixture diagnostic", result.stderr)

    def test_native_shutdown_failure_cannot_be_reported_as_success(self):
        command = NATIVE_MODULE + "reduce tamXCroleA .\n"

        result = native_stream(command, "result Msg: tamXCroleA\nMaude> ", shutdown_error=True)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("native shutdown", result.stderr)

    def test_bad_later_solution_does_not_forward_an_earlier_valid_solution(self):
        command = NATIVE_MODULE + "unify in MSG : x0:Pub =? p(0) .\n"
        reply = "Unifier 1\nx0:Pub --> p(0)\nUnifier 2\nx0:Pub --> tamXCroleA\nMaude> "

        result = native_stream(command, reply)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn("Unifier 1", result.stdout)
        self.assertIn("incompatible sort", result.stderr)

    def test_truncated_native_reply_rejects_instead_of_waiting_on_eof(self):
        command = NATIVE_MODULE + "reduce tamXCroleA .\n"

        result = native_stream(command, "result Msg: tamXCroleA\n")

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn("result Msg:", result.stdout)
        self.assertIn("premature EOF", result.stderr)

    def test_non_regular_evidence_destination_fails_without_blocking(self):
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / "maude-fixture"
            executable.write_text(f"#!{sys.executable}\nprint('3.5.1')\n")
            executable.chmod(0o755)
            report = Path(temporary) / "report-fifo"
            os.mkfifo(report)
            environment = dict(
                os.environ, CAIRN_MAUDE_BINARY=str(executable),
                CAIRN_MAUDE_GUARD_REPORT=str(report),
            )

            result = subprocess.run(
                [sys.executable, str(Path(__file__).parent / "equations/maude_boundary.py"), "--version"],
                text=True, capture_output=True, env=environment, timeout=5,
            )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("native evidence report", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_malformed_evidence_is_a_controlled_command_failure(self):
        reports = (
            "", '{"event":"version","pid":1337}', "not-json\n",
            '{"event":[],"pid":1337}\n',
            '{"event":"version","pid":true}\n',
            '{"event":"unknown","pid":1337}\n',
            '{"event":"begin","pid":1337,"kind":[]}\n',
            '{"event":"shutdown","pid":1337}\n',
            '{"event":"version","pid":1337,"extra":0}\n',
            '{"event":"start","pid":1337}\n{"event":"module","pid":1337}\n'
            '{"event":"shutdown","pid":1337}\n',
            '{"event":"version","pid":1337}\n{"event":"failure","pid":1337,"reason":"rejected"}\n',
        )
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / "tamarin-prover"
            for report in reports:
                executable.write_text(
                    f"#!{sys.executable}\nimport os\nfrom pathlib import Path\n"
                    f"Path(os.environ['CAIRN_MAUDE_GUARD_REPORT']).write_text({report!r})\n"
                    "print('unattested proof success')\n",
                )
                executable.chmod(0o755)

                with self.subTest(report=report), self.assertRaises(GuardError):
                    run_guarded_tamarin([str(executable), "--parse-only", "fixture.spthy"], 30)

    def test_duplicate_evidence_fields_cannot_hide_native_failure(self):
        report = '{"event":"failure","event":"version","pid":1337}\n'
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / "tamarin-prover"
            executable.write_text(
                f"#!{sys.executable}\nimport os\nfrom pathlib import Path\n"
                f"Path(os.environ['CAIRN_MAUDE_GUARD_REPORT']).write_text({report!r})\n"
                "print('unattested proof success')\n",
            )
            executable.chmod(0o755)

            with self.assertRaisesRegex(GuardError, "duplicate native boundary field"):
                run_guarded_tamarin([str(executable), "--parse-only", "fixture.spthy"], 30)

    def test_tool_success_without_native_boundary_evidence_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / "tamarin-prover"
            executable.write_text(f"#!{sys.executable}\nprint('unattested proof success')\n")
            executable.chmod(0o755)

            with self.assertRaisesRegex(GuardError, "missing native boundary"):
                run_guarded_tamarin([str(executable), "--parse-only", "fixture.spthy"], 30)

    def test_changed_equations_reject_the_whole_native_stream(self):
        module = NATIVE_MODULE.replace(
            "eq tamXCflip(tamXCroleA) = tamXCroleB",
            "eq tamXCflip(tamXCroleA) = tamXCroleA",
        )
        result = native_stream(module + "reduce tamXCflip(tamXCroleA) .\n", "result Msg: tamXCroleA\nMaude> ")

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("native module: unreviewed", result.stderr)
        self.assertNotIn("result Msg:", result.stdout)


@unittest.skipUnless(shutil.which("maude"), "pinned native Maude integration needs maude on PATH")
class NativeMaudeIntegrationTests(unittest.TestCase):
    def test_every_native_operation_kind_preserves_the_real_reply(self):
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
            [sys.executable, str(Path(__file__).parent / "equations/maude_boundary.py"),
             "-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"],
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


@unittest.skipUnless(shutil.which("tamarin-prover"), "pinned Tamarin integration needs tamarin-prover on PATH")
class NativeTamarinIntegrationTests(unittest.TestCase):
    def test_guarded_tool_proves_a_tiny_exact_signature_normalization_witness(self):
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
            model = Path(temporary) / "native-probe.spthy"
            model.write_text(source)

            output = run_guarded_tamarin([
                "tamarin-prover", str(model), "--quit-on-warning", "--prove=normalization_witness",
            ], 60)

        self.assertIn("normalization_witness (exists-trace): verified", output)


if __name__ == "__main__":
    unittest.main()
