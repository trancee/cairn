# Ubique `uniffi-kotlin-multiplatform-bindings` target-matrix compatibility — 2026-10-08

**Decision update (2026-10-08):** the project owner subsequently selected
Ubique instead of Gobley; ADR 0004 now records that choice. This remains a
source-only compatibility assessment, not proof that the selected integration
builds or satisfies the iOS 15 deployment floor. See prototype issue 44.

## Question

Resolves issue 43 (`.scratch/pqcble-r1/issues/43-ubique-kmp-target-compatibility.md`):
does `UbiqueInnovation/uniffi-kotlin-multiplatform-bindings` support ADR 0004's
required target matrix — Android API 26+, iOS 15+, `iosArm64` device +
`iosSimulatorArm64` simulator, and a KMP library module (`sdk/`) + Compose
Multiplatform app (`app/`) split — and does its documented toolchain overlap the
project's currently fully-supported KGP tuple (Kotlin 2.4.20/2.4.21, Gradle max
9.7.0, AGP max 9.3.1)? Research only; no builds run, no code changed, no binding
project selected.

## TL;DR / go-no-go

**Conditional go, with one unresolved and materially important gap.** Primary
sources confirm the Kotlin/Gradle/AGP/target-architecture matrix overlaps the
project's supported tuple, confirm real (not just claimed) `iosArm64` +
`iosSimulatorArm64` framework-link success on Kotlin 2.4.20 as of two days before
this note, and confirm a KMP-library + app split is not just compatible but a
named strength (Multi Module Support) over Gobley. **It is not verified** whether
Ubique's own published artifact chain enforces an iOS 15+ floor or a higher one —
their release CI sets `IPHONEOS_DEPLOYMENT_TARGET=16.4` for the one module they
publish as a prebuilt Apple binary, which is above ADR 0004's iOS 15+ requirement
and is not explained or configurable in any doc found. Android API 26+ is
unambiguously fine (floor is a consumer `minSdk` setting the plugin does not
constrain beyond the NDK's own floor). No independent compile/runtime proof was
found of an actual iOS 15-deployment-target build with this plugin; this should
be verified directly (a throwaway Gradle project building `iosArm64()` with
`deploymentTarget = "15.0"`) before an ADR change, not assumed from the matrix
overlap alone.

## Toolchain requirements — verified against the project's supported KGP tuple

Ubique's README states (fetched 2026-10-08, same text also in the prior
`2026-10-08-gobley-maintenance.md` note):

