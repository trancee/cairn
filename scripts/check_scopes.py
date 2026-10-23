"""Select the local and CI gates that a set of changed paths can affect.

The patterns use GitHub Actions `paths` syntax and are the single source for
both `.githooks/pre-commit` and the `pull_request` filters of the workflows in
WORKFLOWS; test_check_scopes.py fails when the two disagree. Pushes to main,
scheduled runs and manual dispatches always run every gate.
"""

import re
import subprocess
import sys

SCOPES = {
    "rust": [
        "core/**",
        "rust-toolchain.toml",
        "scripts/check-rust.sh",
        "scripts/check-ct.sh",
        ".github/workflows/rust.yml",
    ],
    "models": [
        "docs/spec/models/**",
        "!docs/spec/models/**/*.md",
        "rust-toolchain.toml",
        "scripts/check.sh",
        "scripts/check_scopes.py",
        "scripts/test_check_scopes.py",
        ".githooks/**",
        ".github/workflows/lifecycle.yml",
    ],
    "workflows": [
        ".github/workflows/**",
    ],
    "codeql": [
        ".github/**",
        "**/*.py",
        "**/*.rs",
        "**/Cargo.toml",
        "**/Cargo.lock",
        "rust-toolchain.toml",
    ],
}

# The lifecycle lane also runs actionlint through scripts/check.sh.
WORKFLOWS = {
    "rust.yml": ["rust"],
    "lifecycle.yml": ["models", "workflows"],
    "codeql.yml": ["codeql"],
}

# Gates the pre-commit hook runs; codeql runs only in CI.
HOOK_SCOPES = ("rust", "models", "workflows")


def _regex(pattern):
    out = []
    i = 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("".join(out) + r"\Z")


def matches(patterns, path):
    selected = False
    for pattern in patterns:
        negated = pattern.startswith("!")
        if _regex(pattern[1:] if negated else pattern).match(path):
            selected = not negated
    return selected


def scopes_for(paths):
    return {name for name, patterns in SCOPES.items()
            if any(matches(patterns, path) for path in paths)}


def patterns_for(scopes):
    return [pattern for scope in scopes for pattern in SCOPES[scope]]


def pull_request_paths(workflow_text):
    lines = workflow_text.splitlines()
    start = lines.index("  pull_request:")
    paths = []
    in_paths = False
    for line in lines[start + 1:]:
        if line and not line.startswith("    "):
            break
        stripped = line.strip()
        if stripped == "paths:":
            in_paths = True
        elif in_paths and stripped.startswith("- "):
            paths.append(stripped[2:].strip("'\""))
        elif in_paths and stripped and not stripped.startswith("#"):
            in_paths = False
    return paths


def staged_paths():
    output = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--no-renames", "-z"],
        check=True, capture_output=True, text=True,
    ).stdout
    return [path for path in output.split("\0") if path]


def main(argv):
    if argv == ["--all"]:
        print(" ".join(HOOK_SCOPES))
    elif argv == ["--staged"]:
        print(" ".join(s for s in HOOK_SCOPES if s in scopes_for(staged_paths())))
    else:
        print("usage: check_scopes.py --staged | --all", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
