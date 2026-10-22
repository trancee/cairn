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
    "native-tool", "native-compilation", "native-cinterop",
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

    def test_codeql_cell_runs_only_setup_and_the_traced_binding_paths(self):
        self.assertEqual(plan.probes("codeql"), [
            "codeql-startup", "toolchains", *SETUP, *BINDING_PATH,
            "repository-bindings", "repository-codeql", "codeql-analysis",
        ])
        self.assertTrue(set(ISOLATION_ONLY).isdisjoint(plan.probes("codeql")))

    def test_only_the_codeql_cell_leaves_boundary_probes_to_the_isolation_cell(self):
        self.assertEqual(plan.boundary_probes("full"), True)
        self.assertEqual(plan.boundary_probes("isolation"), True)
        self.assertEqual(plan.boundary_probes("codeql"), False)

    def test_runner_guards_every_boundary_probe_by_the_plan(self):
        text = RUNNER.read_text()
        guarded = "".join(re.findall(
            r'^if \[ "\$boundary" = true \]; then\n(.*?)^fi$', text, re.MULTILINE | re.DOTALL,
        ))
        markers = [
            "test_uid_supervisor.py", "probe-pf.py\" \"$work/proof-output/pf.log",
            "probe-resources.py\" \"$volume", "-size 256m",
            "sandbox-pf.log", "launch-probes.py",
        ]

        for marker in markers:
            self.assertEqual(text.count(marker), 1, marker)
            self.assertIn(marker, guarded)

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
            *BINDING_PATH, "repository-bindings", "repository-codeql", "codeql-analysis",
        ]
        covered = set(plan.probes("codeql")) | set(plan.probes("isolation"))

        self.assertEqual(covered, set(unsplit))
        for scope in ["codeql", "isolation"]:
            ordered = [probe for probe in unsplit if probe in plan.probes(scope)]
            self.assertEqual(plan.probes(scope), ordered)

    def test_fixture_targets_always_follow_the_warming_toolchain_probe(self):
        # Probe deadlines were calibrated with fixture selection warming the
        # Gradle home before fixture targets; a cold start can exceed 60s.
        for scope in plan.SCOPES:
            probes = plan.probes(scope)
            self.assertIn("toolchains", probes, scope)
            self.assertLess(probes.index("toolchains"), probes.index("fixture-targets"), scope)

    def test_fixture_targets_reports_owned_processes_before_its_unchanged_deadline(self):
        arm = re.search(r"^    fixture-targets\)\n(.*?)^      ;;$", RUNNER.read_text(),
                        re.MULTILINE | re.DOTALL)
        self.assertIsNotNone(arm)
        supervisor = re.search(r'uid-supervisor\.py"((?:[^\n]|\\\n)*?)"\$work/proof-output/fixture-targets\.log"',
                               arm.group(1))
        self.assertIsNotNone(supervisor, arm.group(1))

        self.assertEqual(supervisor.group(1).split(),
                         ["--seconds", "60", "--diagnose-after", "50", "\\"])

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

    def test_cli_prints_tool_and_boundary_requirements_then_one_probe_per_line(self):
        result = subprocess.run(
            [sys.executable, "-I", str(SCRIPT), "codeql"],
            capture_output=True, text=True, timeout=5,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            ["codeql=true", "boundary-probes=false", *plan.probes("codeql")],
        )

    def test_runner_has_exactly_one_case_arm_for_every_planned_probe(self):
        arms = [
            arm for line in re.findall(r"^    ([a-z|-]+)\)$", RUNNER.read_text(), re.MULTILINE)
            for arm in line.split("|")
        ]
        planned = {probe for scope in plan.SCOPES for probe in plan.probes(scope)}

        self.assertEqual(sorted(arms), sorted(planned))


if __name__ == "__main__":
    unittest.main()
