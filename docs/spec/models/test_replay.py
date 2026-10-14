import unittest
import sys
from unittest.mock import patch
import io
import replay
from pathlib import Path

from replay import ReplayError, check_result, compare_replay, main, run, select_certificate


EXPORT = """
theory Example
begin
builtins: natural-numbers
functions: roleA/0, roleB/0, flip/1
equations: flip(roleA)=roleB, flip(roleB)=roleA
restriction unique:
  "All x #i #j. Done(x)@i & Done(x)@j ==> #i=#j"
rule (modulo E) Pair:
  [ Fr(~x) ] --[ Done(~x) ]-> [ Out(~x) ]
lemma unrelated [reuse]:
  all-traces "All x #i. Done(x)@i ==> Ex #j. Done(x)@j"
by sorry
lemma witness []:
  exists-trace "Ex x #i. Done(x)@i"
simplify
SOLVED
lemma origin [sources]:
  all-traces "All x #i. Done(x)@i ==> Ex #j. Done(x)@j"
by contradiction
end
""".lstrip()


class ProfileTests(unittest.TestCase):
    def test_partial_sources_stop_before_certificate_replay(self):
        export = EXPORT.replace("witness", "executable")

        def native(command, timeout):
            if "--version" in command:
                return "tamarin-prover 1.12.0,\nMaude version 3.5.1\n"
            if "--precompute-only" in command:
                return "Refined sources: 43 cases, 16 partial deconstructions left\n"
            destination = next(arg[9:] for arg in command if arg.startswith("--output="))
            text = export if Path(destination).name == "assembled.spthy" else select_certificate(
                export, "executable",
            )[0]
            Path(destination).write_text(text)
            return ""

        with patch.object(
            sys, "argv", ["replay.py", "--disclosure-sources", "--target", "executable"],
        ), patch("replay.run", side_effect=native) as execute, patch(
            "sys.stderr", new_callable=io.StringIO,
        ) as diagnostics:
            result = main()

        self.assertEqual(result, 1)
        self.assertIn("source deconstructions", diagnostics.getvalue())
        self.assertEqual(execute.call_count, 4)
        self.assertIn("--precompute-only", execute.call_args.args[0])

    def test_exists_trace_witness_targets_are_accepted(self):
        version = "tamarin-prover 1.12.0,\nMaude version 3.5.1\n"
        targets = (
            "executable", "initiator_candidate_recovery",
            "fresh_epoch_after_compromise",
        )
        for target in targets:
            with self.subTest(target=target), patch.object(
                sys, "argv",
                ["replay.py", "--disclosure-sources", "--target", target],
            ), patch(
                "replay.run", side_effect=[version, ReplayError("export probe")]
            ) as execute, patch("sys.stderr", new_callable=io.StringIO) as diagnostics:
                result = main()

            self.assertEqual(result, 1)
            self.assertIn("export probe", diagnostics.getvalue())
            self.assertIn("--defines=DISCLOSURE_SOURCES", execute.call_args_list[1].args[0])

    def test_joint_ct_origin_target_is_accepted(self):
        version = "tamarin-prover 1.12.0,\nMaude version 3.5.1\n"
        with patch.object(
            sys, "argv",
            ["replay.py", "--disclosure-sources", "--target", "kem_and_ct_tail_origin"],
        ), patch(
            "replay.run", side_effect=[version, ReplayError("export probe")]
        ) as execute, patch("sys.stderr", new_callable=io.StringIO) as diagnostics:
            result = main()

        self.assertEqual(result, 1)
        self.assertIn("export probe", diagnostics.getvalue())
        self.assertIn("--defines=DISCLOSURE_SOURCES", execute.call_args_list[1].args[0])

    def test_ct_tail_origin_target_is_accepted(self):
        version = "tamarin-prover 1.12.0,\nMaude version 3.5.1\n"
        with patch.object(
            sys, "argv",
            ["replay.py", "--disclosure-sources", "--target", "encrypted_ct_tail_encapsulated"],
        ), patch(
            "replay.run", side_effect=[version, ReplayError("export probe")]
        ) as execute, patch("sys.stderr", new_callable=io.StringIO) as diagnostics:
            result = main()

        self.assertEqual(result, 1)
        self.assertIn("export probe", diagnostics.getvalue())
        self.assertIn("--defines=DISCLOSURE_SOURCES", execute.call_args_list[1].args[0])

    def test_disclosure_profile_is_forwarded_to_native_source_export(self):
        version = "tamarin-prover 1.12.0,\nMaude version 3.5.1\n"
        with patch.object(sys, "argv", ["replay.py", "--disclosure-sources"]), patch(
            "replay.run", side_effect=[version, ReplayError("export probe")]
        ) as execute, patch("sys.stderr", new_callable=io.StringIO) as diagnostics:
            result = main()

        self.assertEqual(result, 1)
        self.assertIn("export probe", diagnostics.getvalue())
        self.assertIn("--defines=DISCLOSURE_SOURCES", execute.call_args_list[1].args[0])

    def test_default_export_has_no_profile_definition(self):
        version = "tamarin-prover 1.12.0,\nMaude version 3.5.1\n"
        with patch.object(sys, "argv", ["replay.py"]), patch(
            "replay.run", side_effect=[version, ReplayError("export probe")]
        ) as execute, patch("sys.stderr", new_callable=io.StringIO) as diagnostics:
            result = main()

        self.assertEqual(result, 1)
        self.assertIn("export probe", diagnostics.getvalue())
        self.assertFalse(any(arg.startswith("--defines") for arg in execute.call_args_list[1].args[0]))


