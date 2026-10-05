# Constant-time and conformance tooling for the Rust core

Type: research
Status: resolved
Blocked by: 

## Question

Which tools can gate constant-time behaviour and conformance for the Rust core in CI, on which targets? Survey: dudect-bencher / dudect for Rust; valgrind/ctgrind and memcheck secret-taint (x86_64 and aarch64 Linux); Binsec/Rel and other binary-level checkers; `cargo-careful`/Miri; fuzzing (`cargo-fuzz`, AFL++); test vectors: ACVP/CAVP JSON for ML-KEM-768, AES-256-GCM, HKDF/HMAC-SHA-384, the X-Wing draft-11 vectors, Wycheproof for AES-GCM/X25519/HKDF/HMAC/ML-KEM. Also: what `aws-lc-rs` and `mlkem-native` already prove (CBMC, HOL-Light, SAW), which of those claims transfer to our build flags/targets, and the practical runtime/flakiness of dudect on GitHub-hosted runners. Output a recommended CI gate list.

## Comments

## Answer

Findings: [constant-time and conformance tooling](../../../docs/research/2026-10-05-ct-conformance-tooling.md).

- No tool verifies constant-time behaviour of the actual Android or iOS binaries. Valgrind CT checks, SAW/HOL-Light/CBMC proofs and Microwalk all run on Linux x86_64/aarch64 only.
- Upstream proofs (AWS-LC, mlkem-native) are confidence signals, not evidence for our own builds.
- Candidate gates:
  - **Per PR:** `cargo careful`, Miri on `pqcble-wire`/`pqcble-proto`, ACVP (ML-KEM-768) and Wycheproof (AES-GCM/HKDF/HMAC/X25519, plus ML-KEM if its vectors are confirmed) against both adapters, and a cross-compile smoke build for all targets.
  - **Nightly:** advisory `dudect-bencher`, `cargo fuzz`, and a valgrind CT job for vendored C.
  - **Pre-release:** a full vector sweep and an X-Wing cross-check against BoringSSL/CIRCL, because the draft ships no vectors.
- Biggest gap: there is no on-device CT verification. That feeds *Constant-time and conformance CI gates*.
