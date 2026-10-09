import unittest
from pathlib import Path
import subprocess

from projection import ProjectionError, parse_fact, project_export, project_rule, split_terms


class ProjectionTests(unittest.TestCase):
    def test_acquire_matches_linear_rewrite(self):
        rule = """
        [ ResumeSlot(pid,r,%s)[no_precomp] ]
        --[ LockStage(pid,r,(%s %+ %1)), LockAcquire(pid,r,(%s %+ %1)) ]->
        [ StartPermit(pid,r,(%s %+ %1)), BusySlot(pid,r,(%s %+ %1)) ]
        """

        result = project_rule("Acquire_Resume", rule)

        self.assertEqual(result.action, "acquire")

    def test_duplicate_permit_is_rejected(self):
        rule = """
        [ ResumeSlot(pid,r,%s) ]
        --[ LockStage(pid,r,(%s %+ %1)), LockAcquire(pid,r,(%s %+ %1)) ]->
        [ StartPermit(pid,r,(%s %+ %1)), StartPermit(pid,r,(%s %+ %1)),
          BusySlot(pid,r,(%s %+ %1)) ]
        """

        with self.assertRaisesRegex(ProjectionError, "projection mismatch"):
            project_rule("Acquire_Resume", rule)

    def test_missing_release_marker_is_rejected(self):
        rule = """
        [ FinishPermit(pid,r,%s) ]
        --[ LockRelease(pid,r,%s) ]-> [ ResumeSlot(pid,r,%s) ]
        """

        with self.assertRaisesRegex(ProjectionError, "projection mismatch"):
            project_rule("Release_Resume", rule)

    def test_finish_must_advance_stage(self):
        rule = """
        [ BusySlot(pid,r,%s), IWait(pid,r,p,ck,e,g,n,h,x,m,pq,ss,ek,ct,%s) ]
        --[ ResumeFinish(pid,r,%s) ]-> [ FinishPermit(pid,r,%s) ]
        """

        with self.assertRaisesRegex(ProjectionError, "projection mismatch"):
            project_rule("I_Timeout", rule)

    def test_wrong_role_is_rejected(self):
        rule = """
        [ FinishPermit(pid,r,%s) ]
        --[ LockStage(pid,roleB,%s), LockRelease(pid,r,%s) ]->
        [ ResumeSlot(pid,r,%s) ]
        """

        with self.assertRaisesRegex(ProjectionError, "projection mismatch"):
            project_rule("Release_Resume", rule)

    def test_persistent_linear_token_is_rejected(self):
        rule = """
        [ !FinishPermit(pid,r,%s) ]
        --[ LockStage(pid,r,%s), LockRelease(pid,r,%s) ]->
        [ ResumeSlot(pid,r,%s) ]
        """

        with self.assertRaisesRegex(ProjectionError, "persistent lifecycle"):
            project_rule("Release_Resume", rule)

    def test_unknown_rule_cannot_mutate_lifecycle(self):
        rule = "[ ] --[ ]-> [ ResumeSlot(pid,r,%s) ]"

        with self.assertRaisesRegex(ProjectionError, "unclassified lifecycle"):
            project_rule("Unexpected", rule)

    def test_non_lifecycle_rule_is_stutter(self):
        rule = """
        [ !St(pid,r,ck,%e,g), In(<x,mac(ck,<y,z>)>) ]
        --[ Cur(pid,r,ck) ]-> [ Out(senc(<x,y>,ck)) ]
        """

        result = project_rule("Unrelated", rule)

        self.assertEqual(result.action, "stutter")

    def test_malformed_fact_fails_closed(self):
        rule = "[ FinishPermit(pid,r,%s ] --[ ]-> [ ]"

        with self.assertRaises(ProjectionError):
            project_rule("Release_Resume", rule)

    def test_start_keeps_attempt_stage(self):
        rule = """
        [ StartPermit(pid,r,%s) ]
        --[ ResumeStart(pid,r,%s), I_Start(pid,r,x,'none') ]->
        [ IWait(pid,r,p,ck,e,g,n,h,x,m,pq,ss,ek,ct,(%s %+ %1)) ]
        """

        with self.assertRaisesRegex(ProjectionError, "projection mismatch"):
            project_rule("I_S1_classic", rule)

    def test_lifecycle_token_in_actions_is_rejected(self):
        rule = "[ ] --[ ResumeSlot(pid,r,%s) ]-> [ ]"

        with self.assertRaisesRegex(ProjectionError, "lifecycle fact position"):
            project_rule("Unexpected", rule)

    def test_action_label_in_state_is_rejected(self):
        rule = "[ ] --[ ]-> [ LockStage(pid,r,%s) ]"

        with self.assertRaisesRegex(ProjectionError, "lifecycle fact position"):
            project_rule("Unexpected", rule)

    def test_empty_argument_cannot_be_discarded(self):
        with self.assertRaisesRegex(ProjectionError, "empty term"):
            split_terms("pid,r,%s,")

    def test_multiple_calls_are_not_one_fact(self):
        with self.assertRaisesRegex(ProjectionError, "unsupported fact"):
            parse_fact("Unrelated(pid) LockStage(pid,r,%s)")

    def test_comment_markers_inside_literal_are_preserved(self):
        rule = "[ ] --[ ]-> [ Out('/* not a comment */') ]"

        result = project_rule("Unrelated", rule)

        self.assertEqual(result.action, "stutter")

    def test_quoted_comment_markers_cannot_hide_lifecycle_facts(self):
        rule = "[ ] --[ ]-> [ Out('/*'), ResumeSlot(pid,r,%s), Out('*/') ]"

        with self.assertRaisesRegex(ProjectionError, "unclassified lifecycle"):
            project_rule("Unexpected", rule)

    def test_trailing_comma_is_rejected(self):
        rule = "[ ] --[ ]-> [ Unrelated(pid), ]"

        with self.assertRaisesRegex(ProjectionError, "empty term"):
            project_rule("Unrelated", rule)

    def test_unterminated_comment_is_rejected(self):
        rule = "[ ] --[ ]-> [ ] /* incomplete"

        with self.assertRaisesRegex(ProjectionError, "unterminated comment"):
            project_rule("Unrelated", rule)

    def test_unterminated_literal_is_rejected(self):
        rule = "[ ] --[ ]-> [ Out('incomplete) ]"

        with self.assertRaisesRegex(ProjectionError, "unterminated literal"):
            project_rule("Unrelated", rule)

    def test_unsupported_fact_annotation_is_rejected(self):
        rule = "[ ] --[ ]-> [ Out(pid)[unreviewed] ]"

        with self.assertRaisesRegex(ProjectionError, "unsupported fact suffix"):
            project_rule("Unrelated", rule)

    def test_quoted_delimiters_do_not_split_terms(self):
        result = split_terms("'comma, brackets[] and >',<pid,roleA>")

        self.assertEqual(result, ["'comma, brackets[] and >'", "<pid,roleA>"])


class ExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        model = Path(__file__).resolve().parent.parent / "ratchet.spthy"
        cls.export = subprocess.run(
            ["tamarin-prover", "--parse-only", str(model)], check=True,
            text=True, capture_output=True, timeout=120,
        ).stdout

    def test_every_default_rule_is_projected(self):
        rows = project_export(self.export)

        self.assertEqual(len(rows), 43)
        self.assertEqual(sum(row.action == "finish" for row in rows), 10)

    def test_missing_initialization_is_rejected(self):
        mutated = self.export.replace("rule (modulo E) Pair:", "rule (modulo E) NotPair:", 1)

        with self.assertRaisesRegex(ProjectionError, "missing required"):
            project_export(mutated)

    def test_duplicate_rule_is_rejected(self):
        mutated = self.export.replace("rule (modulo E) Reveal_CK:", "rule (modulo E) Pair:", 1)

        with self.assertRaisesRegex(ProjectionError, "duplicate rule"):
            project_export(mutated)

    def test_unsupported_rule_syntax_is_rejected(self):
        mutated = self.export.replace("rule (modulo E) Reveal_CK:", "rule Reveal_CK:", 1)

        with self.assertRaisesRegex(ProjectionError, "unsupported or unparsed"):
            project_export(mutated)

    def test_unreviewed_role_equation_is_rejected(self):
        mutated = self.export.replace("flip(roleA) = roleB", "flip(roleA) = roleA", 1)

        with self.assertRaisesRegex(ProjectionError, "unreviewed equational"):
            project_export(mutated)

    def test_unreviewed_builtin_is_rejected(self):
        mutated = self.export.replace("builtins: natural-numbers", "builtins: xor", 1)

        with self.assertRaisesRegex(ProjectionError, "unreviewed builtin"):
            project_export(mutated)

    def test_pair_id_must_remain_fresh(self):
        mutated = self.export.replace("[ Fr( ~pid ), Fr( ~ck ) ]", "[ In( ~pid ), Fr( ~ck ) ]", 1)

        self.assertNotEqual(mutated, self.export)
        with self.assertRaisesRegex(ProjectionError, "fresh pair identifier"):
            project_export(mutated)

    def test_changed_claim_is_rejected(self):
        mutated = self.export.replace("lemma resume_serialized ", "lemma different_serialized ", 1)

        with self.assertRaisesRegex(ProjectionError, "unreviewed target formula"):
            project_export(mutated)

    def test_pair_randomness_cannot_be_persistent(self):
        mutated = self.export.replace("[ Fr( ~pid ), Fr( ~ck ) ]", "[ !Fr( ~pid ), Fr( ~ck ) ]", 1)

        self.assertNotEqual(mutated, self.export)
        with self.assertRaisesRegex(ProjectionError, "fresh pair identifier"):
            project_export(mutated)

    def test_pair_cannot_initialize_an_existing_identifier(self):
        mutated = self.export.replace("ResumeSlot( ~pid, roleA", "ResumeSlot( pid, roleA", 1)

        self.assertNotEqual(mutated, self.export)
        with self.assertRaisesRegex(ProjectionError, "projection mismatch"):
            project_export(mutated)

    def test_pair_roles_cannot_alias(self):
        mutated = self.export.replace("ResumeSlot( ~pid, roleB", "ResumeSlot( ~pid, roleA", 1)

        self.assertNotEqual(mutated, self.export)
        with self.assertRaisesRegex(ProjectionError, "projection mismatch"):
            project_export(mutated)

    def test_duplicate_target_declaration_is_rejected(self):
        declaration = self.export[self.export.index("lemma resume_serialized "):]
        declaration = declaration[:declaration.index("by sorry") + len("by sorry")]
        mutated = self.export + "\n" + declaration

        with self.assertRaisesRegex(ProjectionError, "unreviewed target formula"):
            project_export(mutated)

    def test_incompatible_duplicate_target_is_rejected(self):
        mutated = self.export + '\nlemma resume_serialized [reuse]: exists-trace "T" by sorry\n'

        with self.assertRaisesRegex(ProjectionError, "unreviewed target formula"):
            project_export(mutated)

    def test_second_builtin_declaration_is_rejected(self):
        mutated = self.export + "\nbuiltins: xor\n"

        with self.assertRaisesRegex(ProjectionError, "unreviewed builtin"):
            project_export(mutated)


if __name__ == "__main__":
    unittest.main()
