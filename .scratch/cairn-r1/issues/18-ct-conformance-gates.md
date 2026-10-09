# Constant-time and conformance CI gates

Type: grilling
Status: resolved
Blocked by: 17

## Question

Which CI gates does the Rust core have to pass before a merge or a release, and on which targets? Decide which tools from the tooling research are mandatory, the vector sets per primitive, fuzz targets and corpus policy (parsers in `cairn-wire`, the record parser, state machines), the thresholds/flakiness policy for timing tests, and which gates run per PR vs nightly vs pre-release.

## Comments

## Answer

Recorded in [ADR 0007: Constant-time and conformance CI gates](../../../docs/adr/0007-ct-conformance-gates.md). The user accepted all recommendations on 2026-10-05. CI runs on GitHub Actions (Linux x86_64/aarch64 and macOS).

**Per PR (blocking):**
- fmt, clippy, tests on both adapters;
- `cargo deny`; Miri and `cargo careful`;
- ACVP and Wycheproof known-answer tests;
- pinned X-Wing vectors from BoringSSL and CIRCL;
- the differential adapter test;
- the **valgrind secret-taint constant-time check**;
- cross-builds and fuzz smoke runs.

**Nightly (advisory):** dudect and 30-minute fuzz runs per target, including a state-machine fuzzer.

**Pre-release:** a full vector sweep, an on-device timing smoke test on the core device matrix, and no open fuzz crashes.
