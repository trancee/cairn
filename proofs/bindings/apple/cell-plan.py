import sys

SETUP = ["fixture-targets", "cargo-inputs"]
ISOLATION = [
    "native-tool", "native-compilation", "native-cinterop", "native-linkage",
    "allocator-inputs", "fixture-rust",
]
BINDINGS = ["install-bindgen", "build-bindings", "jvm"]

# Each scope is (needs CodeQL, runs boundary probes, ordered probe list) for
# one bounded cell. The CodeQL lane runs "codeql" and "isolation" as parallel
# cells on separate runners; the isolation cell proves the shared boundary.
PLANS = {
    "full": (False, True, ["toolchains", *SETUP, *ISOLATION, *BINDINGS, "native-binaries"]),
    "codeql": (True, False, [
        "codeql-startup", "toolchain-startup", *SETUP, *BINDINGS, "codeql-analysis",
    ]),
    "isolation": (True, True, ["codeql-startup", "toolchains", *SETUP, *ISOLATION]),
}
SCOPES = tuple(PLANS)


def requires_codeql(scope: str) -> bool:
    return PLANS[scope][0]


def boundary_probes(scope: str) -> bool:
    return PLANS[scope][1]


def probes(scope: str) -> list[str]:
    return list(PLANS[scope][2])


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in PLANS:
        print("FAIL: unknown cell scope", file=sys.stderr)
        return 2
    scope = sys.argv[1]
    print(f"codeql={'true' if requires_codeql(scope) else 'false'}")
    print(f"boundary-probes={'true' if boundary_probes(scope) else 'false'}")
    for probe in probes(scope):
        print(probe)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
