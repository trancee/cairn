#!/usr/bin/env python3
"""Report kernel sandbox denials of java paths under /opt since a probe began."""

import subprocess
import sys

PREDICATE = (
    'process == "kernel" AND eventMessage CONTAINS "Sandbox" '
    'AND eventMessage CONTAINS "java(" AND eventMessage CONTAINS "/opt"'
)


def query(start):
    return ["/usr/bin/log", "show", "--start", start, "--style", "compact",
            "--predicate", PREDICATE]


def summarize(text):
    denials = [
        line[:23] + " " + line.split("Sandbox: ", 1)[1]
        for line in text.splitlines() if "Sandbox: " in line
    ]
    return [f"DIAGNOSTIC: sandbox-denial {denial}" for denial in denials] + [
        f"DIAGNOSTIC: java sandbox denials under /opt: {len(denials)}"
    ]


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: report-sandbox-denials.py 'YYYY-MM-DD HH:MM:SS'")
    result = subprocess.run(query(sys.argv[1]), check=True, capture_output=True,
                            text=True, timeout=15)
    print("\n".join(summarize(result.stdout)), flush=True)


if __name__ == "__main__":
    main()
