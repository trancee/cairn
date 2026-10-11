"""Collect bounded source-closure and delivered-runtime evidence; not acceptance."""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile


def inspect(tools):
    cargo = tools / "rust/bin/cargo"
    config = tools / "cargo-inputs/vendor.toml"
    patterns = re.compile(
        r"global_allocator|alloc_error_handler|GlobalAlloc|__rust_alloc|__rg_alloc"
    )
    manifests = (
        (tools / "fixture/sdk/rust/Cargo.toml", "cairn-binding-smoke"),
        (tools / "ubique/runtime/Cargo.toml", "uniffi-runtime"),
        (tools / "ubique/bindgen/Cargo.toml", "uniffi_bindgen_kotlin_multiplatform"),
    )
    targets = (
        "aarch64-apple-darwin",
        "aarch64-apple-ios",
        "aarch64-apple-ios-sim",
    )
    inspected = set()
    for manifest, package in manifests:
        for target in targets:
            command = [
                str(cargo), "--config", str(config),
            ]
            metadata = json.loads(subprocess.check_output(
                command + [
                    "metadata", "--format-version", "1", "--locked", "--offline",
                    "--filter-platform", target, "--manifest-path", str(manifest),
                ],
                text=True,
            ))
            tree = subprocess.check_output(
                command + [
                    "tree", "--locked", "--offline", "--target", target,
                    "--prefix", "none", "--no-dedupe", "-e", "normal,build",
                    "--format", "{p}|{f}", "--manifest-path", str(manifest),
                    "-p", package,
                ],
                text=True,
            )
            identities = {}
            for dependency in metadata["packages"]:
                key = dependency["name"] + " v" + dependency["version"]
                identities.setdefault(key, []).append(dependency)
            selected = set()
            for row in tree.splitlines():
                match = re.match(r"^(\S+ v\S+)", row)
                if match is None or len(identities.get(match[1], [])) != 1:
                    raise RuntimeError("Ambiguous or unknown Cargo tree package identity")
                dependency = identities[match[1]][0]
                selected.add(dependency["id"])
                print(f"FEATURE: {package} {target} {row}")
                if dependency["id"] in inspected:
                    continue
                inspected.add(dependency["id"])
                root = Path(dependency["manifest_path"]).parent.resolve()
                root.relative_to(tools)
                count = 0
                hits = 0
                for path in sorted(root.rglob("*")):
                    if not path.is_file() or path.suffix not in (".rs", ".toml"):
                        continue
                    path.resolve().relative_to(tools)
                    count += 1
                    for number, line in enumerate(path.read_text().splitlines(), 1):
                        if patterns.search(line):
                            hits += 1
                            if hits > 100:
                                raise RuntimeError("Allocator candidate report exceeds bound")
                            print(f"CANDIDATE: {path.relative_to(tools)}:{number}: {line.strip()}")
                print(f"SOURCE: {dependency['id']} files={count} candidates={hits}")
            print(f"CLOSURE: {package} {target} packages={len(selected)}")
    artifacts = 0
    for path in sorted((tools / "gradle-dependencies").rglob("*")):
        if not path.is_file() or not path.name.startswith("uniffi-runtime-"):
            continue
        if path.suffix not in (".jar", ".klib"):
            continue
        artifacts += 1
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        print(f"ARTIFACT: {path.relative_to(tools)} sha256={digest}")
        with zipfile.ZipFile(path) as archive:
            for name in archive.namelist():
                if name.endswith((".a", ".dylib")):
                    print(f"NATIVE-ENTRY: {path.name}:{name}")
    if artifacts == 0:
        raise RuntimeError("No delivered Ubique runtime artifacts found")
    print("INSPECTION ONLY: classify candidates and inspect delivered allocator thunks before FFI")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: inspect-allocator-inputs.py TOOL_ROOT")
    inspect(Path(sys.argv[1]).resolve())
