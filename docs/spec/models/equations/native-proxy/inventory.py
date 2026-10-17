"""Generate the native guard inventory and embedded source identity."""

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from equations.maude_module import reviewed_module
from equations.signature import FUNCTIONS
from equations.maude_native import source_identity, source_inputs
from equations.maude_runner import GuardError


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    try:
        rows = [
            f"pub const SOURCE_ID: &str = {json.dumps(source_identity())};",
            f"pub const EXPECTED_MODULE: &str = {json.dumps(reviewed_module())};",
            "pub const FUNCTIONS: &[(&str, usize)] = &[",
            *(f"    ({json.dumps(name)}, {arity})," for name, (arity, _) in FUNCTIONS.items()),
            "];",
        ]
        (arguments.output / "inventory.rs").write_text("\n".join(rows) + "\n")
        for source in (*source_inputs(), Path(__file__).resolve().parent / "src"):
            print(f"cargo:rerun-if-changed={source}")
    except (GuardError, OSError, UnicodeError):
        print("FAIL: native guard inventory/source generation unavailable", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
