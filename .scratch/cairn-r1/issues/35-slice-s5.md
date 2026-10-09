# Slice S5: Sealed storage and store-and-forward

Type: task
Status: open
Blocked by: 32

## Question

Build sealed persistence per ADR 0006 (master key, SQLDelight `state`/`queue`/`history`, Persist ordering, contact removal as cryptographic erase) and the store-and-forward semantics of ADR 0002: QUEUED, ACK, READ, EXPIRED and the receipts.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments
