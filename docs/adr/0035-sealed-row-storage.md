---
status: accepted
date: 2026-10-27
version: cairn-r1
---

# 0035: Sealed row storage in the SDK

## Context

[ADR 0034](0034-store-and-forward-core.md) §5 step 2 replaces the SDK's
in-memory `RowStore` with the sealed SQLite storage of
[ADR 0006](0006-key-storage.md). The core emits four row actions:
`PersistDevice`, `PersistContact`, `PutQueued` and `DeleteQueued`.
`Restore` takes every row back.

ADR 0006 says Kotlin wraps each row with the master key using AES-GCM,
with AAD = row id ‖ version. It leaves three things open:

- Which code holds and uses the master key. Kotlin/Native has no public
  AES-GCM API on iOS. CommonCrypto's GCM functions are not public API.
- The exact AAD.
- How "all `Persist` actions of one `handle()` result" maps onto the four
  row actions.

## Decision

### 1. The sealing seam

The SDK seals and opens rows through a `RowSealer` interface. Each
platform implements it with its own AES-256-GCM:

- **Android:** a non-exportable Keystore key, in StrongBox when present
  (ADR 0006). The key never enters app memory.
- **iOS:** CryptoKit `AES.GCM`, with the key read from the
  `…ThisDeviceOnly` Keychain item. The key stays in Swift.

The master key never crosses into Kotlin common code or the Rust core.

A sealed row is `nonce(12) ‖ ciphertext ‖ tag(16)`. The platform draws a
random 96-bit nonce for every seal. A device writes far fewer rows than
the 2^32 seals NIST SP 800-38D allows under one key with random nonces.

### 2. Binding a row to its slot

```
AAD = "cairn row v1" ‖ kind(1) ‖ u64be(contact) ‖ u32be(msgno) ‖ u32be(version)
```

`kind` is 0 for the device row, 1 for a contact row and 2 for a queued
row. Fields a kind lacks are zero. A row copied into another slot, or
relabelled with another version, fails to open.

### 3. Schema

One SQLDelight database with three tables: `device` (at most one row),
`contact` (keyed by contact id) and `queued` (keyed by contact id and
`msgno`). Each row stores `version` in clear and the sealed blob.
`history` waits until the core produces history rows.

### 4. Atomicity

The driver commits every row action of one `handle()` result in a single
SQLite transaction before it executes any other action of that result.
A row is therefore stored before any `Send` in the same result reveals
data that depends on it. A crash before the commit leaves the previous
rows intact.

If the commit fails, the exception propagates and nothing else in the
result runs.

### 5. Unreadable storage

If any row fails to open during restore, the store deletes every row and
restores an empty state. The driver reports a `STORAGE_RESET` fault, and the
app tells the user that contacts must pair again (ADR 0006, "Master-key
loss"). There is no fallback to plaintext and no partial restore.

## Formal model

No model changes. Storage at rest is outside the Dolev-Yao models. The
threat model treats an unlocked or extracted phone (A4b) as full
compromise, and OS rollback is out of scope.

## Consequences

- The SDK depends on the SQLDelight runtime. Each app supplies a driver
  and a `RowSealer`.
- `LinkDriver` takes its row store as a constructor parameter. The
  in-memory `RowStore` remains for tests.
- A restore reads and opens every row. That cost grows with queued
  messages, which are bounded by contacts × 500.
- On Android, every commit seals rows synchronously on the session thread,
  which is the main looper. StrongBox seals are slow on some devices
  (ADR 0006 risk). The device demonstration measures commit latency. If it
  is too slow, the store moves to a worker thread or the key moves to the TEE.
- On iOS, `KeychainRowSealer` and `RowStorage` live in the Swift host app,
  because the CodeQL inventory rejects iOS-only Kotlin (ADR 0015). XCTest
  covers them on a simulator, but they are outside CI and the coverage gates.
- A single corrupt row resets all storage. This favours a clean failure
  over guessing which state is still consistent.

## Rejected alternatives

- **Seal rows in Rust.** On iOS the master key would cross the FFI, and
  the Rust core would hold a second long-lived secret.
- **SQLCipher.** Rejected in ADR 0006: an extra crypto stack, and no
  per-contact erasure.
- **AES-GCM in Kotlin common code.** A third crypto implementation, with
  the master key in managed memory.
- **One transaction per row action.** A crash between actions of one
  result could leave the chain advanced without its queued message.
- **Skipping unreadable rows.** Partial state can reuse a chain index or
  lose a contact silently.
