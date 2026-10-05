# Slice S1: Walking skeleton (loopback)

Type: task
Status: open
Blocked by: 26, 30

## Question

Build TOFU pairing (P1–P4) and CHAT DATA frames between two `PqcbleCore` instances over an in-memory loopback, driven through UniFFI from a KMP test. This harness is deterministic, with seeded randomness, and later slices reuse it. Switch on the gates for `pqcble-wire` fuzzing and the constant-time taint check on `pqcble-proto`.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments
