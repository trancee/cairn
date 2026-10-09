import unittest

from check import check_axioms, check_tamarin_version
from projection import ProjectionError, lean_certificate, Projection


class EvidenceTests(unittest.TestCase):
    def test_pinned_tamarin_and_maude_are_accepted(self):
        output = "tamarin-prover 1.12.0,\nMaude version 3.5.1\n"

        check_tamarin_version(output)

    def test_unpinned_maude_is_rejected(self):
        output = "tamarin-prover 1.12.0,\nMaude version 3.4\n"

        with self.assertRaisesRegex(RuntimeError, "expected Maude 3.5.1"):
            check_tamarin_version(output)

    def test_missing_maude_version_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "expected Maude 3.5.1"):
            check_tamarin_version("tamarin-prover 1.12.0,\n")

    def test_unpinned_tamarin_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "expected Tamarin 1.12.0"):
            check_tamarin_version("tamarin-prover 1.11.0,\nMaude version 3.5.1\n")

    def test_standard_kernel_axioms_are_accepted(self):
        output = "'theorem' depends on axioms: [propext, Classical.choice, Quot.sound]"

        check_axioms(output)

    def test_sorry_axiom_is_rejected(self):
        output = "'theorem' depends on axioms: [propext, sorryAx]"

        with self.assertRaisesRegex(RuntimeError, "unexpected theorem axioms"):
            check_axioms(output)

    def test_custom_axiom_is_rejected(self):
        output = "'theorem' depends on axioms: [AssumedSerialization]"

        with self.assertRaisesRegex(RuntimeError, "unexpected theorem axioms"):
            check_axioms(output)

    def test_missing_axiom_report_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "missing Lean theorem"):
            check_axioms("compiled without an axiom audit")

    def test_each_required_theorem_must_be_audited(self):
        output = "'Cairn.resume_serialized' depends on axioms: [propext]"

        with self.assertRaisesRegex(RuntimeError, "missing Lean theorem"):
            check_axioms(output, ("Cairn.resume_serialized", "Cairn.lock_stage_order"))

    def test_axiom_free_theorem_report_is_accepted(self):
        output = "'Cairn.stutter_records_no_actions' does not depend on any axioms"

        check_axioms(output, ("Cairn.stutter_records_no_actions",))

    def test_duplicate_theorem_report_is_rejected(self):
        output = "'theorem' depends on axioms: [propext]\n" * 2

        with self.assertRaisesRegex(RuntimeError, "duplicate Lean theorem"):
            check_axioms(output)

    def test_certificate_uses_extracted_tokens(self):
        row = Projection(
            "Acquire_Resume", "acquire",
            (("slot", "pid", "r", "%s"),),
            (("permit", "pid", "r", "%s%+%1"), ("busy", "pid", "r", "%s%+%1")),
            (("LockStage", "pid", "r", "%s%+%1"),),
        )

        certificate = lean_certificate([row])

        self.assertIn("[.slot stage] = inputs .acquire stage", certificate)
        self.assertIn("[.permit (stage + 1), .busy (stage + 1)]", certificate)
        self.assertIn("(some (stage + 1), none, none)", certificate)

    def test_unknown_stage_encoding_is_rejected(self):
        row = Projection("Invalid", "start", (("permit", "pid", "r", "arbitrary"),))

        with self.assertRaisesRegex(ProjectionError, "unsupported stage"):
            lean_certificate([row])

    def test_pair_certificate_uses_each_extracted_role_and_marker(self):
        row = Projection(
            "Pair", "pair", (),
            (("slot", "~pid", "roleA", "%1"), ("slot", "~pid", "roleB", "%1")),
            (("Init", "~pid"), ("LockStage", "~pid", "roleA", "%1"),
             ("LockStage", "~pid", "roleB", "%1")),
        )

        certificate = lean_certificate([row])

        self.assertEqual(certificate.count("inventory (initialAt clock)"), 2)
        self.assertEqual(certificate.count("recordEvent (some 1) clock []"), 2)
        self.assertIn("[(pid, false), (pid, true)]", certificate)

    def test_pair_certificate_cannot_ignore_unknown_stage(self):
        row = Projection("Pair", "pair", (), (("slot", "~pid", "roleA", "%2"),))

        with self.assertRaisesRegex(ProjectionError, "unsupported stage"):
            lean_certificate([row])


if __name__ == "__main__":
    unittest.main()
