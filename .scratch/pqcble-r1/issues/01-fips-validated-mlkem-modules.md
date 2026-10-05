# FIPS-validated modules providing ML-KEM for Rust, Android and iOS

Type: research
Status: open
Blocked by:

## Question

Which CMVP-validated (or in-process) FIPS 140-3 cryptographic modules provide ML-KEM-768 (plus AES-256-GCM, HKDF/KMAC, SHA-2/3, and ideally X25519/ECDH) and can be embedded in a Rust core shipped inside an Android app and an iOS app? For each candidate (e.g. AWS-LC-FIPS via `aws-lc-rs`, BoringCrypto, Apple corecrypto/CryptoKit, OpenSSL 3.5 FIPS provider, wolfCrypt FIPS, Android Conscrypt/BoringSSL): certificate number and status, which algorithms are inside the boundary, supported platforms/architectures (aarch64 iOS, Android arm64/x86_64), minimum OS, licensing, constant-time evidence, and the operational constraints for claiming 'uses a validated module' (operating environment, self-tests, approved mode).
