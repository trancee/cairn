---
status: accepted
date: 2026-10-05
version: pqcble-r1
---

# 0006: Key storage and state persistence

## Context

[ADR 0004](0004-core-architecture.md) has the Rust core emit `Persist(blob, version)` actions and accept a `Restore` event. Kotlin keeps the stored data sealed at rest. [ADR 0002](0002-store-and-forward.md) requires the sealed message and its chain advance to persist atomically, and excludes all of this from backups.

The [threat model](../spec/threat-model.md) puts these limits on what storage can achieve:
- Background BLE must work while the phone is locked.
- An unlocked or forensically extracted phone (A4b) is treated as full compromise.
- Rollback by a rooted OS is out of scope.

Platform floors are Android 8 (API 26) and iOS 15.

## Decision

- **Availability class:** keys are usable after the first unlock since boot.
  - iOS: Keychain `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; database files use `NSFileProtectionCompleteUntilFirstUserAuthentication`.
  - Android: Keystore keys have no user-authentication requirement and no `setUnlockedDeviceRequired`. Data lives in credential-encrypted storage, so nothing runs in Direct Boot.
- **Master key:** one per installation.
  - Android: an AES-256-GCM key in the Keystore, in StrongBox when present (API 28+) and in the TEE otherwise.
  - iOS: a random AES-256 key stored as a `…ThisDeviceOnly` Keychain item. There is no Secure Enclave wrap, which keeps it purely symmetric and PQ-consistent.
  - Neither platform binds the key to biometrics or PIN.
- **Layout:** one SQLite database (SQLDelight), in app-private storage excluded from backups.
  - Tables: `state` (one device row and one row per contact), `queue` (sealed queued messages) and `history`.
  - Kotlin wraps each state row with the master key (AES-GCM, AAD = row id ‖ version).
- **Per-contact storage key:**
  - Each contact's state inside the core holds a **storage key**.
  - The core encrypts history bodies (AES-256-GCM through `CryptoBackend`) and hands Kotlin only ciphertext.
  - No storage key crosses the FFI.
- **Atomicity:** Kotlin applies all `Persist` actions of one `handle()` result in **a single SQLite transaction** before executing any later action. A crash before commit leaves the previous state intact.
- **Backups and migration:**
  - Android: `allowBackup=false`, plus `fullBackupContent` and `dataExtractionRules` (API 31+) that exclude everything.
  - iOS: `ThisDeviceOnly` Keychain items, plus `isExcludedFromBackup` on the database directory.
  - Moving to a new device, or restoring one, requires **re-pairing** every contact.
- **Fresh install on iOS:** if no database exists at launch, delete every `pqcble` Keychain item before creating new ones. This handles Keychain items that survive app deletion.
- **Master-key loss:** if unwrapping fails, there is no fallback to plaintext and no new key is used to keep the old data. The app wipes the database, tells the user "Secure storage was reset; contacts must pair again", and starts over.
- **Contact removal:** one transaction deletes the contact's state row (destroying its storage key), its queue rows and its history rows, then the core rotates the device beacon key ([ADR 0005](0005-wire-format.md)). Physical erasure of flash is not guaranteed; the guarantee rests on destroying the key.
- **History retention:** messages are kept until the user clears them (per contact) or removes the contact. There are no disappearing messages in r1.

## Alternatives considered

- **Secure Enclave ECIES wrap on iOS.** The key could not be extracted, but the wrap is classical P-256: an image extracted today could be unwrapped later with a quantum computer. It also adds little against A4b, which the threat model already treats as full compromise.
- **Layered Keychain + Secure Enclave.** More complexity for marginal gain.
- **Keys bound to biometrics or the unlocked device.** These break background Resume.
- **SQLCipher.** An extra native dependency with its own crypto stack outside the FIPS seam, and it does not cryptographically erase per contact.
- **OS file encryption only.** Contact removal could not erase history cryptographically.
- **Storage keys in Kotlin using platform AES.** A second crypto stack, and secrets in Kotlin memory, against ADR 0004.
- **One blob for everything.** Write amplification grows with the number of contacts, and erasure per contact is impossible.

## Risks

- **Forensic extraction.** After the first unlock, forensic tools may extract the Keychain item or abuse the Keystore key. This is accepted under A4b.
- **Disappearing keys.** Keystore keys can vanish through OEM bugs or OS updates. This forces a full re-pair, which is disruptive but safe.
- **StrongBox speed.** StrongBox is slow on some devices; per-transaction wrap latency needs measuring in the device test lab. If it's too slow, switch to the TEE key for row wrapping.
- **Flash remanence.** SQLite free pages and flash wear-levelling may keep old ciphertext. That ciphertext is useless once the key is gone.
- **Growing history.** Retaining history indefinitely increases A4b exposure over time.

## Migration

This is the first version. Changing the schema uses versioned SQLDelight migrations. Changing the wrapping or availability class requires re-wrapping on first launch after an upgrade, never a silent downgrade.