class SelectionTests(unittest.TestCase):
    def test_complete_safety_suite_retains_every_safety_certificate(self):
        export = EXPORT.replace("by sorry", "by contradiction")

        selected, retained = select_certificate(export, "complete_safety", "all-traces")

        self.assertEqual(retained, ("unrelated", "origin"))
        self.assertNotIn("lemma witness", selected)

    def test_complete_safety_suite_rejects_unexpected_incomplete_claim(self):
        with self.assertRaisesRegex(ReplayError, "unrelated: incomplete safety certificate"):
            select_certificate(EXPORT, "complete_safety", "all-traces")

    def test_complete_safety_suite_excludes_only_named_compositional_claims(self):
        export = EXPORT.replace("lemma unrelated", "lemma lock_stage_order")

        selected, retained = select_certificate(export, "complete_safety", "all-traces")

        self.assertEqual(retained, ("origin",))
        self.assertNotIn("lemma lock_stage_order", selected)

    def test_complete_safety_suite_roundtrip_preserves_all_certificates(self):
        export = EXPORT.replace("by sorry", "by contradiction")
        selected, retained = select_certificate(export, "complete_safety", "all-traces")

        self.assertEqual(
            compare_replay(export, selected, "complete_safety", "all-traces"), retained,
        )

    def test_complete_safety_suite_rejects_empty_safety_inventory(self):
        export = EXPORT.replace("all-traces", "exists-trace")

        with self.assertRaisesRegex(ReplayError, "missing safety certificates"):
            select_certificate(export, "complete_safety", "all-traces")

    def test_safety_certificate_selection_requires_explicit_trace_kind(self):
        selected, retained = select_certificate(EXPORT, "origin", trace_kind="all-traces")

        self.assertEqual(retained, ("origin",))
        self.assertIn("lemma origin [sources]", selected)

    def test_safety_selection_rejects_an_existential_target(self):
        with self.assertRaisesRegex(ReplayError, "all-traces"):
            select_certificate(EXPORT, "witness", trace_kind="all-traces")

    def test_safety_roundtrip_preserves_formula_and_certificate(self):
        selected, retained = select_certificate(EXPORT, "origin", trace_kind="all-traces")

        self.assertEqual(
            compare_replay(EXPORT, selected, "origin", trace_kind="all-traces"), retained,
        )

    def test_declared_dependency_is_retained_before_the_target(self):
        proved = EXPORT.replace("by sorry", "by contradiction")
        selected, retained = select_certificate(proved, "witness", uses=("unrelated",))

        self.assertEqual(retained, ("unrelated", "witness", "origin"))
        self.assertIn("lemma unrelated [reuse]", selected)

    def test_missing_dependency_is_rejected(self):
        with self.assertRaisesRegex(ReplayError, "missing dependency"):
            select_certificate(EXPORT, "witness", uses=("absent",))

    def test_dependency_after_target_is_rejected(self):
        with self.assertRaisesRegex(ReplayError, "dependency follows target"):
            select_certificate(EXPORT, "unrelated", "all-traces", uses=("origin",))

    def test_incomplete_dependency_is_rejected(self):
        with self.assertRaisesRegex(ReplayError, "unrelated: incomplete certificate"):
            select_certificate(EXPORT, "witness", uses=("unrelated",))

    def test_dependency_roundtrip_preserves_retained_lemmas(self):
        proved = EXPORT.replace("by sorry", "by contradiction")
        selected, retained = select_certificate(proved, "witness", uses=("unrelated",))

        self.assertEqual(compare_replay(proved, selected, "witness", uses=("unrelated",)), retained)

    def test_only_target_and_source_lemmas_are_retained(self):
        selected, retained = select_certificate(EXPORT, "witness")

        self.assertEqual(retained, ("witness", "origin"))
        self.assertNotIn("lemma unrelated", selected)
        self.assertIn("lemma origin [sources]", selected)

    def test_all_non_lemma_declarations_are_byte_preserved(self):
        selected, _ = select_certificate(EXPORT, "witness")

        self.assertEqual(selected.split("lemma ")[0], EXPORT.split("lemma ")[0])

    def test_target_formula_and_certificate_are_preserved(self):
        selected, _ = select_certificate(EXPORT, "witness")
        target = EXPORT[EXPORT.index("lemma witness"):EXPORT.index("lemma origin")]

        self.assertIn(target, selected)

    def test_missing_target_is_rejected(self):
        with self.assertRaisesRegex(ReplayError, "missing target"):
            select_certificate(EXPORT, "missing")

    def test_duplicate_lemma_is_rejected(self):
        mutated = EXPORT.replace("lemma unrelated", "lemma witness")

        with self.assertRaisesRegex(ReplayError, "duplicate lemma"):
            select_certificate(mutated, "witness")

    def test_safety_target_is_rejected(self):
        with self.assertRaisesRegex(ReplayError, "exists-trace"):
            select_certificate(EXPORT, "origin")

    def test_incomplete_target_certificate_is_rejected(self):
        mutated = EXPORT.replace("SOLVED", "by sorry")

        with self.assertRaisesRegex(ReplayError, "incomplete certificate"):
            select_certificate(mutated, "witness")

    def test_incomplete_source_certificate_is_rejected(self):
        mutated = EXPORT.replace("by contradiction", "by sorry")

        with self.assertRaisesRegex(ReplayError, "incomplete certificate"):
            select_certificate(mutated, "witness")

    def test_comment_cannot_create_a_declaration(self):
        mutated = EXPORT.replace("begin", "begin\n/*\nlemma witness []:\nend\n*/", 1)

        selected, retained = select_certificate(mutated, "witness")

        self.assertEqual(retained, ("witness", "origin"))
        self.assertIn("/*\nlemma witness []:\nend\n*/", selected)

    def test_multiline_formula_cannot_create_a_declaration(self):
        mutated = EXPORT.replace("Ex x #i. Done(x)@i", "Ex x #i.\nlemma pretend\nDone(x)@i")

        _, retained = select_certificate(mutated, "witness")

        self.assertEqual(retained, ("witness", "origin"))

    def test_unterminated_comment_is_rejected(self):
        with self.assertRaisesRegex(ReplayError, "unterminated comment"):
            select_certificate(EXPORT + "/*", "witness")

    def test_unterminated_formula_is_rejected(self):
        with self.assertRaisesRegex(ReplayError, "unterminated quoted"):
            select_certificate(EXPORT + '"', "witness")

    def test_malformed_header_is_rejected(self):
        mutated = EXPORT.replace("theory Example", "Example")

        with self.assertRaisesRegex(ReplayError, "canonical theory header"):
            select_certificate(mutated, "witness")

    def test_missing_end_is_rejected(self):
        with self.assertRaisesRegex(ReplayError, "lemma layout"):
            select_certificate(EXPORT.removesuffix("end\n"), "witness")

    def test_suffix_is_rejected(self):
        with self.assertRaisesRegex(ReplayError, "theory suffix"):
            select_certificate(EXPORT + "extra", "witness")

    def test_interspersed_rule_is_rejected(self):
        mutated = EXPORT.replace("lemma origin", "rule Additional: [ ] --[ ]-> [ ]\nlemma origin")

        with self.assertRaisesRegex(ReplayError, "non-lemma declaration"):
            select_certificate(mutated, "witness")


