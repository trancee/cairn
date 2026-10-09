import tempfile
import unittest
from pathlib import Path

import check_certificates as c


def tree(files):
    d = tempfile.TemporaryDirectory()
    for name, body in files.items():
        (Path(d.name) / name).write_text(body)
    return d


class CertificateGate(unittest.TestCase):
    def test_repository_is_clean(self):
        self.assertEqual(c.problems(), [])

    def test_flags_sorry(self):
        d = tree({"t.spthy": '#include "a.inc"', "a.inc": "by sorry"})
        self.assertTrue(any("unfinished" in p for p in c.problems(Path(d.name))))

    def test_ignores_sorry_in_comment(self):
        d = tree({"t.spthy": '#include "a.inc"', "a.inc": "/* sorry */"})
        self.assertEqual(c.problems(Path(d.name)), [])

    def test_flags_orphan_and_missing(self):
        d = tree({"t.spthy": '#include "gone.inc"', "a.inc": ""})
        found = c.problems(Path(d.name))
        self.assertTrue(any("not included" in p for p in found))
        self.assertTrue(any("missing" in p for p in found))


if __name__ == "__main__":
    unittest.main()
