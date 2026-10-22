"""Repeated-exchange adversarial controls at the public native stream."""

from pathlib import Path
import unittest

from test_maude_boundary import NATIVE_MODULE, native_stream


class CompiledValidationTests(unittest.TestCase):
    proxy: Path

    def test_changed_query_revalidates_reply_provenance_and_operation_kind(self):
        cases = (
            ("reduce p(0) .", "reduce p(1) .",
             "result Pub: p(0)\n", "new rigid atom"),
            ("reduce x0:Msg .", "reduce x1:Msg .",
             "result Msg: x0:Msg\n", "unbound original variable"),
            ("reduce p(0) .", "reduce f(0) .",
             "result Pub: p(0)\n", "incompatible result sort"),
            ("unify in MSG : p(0) =? p(0) .",
             "match in MSG : p(0) <=? p(0) .",
             "Unifier 1\nempty substitution\n", "solution header"),
        )
        for first, second, reply, reason in cases:
            with self.subTest(reason=reason):
                replies = (reply + "Maude> ", reply + "Maude> ")

                result = native_stream(
                    NATIVE_MODULE + first + "\n" + second + "\n",
                    replies, proxy=self.proxy,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertEqual(result.stdout.count(reply), 1)
                self.assertIn(reason, result.stderr)

    def test_solutions_that_do_not_solve_the_query_reject_the_whole_reply(self):
        cases = (
            ("unify in MSG : x0:Msg =? tamXCh(x1:Msg) .",
             "Unifier 1\nx0:Msg --> #1:Msg\nx1:Msg --> #2:Msg\n"),
            ("unify in MSG : x0:Msg =? x1:Msg .", "Unifier 1\nempty substitution\n"),
            ("unify in MSG : tamtplus(x0:TamNat,tamXCtone) =? tamtplus(t(0),t(1)) .",
             "Unifier 1\nx0:TamNat --> t(0)\n"),
            ("unify in MSG : x0:Msg =? x1:Msg /\\ x0:Msg =? p(0) .",
             "Unifier 1\nx0:Msg --> p(0)\nx1:Msg --> #1:Msg\n"),
            ("match in MSG : tamXCh(x0:Msg) <=? tamXCh(tamXCroleA) .",
             "Matcher 1\nx0:Msg --> tamXCroleB\n"),
            ("match in MSG : tamXCpair(x0:Msg,x0:Msg) <=? tamXCpair(tamXCroleA,tamXCroleB) .",
             "Matcher 1\nx0:Msg --> tamXCroleA\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command):
                result = native_stream(NATIVE_MODULE + command + "\n", reply + "Maude> ", proxy=self.proxy)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn(reply, result.stdout)
                self.assertIn("solution does not solve the query", result.stderr)

    def test_solutions_equal_modulo_ac_are_forwarded(self):
        cases = (
            ("unify in MSG : tamtplus(x0:TamNat,tamXCtone) =? tamtplus(tamXCtone,t(0)) .",
             "Unifier 1\nx0:TamNat --> t(0)\n"),
            ("unify in MSG : tamtplus(x0:TamNat,x1:TamNat) =? tamtplus(t(0),tamtplus(t(1),tamXCtone)) .",
             "Unifier 1\nx0:TamNat --> tamtplus(tamXCtone,t(0))\nx1:TamNat --> t(1)\n"),
            ("unify in MSG : tamXCpair(x0:Msg,x1:Msg) =? tamXCpair(x1:Msg,x0:Msg) .",
             "Unifier 1\nx0:Msg --> #1:Msg\nx1:Msg --> #1:Msg\n"),
            ("unify in MSG : tamtplus(t(0),t(1)) =? tamtplus(t(1),t(0)) .",
             "Unifier 1\nempty substitution\n"),
            ("match in MSG : tamXCh(tamtplus(x0:TamNat,t(1))) <=? tamXCh(tamtplus(t(1),t(0))) .",
             "Matcher 1\nx0:TamNat --> t(0)\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command):
                result = native_stream(NATIVE_MODULE + command + "\n", reply + "Maude> ", proxy=self.proxy)

                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(reply, result.stdout)

    def test_incomplete_syntactic_solution_families_reject_the_whole_reply(self):
        cases = (
            ("unify in MSG : x0:Msg =? p(0) .", "No unifier.\n"),
            ("unify in MSG : x0:Msg =? x1:Msg /\\ x1:Msg =? tamXCh(x2:Msg) .", "No unifier.\n"),
            ("unify in MSG : tamXCpair(x0:Msg,p(0)) =? tamXCpair(x1:Msg,p(0)) .",
             "Unifier 1\nx0:Msg --> p(0)\nx1:Msg --> p(0)\n"),
            ("unify in MSG : tamXCpair(x0:Msg,f(0)) =? tamXCpair(x1:Fresh,f(0)) .",
             "Unifier 1\nx0:Msg --> f(0)\nx1:Fresh --> f(0)\n"),
            ("unify in MSG : tamXCpair(x0:Msg,x1:Msg) =? tamXCpair(x2:Msg,x2:Msg) .",
             "Unifier 1\nx0:Msg --> tamXCh(#1:Msg)\nx1:Msg --> tamXCh(#1:Msg)\n"
             "x2:Msg --> tamXCh(#1:Msg)\n"),
            ("match in MSG : tamXCh(x0:Msg) <=? tamXCh(tamXCroleA) .", "No match.\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command):
                result = native_stream(NATIVE_MODULE + command + "\n", reply + "Maude> ", proxy=self.proxy)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn(reply, result.stdout)
                self.assertIn("solution family is incomplete", result.stderr)

    def test_complete_syntactic_solution_families_are_forwarded(self):
        cases = (
            ("unify in MSG : x0:Fresh =? p(0) .", "No unifier.\n"),
            ("unify in MSG : x0:Msg =? tamXCh(x0:Msg) .", "No unifier.\n"),
            ("unify in MSG : x0:Node =? x1:Msg .", "No unifier.\n"),
            ("unify in MSG : x0:Msg =? x1:Fresh .",
             "Unifier 1\nx0:Msg --> #1:Fresh\nx1:Fresh --> #1:Fresh\n"),
            ("unify in MSG : tamXCpair(x0:Msg,x1:Msg) =? tamXCpair(x2:Msg,x2:Msg) .",
             "Unifier 1\nx0:Msg --> #1:Msg\nx1:Msg --> #1:Msg\nx2:Msg --> #1:Msg\n"),
            ("unify in MSG : x0:Msg =? tamXCh(x1:Msg) /\\ x1:Msg =? p(0) .",
             "Unifier 1\nx0:Msg --> tamXCh(p(0))\nx1:Msg --> p(0)\n"),
            ("match in MSG : tamXCh(x0:Fresh) <=? tamXCh(x1:Msg) .", "No match.\n"),
            ("match in MSG : tamXCpair(x0:Msg,x0:Msg) <=? tamXCpair(tamXCroleA,tamXCroleB) .",
             "No match.\n"),
            ("unify in MSG : tamtplus(x0:TamNat,tamXCtone) =? tamtplus(t(0),t(1)) .", "No unifier.\n"),
            ("unify in MSG : tamtplus(x0:Fresh,tamXCtone) =? tamtplus(x1:TamNat,x2:TamNat) .",
             "No unifier.\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command):
                result = native_stream(NATIVE_MODULE + command + "\n", reply + "Maude> ", proxy=self.proxy)

                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(reply, result.stdout)

    def test_incomplete_sum_solution_families_reject_the_whole_reply(self):
        cases = (
            ("match in MSG : list(cons(tamtplus(t(0),tamXCtone,tamXCtone),nil)) <=? "
             "list(cons(tamtplus(t(0),tamXCtone,tamXCtone),nil)) .", "No match.\n"),
            ("match in MSG : tamXCpair(x0:Msg,tamtplus(t(0),tamXCtone)) <=? "
             "tamXCpair(p(0),tamtplus(tamXCtone,t(0))) .", "No match.\n"),
            ("match in MSG : tamtplus(x0:TamNat,tamXCtone) <=? tamtplus(tamXCtone,tamXCtone,t(1)) .",
             "No match.\n"),
            ("unify in MSG : tamtplus(x0:Fresh,tamXCtone) =? tamtplus(x0:Fresh,tamXCtone) .",
             "No unifier.\n"),
            ("unify in MSG : tamtplus(tamXCtone,tamXCtone) =? tamtplus(x0:TamNat,tamXCtone) .",
             "No unifier.\n"),
            ("unify in MSG : tamtplus(t(0),t(1)) =? tamtplus(t(1),t(0)) .", "No unifier.\n"),
            ("unify in MSG : tamtplus(x0:TamNat,tamXCtone,tamXCtone) =? tamtplus(x1:TamNat,tamXCtone) .",
             "Unifier 1\nx0:TamNat --> tamXCtone\nx1:TamNat --> tamtplus(tamXCtone, tamXCtone)\n"),
            ("unify in MSG : tamtplus(tamXCtone,tamXCtone) =? tamtplus(tamXCtone,tamXCtone) /\\ "
             "tamtplus(x0:TamNat,tamXCtone) =? tamtplus(x1:TamNat,tamXCtone) .", "No unifier.\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command):
                result = native_stream(NATIVE_MODULE + command + "\n", reply + "Maude> ", proxy=self.proxy)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn(reply, result.stdout)
                self.assertIn("solution family is incomplete", result.stderr)

    def test_real_sum_replies_are_forwarded(self):
        cases = (
            ("match in MSG : list(cons(tamtplus(t(0),tamXCtone,tamXCtone),nil)) <=? "
             "list(cons(tamtplus(t(0),tamXCtone,tamXCtone),nil)) .", "Matcher 1\nempty substitution\n"),
            ("match in MSG : list(cons(tamtplus(t(0),tamXCtone,tamXCtone,tamXCtone),nil)) <=? "
             "list(cons(tamtplus(t(0),tamXCtone,tamXCtone),nil)) .", "No match.\n"),
            ("match in MSG : tamXCpair(x0:Msg,tamtplus(t(0),tamXCtone)) <=? "
             "tamXCpair(p(0),tamtplus(tamXCtone,t(0))) .", "Matcher 1\nx0:Msg --> p(0)\n"),
            ("match in MSG : tamtplus(x0:TamNat,tamXCtone) <=? tamtplus(tamXCtone,tamXCtone,t(1)) .",
             "Matcher 1\nx0:TamNat --> tamtplus(tamXCtone, t(1))\n"),
            ("unify in MSG : tamtplus(x0:Fresh,tamXCtone) =? tamtplus(x0:Fresh,tamXCtone) .",
             "Unifier 1\nx0:Fresh --> #1:Fresh\n"),
            ("unify in MSG : tamtplus(tamXCtone,tamXCtone) =? tamtplus(x0:TamNat,tamXCtone) .",
             "Unifier 1\nx0:TamNat --> tamXCtone\n"),
            ("unify in MSG : tamtplus(tamXCtone,tamXCtone) =? tamXCtone .", "No unifier.\n"),
            ("unify in MSG : tamtplus(tamXCtone,tamXCtone) =? "
             "tamtplus(tamXCtone,tamXCtone,tamXCtone) .", "No unifier.\n"),
            ("unify in MSG : tamtplus(x0:TamNat,tamXCtone) =? tamtplus(x1:TamNat,tamXCtone) .",
             "Unifier 1\nx0:TamNat --> #1:TamNat\nx1:TamNat --> #1:TamNat\n"),
            ("unify in MSG : tamtplus(x0:TamNat,tamXCtone,tamXCtone) =? tamtplus(x1:TamNat,tamXCtone) .",
             "Unifier 1\nx0:TamNat --> #1:TamNat\nx1:TamNat --> tamtplus(tamXCtone, #1:TamNat)\n"),
            ("unify in MSG : tamtplus(x0:TamNat,tamXCtone,tamXCtone,tamXCtone) =? "
             "tamtplus(tamXCtone,tamXCtone) .", "No unifier.\n"),
            ("unify in MSG : tamtplus(x0:Fresh,tamXCtone) =? tamtplus(x1:TamNat,x2:TamNat) .",
             "No unifier.\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command):
                result = native_stream(NATIVE_MODULE + command + "\n", reply + "Maude> ", proxy=self.proxy)

                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(reply, result.stdout)

    def test_reductions_other_than_the_normal_form_reject_the_reply(self):
        cases = (
            ("reduce tamXCroleA .", "result Msg: tamXCroleB\n"),
            ("reduce tamXCflip(tamXCroleA) .", "result Msg: tamXCroleA\n"),
            ("reduce tamXCflip(tamXCroleA) .", "result Msg: tamXCflip(tamXCroleA)\n"),
            ("reduce tamXCfst(tamXCpair(p(0),p(1))) .", "result Pub: p(1)\n"),
            ("reduce tamXCsdec(tamXCsenc(p(0),tamtplus(t(0),tamXCtone)),tamtplus(tamXCtone,t(0))) .",
             "result Msg: tamXCsdec(tamXCsenc(p(0), tamtplus(tamXCtone, t(0))), tamtplus(tamXCtone, t(0)))\n"),
            ("reduce tamXCsdec(tamXCsenc(p(0),p(1)),p(2)) .", "result Pub: p(0)\n"),
            ("reduce tamXCkdec(tamXCkem(x0:Msg,tamXCpk(x1:Fresh)),x1:Fresh) .",
             "result Msg: tamXCkdec(tamXCkem(x0:Msg, tamXCpk(x1:Fresh)), x1:Fresh)\n"),
            ("reduce tamXCh(tamXCfst(tamXCpair(tamXCflip(tamXCroleB),tamXCsnd(x0:Msg)))) .",
             "result Msg: tamXCh(tamXCflip(tamXCroleB))\n"),
            ("reduce tamtplus(t(1),tamXCtone,t(0)) .", "result TamNat: tamtplus(tamXCtone, t(0))\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command, reply=reply):
                result = native_stream(NATIVE_MODULE + command + "\n", reply + "Maude> ", proxy=self.proxy)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn(reply, result.stdout)
                self.assertIn("result is not the normal form", result.stderr)

    def test_real_normal_form_reductions_are_forwarded(self):
        cases = (
            ("reduce tamXCflip(tamXCroleA) .", "result Msg: tamXCroleB\n"),
            ("reduce tamXCfst(tamXCpair(p(0),p(1))) .", "result Pub: p(0)\n"),
            ("reduce tamXCsnd(tamXCpair(p(0),tamXCh(f(1)))) .", "result Msg: tamXCh(f(1))\n"),
            ("reduce tamXCsdec(tamXCsenc(p(0),tamtplus(t(0),tamXCtone)),tamtplus(tamXCtone,t(0))) .",
             "result Pub: p(0)\n"),
            ("reduce tamXCsdec(tamXCsenc(p(0),p(1)),p(2)) .",
             "result Msg: tamXCsdec(tamXCsenc(p(0), p(1)), p(2))\n"),
            ("reduce tamXCkdec(tamXCkem(x0:Msg,tamXCpk(x1:Fresh)),x1:Fresh) .", "result Msg: x0:Msg\n"),
            ("reduce tamXCkdec(x0:Msg,x1:Fresh) .", "result Msg: tamXCkdec(x0:Msg, x1:Fresh)\n"),
            ("reduce tamXCflip(x0:Msg) .", "result Msg: tamXCflip(x0:Msg)\n"),
            ("reduce tamtplus(t(1),tamXCtone,t(0)) .", "result TamNat: tamtplus(tamXCtone, t(0), t(1))\n"),
            ("reduce tamXCh(tamXCfst(tamXCpair(tamXCflip(tamXCroleB),tamXCsnd(x0:Msg)))) .",
             "result Msg: tamXCh(tamXCroleA)\n"),
            ("reduce tamXCpair(x0:Msg,tamXCpair(tamXCh(x1:Msg),tamXCh(x2:Msg))) .",
             "result Msg: tamXCpair(x0:Msg, tamXCpair(tamXCh(x1:Msg), tamXCh(x2:Msg)))\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command):
                result = native_stream(NATIVE_MODULE + command + "\n", reply + "Maude> ", proxy=self.proxy)

                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(reply, result.stdout)

    def test_variant_families_missing_a_variant_reject_the_reply(self):
        flip = "get variants in MSG : list(cons(tamXCflip(x0:Msg),nil)) .\n"
        stay = "Variant 1\nrewrites: 0\nTOP: list(cons(tamXCflip(#1:Msg), nil))\nx0:Msg --> #1:Msg\n\n"
        role_b = "Variant 2\nrewrites: 2\nTOP: list(cons(tamXCroleB, nil))\nx0:Msg --> tamXCroleA\n\n"
        role_a = "Variant 2\nrewrites: 2\nTOP: list(cons(tamXCroleA, nil))\nx0:Msg --> tamXCroleB\n\n"
        fst = "get variants in MSG : list(cons(tamXCfst(x0:Msg),nil)) .\n"
        fst_stay = "Variant 1\nrewrites: 0\nTOP: list(cons(tamXCfst(#1:Msg), nil))\nx0:Msg --> #1:Msg\n\n"
        cases = (
            (flip, stay + role_b),
            (flip, stay + role_a),
            (flip, role_b.replace("Variant 2", "Variant 1") + role_a),
            (fst, fst_stay),
            ("get variants in MSG : list(cons(x2:Fresh,cons(tamXCkdec(x3:Msg,x2:Fresh),nil))) .\n",
             "Variant 1\nrewrites: 0\nTOP: list(cons(#1:Fresh, cons(tamXCkdec(#2:Msg, #1:Fresh), nil)))\n"
             "x2:Fresh --> #1:Fresh\nx3:Msg --> #2:Msg\n\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command, reply=reply):
                result = native_stream(
                    NATIVE_MODULE + command, reply + "No more variants.\nrewrites: 2\nMaude> ", proxy=self.proxy
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn(reply, result.stdout)
                self.assertIn("variant family is incomplete", result.stderr)

    def test_variant_families_with_an_undecided_scheme_make_no_completeness_claim(self):
        command = (
            "get variants in MSG : list(cons(tamXCsdec(tamXCsenc(x2:Msg,tamtplus(x0:TamNat,x1:TamNat)),"
            "tamtplus(x3:TamNat,x4:TamNat)),nil)) .\n"
        )
        reply = (
            "Variant 1\nrewrites: 7\nTOP: list(cons(%1:Msg, nil))\nx2:Msg --> %1:Msg\n"
            "x0:TamNat --> %2:TamNat\nx1:TamNat --> %3:TamNat\nx3:TamNat --> %2:TamNat\n"
            "x4:TamNat --> %3:TamNat\n\nNo more variants.\nrewrites: 7\n"
        )

        result = native_stream(NATIVE_MODULE + command, reply + "Maude> ", proxy=self.proxy)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(reply, result.stdout)

    def test_variants_other_than_the_normal_form_of_their_instance_reject_the_reply(self):
        cases = (
            ("get variants in MSG : list(cons(tamXCflip(x0:Msg),nil)) .\n",
             "Variant 1\nrewrites: 0\nTOP: list(cons(tamXCflip(#1:Msg), nil))\nx0:Msg --> #1:Msg\n\n"
             "Variant 2\nrewrites: 2\nTOP: list(cons(tamXCroleA, nil))\nx0:Msg --> tamXCroleA\n\n"
             "Variant 3\nrewrites: 2\nTOP: list(cons(tamXCroleA, nil))\nx0:Msg --> tamXCroleB\n\n"),
            ("get variants in MSG : list(cons(tamXCfst(x0:Msg),nil)) .\n",
             "Variant 1\nrewrites: 0\nTOP: list(cons(tamXCfst(#1:Msg), nil))\nx0:Msg --> #1:Msg\n\n"
             "Variant 2\nrewrites: 1\nTOP: list(cons(%2:Msg, nil))\nx0:Msg --> tamXCpair(%1:Msg, %2:Msg)\n\n"),
            ("get variants in MSG : list(cons(tamXCh(x0:Msg),nil)) .\n",
             "Variant 1\nrewrites: 0\nTOP: list(cons(tamXCh(#2:Msg), nil))\nx0:Msg --> #1:Msg\n\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command, reply=reply):
                result = native_stream(
                    NATIVE_MODULE + command, reply + "No more variants.\nrewrites: 2\nMaude> ", proxy=self.proxy
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn(reply, result.stdout)
                self.assertIn("variant is not the normal form of its instance", result.stderr)

    def test_real_variant_families_are_forwarded(self):
        cases = (
            ("get variants in MSG : list(cons(tamXCflip(x0:Msg),nil)) .\n",
             "Variant 1\nrewrites: 0\nTOP: list(cons(tamXCflip(#1:Msg), nil))\nx0:Msg --> #1:Msg\n\n"
             "Variant 2\nrewrites: 2\nTOP: list(cons(tamXCroleB, nil))\nx0:Msg --> tamXCroleA\n\n"
             "Variant 3\nrewrites: 2\nTOP: list(cons(tamXCroleA, nil))\nx0:Msg --> tamXCroleB\n\n"),
            ("get variants in MSG : list(cons(tamXCfst(x0:Msg),nil)) .\n",
             "Variant 1\nrewrites: 0\nTOP: list(cons(tamXCfst(#1:Msg), nil))\nx0:Msg --> #1:Msg\n\n"
             "Variant 2\nrewrites: 1\nTOP: list(cons(%1:Msg, nil))\nx0:Msg --> tamXCpair(%1:Msg, %2:Msg)\n\n"),
            ("get variants in MSG : list(cons(x2:Fresh,cons(tamXCkdec(x3:Msg,x2:Fresh),nil))) .\n",
             "Variant 1\nrewrites: 0\nTOP: list(cons(#1:Fresh, cons(tamXCkdec(#2:Msg, #1:Fresh), nil)))\n"
             "x2:Fresh --> #1:Fresh\nx3:Msg --> #2:Msg\n\n"
             "Variant 2\nrewrites: 1\nTOP: list(cons(%2:Fresh, cons(%1:Msg, nil)))\n"
             "x2:Fresh --> %2:Fresh\nx3:Msg --> tamXCkem(%1:Msg, tamXCpk(%2:Fresh))\n\n"),
            ("get variants in MSG : list(cons(tamXCh(x0:Msg),nil)) .\n",
             "Variant 1\nrewrites: 0\nTOP: list(cons(tamXCh(#1:Msg), nil))\nx0:Msg --> #1:Msg\n\n"),
            ("get variants in MSG : list(cons(x0:Fresh,cons(tamXCflip(tamXCroleA),nil))) .\n",
             "Variant 1\nrewrites: 1\nTOP: list(cons(#1:Fresh, cons(tamXCroleB, nil)))\nx0:Fresh --> #1:Fresh\n\n"),
        )
        for command, reply in cases:
            with self.subTest(command=command):
                reply += "No more variants.\nrewrites: 2\n"
                result = native_stream(NATIVE_MODULE + command, reply + "Maude> ", proxy=self.proxy)

                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(reply, result.stdout)

    def test_repeated_query_revalidates_the_complete_changed_reply(self):
        valid = "result Msg: tamXCroleA\n"
        changed = (
            "result Msg: tamXCroleA\nunexpected suffix\n",
            "result Msg: #1:Msg\n",
            "result Msg: tamXCunknown\n",
            "result Msg: p(0)\n",
            "result Msg: tamXCroleA\u00a0\n",
        )
        for rejected in changed:
            with self.subTest(reply=rejected):
                replies = (valid + "Maude> ", rejected + "Maude> ")

                result = native_stream(
                    NATIVE_MODULE + "reduce tamXCroleA .\n" * 2,
                    replies, proxy=self.proxy,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertEqual(result.stdout.count(valid), 1)
                self.assertNotIn(rejected, result.stdout)

    def test_repeated_unification_revalidates_all_changed_bindings(self):
        valid = "Unifier 1\nx0:Pub --> p(0)\n"
        changed = (
            "Unifier 1\nx0:Pub --> p(1)\n",
            "Unifier 1\nx0:Pub --> p(0)\nx0:Pub --> p(0)\n",
            "Unifier 1\nx0:Pub --> tamXCroleA\n",
            "Unifier 1\nx1:Pub --> p(0)\n",
        )
        for rejected in changed:
            with self.subTest(reply=rejected):
                replies = (valid + "Maude> ", rejected + "Maude> ")

                result = native_stream(
                    NATIVE_MODULE + "unify in MSG : x0:Pub =? p(0) .\n" * 2,
                    replies, proxy=self.proxy,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertEqual(result.stdout.count(valid), 1)
                self.assertNotIn(rejected, result.stdout)

    def test_later_truncated_reply_cannot_reuse_a_complete_reply(self):
        valid = "result Msg: tamXCroleA\n"
        replies = (valid + "Maude> ", valid)

        result = native_stream(
            NATIVE_MODULE + "reduce tamXCroleA .\n" * 2,
            replies, proxy=self.proxy,
        )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count(valid), 1)
        self.assertIn("premature EOF", result.stderr)

    def test_repeated_query_accepts_different_valid_generated_names(self):
        replies = tuple(
            f"Unifier 1\nx0:Msg --> #{index}:Msg\nx1:Msg --> #{index}:Msg\n"
            for index in (1, 2)
        )

        result = native_stream(
            NATIVE_MODULE + "unify in MSG : x0:Msg =? x1:Msg .\n" * 2,
            tuple(reply + "Maude> " for reply in replies), proxy=self.proxy,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, "")
        for reply in replies:
            self.assertEqual(result.stdout.count(reply), 1)

    def test_replaced_query_cannot_certify_the_previous_querys_reply(self):
        first = "result Pub: p(0)\n"
        second = "result Pub: p(1)\n"
        commands = "reduce p(0) .\nreduce p(1) .\nreduce p(0) .\n"
        replies = (first + "Maude> ", second + "Maude> ", second + "Maude> ")

        result = native_stream(NATIVE_MODULE + commands, replies, proxy=self.proxy)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count(first), 1)
        self.assertEqual(result.stdout.count(second), 1)
        self.assertIn("new rigid atom", result.stderr)

    def test_large_queries_and_replies_keep_the_original_grammar(self):
        term = "tamXCh(" * 2400 + "tamXCroleA" + ")" * 2400
        command = "reduce tamXCroleA ."
        cases = [
            (f"reduce {term} .\n", f"result Msg: {term}\n"),
            (f"reduce tamXCfst(tamXCpair({term},tamXCroleA)) .\n", f"result Msg: {term}\n"),
            *(
                ("reduce " + " " * (size - len(command)) + "tamXCroleA .\n",
                 "result Msg: tamXCroleA\n")
                for size in (16_383, 16_384, 16_385)
            ),
        ]
        for command, reply in cases:
            with self.subTest(query_bytes=len(command) - 1, reply_bytes=len(reply)):
                replies = (reply + "Maude> ", reply + "Maude> ")

                result = native_stream(
                    NATIVE_MODULE + command * 2, replies, proxy=self.proxy,
                )

                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.stdout.count(reply), 2)

    def test_later_invalid_query_is_not_accepted_as_a_repeated_prefix(self):
        valid = "result Msg: tamXCroleA\n"
        for command in ("reduce tamXCunknown .", "reduce #1:Msg .",
                        "reduce tamXCroleA . trailing"):
            with self.subTest(command=command):
                replies = (valid + "Maude> ", valid + "Maude> ")

                result = native_stream(
                    NATIVE_MODULE + "reduce tamXCroleA .\n" + command + "\n",
                    replies, proxy=self.proxy,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertEqual(result.stdout.count(valid), 1)
                self.assertNotIn("panicked", result.stderr)
