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

Since ADR 0023, `:app` holds only `coreStatus()`, `:androidBle` adds the
Android radio, and `:androidApp` holds the chat screen.

The version catalog lives in `gradle/libs.versions.toml`. Repositories are
declared only in settings (`FAIL_ON_PROJECT_REPOS`), with `google()` limited
to the AndroidX, Android and Google groups. Lanes may substitute a
pre-provisioned generator through `-Pcairn.uniffi.bindgen=<path>`.

**Interim FFI surface.** Superseded on 2026-10-23: `CairnCore`
([ADR 0022](0022-cairn-core-contract.md)) replaced it, and the
`run-isolated-android.sh` pass text became the `CairnCore` loopback status.
`cairn-ffi` exported only public byte-level APIs and no secrets:
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
  merges without a build proof (delivered 2026-10-24; see the amendment
  "iOS targets"). That increment must deliver:
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

## Amendment: build-tool security floors (2026-10-23)

GitHub's automatic Gradle dependency submission reported 50 Dependabot alerts
against `settings.gradle.kts`. Every alert is transitive build tooling of the
AGP `9.3.1` tuple; none ships in an SDK or app artifact:

- netty `4.1.93`/`4.1.110` via `grpc-netty` (UTP and the emulator protocol);
- Bouncy Castle `1.79` via apkzlib, builder and sdk-common;
- jose4j `0.9.5` via bundletool, jdom2 `2.0.6` via jetifier;
- httpclient `4.5.6` via httpmime, commons-lang3 `3.16.0` via commons-compress.

Dependabot security updates cannot fix them: the jobs fail with
`dependency_not_found`, because no manifest declares these modules.

**Decision.** The `build-tool-floors` bundle in `gradle/libs.versions.toml` lists
patched floors: netty `4.1.139.Final`, Bouncy Castle `1.86`, jose4j `0.9.7`,
jdom2 `2.0.6.1`, httpcomponents `4.5.14` and commons-lang3 `3.21.0`.
The root `build.gradle.kts` applies them as dependency constraints in two places:

- the root buildscript `classpath`, which carries the plugins;
- a `cairnBuildToolFloors` dependency scope. Every resolvable configuration in
  every project extends from it. That includes AGP's lint and UTP
  configurations, which are created resolvable and consumable.

Constraints only lift versions that are already in a graph, and they add no
dependency. The consumable-only `*Elements` variants that publishing would use
are not resolvable, so their metadata is unchanged. Every module of a family
gets a floor: all netty modules, `bcprov`/`bcpkix`/`bcutil`, and
`httpclient`/`httpmime`. That keeps each family on one version.
`resolve-repository-inputs.gradle` fails the input preparation if any floored
module resolves below its floor. The task runs in both the strict CodeQL cell
and the Linux lane.

Remove a floor once the tuple's AGP brings that version or newer itself.

**Extension (2026-10-25).** Two more alerts came from the same submission:

- freemarker `2.3.32` (GHSA-27j2-h3m2-8237). It reaches the root buildscript
  `classpath` through Kover `0.9.11`'s `coverage-report`, which renders the
  HTML reports.
- `opentelemetry-api` `1.41.0` (GHSA-rcgg-9c38-7xpx). It comes through KGP
  `2.4.21`'s `swift-export-embeddable` in `:sdk:swiftExportClasspathResolvable`.
  KGP registers that configuration, but the repository never runs Swift export.

Both plugins are at their latest stable release, so the bundle adds the floors
freemarker `2.3.35` and opentelemetry `1.62.0`. The opentelemetry floor covers
both `opentelemetry-api` and `opentelemetry-context`. The same removal rule
applies, keyed to the Kover or Kotlin release.

**Extension (2026-10-31).** The same submission reported two more alerts:

- guava `33.4.0-jre` (GHSA-xxph-c9ww-hj94, high). It reaches the root buildscript `classpath` and
  AGP's lint and UTP configurations through AGP `9.3.1`. No SDK or app
  runtime classpath contains it.
- `opentelemetry-api` up to `1.66.0` (GHSA-ccrj-gw8r-854m, medium), on the same KGP path as above.

The bundle adds the floor guava `33.7.2-jre` and raises the opentelemetry
floor to `1.67.0`. The same removal rule applies, keyed to the AGP or Kotlin
release.

**Alternatives.**
- **Dismiss the alerts as build-only.** Rejected: that weakens the gate, and
  build tooling runs with repository access.
- **Exclude configurations from dependency submission.** Rejected for the same
  reason.
- **Upgrade AGP.** Out of scope: that is a separate tuple decision.

## Amendment: iOS targets (2026-10-24)

[Issue 48](../../.scratch/cairn-r1/issues/48-apple-lane-ios-targets.md)
delivers the Apple-lane increment deferred above.

**Decision.** `:sdk` adds `iosArm64` and `iosSimulatorArm64`, each with a
`CairnSdk` framework. The root `gradle.properties` sets
`kotlin.mpp.enableCInteropCommonization=true`; Ubique refuses to configure
iOS targets without it. The owner chose three options:

- **Lane.** The strict `codeql` cell builds the iOS binaries. A new
  `repository-native` arm runs untraced between `repository-bindings` and
  `repository-codeql` (`build.sb`, 900 s). It links both frameworks and the
  simulator test executable offline with the pinned Kotlin/Native `2.4.21`
  compiler and Rust `1.99.0` with the iOS standard libraries. `vtool` then
  requires platform `IOS`/`IOSSIMULATOR` and `minos 15.0` on all three
  binaries.
- **Tests.** The cell exports the `commonTest` simulator executable. A
  separate, explicitly non-strict job runs it on a fresh iPhone 17
  simulator (iOS 26.4), the same pattern as the fixture's functional
  runtime. It requires `[  PASSED  ]` and no `[  FAILED  ]`.
- **CodeQL.** CodeQL cannot extract Kotlin/Native, so iOS-only sources are
  not analysed. The compiled-source inventory gate already fails on any
  tracked `.kt` without JVM extraction, so no iOS-only handwritten source
  can merge unscanned. Today all handwritten Kotlin is common, JVM or
  Android code.

Preparation reuses the frozen fixture native dependencies. It fails closed
unless the `2.4.21` `konan.properties` equals the frozen `2.4.20` one apart
from `compilerVersion`. `resolve-repository-inputs.gradle` skips commonized
cinterop configurations, which are built locally; this matches the fixture.

**Evidence.** Run [`40084024801`](https://github.com/trancee/cairn/actions/runs/40084024801) at `98af6a7`:
- `repository-native` took 2 min 37 s; the `codeql` cell took 23 min of 45.
- All three binaries report `minos 15.0`, so the iOS 15 floor is verified at
  build level ([ADR 0004](0004-core-architecture.md)).
- The simulator ran the four `CoreLoopbackTest` tests through the generated
  bindings: `[  PASSED  ] 4 tests.`
- The first attempt's cleanup timed out on `simctl list` after the tests
  passed; the rerun passed. The owner approved raising that timeout to 60 s
  and the cleanup budget from 75 s to 150 s for both simulator jobs.

The Linux lane is unaffected: guest label `ios-targets` passed
`:sdk:jvmTest :androidApp:assembleDebug` offline and the API 26 emulator
`CoreStatusInstrumentation`.

**Still open.** The oldest/newest-iPhone demonstration on physical devices,
and an XCFramework or release build.
