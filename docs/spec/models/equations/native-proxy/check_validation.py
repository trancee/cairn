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
            ("unify in MSG : x0:Msg =? x1:Msg .",
             "match in MSG : x0:Msg <=? x1:Msg .",
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
            (command + "\n", f"result Msg: {term}\n"),
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
