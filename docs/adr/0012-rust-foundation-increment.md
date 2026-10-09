---
status: accepted
date: 2026-10-09
version: cairn-r1
---

# 0012: Host-only Rust foundation increment

## Context

Hosted formal CI is green, but it does not complete composed-ratchet
verification, constant-time evidence or the mobile binding proof. S0 in
[ADR 0004](0004-core-architecture.md) is broader than the first Rust increment.

## Decision

The user approved workspace/public wire codec and symmetric crypto seams on
2026-10-09. Implement only working `cairn-wire` and `cairn-crypto` crates,
with no empty protocol/FFI crates. Pin Rust 1.99.0, currently installed and
verified stable, and commit Cargo.lock. Keep the repository's Unlicense.

The wire boundary follows spec §2.2 and rejects noncanonical u32 LEB128,
truncation, overflow and insufficient output capacity through typed errors.
The crypto boundary implements SHA-384, HMAC-SHA-384 and raw HKDF-SHA-384
using AWS-LC and RustCrypto, selected by Cargo features, with independent
vectors and differential testing. Returned secret buffers zeroize on drop.
Do not introduce new cryptographic constructions.

## Alternatives

Full S0 with KMP/bindings remains blocked on target proof and would obscure
the independent host foundation. Wire-only bootstrap was offered; the user
selected wire plus symmetric crypto. A single provider was rejected by
ADR 0004's differential-testing requirement.

## Risks and gates

The trait is deliberately partial and may evolve before SDK release.
Provider memory handling is not fully verified. Host tests do not establish
constant-time behavior or mobile compatibility, and the non-FIPS adapter is
not a validated mobile module. All applicable gates from
[ADR 0007](0007-ct-conformance-gates.md) and the Constitution still apply;
this increment does not waive them. Open gates are recorded in issue 46.

## Migration

No published APIs, deployed wire behavior or protocol labels change.
The existing formal artifacts remain unchanged. Future KEM/AEAD operations
extend the seam with their own conformance and adversarial evidence before
state-machine integration. This decision authorizes neither S1 nor a release.
