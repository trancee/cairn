# Slice S9: PQ ratchet

Type: task
Status: open
Blocked by: 28, 37

## Question

Implement the PQ ratchet per the proven ratchet model: KEM_EK/KEM_CT chunks in bucket slack, with a completed epoch mixed into CK at the next Resume.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments
