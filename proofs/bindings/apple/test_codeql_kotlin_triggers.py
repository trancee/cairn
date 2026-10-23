from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[3]
WORKFLOWS = ROOT / ".github" / "workflows"
KOTLIN = WORKFLOWS / "codeql-kotlin.yml"
REPOSITORY_INPUTS = ROOT / "proofs" / "bindings" / "apple" / "prepare-repository-inputs.sh"


def trigger_block(text, event):
    lines = text.splitlines()
    start = lines.index("on:") + 1
    block, inside = [], False
    for line in lines[start:]:
        if line and not line.startswith(" "):
            break
        if re.fullmatch(r"  [a-z_]+:.*", line):
            inside = line.strip().startswith(f"{event}:")
            if inside:
                block.append(line)
            continue
        if inside:
            block.append(line)
    return block


def pull_request_paths(text):
    paths, inside = [], False
    for line in trigger_block(text, "pull_request"):
        if line.strip() == "paths:":
            inside = True
        elif inside and line.strip().startswith("- "):
            paths.append(line.strip()[2:].strip("'\""))
        elif inside:
            inside = False
    return paths


def copied_root_pathspecs(script):
    command = re.search(r"ls-files -z --(.*?)\|", script, re.S).group(1)
    return [
        spec for spec in command.replace("\\\n", " ").split()
        if not spec.startswith("':(exclude)")
    ]


def glob_pattern(glob):
    parts = re.split(r"(\*\*|\*)", glob)
    return re.compile("".join(
        ".*" if part == "**" else "[^/]*" if part == "*" else re.escape(part)
        for part in parts
    ))


def reachable_workflows(name):
    seen, pending = [], [name]
    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.append(current)
        text = (WORKFLOWS / current).read_text()
        pending.extend(re.findall(r"uses: \./\.github/workflows/([\w.-]+\.yml)", text))
    return seen


def repository_paths(text):
    roots = sorted(
        entry.name for entry in ROOT.iterdir()
        if entry.is_dir() and not entry.name.startswith(".") and entry.name != "target"
    )
    pattern = re.compile(rf"(?<![\w/.$-])((?:{'|'.join(roots)})/[\w./*-]+)")
    return {
        path for line in text.splitlines()
        if not line.strip().startswith("branches:")
        for path in pattern.findall(line)
    }


class CodeqlKotlinTriggersTest(unittest.TestCase):
    def setUp(self):
        self.text = KOTLIN.read_text()
        self.paths = pull_request_paths(self.text)
        self.patterns = [glob_pattern(path) for path in self.paths]

    def covered(self, path):
        return any(pattern.fullmatch(path) for pattern in self.patterns)

    def test_pull_requests_are_path_filtered(self):
        filtered = self.paths

        self.assertTrue(filtered)

    def test_filter_covers_every_reachable_workflow(self):
        workflows = reachable_workflows(KOTLIN.name)

        uncovered = [
            name for name in workflows if not self.covered(f".github/workflows/{name}")
        ]

        self.assertEqual(uncovered, [])
        self.assertIn("apple-toolchain-preparation.yml", workflows)
        self.assertIn("apple-isolation-probe.yml", workflows)

    def test_filter_covers_every_repository_path_the_lane_reads(self):
        referenced = set()
        for name in reachable_workflows(KOTLIN.name):
            referenced |= repository_paths((WORKFLOWS / name).read_text())

        uncovered = sorted(path for path in referenced if not self.covered(path))

        self.assertTrue(referenced)
        self.assertEqual(uncovered, [])

    def test_filter_covers_root_inputs_that_change_checkout_or_toolchain(self):
        root_inputs = [".gitattributes", "rust-toolchain.toml"]

        uncovered = [path for path in root_inputs if not self.covered(path)]

        self.assertEqual(uncovered, [])

    def test_filter_covers_every_root_build_input_the_lane_copies(self):
        specs = copied_root_pathspecs(REPOSITORY_INPUTS.read_text())

        uncovered = [
            spec for spec in specs
            if not self.covered(spec) and not self.covered(f"{spec}/any/File.kt")
        ]

        self.assertIn("sdk", specs)
        self.assertEqual(uncovered, [])

    def test_main_pushes_and_weekly_scans_are_never_filtered(self):
        push = trigger_block(self.text, "push")
        schedule = trigger_block(self.text, "schedule")

        self.assertIn("    branches: [main]", push)
        self.assertFalse([line for line in push if "paths" in line])
        self.assertTrue([line for line in schedule if "cron:" in line])

    def test_hosted_codeql_workflow_no_longer_owns_the_strict_lane(self):
        hosted = (WORKFLOWS / "codeql.yml").read_text()

        owners = [
            name for name in sorted(path.name for path in WORKFLOWS.glob("*.yml"))
            if "uses: ./.github/workflows/apple-toolchain-preparation.yml"
            in (WORKFLOWS / name).read_text()
        ]

        self.assertNotIn("apple-toolchain-preparation.yml", hosted)
        self.assertEqual(owners, [KOTLIN.name])


if __name__ == "__main__":
    unittest.main()