class CorrespondenceTests(unittest.TestCase):
    def setUp(self):
        self.selected, self.retained = select_certificate(EXPORT, "witness")

    def test_exact_selection_is_accepted(self):
        retained = compare_replay(EXPORT, self.selected, "witness")

        self.assertEqual(retained, self.retained)

    def test_missing_rule_is_rejected(self):
        mutated = self.selected.replace("rule (modulo E) Pair:", "rule (modulo E) Different:")

        with self.assertRaisesRegex(ReplayError, "transition-system"):
            compare_replay(EXPORT, mutated, "witness")

    def test_changed_restriction_is_rejected(self):
        mutated = self.selected.replace("#i=#j", "#i<#j")

        with self.assertRaisesRegex(ReplayError, "restriction mismatch"):
            compare_replay(EXPORT, mutated, "witness")

    def test_changed_equation_is_rejected(self):
        mutated = self.selected.replace("flip(roleA)=roleB", "flip(roleA)=roleA")

        with self.assertRaisesRegex(ReplayError, "signature"):
            compare_replay(EXPORT, mutated, "witness")

    def test_changed_target_formula_is_rejected(self):
        mutated = self.selected.replace("Ex x #i. Done(x)@i", "Ex x #i. Done(x)@i & #i=#i")

        with self.assertRaisesRegex(ReplayError, "formula/attributes/certificate"):
            compare_replay(EXPORT, mutated, "witness")

    def test_changed_attributes_are_rejected(self):
        mutated = self.selected.replace("lemma witness []:", "lemma witness [reuse]:")

        with self.assertRaisesRegex(ReplayError, "formula/attributes/certificate"):
            compare_replay(EXPORT, mutated, "witness")

    def test_changed_proof_is_rejected(self):
        mutated = self.selected.replace("SOLVED", "by sorry")

        with self.assertRaisesRegex(ReplayError, "formula/attributes/certificate"):
            compare_replay(EXPORT, mutated, "witness")

    def test_removed_source_lemma_is_rejected(self):
        mutated = self.selected[:self.selected.index("lemma origin")] + "end\n"

        with self.assertRaisesRegex(ReplayError, "lemma inventory"):
            compare_replay(EXPORT, mutated, "witness")

    def test_extra_lemma_is_rejected(self):
        with self.assertRaisesRegex(ReplayError, "lemma inventory"):
            compare_replay(EXPORT, EXPORT, "witness")


