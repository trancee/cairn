---
status: accepted
date: 2026-10-22
version: cairn-r1
---

# 0019: Host-only AES-256-GCM, X25519 and randomness seam completion

## Context

[ADR 0004](0004-core-architecture.md) lists X25519, AES-256-GCM and random
number generation in `CryptoBackend`. [ADR 0018](0018-kem-backend-increment.md)
used X25519 only inside X-Wing and did not expose it. Spec §2.1 fixes
AES-256-GCM with a 96-bit nonce and a 16-byte tag. Resume uses
`X25519(e, E_peer)` and rejects an all-zero output.
[ADR 0007](0007-ct-conformance-gates.md) requires ACVP and Wycheproof vectors
for AES-256-GCM, and Wycheproof vectors for X25519.

Findings on 2026-10-22:

- The pinned ACVP-Server commit `975de31e` has only `AES-GCM-1.0` sample
  groups. They use 128-bit keys or IV/tag sizes that Cairn does not use, so
  no case applies to AES-256-GCM with a 96-bit IV and a 128-bit tag.
- The NIST CAVP GCMVS static vectors (`gcmtestvectors.zip`) contain 375
  encryption and 375 decryption cases at that size. 191 of the decryption
  cases must fail.
- `aes-gcm` 0.11.1 verifies the tag in constant time before decrypting.
  AWS-LC decrypts first, then compares in constant time; `aws-lc-rs` returns
  no plaintext on failure.

## Decision

The user approved on 2026-10-22 adding to the host-only `CryptoBackend` seam:

- `aes256gcm_seal(key, nonce, aad, plaintext) -> ciphertext ‖ tag`;
- `aes256gcm_open(key, nonce, aad, sealed) -> Zeroizing<Vec<u8>>`;
- `x25519_generate() -> (X25519SecretKey, public)`;
- `x25519(key, public) -> SharedSecret`;
- `fill_random(output)`.

Contract:

- Keys and nonces have fixed types (32-byte key, 12-byte nonce), so other
  sizes are unrepresentable. Callers own nonce uniqueness. The spec's DATA
  and handshake nonce constructions stay in the protocol layer.
- Any tag mismatch, or sealed input shorter than 16 bytes, returns
  `CryptoError::AuthenticationFailed` with no plaintext. Provider internal
  errors return `BackendFailure`.
- X25519 accepts any 32-byte public value and clamps the scalar, per RFC 7748.
  An all-zero output returns `ZeroSharedSecret` (spec §2.1).
  `X25519SecretKey` zeroizes on drop and redacts `Debug`.
- `fill_random` uses the OS CSPRNG (`aws_lc_rs::rand`, `getrandom`).
  ADR 0004's seeded test generator is a protocol-layer injection and is not
  part of this increment.
- The reference adapter adds `aes-gcm` 0.11.1 with the `aes`, `alloc` and
  `zeroize` features only.

Evidence, as pinned in `core/README.md`:

- Both adapters run all CAVP GCMVS AES-256 / 96-bit IV / 128-bit tag cases,
  in both directions. Seal must reproduce `ciphertext ‖ tag`; open must
  reproduce the plaintext or reject `FAIL` cases.
- Both adapters run Wycheproof `aes_gcm_test.json`: 39 valid and 27 invalid
  applicable cases. The 250 cases with other sizes are counted as
  unsupported.
- Both adapters run Wycheproof `x25519_test.json`: 487 agreement cases,
  including RFC 7748 "acceptable" twist and non-canonical inputs, and 31
  cases that must return `ZeroSharedSecret`.
- The tests cover: the wrong AAD or nonce; truncated input; empty plaintext;
  a public key equal to `X25519(sk, 9)`; agreement; cross-adapter
  differential AEAD and X25519; and sanity checks on randomness output.
- The `core/ct` Memcheck harness taints the AES-GCM key and plaintext and
  requires tainted sealing output on both adapters.

## Alternatives

- **ACVP AES-GCM from a newer or generated server run.** Static CAVP vectors
  give fixed known answers at the exact size without registering a
  validation session. Neither source confers validation.
- **A generic `aead` trait object, or a nonce-sequence type.** Nonce policy
  belongs to the protocol layer. A byte-array API keeps both adapters thin.
- **Accepting an all-zero X25519 output and checking in the caller.** That
  would duplicate the spec §2.1 rule at every call site; X-Wing already
  rejects it inside the backend.

## Risks and gates

- AES-GCM opening and X25519 agreement are not under Memcheck taint. Both
  providers branch on the tag verdict and on the X25519 all-zero check. Both
  are public-by-design results that Memcheck cannot declassify inside the
  library: a run with a tainted key was flagged at `e_aes.c:1188` (AWS-LC)
  and at `aes-gcm` `lib.rs:311`. Constant-time behavior for these operations
  relies on upstream evidence.
- Randomness has no known-answer test; only sanity checks of the output.
- None of this is mobile constant-time evidence, ACVP certification or CMVP
  validation. The other ADR 0007 gates still apply; issue 46 tracks them.

## Migration

No wire bytes, protocol labels or published APIs change. This does not
authorize S1, state-machine integration, bindings or a release.
