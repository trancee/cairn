---
status: accepted
date: 2026-10-22
version: cairn-r1
---

# 0020: Root Gradle build, interim wire FFI surface and Android-first binding lane

## Context

[ADR 0004](0004-core-architecture.md) plans `core/cairn-ffi`, a KMP `sdk/`
and a Compose Multiplatform `app/`, bound with Ubique's UniFFI plugin. Until
now only the `proofs/bindings` fixtures exercised that plugin. The
repository had no root Gradle build. Slice S0 ([issue 30](../../.scratch/cairn-r1/issues/30-slice-s0.md))
needs that build, and [issue 44](../../.scratch/cairn-r1/issues/44-ubique-binding-smoke-test.md)
needs a proof through the planned module boundary.

`CairnCore`, the planned single-object surface, does not exist yet, because
the protocol state machines are unimplemented. The existing public Rust API
with no secrets is the `cairn-wire` codec and `cairn-proto`'s
`IncomingObject` chunk reassembly.

Findings on 2026-10-22:

- Ubique `1.3.2` (tag commit `0a901a3d`) is the latest stable release. It
  still uses UniFFI `0.32.0`.
- UniFFI's default features pull in `cargo_metadata`. Ubique's bindgen does
  not need it from the library crate.
- The six `uniffi*` crates are MPL-2.0, which `core/deny.toml` did not allow.
- `serde_derive` `1.0.229` moved to `syn` 3. `cargo deny` then rejects the
  duplicate `syn` 2/3 graph.
- UniFFI errors must implement `Display`. The orphan rule forbids adding
  that for `cairn_wire::WireError` from `cairn-ffi`.
- With AGP `9.3.1`, Ubique builds the host library for Android host tests
  (`mergeUniffiAndroidHostTestResources`), but `processAndroidHostTestJavaRes`
  never puts it on the test classpath. All host tests failed with
  `UnsatisfiedLinkError` (`linux-x86-64/libcairn_ffi.so` not found).
  Upstream's only host test does not load a crate library.

## Decision

The user approved the following on 2026-10-22.

**Tuple.** Update the toolchain tuple. This amends ADR 0004 and issue 44:

| Component | Version |
|---|---|
| Ubique plugin/runtime/bindgen | `1.3.2` |
| UniFFI | `0.32.0` |
| Rust | `1.99.0` (`rust-toolchain.toml`) |
| Kotlin | `2.4.21` |
| Gradle | `9.7.0` (checked-in wrapper with distribution checksum) |
| AGP | `9.3.1`, `compileSdk` 37, `minSdk` 26, NDK `30.0.16248370` |
| Compose Multiplatform | `1.12.2` |
| JDK | 25 for the Gradle daemon; toolchain 21 for compilation |

**Root build.** The root build has these modules:
- `:sdk` (KMP JVM and Android library with generated bindings in
  `ch.trancee.cairn.ffi`);
- `:app` (Compose `App()` and `coreStatus()`);
- `:androidApp` (an Android application shell).

The version catalog lives in `gradle/libs.versions.toml`. Repositories are
declared only in settings (`FAIL_ON_PROJECT_REPOS`), with `google()` limited
to the AndroidX, Android and Google groups. Lanes may substitute a
pre-provisioned generator through `-Pcairn.uniffi.bindgen=<path>`.

**Interim FFI surface.** `cairn-ffi` exports only public byte-level APIs and
no secrets:
- `encode_leb128` and `decode_leb128`;
- `encode_length_prefixed` and `decode_length_prefixed`;
- `WireError` as a typed error;
- `ObjectKind` and `ChunkOutcome`;
- `IncomingObject`, a Rust object with chunk acceptance and a typed
  `TransferError`.

Exposing `IncomingObject` is the new owner decision that
[ADR 0016](0016-unexposed-epoch-transfer-core.md) requires for `cairn-ffi`
exposure. It is limited to binding proof: no SDK feature, wire use,
persistence or profile activation calls it, and the model ticket and S9 stay
open.

`cairn-wire`'s `WireError` gains a redacted `Display` and `core::error::Error`.
`CairnCore` will replace this surface. Removing it is a breaking SDK change,
which is acceptable because no SDK consumers have been released.

**Dependencies.**
- `uniffi = "=0.32.0"` with `default-features = false`.
- Per-crate MPL-2.0 exceptions in `core/deny.toml` for `uniffi`,
  `uniffi_core`, `uniffi_internal_macros`, `uniffi_macros`, `uniffi_meta` and
  `uniffi_pipeline`. MPL-2.0 stays disallowed for every other crate.
- `serde`, `serde_core` and `serde_derive` are pinned at `1.0.228` in
  `core/Cargo.lock` until UniFFI's graph accepts `syn` 3. `cargo deny`
  catches an accidental update.

**Scope.**
- Android host tests are not enabled. `jvmTest` exercises the same JVM, JNA
  and host library, and API 26 emulator instrumentation proves Android.
  Re-enable `withHostTest {}` once Ubique's resource wiring works with
  AGP's KMP library plugin.
- iOS targets are deferred to the Apple-lane increment, so no iOS code
  merges without a build proof. That increment must deliver:
  - device and simulator-arm64 framework builds;
  - the iOS 15 floor check.
- Strict Kotlin CodeQL over the root JVM/Android sources is part of this
  increment (see the ADR 0015 amendment). It must be extended to iOS sources
  when the iOS targets land.

**Linux/Android lane.**
- `proofs/bindings/linux-android/prepare-repository-inputs.sh` runs on the
  networked preparation guest. It:
  - installs signature- and checksum-verified Rust `1.99.0` with Android
    standard libraries;
  - pins the Ubique `1.3.2` source by commit;
  - fetches the Cargo graphs with `--locked`;
  - resolves every Gradle configuration plus AAPT2 without compiling;
  - freezes root-owned, read-only inputs with checksums.
- `build-repository-offline.sh` builds a source archive in a networkless
  systemd sandbox. The source and downloaded inputs are mounted read-only. It
  runs `:sdk:jvmTest :androidApp:assembleDebug` and inspects the APK's native
  entries.
- `run-isolated-android.sh` now accepts an APK, package, instrumentation and
  pass text. It runs the app's `coreStatus()` on a fresh API 26 emulator.

## Alternatives

- **Keep the `1.3.1` tuple.** Rejected: the user chose the latest stable
  releases, and the fixture lanes remain as historical `1.3.1` evidence.
- **Expose crypto or secrets now.** Rejected: ADR 0004 forbids secrets
  crossing the FFI. A wire-level surface proves generated calls, typed errors
  and object lifetimes without that risk.
- **Allow MPL-2.0 globally.** Rejected: the exceptions are per crate, so any
  new MPL dependency needs review.
- **Work around the host-test wiring in `sdk/build.gradle.kts`.** Rejected:
  it would duplicate plugin wiring for a test that adds no coverage beyond
  `jvmTest`.
- **Merge iOS targets unverified, or add the Apple lane in this increment.**
  The user chose to defer the targets instead.

## Consequences

- S0 now has the root Gradle/UniFFI wiring with Linux/Android proof. S0 and
  issue 44 stay open for the Apple lane, Compose UI execution, release
  builds, physical hardware and the oldest/newest-device demonstration.
- Strict Kotlin CodeQL traces the fixture and the root Gradle build into one
  database, so the root JVM/Android Kotlin is scanned (ADR 0015 amendment).
- The serde pin and MPL exceptions need review whenever UniFFI updates.
