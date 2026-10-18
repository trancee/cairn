import importlib.util
from pathlib import Path
import re
import subprocess
import sys
import unittest


SCRIPT = Path(__file__).with_name("cell-plan.py")
RUNNER = Path(__file__).with_name("run-resource-probes.sh")
spec = importlib.util.spec_from_file_location("cell_plan", SCRIPT)
plan = importlib.util.module_from_spec(spec)
spec.loader.exec_module(plan)

BINDING_PATH = ["install-bindgen", "build-bindings", "jvm"]
ISOLATION_ONLY = [
    "codeql-startup", "native-tool", "native-compilation", "native-cinterop",
    "native-linkage", "allocator-inputs", "fixture-rust",
]
SETUP = ["fixture-targets", "cargo-inputs"]


class CellPlanTest(unittest.TestCase):
    def test_full_functional_cell_keeps_the_unsplit_order(self):
        self.assertEqual(plan.probes("full"), [
            "toolchains", "fixture-targets", "cargo-inputs", "native-tool",
            "native-compilation", "native-cinterop", "native-linkage", "allocator-inputs",
            "fixture-rust", "install-bindgen", "build-bindings", "jvm", "native-binaries",
        ])

    def test_codeql_cell_runs_only_setup_and_the_traced_binding_path(self):
        self.assertEqual(plan.probes("codeql"), [
            "toolchain-startup", *SETUP, *BINDING_PATH, "codeql-analysis",
        ])

    def test_isolation_cell_runs_every_probe_removed_from_the_codeql_cell(self):
        isolation = plan.probes("isolation")

        self.assertEqual(isolation, [
            "codeql-startup", "toolchains", *SETUP, "native-tool", "native-compilation",
            "native-cinterop", "native-linkage", "allocator-inputs", "fixture-rust",
        ])
        self.assertTrue(set(BINDING_PATH).isdisjoint(isolation))

    def test_split_cells_together_cover_the_unsplit_codeql_chain_in_order(self):
        unsplit = [
            "codeql-startup", "toolchains", *SETUP, "native-tool", "native-compilation",
            "native-cinterop", "native-linkage", "allocator-inputs", "fixture-rust",
            *BINDING_PATH, "codeql-analysis",
        ]
        covered = set(plan.probes("codeql")) | set(plan.probes("isolation"))
        covered.discard("toolchain-startup")

        self.assertEqual(covered, set(unsplit))
        for scope in ["codeql", "isolation"]:
            ordered = [probe for probe in unsplit if probe in plan.probes(scope)]
            self.assertEqual(
                [probe for probe in plan.probes(scope) if probe != "toolchain-startup"],
                ordered,
            )

    def test_each_scope_requires_its_matching_codeql_tool_state(self):
        self.assertEqual(plan.requires_codeql("full"), False)
        self.assertEqual(plan.requires_codeql("codeql"), True)
        self.assertEqual(plan.requires_codeql("isolation"), True)

    def test_unknown_scope_fails_without_a_plan(self):
        result = subprocess.run(
            [sys.executable, "-I", str(SCRIPT), "everything"],
            capture_output=True, text=True, timeout=5,
        )

        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "FAIL: unknown cell scope\n")

    def test_cli_prints_codeql_requirement_then_one_probe_per_line(self):
        result = subprocess.run(
            [sys.executable, "-I", str(SCRIPT), "codeql"],
            capture_output=True, text=True, timeout=5,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["codeql=true", *plan.probes("codeql")])

    def test_runner_has_exactly_one_case_arm_for_every_planned_probe(self):
        arms = [
            arm for line in re.findall(r"^    ([a-z|-]+)\)$", RUNNER.read_text(), re.MULTILINE)
            for arm in line.split("|")
        ]
        planned = {probe for scope in plan.SCOPES for probe in plan.probes(scope)}

        self.assertEqual(sorted(arms), sorted(planned))


if __name__ == "__main__":
    unittest.main()
