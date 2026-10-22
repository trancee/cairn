# Slice S0: Bootstrap

Type: task
Status: claimed
Blocked by: 44

## Question

Create the root Gradle build (`settings.gradle.kts` with `:sdk` and `:app`, plus a version catalog) and the `core/` Cargo workspace from ADR 0004, with Ubique UniFFI wiring and `rust-toolchain.toml`. Implement the `CryptoBackend` trait with the `aws-lc-rs` and reference adapters. Switch on the ADR 0007 gates for this code: fmt, clippy, tests, `cargo deny`, Miri, ACVP, Wycheproof, X-Wing vectors and the differential test. Fill the verified `PROJECT.md` profile. No protocol logic.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments

2026-10-22: the KEM part of the `CryptoBackend` trait is implemented
host-only under [ADR 0018](../../../docs/adr/0018-kem-backend-increment.md).
ACVP, Wycheproof, X-Wing vectors and differential tests are now on, subject
to the `aws-lc-rs` KAT limits recorded there. Gradle/UniFFI wiring and the
device demonstration are not done, so S0 remains incomplete (see issue 46).
