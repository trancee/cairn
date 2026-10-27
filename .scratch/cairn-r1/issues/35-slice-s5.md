# Slice S5: Sealed storage and store-and-forward

Type: task
Status: open
Blocked by: 32

## Question

Build sealed persistence per ADR 0006 (master key, SQLDelight `state`/`queue`/`history`, Persist ordering, contact removal as cryptographic erase) and the store-and-forward semantics of ADR 0002: QUEUED, ACK, READ, EXPIRED and the receipts.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments

2026-10-27: the owner treats S2's blocker as satisfied for S5's core work and
chose the rules in [ADR 0034](../../../docs/adr/0034-store-and-forward-core.md)
(spec OI-38, draft 0.17). Order: (1) Rust core and FFI/Kotlin contract with
row persistence and an in-memory store; (2) SQLDelight sealed storage per
ADR 0006; then couriers (issue 54).

2026-10-28: step 1 implemented on `feat/s5-store-and-forward-core`: the core
holds QUEUED chats, ACK/READ/EXPIRED notices and the four row actions; the
FFI, the Kotlin `RowStore` and the Android app adopt them. Rust and Kover
coverage are 100%. Steps 2 (SQLDelight) and the device demonstration remain.

2026-10-29: step 2a on `feat/s5-sealed-storage`:
[ADR 0035](../../../docs/adr/0035-sealed-row-storage.md) fixes the sealed row
format, AAD and wipe-on-failure rule. The SDK gains the `Rows` and `RowSealer`
seams and a SQLDelight `SealedRowStore`. `LinkDriver` commits one result's row
actions in a single transaction before its other actions, and reports
`STORAGE_RESET`. The app still uses the in-memory `RowStore`. Remaining work:
the Android Keystore sealer (2b), the iOS CryptoKit sealer (2c) and the device
demonstration.
