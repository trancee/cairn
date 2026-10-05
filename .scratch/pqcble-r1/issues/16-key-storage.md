# Key storage and state persistence

Type: grilling
Status: open
Blocked by: 15

## Question

How does the KMP shell store the core's Persist blobs and app data at rest on Android 8+ and iOS 15+? Decide: the wrapping-key type (Android Keystore AES-GCM with StrongBox when available vs TEE; iOS Keychain `…ThisDeviceOnly` vs a Secure Enclave–wrapped key), user-auth binding (none / device unlock / biometric), the file layout (one blob vs per-contact), backup exclusion on both platforms, local message-history encryption, the behaviour after reinstall/restore/device migration, rollback detection (the monotonic-counter question from findings §9.3), and secure deletion of a contact.

## Comments
