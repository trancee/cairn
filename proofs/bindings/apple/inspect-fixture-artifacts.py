"""Inspect compiled fixture allocator forwarding before generated FFI calls."""

from pathlib import Path
import re
import subprocess
import sys


def inspect(target):
    binary = Path.home() / f"fixture-cargo-target/{target}/debug/libcairn_binding_smoke.a"
    objdump = subprocess.check_output(
        ["/usr/bin/xcrun", "--find", "llvm-objdump"], text=True
    ).strip()
    table = subprocess.check_output(
        [objdump, "--syms", str(binary)], text=True
    )
    selected = {}
    for operation in ("alloc", "dealloc", "realloc", "alloc_zeroed"):
        matches = {
            row.split()[-1] for row in table.splitlines()
            if row.split() and row.split()[-1].endswith("___rust_" + operation)
        }
        if len(matches) != 1:
            raise RuntimeError(f"Fixture allocator symbol is missing or ambiguous: {operation}")
        selected[operation] = matches.pop()
    disassembly = subprocess.check_output([
        objdump, "--disassemble", "--reloc",
        "--disassemble-symbols=" + ",".join(selected.values()), str(binary),
    ], text=True)
    for operation, symbol in selected.items():
        match = re.search(
            r"<" + re.escape(symbol) + r">:\n(.*?)(?:\n\n|\Z)",
            disassembly, re.DOTALL,
        )
        if match is None or "___rdl_" + operation not in match[1]:
            raise RuntimeError(f"Fixture allocator does not forward to default: {operation}")
        print(symbol + ":\n" + match[1])
    candidates = 0
    for path in sorted((Path.home() / "fixture-cargo-target").rglob("*.rs")):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if re.search(r"global_allocator|alloc_error_handler|GlobalAlloc|__rg_alloc", line):
                candidates += 1
                print(f"GENERATED-CANDIDATE: {path}:{number}: {line.strip()}")
    if candidates:
        raise RuntimeError("Generated Rust allocator candidates require classification")
    print(f"PASS: fixture default allocator thunks and generated-source scan {target}")


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in (
        "aarch64-apple-darwin", "aarch64-apple-ios", "aarch64-apple-ios-sim",
    ):
        raise SystemExit("Usage: inspect-fixture-artifacts.py APPLE_RUST_TARGET")
    inspect(sys.argv[1])
