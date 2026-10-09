#!/usr/bin/env python3
"""Static certificate gate: no unfinished proofs and no orphaned include files."""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
INCLUDE = re.compile(r'^\s*#include\s+"([^"]+)"', re.M)
UNFINISHED = re.compile(r"\b(sorry|admit)\b")


def problems(root=HERE):
    found = []
    sources = [*root.glob("*.spthy"), *root.glob("*.inc")]
    included = {m for p in sources for m in INCLUDE.findall(p.read_text())}
    for inc in sorted(root.glob("*.inc")):
        text = re.sub(r"/\*.*?\*/", "", inc.read_text(), flags=re.S)
        for n, line in enumerate(text.splitlines(), 1):
            if UNFINISHED.search(line):
                found.append(f"{inc.name}: unfinished proof step near line {n}")
        if inc.name not in included:
            found.append(f"{inc.name}: not included by any theory or include file")
    for name in sorted(included):
        if not (root / name).exists():
            found.append(f"{name}: included but missing")
    return found


if __name__ == "__main__":
    issues = problems()
    print("\n".join(issues) or "certificates: ok")
    sys.exit(1 if issues else 0)
