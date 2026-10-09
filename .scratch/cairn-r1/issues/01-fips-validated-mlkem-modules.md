# FIPS-validated modules providing ML-KEM for Rust, Android and iOS

Type: research
Status: resolved
Blocked by:

## Question

Which CMVP-validated (or in-process) FIPS 140-3 cryptographic modules provide ML-KEM-768 (plus AES-256-GCM, HKDF/KMAC, SHA-2/3, and ideally X25519/ECDH) and can be embedded in a Rust core shipped inside an Android app and an iOS app? For each candidate (e.g. AWS-LC-FIPS via `aws-lc-rs`, BoringCrypto, Apple corecrypto/CryptoKit, OpenSSL 3.5 FIPS provider, wolfCrypt FIPS, Android Conscrypt/BoringSSL): certificate number and status, which algorithms are inside the boundary, supported platforms/architectures (aarch64 iOS, Android arm64/x86_64), minimum OS, licensing, constant-time evidence, and the operational constraints for claiming 'uses a validated module' (operating environment, self-tests, approved mode).

## Comments

- 2026-10-05 research: findings in [docs/research/2026-10-05-fips-validated-mlkem-modules.md](../../../docs/research/2026-10-05-fips-validated-mlkem-modules.md)

The prior claim ("no active cert covers ML-KEM, AWS-LC v4.0 is in process") is outdated: AWS-LC 3 Cryptographic Module (static), cert 5314, AWS-LC FIPS 3.1.0, has been Active since 2026-06-05 and does include ML-KEM-512/768/1024. The real gap is operating-environment coverage, not algorithm support: every ML-KEM-capable Active certificate (AWS-LC 3.1.0 cert 5314; SafeLogic CryptoComply/AWS-LC cert 5525) is tested only on Amazon Linux 2023 EC2 server instances, with no Android/iOS OE, tested or vendor-affirmed. Conversely, every certificate with a real mobile OE (BoringCrypto on Android via Zebra/Samsung/Motorola/SafeLogic rebuilds, wolfCrypt on Android, Apple corecrypto on iOS) has no ML-KEM. Apple's "corecrypto Module OS 26" (the version aligned with CryptoKit's ML-KEM/X-Wing APIs) is still In Process on the MIP list, not yet Active, so even its eventual algorithm boundary is unverified. No candidate today supports a legitimate "validated module" claim on both iOS and Android from a Rust core; the honest interim claim is "FIPS-approved algorithms, no validated module yet," which matches the project's backend-seam design.

## Answer

No CMVP module today supports a legitimate "validated module" claim for ML-KEM on **both** iOS and Android from a Rust core. AWS-LC 3 (cert 5314, Active 2026-06-05) includes ML-KEM, but its tested environments are Amazon Linux servers only. The mobile-tested certificates (BoringCrypto on Android, wolfCrypt, Apple corecrypto) lack ML-KEM, and Apple's OS-26 corecrypto with ML-KEM is still In Process. Interim claim: "FIPS-approved algorithms, no validated module yet". Keep the backend seam and re-check `aws-lc-rs` FIPS and Apple corecrypto later. Detail: [findings](../../../docs/research/2026-10-05-fips-validated-mlkem-modules.md).
