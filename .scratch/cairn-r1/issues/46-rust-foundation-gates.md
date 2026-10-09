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
failures.

Follow-up (user approved the typed provider-error conversion seam):
`From` implementations map genuine provider HKDF length failures and the
documented defensive HMAC length error to `CryptoError::BackendFailure`.
Tests cover that public contract. Both crates now have 100% measured source
line and recorded branch coverage. Four error-propagation regions remain
uncovered (crypto region coverage 94.81%); line coverage does not establish
that errors occurred inside valid adapter calls. No suppression was added.

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
CI enforces 100% source line/branch coverage, which now passes locally.
Binding deployment
floors/device proofs remain issue 44 and S0 obligations. Independent protocol
review and the composed-ratchet gate also remain open.

Done when the applicable ADR 0007 and Constitution gates are green, the
CI results are recorded, and PROJECT/core documentation agrees with them.

HMAC ACVP follow-up: both adapters pass all 150 AFT cases from the official
NIST ACVP-Server HMAC-SHA2-384-2.0 corpus at commit
`975de31eb83d87039ec88934fdc47d8c312b892d`. Prompt/results and NIST notice
are retained unchanged with checksums in core/README.

HKDF KDA follow-up: the owning extraction script validates both upstream
checksums and retains all 100 SHA2-384 single-expansion cases (50 AFT/50 VAL)
from KDA-HKDF-Sp800-56Cr2 at the same NIST commit. Both adapters pass,
including accepted/rejected VAL cases. Fixed info follows upstream
`FixedInfo.cs` (U party info || V party info || u32 output-bit length);
shared input is Z || T. Selected group contents are unchanged and the
subset notice records the modification. Multi-expansion coverage remains
open; no full-corpus or certification claim is made.
