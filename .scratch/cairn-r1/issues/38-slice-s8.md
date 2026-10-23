# Slice S8: In-chat Verify

Type: task
Status: open
Blocked by: 29, 31

## Question

Implement the in-chat Verify upgrade (SAS comparison per the proven SAS model), the Compromised-contact state and contact naming from ADR 0009 as amended by [ADR 0021](../../../docs/adr/0021-automatic-neighbour-admission.md).

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments

2026-10-23: SAS pairing is retired by [ADR 0021](../../../docs/adr/0021-automatic-neighbour-admission.md); only the in-chat Verify
remains, so the block on S4 is dropped.
