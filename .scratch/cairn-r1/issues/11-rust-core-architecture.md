# Rust core architecture and crypto backend seam

Type: grilling
Status: resolved
Blocked by: 03, 05

## Question

How is the Rust core structured: crate boundaries (wire codec, state machines, crypto backend, storage interface, FFI), the seam that isolates the FIPS crypto backend, sans-IO protocol design vs owning transport, the FFI surface exposed to KMP, and how state persistence is delegated to the platform? Outcome: an ADR and module map.

## Answer

Recorded in [ADR 0004 — Core architecture](../../../docs/adr/0004-core-architecture.md) (user, 2026-10-05, two grilling rounds):
- A sans-IO, single-threaded Rust core whose interface is one object: `CairnCore.handle(event) -> actions`. Time is passed in with events, and randomness can be injected for tests.
- A compile-time `CryptoBackend` trait with two adapters: `aws-lc-rs`, and a reference adapter (`mlkem-native` + RustCrypto) for differential testing.
- Persist/Restore actions; Kotlin seals the blob with the platform keystore.
- `zeroize`/`subtle`; no secrets cross the FFI; constant-time CI.
- Monorepo: `core/` (crates `cairn-wire`, `cairn-crypto`, `cairn-proto`, `cairn-ffi`; wire and proto are `no_std`), `sdk/` (KMP), `app/` (Compose Multiplatform).
- Toolchain: Ubique UniFFI plugin + UniFFI, `cargo-ndk` for 3 Android ABIs, a Kotlin/Native XCFramework for iOS (selected in ADR 0004; target proof tracked by issue 44).
