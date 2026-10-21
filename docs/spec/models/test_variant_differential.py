"""Lean variant schemes and native Maude variants must cover each other."""

import unittest

from equations.variant_differential import (
    Case, NativeSession, check_case, parse_blocks, parse_export, parse_term, render, split_replies,
)


def case(term, variables, *schemes):
    def system(value, equations):
        equations = (*equations, (term, term), (value, value))
        return tuple((parse_term(left), parse_term(right)) for left, right in equations)

    return Case(
        parse_term(term), tuple(parse_term(variable) for variable in variables),
        tuple((parse_term(value), system(value, equations)) for value, equations in schemes),
    )


def first():
    return case(
        "tamXCfst(x0:Msg)", ("x0:Msg",),
        ("tamXCfst(x0:Msg)", ()),
        ("x1:Msg", (("x0:Msg", "tamXCpair(x1:Msg,x2:Msg)"),)),
    )


class SyntaxTests(unittest.TestCase):
    def test_terms_round_trip_without_reply_spacing(self):
        term = parse_term("tamXCsdec(#1:Msg, tamtplus(tamXCtone, %2:TamNat))")

        self.assertEqual(render(term), "tamXCsdec(#1:Msg,tamtplus(tamXCtone,%2:TamNat))")

    def test_replies_follow_the_setup_and_module_prompts(self):
        output = "Maude> " * 5 + "\nfirst\nMaude> \nsecond\nMaude> "

        self.assertEqual(split_replies(output, 2), ["first", "second"])

    def test_missing_replies_are_rejected(self):
        with self.assertRaises(ValueError):
            split_replies("Maude> " * 5 + "\nfirst\nMaude> ", 2)

    def test_variant_blocks_keep_value_and_bindings(self):
        reply = (
            "Variant 1\nrewrites: 0\nMsg: tamXCfst(#1:Msg)\nx0:Msg --> #1:Msg\n\n"
            "Variant 2\nrewrites: 1\nMsg: %1:Msg\nx0:Msg --> tamXCpair(%1:Msg, %2:Msg)\n\n"
            "No more variants.\nrewrites: 1"
        )

        blocks = parse_blocks(reply, "Variant")

        self.assertEqual([render(value) for value, _ in blocks], ["tamXCfst(#1:Msg)", "%1:Msg"])
        self.assertEqual(render(blocks[1][1]["x0:Msg"]), "tamXCpair(%1:Msg,%2:Msg)")

    def test_unsolvable_systems_have_no_unifier_blocks(self):
        self.assertEqual(parse_blocks("No unifier.", "Unifier"), [])

    def test_lean_export_lists_terms_variables_and_scheme_systems(self):
        exported = (
            "CASE tamXCfst(x0:Msg)\nVARS x0:Msg\n"
            "SCHEME tamXCfst(x0:Msg)\n"
            "EQUATION tamXCfst(x0:Msg) =? tamXCfst(x0:Msg)\n"
            "EQUATION tamXCfst(x0:Msg) =? tamXCfst(x0:Msg)\n"
            "SCHEME x1:Msg\nEQUATION x0:Msg =? tamXCpair(x1:Msg,x2:Msg)\n"
            "EQUATION tamXCfst(x0:Msg) =? tamXCfst(x0:Msg)\nEQUATION x1:Msg =? x1:Msg\n"
        )

        self.assertEqual(parse_export(exported), [first()])


class NativeDifferentialTests(unittest.TestCase):
    def test_complete_schemes_cover_native_variants_both_ways(self):
        with NativeSession() as session:
            report = check_case(first(), session)

        self.assertEqual(report.failures, ())
        self.assertEqual((report.lean, report.maude), (2, 2))

    def test_missing_rule_scheme_leaves_a_native_variant_uncovered(self):
        full = first()
        identity = Case(full.term, full.variables, full.schemes[:1])

        with NativeSession() as session:
            report = check_case(identity, session)

        self.assertIn("native variant 2 is not an instance of any Lean variant", report.failures)

    def test_wrong_scheme_value_is_not_sound(self):
        wrong = case(
            "tamXCfst(x0:Msg)", ("x0:Msg",),
            ("tamXCfst(x0:Msg)", ()),
            ("x2:Msg", (("x0:Msg", "tamXCpair(x1:Msg,x2:Msg)"),)),
        )

        with NativeSession() as session:
            report = check_case(wrong, session)

        self.assertIn("Lean variant 2 does not normalize like its term instance", report.failures)
        self.assertIn("Lean variant 2 is not an instance of any native variant", report.failures)


if __name__ == "__main__":
    unittest.main()
