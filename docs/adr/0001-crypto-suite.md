---
status: accepted
date: 2026-10-05
version: pqcble-r1
---

# 0001 — `pqcble-r1` cryptographic suite

## Context

`pqcble-r1` must be post-quantum (target NIST category 3), constant-time, and as small on the wire as possible over BLE. "FIPS required" was defined as **FIPS-approved algorithms now**, with a hybrid classical component allowed when ML-KEM is the approved component. The target is a CMVP-validated module later, behind a crypto-backend seam.

As of 2026-10, no validated module covers ML-KEM on both iOS and Android ([FIPS-validated modules research](../research/2026-10-05-fips-validated-mlkem-modules.md)). NIST SP 800-227 §4.6 uses X-Wing as its worked example of an acceptable PQ/T hybrid. X25519 is not an approved SP 800-56A scheme and may only act as the auxiliary secret `T` in SP 800-56C's `Z‖T`. ChaCha20-Poly1305 is not approved ([hybrid combiner research](../research/2026-10-05-fips-hybrid-kem-combiner.md)).

## Decision

A single fixed suite per protocol version: a version byte only, with **no negotiation**.

| Use | Primitive |
|---|---|
| Pairing KEM | **X-Wing** (ML-KEM-768 + X25519, SHA3-256 combiner) |
| PQ ratchet KEM | **ML-KEM-768** (pure) |
| Resume ephemeral exchange | **X25519**, output used only as auxiliary `T`; the approved secret is the KDF over the ML-KEM-rooted chain key |
| KDF / MAC / PRF / transcript hash | **HKDF-SHA-384 / HMAC-SHA-384 / SHA-384**, outputs truncated as needed |
| AEAD | **AES-256-GCM**, 16 B tag; implicit 96-bit nonce. *(Amended by [ADR 0005](0005-wire-format.md): the doorbell is an 8 B truncated HMAC-SHA-384 tag, not an AEAD tag.)* |
| Signatures | **None.** Authentication comes from pairing verification plus MAC/KEM |
| Randomness | **OS CSPRNG** now; the validated backend's SP 800-90A DRBG later |
| KCI-resistant profile | Static ML-KEM-768 key per contact; **opt-in per contact, off by default** |
| Key commitment | None added |

Truncations (all ≥ 64 bits, SP 800-107): pseudonym 8 B, beacon 8 B, Resume MAC 16 B, key confirmation 16 B, doorbell tag 8 B (HMAC, per ADR 0005). The SAS is 6 digits, protected by commit-then-reveal.

## Alternatives considered

- **Pure ML-KEM-768 for pairing:** saves about 64 B once per contact but loses the classical safety net.
- **SHA-256 family:** faster with hardware acceleration, but a SHA-256 transcript hash gives about 128-bit collision resistance, which is category 2, below L3.
- **KMAC256/SHA3-384:** one Keccak codebase shared with ML-KEM, but slower without SHA3 hardware and less common in protocol tooling.
- **P-256 ECDH in Resume:** approved, but +1 B and harder to make constant-time. **No ephemeral:** loses per-session forward secrecy between ratchet epochs.
- **8 B data tags:** small saving that needs forgery-limit bookkeeping.
- **ML-DSA-65 identities:** 1952 B public keys and 3309 B signatures, with no benefit for pairwise, in-person-verified peers.
- **Negotiated suites:** enable downgrade attacks and cost bytes.
- **ChaCha20-Poly1305:** not FIPS-approved.
- **Key-committing AEAD:** partitioning oracles need attacker-influenced keys, which this design doesn't have.

## Risks

- No validated module exists yet, so the only honest claim is "FIPS-approved algorithms", not "FIPS 140-3 validated".
- X25519 contributes defense-in-depth only and is not an approved component.
- 8 B pseudonyms and beacons may collide in lookups. This costs a retry, not security, because the MAC still authenticates.
- AES-GCM nonce reuse is catastrophic. Counters must be strictly monotonic and must never be restored from a backup.
- The KCI profile is off by default, so a compromised device's long-term state can impersonate peers *to* it for contacts without the profile.

## Migration

This is the first suite, so there is nothing to migrate. Any change ships as a new protocol version byte, with no in-band negotiation. Swapping to a validated module happens behind the crypto-backend seam and leaves the wire unchanged.

## Amendments

2026-10-05, from spec consolidation ([`pqcble-r1` spec §13](../spec/pqcble-r1.md#13-consolidation-issues-resolved-2026-10-05)):
- The KCI profile is chosen at pairing only; enabling it later requires re-pairing (OI-12).
- Doorbell keys are two directional keys derived from `RK` (OI-10).
