import unittest

import branch

SRC = """lemma a [sources]:
  induction
  case x
    solve( q )
      case one
      by sorry
    next
      case two
      by contradiction
    qed
  qed
qed

lemma b [sources]:
  by sorry
"""

PAGE = (
    '<a href="/thy/trace/3/main/method/a/1/x/one">splitEqs</a> (0)<br/>\n<br/>'
    '<a href="/thy/trace/3/main/method/a/2/x/one">contradiction</a> (1)'
)


class Branch(unittest.TestCase):
    def test_paths_are_scoped_to_lemma(self):
        self.assertEqual(branch.sorry_paths(SRC, "a"), ["x/one"])
        self.assertEqual(branch.sorry_paths(SRC, "b"), [""])

    def test_parse_and_priority(self):
        methods = branch.parse_methods(PAGE, "a")
        self.assertEqual([i for i, _ in methods], [1, 2])
        self.assertEqual(branch.choose(methods)[0], 2)

    def test_no_match_is_stuck(self):
        self.assertIsNone(branch.choose([(1, "other")]))


if __name__ == "__main__":
    unittest.main()
