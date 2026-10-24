---
status: accepted
date: 2026-10-24
version: cairn-r1
---

# 0024: Seed AWS-LC from the OS CSPRNG only

## Context

`aws-lc-sys` 0.45 builds AWS-LC's CPU jitter entropy source by default. AWS-LC
uses it to seed the root of its tree DRBG, which serves `RAND_bytes`. Every
AWS-LC operation that draws randomness goes through this DRBG: `fill_random`,
ML-KEM-768 and X-Wing key generation, encapsulation, and X25519 key
generation.

When the jitter collector fails its health tests three times in a row,
`tree_jitter_get_root_seed` calls `abort()`. Rust can't catch an abort, so the
app process dies.

During the S2 fleet test
([issue 32](../../.scratch/cairn-r1/issues/32-slice-s2.md)), a Huawei P10 lite
(Kirin 659, Android 8.0) aborted on every launch: five out of five, about
0.7 s after `onCreate`. The same build had run on that phone earlier the same
night. The symbolized trace is:

`CairnCore.handle(Restore)` → `Core::restore` → `AwsLc::fill_random` →
`RAND_bytes` → `get_entropy_source` → `tree_jitter_initialize_once` →
`tree_jitter_get_root_seed` → `abort()`.

Whether the source passes depends on the device's state, so this failure can
hit any phone, at any time.

## Decision

Build AWS-LC without CPU jitter entropy on every target:

- The repository-root `.cargo/config.toml` sets
  `AWS_LC_SYS_NO_JITTER_ENTROPY=1` in `[env]`.
- Cargo reads this file from any working directory in the repository. That
  covers host tests, fuzzing, CI, the Gradle UniFFI build (which runs from
  `core/cairn-ffi`) and the Apple builds.
- AWS-LC then uses its opt-out entropy source. The OS CSPRNG (`getrandom`)
  seeds the DRBG, and the CPU's RNG instruction supplies the extra input where
  one exists. Without one, the OS source supplies it too.
- `core/cairn-crypto/tests/entropy.rs` asserts that
  `aws_lc_rs::try_fips_cpu_jitter_entropy()` fails, so the tests run against
  the same configuration that ships.
- `.cargo/**` is part of the `rust` and `codeql` gate scopes and of the CodeQL
  Kotlin path filter.

We rejected two alternatives:

- **Disable jitter on Android only.** Host tests would then cover a different
  RNG configuration from the shipped one, and iOS could still abort.
- **Keep jitter and report the abort upstream.** That doesn't fix the crash.
  An upstream report remains worth filing separately.

## Consequences

- Randomness now rests only on the OS CSPRNG. That matches ADR 0001's
  "OS CSPRNG now", the threat-model assumption that the OS CSPRNG is secure,
  and the usual policy for mobile platforms. AWS-LC still runs its SP 800-90A
  CTR-DRBG on top of the OS seed.
- The P10 lite starts on every launch: five out of five with the fixed build.
- The non-FIPS build no longer compiles the jitter entropy C sources.
- A future FIPS-validated build would need a new decision, because FIPS
  configurations may require jitter entropy.
