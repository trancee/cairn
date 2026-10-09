# Crypto suite and parameter set under FIPS

Type: grilling
Status: resolved
Blocked by: 01, 02

## Question

Given the charting decision that 'FIPS required' means **FIPS-approved algorithms now, hybrid with X25519 allowed via a SP 800-56C/227-conformant combiner with ML-KEM as the approved component, and a CMVP-validated module as the later target behind a backend seam**, which concrete primitive set does `cairn-r1` use: KEM/hybrid combiner for pairing, resume DH/KEM, KDF, MAC, AEAD, tag lengths (16 B vs compact 8 B), PRF for pseudonyms/beacons? Outcome: an ADR fixing the suite.

## Answer

Recorded in [ADR 0001 — cairn-r1 cryptographic suite](../../../docs/adr/0001-crypto-suite.md) (user, 2026-10-05, two grilling rounds):
- X-Wing for pairing; pure ML-KEM-768 for the ratchet.
- X25519 in Resume as auxiliary `T` only.
- HKDF/HMAC/SHA-384.
- AES-256-GCM with 16 B tags (doorbell 8 B).
- No signatures; OS CSPRNG.
- One fixed suite per version byte, no negotiation.
- 8 B pseudonyms and beacons.
- KCI profile opt-in per contact.
- No key commitment.

Glossary started at [`GLOSSARY.md`](../../../GLOSSARY.md).
