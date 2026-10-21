"""Behavior of the approved native command/reply image boundary."""

import os
from pathlib import Path
import subprocess
import sys
import shutil
import tempfile
import unittest

from equations.maude_native import select_proxy, source_identity
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
    command: str, reply: str | tuple[str, ...], *, shutdown_error: bool = False, proxy: Path | None = None,
    close_errors: bool = False, startup_error: str = "",
) -> subprocess.CompletedProcess[str]:
    final_action = "continue" if shutdown_error or close_errors or isinstance(reply, tuple) else "raise SystemExit(0)"
    fake = f"""#!{sys.executable}
import os, signal, sys
if '--version' in sys.argv:
    print('3.5.1')
    raise SystemExit(0)
if {close_errors!r}:
    os.close(2)
if {startup_error!r}:
    print({startup_error!r}, file=sys.stderr, flush=True)
def shutdown(number, frame):
    print('fixture shutdown diagnostic', file=sys.stderr, flush=True)
    raise SystemExit(1)
if {shutdown_error!r}:
    signal.signal(signal.SIGTERM, shutdown)
print('Maude> ', end='', flush=True)
module = False
replies = list({reply!r}) if {isinstance(reply, tuple)!r} else None
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
        print(replies.pop(0) if replies is not None else {reply!r}, end='', flush=True)
        if replies == []:
            raise SystemExit(0)
        {final_action}
"""
    with tempfile.TemporaryDirectory() as temporary:
        executable = Path(temporary) / "maude-fixture"
        executable.write_text(fake)
        executable.chmod(0o755)
        environment = dict(os.environ, CAIRN_MAUDE_BINARY=str(executable))
        environment.pop("CAIRN_MAUDE_GUARD_REPORT", None)
        driver = [str(proxy if proxy is not None else select_proxy()[0])]
        return subprocess.run(
            [*driver, "-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"],
            input=command, text=True, capture_output=True, env=environment, timeout=30,
        )


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
                        [str(select_proxy()[0])],
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
                [str(select_proxy()[0]), "--version"],
                text=True, capture_output=True, env=environment, timeout=5,
            )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("native evidence report", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_malformed_evidence_is_a_controlled_command_failure(self):
        identity = source_identity()
        version = f'{{"event":"version","pid":1337,"source_id":"{identity}"}}\n'
        reports = (
            ("", "truncated native boundary records"),
            (version.rstrip("\n"), "truncated native boundary records"),
            ("not-json\n", "malformed native boundary records"),
            ('{"event":[],"pid":1337}\n', "malformed native boundary event"),
            ('{"event":"version","pid":true}\n', "malformed native boundary record"),
            ('{"event":"unknown","pid":1337}\n', "inconsistent native boundary lifecycle"),
            ('{"event":"begin","pid":1337,"kind":[]}\n', "malformed native boundary operation"),
            ('{"event":"shutdown","pid":1337}\n', "inconsistent native boundary lifecycle"),
            (f'{{"event":"version","pid":1337,"source_id":"{identity}","extra":0}}\n',
             "malformed native boundary fields"),
            ('{"event":"start","pid":1337}\n{"event":"module","pid":1337}\n'
             '{"event":"shutdown","pid":1337}\n', "inconsistent native boundary lifecycle"),
            (version + '{"event":"failure","pid":1337,"reason":"rejected"}\n',
             "native boundary rejected an operation"),
            ('{"event": "begin", "pid": 1337, "kind": "reduce"}\n',
             "inconsistent native boundary lifecycle"),
            (version + '{"event":"start","pid":1337}\n{"event":"module","pid":1337}\n'
             '{"event": "accepted", "pid": 1337, "kind": "reduce"}\n',
             "inconsistent native boundary lifecycle"),
            (version + '{"event":"start","pid":1337}\n{"event":"module","pid":1337}\n'
             '{"event": "begin", "pid": 1337, "kind": "reduce"}\n'
             '{"event": "accepted", "pid": 1337, "kind": "match"}\n',
             "inconsistent native boundary lifecycle"),
            ('{"event": "begin", "pid": 1337, "kind": "reduce", "kind": "match"}\n',
             "duplicate native boundary field"),
        )
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / "tamarin-prover"
            for report, reason in reports:
                executable.write_text(
                    f"#!{sys.executable}\nimport os\nfrom pathlib import Path\n"
                    f"Path(os.environ['CAIRN_MAUDE_GUARD_REPORT']).write_text({report!r})\n"
                    "print('unattested proof success')\n",
                )
                executable.chmod(0o755)

                with self.subTest(report=report), self.assertRaisesRegex(GuardError, reason):
                    run_guarded_tamarin([str(executable), "--parse-only", "fixture.spthy"], 30)

    def test_in_flight_final_record_is_awaited_within_the_shutdown_window(self):
        version = f'{{"event":"version","pid":1337,"source_id":"{source_identity()}"}}'
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / "tamarin-prover"
            executable.write_text(
                f"#!{sys.executable}\nimport os, subprocess, sys\n"
                "report = os.environ['CAIRN_MAUDE_GUARD_REPORT']\n"
                f"open(report, 'w').write({version!r})\n"
                "subprocess.Popen([sys.executable, '-c', 'import sys, time; time.sleep(0.5); "
                "open(sys.argv[1], \"a\").write(\"\\\\n\")', report], start_new_session=True, "
                "stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
                "print('attested proof success')\n",
            )
            executable.chmod(0o755)

            output = run_guarded_tamarin([str(executable), "--parse-only", "fixture.spthy"], 30)

        self.assertIn("attested proof success", output)

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
    def test_ac_unification_keeps_original_sorts_and_does_not_apply_rewrite_equations(self):
        queries = (
            ("x0:Fresh =? x0:TamNat", "No unifier."),
            ("tamtplus(x0:Fresh,tamXCtone) =? tamtplus(x0:TamNat,tamXCtone)", "No unifier."),
            ("x1:TamNat =? x0:TamNat", "Unifier 1"),
            ("tamXCflip(tamXCroleA) =? tamXCroleB", "No unifier."),
        )
        environment = dict(os.environ)
        environment.pop("CAIRN_MAUDE_BINARY", None)
        environment.pop("CAIRN_MAUDE_GUARD_REPORT", None)
        for query, expected in queries:
            with self.subTest(query=query):
                result = subprocess.run(
                    [str(select_proxy()[0]),
                     "-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"],
                    input=NATIVE_MODULE + f"unify in MSG : {query} .\n",
                    text=True, capture_output=True, env=environment, timeout=30,
                )

                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(result.stderr, "")
                self.assertIn(expected, result.stdout)

    def test_report_capacity_failure_rejects_the_stream_without_a_traceback(self):
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
                [sys.executable, "-c", driver, str(select_proxy()[0]),
                 "-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"],
                input=NATIVE_MODULE + "reduce tamXCroleA .\n" * 512,
                text=True, capture_output=True, env=environment, timeout=30,
            )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("native evidence report", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_many_native_operations_reconcile_complete_evidence_before_success(self):
        commands = NATIVE_MODULE + "reduce tamXCroleA .\n" * 512
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / "tamarin-prover"
            executable.write_text(
                f"#!{sys.executable}\nimport subprocess, sys\n"
                "proxy = next(arg.split('=', 1)[1] for arg in sys.argv if arg.startswith('--with-maude='))\n"
                "result = subprocess.run([proxy, '-interactive', '-no-tecla', "
                "'-no-banner', '-no-wrap', '-batch'], "
                f"input={commands!r}, text=True, capture_output=True, check=True, timeout=30)\n"
                "if result.stdout.count('result Msg: tamXCroleA') != 512:\n"
                "    raise SystemExit('missing native replies')\n"
                "print('all native replies retained')\n",
            )
            executable.chmod(0o755)

            output = run_guarded_tamarin([str(executable), "--fixture"], 30)

        self.assertEqual(output.strip(), "all native replies retained")

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
            [str(select_proxy()[0]),
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
    def test_natural_counter_derivation_checks_retain_the_real_native_kind_query(self):
        model = Path(__file__).parent / "equations/native-proxy/derivation.spthy"

        output = run_guarded_tamarin([
            "tamarin-prover", str(model), "--quit-on-warning",
            "--derivcheck-timeout=60", "--output-module=msr",
        ], 120)

        self.assertIn("rule (modulo E) Natural_Input:", output)

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
