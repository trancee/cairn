# Key storage and state persistence

Type: grilling
Status: resolved
Blocked by: 15

## Question

How does the KMP shell store the core's Persist blobs and app data at rest on Android 8+ and iOS 15+? Decide: the wrapping-key type (Android Keystore AES-GCM with StrongBox when available vs TEE; iOS Keychain `…ThisDeviceOnly` vs a Secure Enclave–wrapped key), user-auth binding (none / device unlock / biometric), the file layout (one blob vs per-contact), backup exclusion on both platforms, local message-history encryption, the behaviour after reinstall/restore/device migration, rollback detection (the monotonic-counter question from findings §9.3), and secure deletion of a contact.

## Comments

## Answer

Recorded in [ADR 0006: Key storage and state persistence](../../../docs/adr/0006-key-storage.md). The user accepted all recommendations over two rounds on 2026-10-05:
- **Availability:** keys are usable after the first unlock, with no biometric binding, so background operation works.
- **Master key:** Android Keystore AES-256-GCM (StrongBox when available); iOS Keychain AES key (`ThisDeviceOnly`).
- **Layout:** SQLDelight/SQLite; each `Persist` batch is one transaction.
- **History:** encrypted by the core with a per-contact storage key, which makes contact removal a cryptographic erase.
- **Backups and migration:** excluded from backups; re-pairing after migration.
- **iOS fresh install:** purge stale Keychain items.
- **Master-key loss:** wipe and re-pair.
- **Retention:** history is kept until the user clears it.
