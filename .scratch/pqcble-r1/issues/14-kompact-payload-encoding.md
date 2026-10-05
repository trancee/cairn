# Kompact suitability for pqcble payload encoding

Type: research
Status: resolved
Blocked by:

## Question

Can [Kompact](https://github.com/trancee/kompact), a KMP library for LSB-first bit-packed messages, shrink `pqcble-r1` payloads, and where should it sit? Specifically:
- Its wire format: fixed vs framed layouts, length/count prefixes, varints, optional fields.
- Byte savings against a hand-designed byte-aligned layout for: Resume S1/S2, data frame header, ratchet chunk carriage, beacon, doorbell, chat message envelope.
- Maturity: version, tests, fuzzing, checked-decode guarantees, allocation behavior, KMP targets incl. iOS.
- Fit with a Rust core that owns the protocol codec. Options: Kompact for app-layer plaintext only; a Rust port or compatible implementation of its format; generating both sides from one schema.
- Security: parsing only after AEAD verification, length leakage vs padding classes, malformed-input handling.

## Comments

Findings: ../../../docs/research/2026-10-05-kompact-payload-encoding.md — Kompact (v0.6.1, 5 weeks old, single-maintainer, LSB-first bit-packing, no varint, no entropy coding, no versioning story) saves **0 bytes** on every already-sketched message (S1, S2, data-frame header, doorbell, beacon) because those are already minimal byte-aligned headers in front of high-entropy keys/MACs/ciphertext; a 1–2 byte doorbell-counter trim is the only quantifiable gain and it's airtime-irrelevant (no PDU boundary crossed). The only place it could plausibly help — the undesigned chat envelope's optional fields — is better served by a hand-rolled presence bitmap in Rust, with no cross-language spec-drift or supply-chain risk. Recommendation: don't adopt it for the Rust/Kotlin codec layer; at most, consider it as optional Kotlin-only polish for post-AEAD chat-envelope parsing.

## Answer

**Don't adopt Kompact for the protocol wire codec.** It saves 0 B on Resume, data frames and beacons, which are high-entropy keys, MACs and ciphertext. It saves only 1–2 B on the doorbell, below any PDU boundary. It is Kotlin/KSP-only with no independent byte-level spec, so the Rust core would need to shadow-maintain a port. It is 5 weeks old, has no fuzzing, and iOS behavior is untested in CI. It does no entropy coding, so there is no compression-oracle risk. The only place where bit-packing could help is the not-yet-designed chat envelope; a presence-bitmap layout in the Rust codec covers that. Detail: [findings](../../../docs/research/2026-10-05-kompact-payload-encoding.md).
