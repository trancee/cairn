---
status: accepted
date: 2026-10-05
version: pqcble-r1
---

# 0004 — Core architecture: sans-IO Rust core, crypto backend seam, KMP shell

## Context

The `pqcble` SDK ships on Android (API 26+) and iOS (15+) behind a Kotlin Multiplatform + Compose Multiplatform shell. Bindings use UniFFI through Ubique's Kotlin Multiplatform plugin. The core API remains synchronous and sans-IO; binding-runtime async behavior is not part of its contract. BLE is platform code, because no KMP library covers peripheral, GATT server and L2CAP together. Two constraints shape the core:

- FIPS: approved algorithms now, and a validated module later behind a seam ([ADR 0001](0001-crypto-suite.md)).
- Formal verification gates Resume, the ratchet and SAS. The implementation must therefore be deterministic and testable against those models.

On 2026-10-08, the user selected Ubique's binding plugin to replace Gobley. Gobley remains maintained, but its released UniFFI/Kotlin/AGP toolchain is substantially behind current supported versions; Ubique `1.3.1` supports UniFFI `0.32.0` and advertises multi-module bindings. The choice changes Gradle integration and generated runtime dependencies, not protocol behavior or wire formats. The smaller adoption base, dependency/license review, and unverified iOS 15 floor remain explicit risks; issue 44 is the required target proof.

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

**Rust/Kotlin bindings.** Use Ubique's unified UniFFI Kotlin Multiplatform plugin (`ch.ubique.uniffi.plugin`) at `1.3.1`, with UniFFI `0.32.0`. This replaces Gobley. Keep the plugin-managed runtime and generated dependencies together at `1.3.1`; do not add Gobley's separate Cargo/Rust/UniFFI plugins or atomicfu compiler-plugin setup.

The first bootstrap must prove the generated API through a real Kotlin call on the JVM, Android API 26+, and iOS device/simulator targets with an iOS 15 deployment floor before the binding choice is considered validated for production. The iOS 15 floor is not yet verified; track the build proof in [issue 44](../../.scratch/pqcble-r1/issues/44-ubique-binding-smoke-test.md).

**Layout (monorepo):**

```
core/   Cargo workspace
  pqcble-wire    codec; no_std; fuzzed
  pqcble-crypto  CryptoBackend trait + adapters
  pqcble-proto   state machines; no_std + alloc
  pqcble-ffi     UniFFI surface (PqcbleCore, Event, Action)
sdk/    KMP library: Ubique UniFFI bindings, BLE adapters (Kable central; native peripheral/GATT server), sealed storage
app/    Compose Multiplatform reference app
```

**Toolchain.**
- Rust stable, with the MSRV pinned in `rust-toolchain.toml`.
- Ubique plugin/runtime/bindgen `1.3.1` and UniFFI `0.32.0`.
- Kotlin stable, per [`guidance/kotlin.md`](../../guidance/kotlin.md).
- The verified fully-supported Kotlin/Gradle/AGP overlap is Kotlin `2.4.20`, Gradle `9.6.1`–`9.7.0`, and AGP `9.3.1`; use a compatible wrapper rather than the installed Gradle `9.7.1`.
- `cargo-ndk` for arm64-v8a, armeabi-v7a and x86_64.
- A Kotlin/Native XCFramework for iOS arm64 and simulator arm64.

## Alternatives considered

- **The core owns transport and timers through callback traits.** This would push async and cancellation across UniFFI, and the core would stop being deterministic.
- **One FFI object per contact or session.** A larger interface with more locks, and no gain.
- **A single crypto backend now, with the trait added later.** A seam with only one adapter is hypothetical, and backend bugs would go uncaught without differential tests.
- **Core-owned encrypted SQLite.** Breaks the sans-IO design and moves key custody away from the OS keystore.
- **Separate repositories.** Coordinated wire and FFI changes would span repositories.
- **Gobley bindings.** Retain a larger adoption base and longer history, but its released toolchain lags the current UniFFI/Kotlin/AGP tuple. Do not integrate both forks; revisit only if Ubique fails the iOS 15 proof.

## Risks

- **Ubique integration maturity.** It has a smaller adoption base than Gobley, and its iOS 15 deployment-target compatibility is unverified. Recent iOS framework-linking regressions were reported and fixed in `1.3.0`/`1.3.1`; issue 44 must pass before this integration is treated as validated. JNI/cinterop remains the fallback for anything UniFFI cannot express.
- **Inline crypto.** ML-KEM on the serial dispatcher could add latency on low-end Android 8 devices. Measure it in the device test lab.
- **Persist blob growth.** One blob per state change could become large. A per-contact blob split may be needed later; that is a change on the Kotlin side only.
- **`aws-lc-rs` on mobile.** Cross-compiling it needs CMake/NDK toolchains in CI, and its FIPS build may not support every ABI, armeabi-v7a in particular.

## Migration

No released SDK consumers exist. The binding-generator choice changes build integration and generated Kotlin/runtime dependencies, not the Rust protocol or wire contract. Switching generators again before release requires replacing the Gradle integration and revalidating every generated target. Changing the `Event`/`Action` FFI surface is a breaking SDK change and needs a major SDK version.
