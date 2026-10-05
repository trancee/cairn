---
status: accepted
date: 2026-10-05
version: pqcble-r1
---

# 0004 — Core architecture: sans-IO Rust core, crypto backend seam, KMP shell

## Context

The `pqcble` SDK ships on Android (API 26+) and iOS (15+) behind a Kotlin Multiplatform + Compose Multiplatform shell. Bindings use UniFFI via Gobley; UniFFI async has no cancellation ([toolchain research](../research/2026-10-05-kmp-rust-ble-toolchain.md)). BLE is platform code, because no KMP library covers peripheral, GATT server and L2CAP together. Two constraints shape the core:

- FIPS: approved algorithms now, and a validated module later behind a seam ([ADR 0001](0001-crypto-suite.md)).
- Formal verification gates Resume, the ratchet and SAS. The implementation must therefore be deterministic and testable against those models.

## Decision

**Sans-IO core.** The Rust core is a pure, deterministic state machine. Its whole interface is one object:

```
PqcbleCore.handle(event: Event) -> List<Action>   // plus read-only queries (contacts, verification state)
```

- **Events** include link up/down, bytes received, timer fired, user sent, Restore and pairing input.
- **Actions** include send bytes, set/cancel timer, Persist, deliver message, update receipts and disconnect.
- Kotlin owns BLE, timers, storage and threads. The core never does I/O.
- **Threading.** The core is single-threaded. Kotlin calls it from one serial dispatcher, and expensive crypto (ML-KEM) runs inline.
- **Time and randomness.** Every event carries a monotonic `now` in milliseconds, plus a wall-clock day where beacons need it. Randomness comes from the crypto backend. Tests inject a seeded deterministic generator through the same trait.
- **Persistence.**
  - The core emits `Persist(blob, version)` actions, and Kotlin seals the blob with a platform-keystore key (Android Keystore, iOS Keychain) outside backups.
  - State is loaded from a `Restore` event.
  - Kotlin must finish a `Persist` before executing any later action from the same batch; this is how ADR 0002's atomicity rule is enforced.
- **Crypto backend seam.** A Rust trait `CryptoBackend` covers X-Wing, ML-KEM-768, X25519, HKDF/HMAC/SHA-384, AES-256-GCM and random number generation. It is selected at compile time by a Cargo feature, with two adapters from day one:
  - `aws-lc-rs`, a non-FIPS build now; its FIPS build when a certificate covers mobile;
  - a reference adapter (`mlkem-native` + RustCrypto) used for differential testing.

  Known-answer tests (ACVP/CAVP) and Wycheproof vectors run against both.
- **Secret hygiene.**
  - Secrets live in `zeroize`-on-drop types and never cross the FFI, apart from the sealed persistence blob.
  - Secret comparisons use `subtle`.
  - `pqcble-proto` and the adapters get constant-time CI gates (valgrind taint / dudect).

**Layout (monorepo):**

```
core/   Cargo workspace
  pqcble-wire    codec; no_std; fuzzed
  pqcble-crypto  CryptoBackend trait + adapters
  pqcble-proto   state machines; no_std + alloc
  pqcble-ffi     UniFFI surface (PqcbleCore, Event, Action)
sdk/    KMP library: Gobley bindings, BLE adapters (Kable central; native peripheral/GATT server), sealed storage
app/    Compose Multiplatform reference app
```

**Toolchain.**
- Rust stable, with the MSRV pinned in `rust-toolchain.toml`.
- Gobley and UniFFI at matching versions.
- Kotlin stable, per [`guidance/kotlin.md`](../../guidance/kotlin.md).
- `cargo-ndk` for arm64-v8a, armeabi-v7a and x86_64.
- A Kotlin/Native XCFramework for iOS arm64 and simulator arm64.

## Alternatives considered

- **The core owns transport and timers through callback traits.** This would push async and cancellation across UniFFI, and the core would stop being deterministic.
- **One FFI object per contact or session.** A larger interface with more locks, and no gain.
- **A single crypto backend now, with the trait added later.** A seam with only one adapter is hypothetical, and backend bugs would go uncaught without differential tests.
- **Core-owned encrypted SQLite.** Breaks the sans-IO design and moves key custody away from the OS keystore.
- **Separate repositories.** Coordinated wire and FFI changes would span repositories.

## Risks

- **Gobley maturity.** It has no integrated Rust debugger and a known `chkstk_darwin` linker pitfall. JNI/cinterop remains the fallback for anything UniFFI can't express.
- **Inline crypto.** ML-KEM on the serial dispatcher could add latency on low-end Android 8 devices. Measure it in the device test lab.
- **Persist blob growth.** One blob per state change could become large. A per-contact blob split may be needed later; that is a change on the Kotlin side only.
- **`aws-lc-rs` on mobile.** Cross-compiling it needs CMake/NDK toolchains in CI, and its FIPS build may not support every ABI, armeabi-v7a in particular.

## Migration

This is the first version, so nothing to migrate. Swapping the crypto backend is a build-time feature change with no wire impact. Changing the `Event`/`Action` FFI surface is a breaking SDK change and needs a major SDK version.
