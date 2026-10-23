# Slice S1: Walking skeleton (loopback)

Type: task
Status: open
Blocked by: 26, 30

## Question

Build automatic admission (P0, the tie-break and the admission limits from spec §5.6), TOFU pairing (P1–P4), a basic Resume (spec §6, non-KCI, no rate limits or concurrent Resume) and CHAT DATA frames between two `CairnCore` instances over an in-memory loopback, driven through UniFFI from a KMP test. Rust tests use seeded randomness through a test-only `CryptoBackend`; the KMP loopback uses the real RNG and asserts outcomes. Later slices reuse the harness. Switch on the gates for `cairn-wire` fuzzing and the constant-time taint check on `cairn-proto`.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments

2026-10-23: re-scoped by the owner. Pairing starts automatically for every
stranger ([ADR 0021](../../../docs/adr/0021-automatic-neighbour-admission.md)), and a basic Resume moves here from S7 because DATA keys
come only from Resume. A `CairnCore` contract ADR comes first.

2026-10-23: the contract is [ADR 0022](../../../docs/adr/0022-cairn-core-contract.md).
The owner chose minimal beacons in S1 (the §10.1 value, day ratchet and
constant-time match on the `beacon` read; advertising stays in S6),
`ChatRejected(NoSession)` instead of queuing, and four stacked PRs.

2026-10-23: PR (b) adds the spec §4.2 header to `cairn-wire` and, in
`cairn-proto`, fragmentation and reassembly, the admission ledger and P0
tie-break, P1–P4 pairing and the version-1 persistence blob behind the
`Core` event loop. Persistence moved from PR (c) to PR (b) because the
contact record is what pairing produces. Two cores pair over a seeded
in-memory loopback in `core/cairn-proto/tests/admission.rs`.
