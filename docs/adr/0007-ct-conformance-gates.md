---
status: accepted
date: 2026-10-05
version: pqcble-r1
---

# 0007: Constant-time and conformance CI gates

## Context

The [threat model](../spec/threat-model.md) requires the implementation to be constant-time with respect to secrets against software timing observation. [ADR 0004](0004-core-architecture.md) has two `CryptoBackend` adapters: `aws-lc-rs`, and a reference adapter (`mlkem-native` + RustCrypto).

The [tooling research](../research/2026-10-05-ct-conformance-tooling.md) found:
- No available tool verifies constant-time behaviour of the actual Android-NDK or iOS binaries; Valgrind, dudect and Microwalk run on Linux hosts.
- Upstream proofs (AWS-LC SAW, mlkem-native CBMC/HOL-Light/valgrind) are confidence signals for their source, not evidence for our build.
- Draft-11 Appendix C contains numeric X-Wing vectors, but their provenance
  is unspecified; see the [source comparison](../research/2026-10-08-x-wing-draft-11-vectors.md).

## Decision

CI runs on **GitHub Actions**: `ubuntu-latest` (x86_64), `ubuntu-24.04-arm` (aarch64) and `macos-latest` for the iOS cross-builds. No CI runs on real devices.

**Per PR (blocking):**
- `cargo fmt --check`, `cargo clippy -D warnings`, and `cargo test` for all crates with **both** backend adapters.
- `cargo deny check` (advisories, licences, sources) with a committed `Cargo.lock`.
- `cargo miri test` on `pqcble-wire` and `pqcble-proto`, excluding RNG and key-generation paths. `cargo careful test` on `pqcble-crypto` and `pqcble-ffi`.
- **Known-answer tests:**
  - NIST ACVP for ML-KEM-768 keyGen/encapDecap, AES-256-GCM, HMAC-SHA-384 and HKDF (KDA).
  - Wycheproof for AES-GCM, X25519, HKDF, HMAC, and ML-KEM where vectors exist.
  - Both run against both adapters.
- **X-Wing vectors:** draft-11 vectors generated once with BoringSSL (`xwing.h`) and Cloudflare CIRCL, then committed. Both adapters must match both implementations.
- **Differential test:** random inputs through both adapters for every `CryptoBackend` operation. The outputs must be identical.
- **Secret-taint constant-time check:** a valgrind memcheck harness, ctgrind style, marks secrets as undefined. It covers our own code paths:
  - pseudonym and MAC verification;
  - key-confirmation comparison;
  - the AEAD-open path and the record parser over decrypted secrets;
  - the X-Wing combiner glue and the KDF wiring.

  It runs on x86_64 and aarch64 Linux. Any secret-dependent branch or memory index fails the build.
- **Builds:** cross-compile smoke builds for `aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`, `aarch64-apple-ios` and `aarch64-apple-ios-sim`.
- **Fuzz smoke run:** 60 s per fuzz target.

**Nightly (non-blocking, tracked):**
- `dudect-bencher` on the same secret paths. Advisory only, with trends recorded.
- **Fuzzing**, 30 min per target:
  - targets: frame header and reassembly, the record parser, the S1/S2 and P1–P4 parsers;
  - a state-machine fuzzer that sends random event sequences to `PqcbleCore` and checks invariants (no data before Resume, monotonic counters, bounded memory);
  - the corpus lives in `core/fuzz/corpus`, and every crash becomes a regression test.
- If any `mlkem-native` C is vendored, a mirror of its KyberSlash-patched valgrind CT job.

**Pre-release (blocking for any tagged release):**
- A full ACVP and Wycheproof sweep across all families.
- An X-Wing re-check against the latest BoringSSL and CIRCL.
- No open fuzz crashes.
- **On-device timing smoke test:** a dudect-style harness in an instrumented test app on the [device test lab](../../.scratch/pqcble-r1/issues/13-device-test-lab.md) core matrix (arm64 Android and iPhone). It covers X-Wing and ML-KEM decapsulation and MAC verification.
- A documented re-check of whether upstream AWS-LC or mlkem-native now cover Android/iOS targets.

The inventory of vector sources and pinned versions lives with the test harness in `core/`, not in a separate spec.

## Alternatives considered

- **dudect as a blocking gate.** Statistical timing tests on shared runners are noisy; a flaky blocking gate gets ignored.
- **Taint checks advisory only.** Taint checking is deterministic, so blocking costs little and catches regressions in our own glue.
- **X-Wing cross-check only before release.** Pinned vectors are cheap once generated, and catching drift late is expensive.
- **Microwalk or Binsec/Rel.** They target x86 only or are not CI-ready (unverified); they add little beyond the valgrind taint check.
- **Device-farm CI per PR.** Costly and slow, and phone timing noise is worse than on runners. Device testing is limited to pre-release.

## Risks

- **Coverage gap.** Constant-time evidence covers host builds of our code, not the NDK or iOS binaries. Compiler differences, such as a branch introduced on armv7, could slip through. The on-device smoke test is the only mitigation.
- **Valgrind on aarch64.** Some instructions (for example the SHA3 extensions) are unsupported, so the harness must build with the portable code paths.
- **ACVP/Wycheproof drift.** File paths and schemas may change (several were unverified in the research), so pin a commit.
- **Expensive per-PR gates.** Miri and the taint checks may slow PRs. If so, limit them to PRs touching `core/`.

## Migration

This is the first version. Adding gates is non-breaking. Removing or downgrading a blocking gate requires amending this ADR.
