# Rust foundation gate completion

Type: task
Status: open
Blocked by: 44

## Scope

The user approved a host-only workspace/wire/symmetric-crypto increment on
2026-10-09, with public wire encoding and crypto backend seams. No state
machines or bindings are authorized by this increment. S0 is not complete.

## Evidence and outstanding gates

Local Rust 1.99.0 tests, clippy, cargo-deny 0.20.2, wire Miri and crypto
careful 0.4.10 (nightly-2026-10-08) pass on macOS ARM64. Both adapters pass
83 HKDF and 174 HMAC Wycheproof cases. CI is configured for three host
platforms, but has not executed for this increment.

Nightly branch coverage measured by cargo-llvm-cov 0.9.1 is 100% for wire
lines/branches and 100% of recorded crypto branches, but only 86.36% of
crypto lines in the first measurement; after diagnostic tests, coverage is
93.94%. The four uncovered lines translate provider errors. An independent failure-capable seam is needed before claiming
full line coverage; do not suppress production code or inject fixture-only
failures. This is a Constitution T3 pre-merge blocker.

The wire fuzz smoke completed 57,843,345 executions in 61 seconds on macOS
ARM64 (cargo-fuzz 0.13.2, nightly-2026-10-08, seed 20261009, max_len 65540)
without a crash. Corpus and fuzz lockfile are retained; Linux x86-64/ARM64
smokes are configured but not yet run.

Provider source investigation: RustCrypto HMAC `new_from_slice` accepts any
key length; RustCrypto HKDF rejects only output longer than 255 digest
blocks. The wrapper already validates that bound. AWS-LC expansion rejects
the same bound and fill rejects output/key length mismatch, neither of
which valid wrapper calls permit. Native fill errors must still fail closed.
These paths must not be fabricated or suppressed for a coverage number.

Outstanding ADR 0007 gates: ACVP ingestion for implemented primitives,
secret-taint checks for own cryptographic glue and mobile cross-builds.
CI enforces 100% source line/branch coverage,
so the currently measured crypto gap must block it. Binding deployment
floors/device proofs remain issue 44 and S0 obligations. Independent protocol
review and the composed-ratchet gate also remain open.

Done when the applicable ADR 0007 and Constitution gates are green, the
CI results are recorded, and PROJECT/core documentation agrees with them.
