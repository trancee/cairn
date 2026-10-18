import sys

SETUP = ["fixture-targets", "cargo-inputs"]
ISOLATION = [
    "native-tool", "native-compilation", "native-cinterop", "native-linkage",
    "allocator-inputs", "fixture-rust",
]
BINDINGS = ["install-bindgen", "build-bindings", "jvm"]

# Each scope is the ordered probe list for one bounded cell. The CodeQL lane
# runs "codeql" and "isolation" as parallel cells on separate runners.
PLANS = {
    "full": (False, ["toolchains", *SETUP, *ISOLATION, *BINDINGS, "native-binaries"]),
    "codeql": (True, ["toolchain-startup", *SETUP, *BINDINGS, "codeql-analysis"]),
    "isolation": (True, ["codeql-startup", "toolchains", *SETUP, *ISOLATION]),
}
SCOPES = tuple(PLANS)


def requires_codeql(scope: str) -> bool:
    return PLANS[scope][0]


def probes(scope: str) -> list[str]:
    return list(PLANS[scope][1])


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in PLANS:
        print("FAIL: unknown cell scope", file=sys.stderr)
        return 2
    scope = sys.argv[1]
    print(f"codeql={'true' if requires_codeql(scope) else 'false'}")
    for probe in probes(scope):
        print(probe)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