| Requirement | Ubique's stated version | Source |
| --- | --- | --- |
| Rust | `>=1.91` | [README "Requirements"](https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings#requirements) |
| UniFFI | `=0.32.0` | same |
| Gradle | `>=9.6.1` | same |
| Kotlin | `>=2.4.0` | same |
| AGP | `9.x`, "built and tested against AGP `9.3.1`" | same |

Cross-checked against JetBrains' own compatibility table
([kotlinlang.org/docs/gradle-configure-project.html](https://kotlinlang.org/docs/gradle-configure-project.html),
fetched 2026-10-08), the row for KGP `2.4.20` (the version in the project's
currently fully-supported tuple) reads:

> KGP `2.4.20` — Gradle min/max `7.6.3–9.7.0` — AGP min/max `8.5.2–9.3.1`

The overlap is real but narrow, not broad:
- **Gradle**: Ubique's floor (`>=9.6.1`) sits inside KGP 2.4.20's fully-supported
  ceiling (`9.7.0`), leaving only the **9.6.1–9.7.0** window as simultaneously
  "meets Ubique's minimum" and "within Kotlin's fully-supported range." Anything
  below 9.6.1 fails Ubique's stated floor even though Kotlin would still fully
  support it; this is Ubique's constraint, not Kotlin's.
- **AGP**: Ubique's own tested version (`9.3.1`) is exactly KGP 2.4.20's
  fully-supported AGP ceiling (`9.3.1`). Ubique's broader claim of "AGP `9.x`"
  is **only independently confirmed at the single version `9.3.1`**; any other
  AGP 9.x point release (9.0–9.2.x, or anything past 9.3.1) is an extrapolation
  from "9.x" phrasing, not a verified-tested claim, and newer-than-9.3.1 AGP
  releases would also exceed KGP 2.4.20's own fully-supported ceiling regardless
  of Ubique.
- **Kotlin**: `>=2.4.0` cleanly covers both 2.4.20 and 2.4.21 in the project's
  supported tuple — no conflict here.

**Conclusion: the tuples overlap, but only at essentially one specific
Gradle/AGP combination (Gradle 9.6.1–9.7.0, AGP 9.3.1) rather than broadly across
the whole AGP 9.x line** — treat "AGP 9.x" in Ubique's README as marketing-level
phrasing, not a tested compatibility claim, per their own "tested against 9.3.1"
qualifier in the same sentence.

## Android — verified

- Android support uses the newer `com.android.kotlin.multiplatform.library`
  plugin (AGP 9 DSL), applied alongside Kotlin Multiplatform, with `minSdk` and
  `compileSdk` set directly inside `kotlin { android { } }`:
  [README "Android"](https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings#android),
  [Targets guide → Android](https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/guide/targets/#android).
- The plugin's own quickstart example sets `minSdk = 21` — **lower** than ADR
  0004's API 26+ floor — and nothing in the README, targets guide, or Android
  section imposes any Android API floor beyond whatever the pinned NDK/Rust
  toolchain requires. **API 26+ is verified compatible** (strictly less
  restrictive than the plugin's own example).
- Release Android builds compile `arm64-v8a`, `x86_64`, and `armeabi-v7a` by
  default (debug builds restrict to the host's matching ABI unless
  `androidDebugAbis`/`-PandroidAbis` is set): [Targets guide → Debug and release
  builds](https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/guide/targets/#debug-and-release-builds).
  This matches ADR 0004's `cargo-ndk` ABI list (arm64-v8a, armeabi-v7a, x86_64)
  one-for-one.
- NDK toolchain is auto-detected under `$ANDROID_HOME/ndk` or pinnable via
  `cargo { ndkVersion = "..." }`: same source.

## iOS — partially verified; deployment-target floor is an open gap

**Verified, supported targets table** (not just prose; a literal target-support
matrix), from the docs site's landing page (fetched 2026-10-08,
[ubiqueinnovation.github.io/.../](https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/)
and [Targets guide](https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/guide/targets/)):

| Kotlin target | Rust target | Library | Delivered as |
| --- | --- | --- | --- |
| `iosArm64()` | `aarch64-apple-ios` | static | cinterop |
| `iosSimulatorArm64()` | `aarch64-apple-ios-sim` | static | cinterop |
| `iosX64()` | `x86_64-apple-ios` | static | cinterop |

Both targets ADR 0004 requires (`iosArm64`, `iosSimulatorArm64`) are explicitly
listed and built via Kotlin/Native cinterop against a Rust `staticlib`, matching
ADR 0004's "Kotlin/Native XCFramework for iOS arm64 and simulator arm64" plan at
the Kotlin-target level (XCFramework packaging itself is standard
Kotlin-Multiplatform Gradle tooling — `binaries.framework{}` /
`XCFrameworkConfig` — independent of which UniFFI binding generator is used;
Ubique does not ship its own XCFramework-assembly feature or example, this is an
**inference from standard KMP mechanics, not independently demonstrated** by
Ubique in a fetched example).

**Real (not just claimed) compile/link proof exists, but it is two days old and
reveals two consecutive regressions**, from GitHub issue
[#29 "Kotlin 2.4.20: Apple framework link fails with 'IrClassSymbolImpl is
already bound' for cinterop/RustBuffer"](https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/issues/29)
(closed 2026-10-08T05:50:37Z):
- A third-party user reported `linkReleaseFrameworkIosSimulatorArm64` and
  `linkReleaseFrameworkIosArm64` (exactly the two tasks needed for ADR 0004's
  targets) **failing outright** on Kotlin 2.4.20 (the version in the project's
  supported tuple), tracing it to an upstream Kotlin compiler bug
  ([KT-89825](https://youtrack.jetbrains.com/issue/KT-89825)) triggered by two
  cinterop klibs both declaring `cinterop.RustBuffer`.
- Maintainer shipped a fix in `v1.3.0` (2026-10-02). The same reporter then found
  the fix **regressed** `compileNativeMainKotlinMetadata` (unresolved FFI
  references during publication) — a second, different break.
- Maintainer shipped a second fix, plus a filed follow-up upstream Kotlin bug
  ([KT-90043](https://youtrack.jetbrains.com/issue/KT-90043)), in **`v1.3.1`
  (2026-10-07)** — the version identified as current in the prior Gobley-maintenance
  note. The reporter confirmed `v1.3.1` "works very well" on 2026-10-08T05:38:40Z,
  i.e. **less than 8 hours before this research pass**.
- **Net effect**: there is genuine third-party confirmation that
  `iosArm64`/`iosSimulatorArm64` framework linking works with Kotlin 2.4.20 and
  Ubique `v1.3.1` — this is stronger evidence than a README claim — but it also
  shows the Apple-framework-linking path had two back-to-back breakages within
  the last release cycle, so "works today" carries materially more regression
  risk than Gobley's (older, slower-moving, but longer-proven) equivalent path.

**Not verified: iOS deployment-target floor.** No README, guide page, or example
states a minimum supported `IPHONEOS_DEPLOYMENT_TARGET`/iOS OS version for
consumer apps. However, the project's own release pipeline
([`.github/workflows/publish.yml`](https://raw.githubusercontent.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/main/.github/workflows/publish.yml),
`publish-runtime` job, `macos-15-xlarge` runner) sets:

```yaml
env:
  IPHONEOS_DEPLOYMENT_TARGET: "16.4"
```

when building and publishing the one Apple-targeting artifact Ubique ships
prebuilt to Maven Central (`ch.ubique.uniffi:runtime`, the shared cinterop
runtime every consumer depends on). This is **above** ADR 0004's iOS 15+ floor.
What is genuinely unresolved from primary sources alone:
- Whether `16.4` only affects *that specific CI job's own published `.klib`*
  (which a consumer could potentially override by recompiling the runtime from
  source instead of pulling the Maven Central artifact), or whether it
  constrains every downstream app's own Xcode `IPHONEOS_DEPLOYMENT_TARGET`
  transitively once linked.
- Whether a consumer project — like `pqcble`, which would generate its own
  bindings from its own Rust crate via `generateFromLibrary()`, rather than
  consuming someone else's pre-published bindings — pulls in the prebuilt
  `ch.ubique.uniffi:runtime` artifact as a Kotlin/Native klib dependency (in
  which case the 16.4 floor likely *does* propagate to the app's own minimum
  deployment target at Xcode link time), or whether the plugin always compiles
  the runtime from source per-consumer (in which case 16.4 is CI-only and
  irrelevant to self-hosted builds).
- No doc page states "minimum iOS X.Y" or discusses `IPHONEOS_DEPLOYMENT_TARGET`
  at all outside this one CI file; it was not possible from fetched sources to
  tell whether `16.4` is a deliberate compatibility floor or an incidental
  default inherited from the `macos-15-xlarge` runner's bundled Xcode/SDK.

**This is the one gap that should block adopting Ubique for ADR 0004 until
directly tested**: if the 16.4 floor is load-bearing on the shared
`ch.ubique.uniffi:runtime` dependency, it would conflict outright with the
iOS 15+ requirement; if it's CI-incidental and a self-hosted build can target 15.0
freely, there's no conflict. Primary sources read here do not resolve which.

## KMP library module + Compose Multiplatform app split — verified compatible, and a stated strength

- Ubique's docs explicitly describe **Multi Module Support** as the project's
  headline differentiator from Gobley: "every crate gets its own Gradle module
  and its own library, and any number of modules can use the types of a shared
  module... Shared types are the same Kotlin classes everywhere and pass between
  modules without conversion"
  ([Comparison with other projects → Multi-module support](https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/guide/comparison/#multi-module-support)).
- This directly supports ADR 0004's `sdk/` (KMP library, Gobley/Ubique bindings +
  BLE adapters) + `app/` (Compose Multiplatform reference app) split: the
  library module produces Kotlin bindings + native artifacts, and the app module
  consumes them as an ordinary KMP library dependency — the standard shape every
  fetched example (`examples/quickstart`, `examples/swift-interop`) already uses
  (crate + Gradle module as a library, consumed by a separate Gradle project).
  [`examples/quickstart` directory listing](https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/tree/main/examples/quickstart)
  (not independently fetched as an app-consumer example, but the single-module
  shape is the same mechanism a library + app split would use).
- No restriction was found anywhere in the README, docs site, or targets guide
  limiting the plugin to single-module/monolithic-app usage; if anything the
  opposite is advertised.

## Generated Kotlin API / source-set layout — verified

- Bindings land in `commonMain`, generated to `build/uniffi/bindings/`, with
  native (cinterop) declarations shared via `nativeMain` — requiring
  `kotlin.mpp.enableCInteropCommonization=true` in `gradle.properties` for any
  Kotlin/Native target, or the plugin fails the build with an explicit error
  message: [Getting started → "Enable cinterop
  commonization"](https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/guide/getting-started/#3-enable-cinterop-commonization).
- JVM/Android call Rust via JNA against a bundled `cdylib`; Kotlin/Native targets
  link a `staticlib` via cinterop — confirmed in both the [Targets
  guide](https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/guide/targets/)
  and the [quickstart Cargo.toml](https://raw.githubusercontent.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/main/README.md)
  (`crate-type = ["lib", "cdylib", "staticlib"]`).
- Default dependencies auto-added to `commonMain`: `okio 3.18.1`,
  `kotlinx-atomicfu 0.33.0`, `kotlinx-coroutines-core 1.11.0`; `jna 5.19.1` added
  to `jvmMain`/`androidMain`/`androidHostTest` — all per the README's
  ["Manual dependency management"](https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings#manual-dependency-management)
  table. These are new transitive dependencies ADR 0004's `sdk/` module would
  pick up that are not mentioned for Gobley in the prior research note; not
  independently checked for license/FIPS/supply-chain concerns here (out of
  scope for this target-matrix question) but flagged for a future review pass.

## Rust MSRV / UniFFI version — verified, re-confirming the prior note

- Rust `>=1.91`, UniFFI `=0.32.0` pinned exactly (not a floor) —
  [README "Requirements"](https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings#requirements)
  and ["Status"](https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings#status)
  section ("Currently `uniffi-rs` version `0.32.0` is supported"). This matches
  what `2026-10-08-gobley-maintenance.md` already recorded; no new discrepancy
  found.
- CI (`run-tests.yml`) reads the Rust channel from the repo's own
  `rust-toolchain.toml` rather than hardcoding a version in the workflow,
  consistent with "MSRV pinned in `rust-toolchain.toml`" being a transferable
  pattern to ADR 0004's own Rust workspace:
  [`.github/workflows/run-tests.yml`](https://raw.githubusercontent.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/main/.github/workflows/run-tests.yml).

## CI coverage — a secondary maturity gap worth flagging

- `run-tests.yml` runs on a single `large-runner` (Linux-flavored: installs
  `apt-get` packages, MinGW cross toolchains, Zig) and only adds Rust targets
  `aarch64-unknown-linux-gnu`, `aarch64-linux-android`,
  `armv7-linux-androideabi`, `x86_64-linux-android`, `x86_64-pc-windows-gnu` —
  **no Apple Rust target is added and no macOS runner is used in the main
  test workflow**:
  [`run-tests.yml`](https://raw.githubusercontent.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/main/.github/workflows/run-tests.yml).
- The only workflow that touches Apple targets is `publish.yml`'s
  `publish-runtime` job (`macos-15-xlarge`), and it is a **publish/release**
  job, not a test job — it has no corresponding assertions, only
  `publishAndReleaseToMavenCentral`:
  [`publish.yml`](https://raw.githubusercontent.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/main/.github/workflows/publish.yml).
- **No CI-verified proof of iOS framework linking or runtime behavior was found
  in this project's own automation.** The strongest evidence of iOS
  compile/link correctness found in this research is the third-party user
  report in issue #29 above, which is real but informal (a GitHub issue
  comment, not a CI gate) and only exercises linking, not execution of generated
  bindings on-device or in-simulator.

## Sources (primary, fetched/queried 2026-10-08)

- https://raw.githubusercontent.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/main/README.md
- https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/
- https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/guide/getting-started/
- https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/guide/targets/
- https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/guide/comparison/
- https://kotlinlang.org/docs/gradle-configure-project.html (KGP/Gradle/AGP compatibility table)
- https://raw.githubusercontent.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/main/.github/workflows/run-tests.yml
- https://raw.githubusercontent.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/main/.github/workflows/publish.yml
- https://raw.githubusercontent.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/main/examples/quickstart/build.gradle.kts
- https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/contents/examples (directory listing)
- https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/contents/examples/swift-interop (directory listing)
- https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/contents/.github/workflows (directory listing, confirms only 3 workflows exist)
- https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/issues/29 (+ its comments)
- https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/issues (full issue list, state=all)
- https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/releases (tag/date confirmation of v1.3.1, v1.3.0)
- `docs/adr/0004-core-architecture.md` (this repo's required target matrix, read for scope)
- `docs/research/2026-10-08-gobley-maintenance.md` (this repo's prior Ubique-vs-Gobley note, read to avoid duplicating already-recorded findings)

## Gaps / not independently verified

- **iOS deployment-target floor (the key open question)**: whether
  `IPHONEOS_DEPLOYMENT_TARGET=16.4` in Ubique's release CI is (a) specific to
  their own published `ch.ubique.uniffi:runtime` prebuilt klib only, (b) an
  incidental default from the `macos-15-xlarge` runner rather than a deliberate
  floor, or (c) something that would propagate to any consumer linking against
  that artifact regardless of the consumer's own Xcode deployment-target
  setting. Resolving this needs either a direct question to the Ubique
  maintainers (issue tracker), or a throwaway local build targeting
  `iosArm64()`/`iosSimulatorArm64()` with the app's own
  `IPHONEOS_DEPLOYMENT_TARGET`/Xcode deployment target set to `15.0` to see
  whether link/run succeeds — this research pass did not and was not asked to
  run any build.
- **No XCFramework-assembly example** was found from Ubique directly (inferred
  compatible via standard Kotlin/Native `binaries.framework{}` mechanics, not
  demonstrated).
- **No device-level (physical iPhone) proof** of generated bindings executing
  correctly was found anywhere in primary sources (Ubique's own CI doesn't test
  Apple targets at all; the only confirmed evidence is a framework *link*
  succeeding, from a third-party issue comment, not a runtime execution report).
- Did not audit the new transitive dependencies (`okio`, `atomicfu`,
  `kotlinx-coroutines-core`, `jna`) for license, supply-chain, or
  FIPS-module-boundary concerns relative to ADR 0001; flagged only, not
  evaluated.
- Did not check Ubique's GitHub Discussions (if any) or Discord/Slack channels
  for additional qualitative reports of iOS runtime behavior beyond the issue
  tracker.
- This note intentionally does not choose or recommend Gobley vs. Ubique vs. any
  other generator — per the issue's scope, that remains an ADR-level decision
  gated on resolving the iOS deployment-target gap above.