class ResultTests(unittest.TestCase):
    def test_complete_refined_sources_are_accepted(self):
        output = "Refined sources: 43 cases, deconstructions complete\n"

        replay.check_source_completion(output)

    def test_partial_refined_sources_are_rejected(self):
        output = "Refined sources: 43 cases, 16 partial deconstructions left\n"

        with self.assertRaisesRegex(ReplayError, "source deconstructions"):
            replay.check_source_completion(output)

    def test_missing_malformed_or_duplicate_source_results_are_rejected(self):
        complete = "Refined sources: 43 cases, deconstructions complete\n"
        for output in ("", "Refined sources: 0 cases, deconstructions complete\n", complete * 2):
            with self.subTest(output=output):
                with self.assertRaisesRegex(ReplayError, "source deconstructions"):
                    replay.check_source_completion(output)

    def test_each_verified_result_is_required(self):
        output = (
            "witness (exists-trace): verified (826 steps)\n"
            "origin (all-traces): verified (9 steps)\n"
        )

        check_result(output, ("witness", "origin"))

    def test_missing_source_result_is_rejected(self):
        output = "witness (exists-trace): verified (826 steps)\n"

        with self.assertRaisesRegex(ReplayError, "origin: missing verified"):
            check_result(output, ("witness", "origin"))

    def test_incomplete_witness_is_rejected(self):
        output = "witness (exists-trace): analysis incomplete (1 steps)\n"

        with self.assertRaisesRegex(ReplayError, "missing verified"):
            check_result(output, ("witness",))

    def test_duplicate_result_is_rejected(self):
        output = "witness (exists-trace): verified (826 steps)\n" * 2

        with self.assertRaisesRegex(ReplayError, "missing verified"):
            check_result(output, ("witness",))


class CommandTests(unittest.TestCase):
    def test_success_returns_output(self):
        output = run([sys.executable, "-c", "print('verified')"], 5)

        self.assertEqual(output, "verified\n")

    def test_nonzero_exit_cannot_count_as_success(self):
        command = [sys.executable, "-c", "import sys; print('failed'); sys.exit(2)"]

        with self.assertRaisesRegex(ReplayError, r"command failed \(2\)"):
            run(command, 5)

    def test_timeout_terminates_the_command(self):
        command = [sys.executable, "-c", "import time; time.sleep(30)"]

        with self.assertRaisesRegex(ReplayError, r"timeout \(1s\)"):
            run(command, 1)


if __name__ == "__main__":
    unittest.main()
