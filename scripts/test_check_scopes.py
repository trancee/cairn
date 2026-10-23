import unittest
from pathlib import Path

import check_scopes

ROOT = Path(__file__).resolve().parents[1]


class ScopesForChangedPaths(unittest.TestCase):
    def test_documentation_only_change_selects_no_gate(self):
        scopes = check_scopes.scopes_for([
            "docs/adr/0021-automatic-neighbour-admission.md",
            "docs/spec/models/README.md",
            "GLOSSARY.md",
            ".scratch/cairn-r1/map.md",
        ])

        self.assertEqual(scopes, set())

    def test_core_source_selects_rust_and_codeql(self):
        scopes = check_scopes.scopes_for(["core/cairn-wire/src/lib.rs"])

        self.assertEqual(scopes, {"rust", "codeql"})

    def test_model_source_selects_models(self):
        scopes = check_scopes.scopes_for(["docs/spec/models/sas.spthy"])

        self.assertEqual(scopes, {"models"})

    def test_toolchain_pin_selects_every_build_that_reads_it(self):
        scopes = check_scopes.scopes_for(["rust-toolchain.toml"])

        self.assertEqual(scopes, {"rust", "models", "codeql"})

    def test_workflow_change_selects_its_lane_and_workflow_lint(self):
        scopes = check_scopes.scopes_for([".github/workflows/rust.yml"])

        self.assertEqual(scopes, {"rust", "workflows", "codeql"})

    def test_scope_tooling_change_selects_models(self):
        scopes = check_scopes.scopes_for([".githooks/pre-commit"])

        self.assertEqual(scopes, {"models"})


class GlobMatching(unittest.TestCase):
    def test_double_star_slash_matches_zero_directories(self):
        self.assertTrue(check_scopes.matches(["**/*.py"], "setup.py"))

    def test_single_star_stops_at_directory_separator(self):
        self.assertFalse(check_scopes.matches(["core/*"], "core/src/lib.rs"))

    def test_later_negation_excludes_earlier_match(self):
        patterns = ["docs/spec/models/**", "!docs/spec/models/**/*.md"]

        self.assertFalse(check_scopes.matches(patterns, "docs/spec/models/lifecycle/NOTES.md"))


class WorkflowFiltersMatchScopes(unittest.TestCase):
    def test_pull_request_paths_equal_the_shared_scope_patterns(self):
        for workflow, scopes in check_scopes.WORKFLOWS.items():
            with self.subTest(workflow=workflow):
                text = (ROOT / ".github/workflows" / workflow).read_text()

                paths = check_scopes.pull_request_paths(text)

                self.assertEqual(paths, check_scopes.patterns_for(scopes))


if __name__ == "__main__":
    unittest.main()
