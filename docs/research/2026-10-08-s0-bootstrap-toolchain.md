# Research findings: Slice S0 bootstrap toolchain tuple and Rust crypto-backend wiring

Scope: official Kotlin/KMP/Compose Multiplatform/Gradle/AGP/Gobley/UniFFI docs and
first-party Rust crate/crate-registry sources only, bounded to what Slice S0
([`.scratch/pqcble-r1/issues/30-slice-s0.md`](../../.scratch/pqcble-r1/issues/30-slice-s0.md))
needs to start: the root Gradle/KMP build, the `core/` Cargo workspace per
[ADR 0004](../adr/0004-core-architecture.md), and the `CryptoBackend` trait's two
adapters under the ADR 0007 gates. No implementation or build/test execution was
performed; this is a planning input, not a verification that S0 is done.

**Binding decision superseded 2026-10-08:** the Gobley setup below is historical.
ADR 0004 now selects Ubique `1.3.1` / UniFFI `0.32.0`; see the
[compatibility research](2026-10-08-ubique-compatibility.md). The iOS 15
deployment-target proof is still open in
[issue 44](../../.scratch/pqcble-r1/issues/44-ubique-binding-smoke-test.md).

## 1. Kotlin/Gradle/AGP tuple

- **Official compatibility table** (`kotlinlang.org/docs/gradle-configure-project.html`,
  fetched 2026-10-08): KGP **2.4.20** fully supports Gradle **7.6.3–9.7.0** and AGP
  **8.5.2–9.3.1**. The page explicitly distinguishes "fully supported" (no deprecated
  methods/properties, all current features) from merely usable-with-warnings: "You can
  also use Gradle and AGP versions up to the latest releases, but if you do, keep in
  mind that you might encounter deprecation warnings or some new features might not
  work."
- **Installed Gradle 9.7.1 is outside the fully-supported window** (max is 9.7.0).
  Resolution is not support, per `guidance/kotlin.md`. **Recommendation:** pin the
  Gradle wrapper to **9.7.0** for S0 rather than accept 9.7.1 as an unverified
  resolvable version; re-check the table before any later bump.
- Kotlin's release cadence page (`kotlinlang.org/docs/releases.html`, fetched
  2026-10-08) confirms 2.4.20 is the current tooling release in the 2.4 line (released
  2026-06-03 language base, in its 18-month stdlib security-support window through
  2027-12-03), and that 2.5.0 is only "planned for December 2026" — i.e. not yet a
  stable alternative. **2.4.20 is the correct "current fully-supported stable"
  Kotlin version** per `guidance/kotlin.md`'s selection rule.
- **AGP ceiling check:** Android's own AGP 9.4 release notes
  (`developer.android.com/build/releases/agp-9-4-0-release-notes`, fetched
  2026-10-08) list only `9.4.0-alpha01` through `-alpha04` fixed-issue tables — AGP
  9.4 is **alpha**, not GA. This matters because Google's own Android-KMP-plugin
  migration guide (below) shows a version-catalog example pinning
  `androidGradlePlugin="9.4.0"`, which is **both pre-release and above KGP 2.4.20's
  fully-supported AGP ceiling of 9.3.1**. Do not copy that example verbatim;
  **pick a GA AGP release ≤ 9.3.1** (e.g. the latest 9.3.x or 8.x GA) for S0.
- **Gap not resolved this pass:** the Gradle 9.7.0/AGP ≤9.3.1 ⨯ JDK 25 daemon
  compatibility was not independently fetched from Gradle's own compatibility matrix.
  `guidance/kotlin.md` requires declaring the daemon JDK separately from the compile
  toolchain and verifying the tuple before adoption — treat JDK 25 as daemon-JDK-only
  until Gradle's compatibility page is checked, and prefer a Kotlin/Java toolchain
  pinned to a JDK release confirmed in Gradle 9.7.0's own support table.

## 2. KMP Android target: library vs. app plugin

- ADR 0004's layout is `sdk/` (KMP library) and `app/` (Compose Multiplatform
  reference app). These need **different** Android Gradle integration:
- **For `:sdk`'s Android target:** Kotlin's own compatibility guide
  (`kotlinlang.org/docs/multiplatform/multiplatform-compatibility-guide.html`,
  fetched 2026-10-08) documents the deprecation/migration path: the `android{}` DSL
  (not `androidTarget`) was removed from KGP at 2.2.0; `androidTarget` itself gained
  a deprecation warning in 2.3.0 that was **reverted** in 2.3.10 when paired with AGP
  8.x — so `androidTarget` still compiles under KGP 2.4.20 without a forced warning,
  but Google's own plugin is the forward path. Android's developer docs
  (`developer.android.com/kotlin/multiplatform/plugin`, fetched 2026-10-08) name
  **`com.android.kotlin.multiplatform.library`** as "the officially supported tool
  for adding an Android target to a KMP library module," note that the legacy
  `com.android.library`-based KMP integration depends on AGP APIs that **require
  opt-in starting AGP 9.0 and are planned for removal in AGP 10.0** (second half of
  2026), and state its own prerequisites: **AGP ≥ 8.10.0, KGP ≥ 2.0.0** — both
  satisfied by the 2.4.20 / ≤9.3.1 tuple above.
  - Caveats verified from the same page: single-variant architecture (no build
    types/flavors), unit/instrumented tests **disabled by default** (must be
    explicitly enabled — relevant to ADR 0007's per-PR `cargo test`/CI gates, which
    are Rust-side, but any Kotlin-side JNI/UniFFI consumer test in `:sdk` needs this
    flag flipped), Java compilation off by default (`withJava()` opt-in), and no
    top-level `android{}` extension — configuration lives inside the KMP `kotlin{}`
    block's `android{}` sub-block instead.
  - This is **library-module-only**. It is not documented as applicable to `:app`.
- **For `:app`:** the Compose Multiplatform reference app is an Android
  *application*, which still needs the standard `com.android.application` AGP
  plugin (the Android-KMP library plugin explicitly does not cover applications;
  Android's docs scope it to "KMP library module" throughout). Do not attempt to
  reuse `com.android.kotlin.multiplatform.library` for `:app`.

## 3. Compose Multiplatform

- `kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html`
  (fetched 2026-10-08, the current canonical URL — the previously-tried
  `jetbrains.com/help/...` path 404s and redirects through `kotlinlang.org/docs/multiplatform/...`)
  confirms Compose Multiplatform **1.12.1** platform minimums: **Android API 21**,
  **iOS 14**. Both are *below* ADR 0004's required floors (Android 26+, iOS 15+), so
  Compose Multiplatform does not block those floors — the project must still set
  `minSdk = 26` and an iOS 15 deployment target explicitly in Gradle/Xcode project
  settings; CMP will not enforce them.
- Same page: "The latest Compose Multiplatform is always compatible with the latest
  version of Kotlin" (no separate pin needed), but requires **the Compose Compiler
  Gradle plugin applied at the exact same version as the Kotlin Multiplatform
  plugin** — i.e. one version-catalog entry must drive both `kotlin` and
  `org.jetbrains.compose.compiler` versions for S0's root build. It further
  recommends **Kotlin ≥ 2.1.0** generally and **≥ 2.2.20** for "platforms with
  rapidly evolving support, such as iOS" — 2.4.20 clears both thresholds.

## 4. iOS / Kotlin-Native target and host

- `kotlinlang.org/docs/native-target-support.html` (fetched 2026-10-08) places
  `iosArm64` and `iosSimulatorArm64` in **Tier 1**, each described as targeting
  "Apple iOS and iPadOS **15.0** and later" — this directly matches, and requires no
  extra configuration beyond, ADR 0004's iOS 15+ floor. Tier 1 also carries the
  compiler's strongest compatibility/testing guarantees (vs. Tier 3's "not
  guaranteed to be tested on CI" / "can't promise source and binary compatibility").
  Tier 1 targets are macOS-arm64-host-only, consistent with `rust-toolchain.toml`
  and CI needing a `macos-latest` runner for the iOS cross-builds (already planned
  in ADR 0007).
- **Gap not resolved this pass:** no official page pinning a minimum Xcode version
  for Kotlin/Native 2.4.20 iOS targets was fetched (the expected
  `apple-configure-compiler.html` URL 404s under the current docs structure).
  Resolve this at implementation time by checking Kotlin's "what's new"/release
  notes for 2.4.20 or by building once on the CI macOS image and reading the actual
  Xcode toolchain error, if any — do not assume a specific Xcode floor without that
  check.

## 5. Gobley / UniFFI

- Gobley's GitHub releases/changelog (`github.com/gobley/gobley/releases` and
  `raw.githubusercontent.com/gobley/gobley/main/CHANGELOG.md`, fetched 2026-10-08):
  latest stable is **0.3.7** (2025-10-08), which pins/bundles **UniFFI 0.29.4**
  (upgraded from 0.29.3 in 0.3.1, PR #167). Gobley's own getting-started tutorial
  (`gobley.dev/docs/tutorial/`, fetched 2026-10-08) shows the two Gradle plugins
  applied at matching versions:
  ```
  plugins {
    id("dev.gobley.cargo") version "0.3.7"
    id("dev.gobley.uniffi") version "0.3.7"
    kotlin("plugin.atomicfu") version libs.versions.kotlin
  }
  ```
  and a Cargo-side `uniffi = "0.29.4"` dependency with `crate-type = ["cdylib",
  "staticlib"]` (dylib used for Android, staticlib for iOS). This satisfies ADR
  0004's "Gobley and UniFFI at matching versions" requirement with concrete,
  currently-stable numbers: **Gobley 0.3.7 / UniFFI 0.29.4**.
- The `kotlin("plugin.atomicfu")` plugin is a **required**, not optional,
  companion for Gobley's generated bindings (used for the atomic types inside
  UniFFI's Kotlin runtime) — must be added to the root version catalog at the same
  Kotlin version as the rest of the build, which S0's "one Kotlin/compiler-plugin
  version owner" rule already requires.
- The README (`github.com/gobley/gobley`, fetched 2026-10-08) states current scope:
  "Android, Kotlin/JVM, and Kotlin/Native are supported. WASM is not supported yet,"
  and the changelog documents **Android NDK Kotlin/Native target support** only
  since **0.3.2** (2025-08-17) — i.e. a comparatively recent capability, worth a
  smoke-test rather than an assumption during S0.
- ADR 0004's named risk ("no integrated Rust debugger," "`chkstk_darwin` linker
  pitfall") was not independently re-verified this pass (out of this bounded scope);
  it was carried over from the existing
  [toolchain research](2026-10-05-kmp-rust-ble-toolchain.md) already cited by the
  ADR and not re-litigated here.

## 6. `CryptoBackend`: `aws-lc-rs` adapter

- `docs.rs/aws-lc-rs/latest/aws_lc_rs/` (fetched 2026-10-08) confirms the Cargo
  feature surface ADR 0004 needs for a **compile-time** backend switch:
  - Default (non-FIPS) build uses `aws-lc-sys` and needs **no CMake, no Go, no
    bindgen** — "Consuming projects will need a C/C++ compiler" only. This is the
    low-friction path for the "non-FIPS build now" adapter named in the ADR.
  - `fips` feature switches to `aws-lc-fips-sys`, which **does** require CMake and
    Go (and potentially bindgen depending on target) — this directly corroborates
    ADR 0004's own risk note ("Cross-compiling it needs CMake/NDK toolchains in CI").
  - `fips` and `non-fips` are mutually exclusive compile-time features (enabling
    both is a compile error), which is exactly the kind of Cargo-feature seam ADR
    0004 specifies — no unsupported API assumption is needed to select FIPS vs.
    non-FIPS at build time; the crate already models it as two features.
  - The FIPS feature currently binds to **AWS-LC-FIPS 4.x** ("latest"); the table on
    the same page shows which `aws-lc-rs` version range maps to which FIPS module
    generation (2.0.x → `<1.12.0`, 3.0.x → `<1.18.0`, 4.x → latest). This is new,
    more specific information than the existing
    [FIPS-validated-modules research](2026-10-05-fips-validated-mlkem-modules.md),
    which examined AWS-LC-FIPS 2.0.0/3.1.0 certs; it does not change that research's
    conclusion that **no FIPS 140-3 certificate currently covers a mobile Android/iOS
    operating environment** — the limiting factor remains certification scope, not
    `aws-lc-rs`'s API or Cargo-feature support.

## 7. `CryptoBackend`: reference adapter (`mlkem-native` + RustCrypto)

This is the most important gap found this pass, material to "whether these can be
wired... without unsupported API assumptions":

- **`mlkem-native` is not a Rust crate.** `github.com/pq-code-package/mlkem-native`
  (fetched 2026-10-08; this is the correct upstream — `pq-crystals/mlkem-native`
  404s) describes itself as "a secure, fast, and portable **C90** implementation of
  ML-KEM," built with `make`, consumed by other projects (libOQS, AWS-LC, rustls)
  as a *C* library, with memory/type-safety proved by **CBMC** and constant-timeness
  by **HOL-Light** for assembly backends. Searching both `docs.rs` and the
  `crates.io` API for `mlkem-native` returned **no matching published crate**
  (404 / no exact match). **Implication for S0:** ADR 0004's "reference adapter
  (`mlkem-native` + RustCrypto)" cannot be wired by adding a crates.io dependency
  named `mlkem-native`; it requires either (a) authoring/vendoring a first-party
  `-sys`-style FFI crate around the upstream C sources (via `cc`/`bindgen`), which
  is itself additional S0-scoped work and is exactly what ADR 0007 anticipates with
  its "If any `mlkem-native` C is vendored, a mirror of its KyberSlash-patched
  valgrind CT job" nightly gate, or (b) using only the RustCrypto pure-Rust `ml-kem`
  crate as the ML-KEM half of the reference adapter and dropping the
  formally-verified C implementation from "day one" scope. Either choice is a
  decision the slice owner must make explicitly; it is not implementable as a bare
  `Cargo.toml` dependency line as currently worded.
- **RustCrypto `ml-kem`** (`lib.rs/crates/ml-kem`, fetched 2026-10-08): pure-Rust
  FIPS 203 (final) implementation, MSRV **rustc 1.85+**, feature flags `zeroize`,
  `pkcs8`, `alloc`, `pem`, `hazmat` (the last explicitly gated as test-only/unsafe:
  "Do NOT enable unless you know what you are doing"). Explicit security warning:
  **"has never been independently audited! USE AT YOUR OWN RISK!"** — acceptable
  for a differential-testing reference adapter per ADR 0004's own design intent
  (two adapters exist precisely so bugs in either show up in the differential
  test), but not a certification or audit claim, and should be stated that way in
  any S0 documentation.
- **RustCrypto `x-wing`** (`lib.rs/crates/x-wing`, fetched 2026-10-08): composes
  `ml-kem` + `x25519-dalek` into X-Wing, same MSRV (1.85+), same audit disclaimer.
  Critically, its README states: **"Current implementation matches the draft RFC
  version 06."** The IETF datatracker page for the draft
  (`datatracker.ietf.org/doc/draft-connolly-cfrg-xwing-kem/`, fetched 2026-10-08)
  shows the **current/latest revision is `-11`**, dated 23 September 2026 — the
  same draft-11 that ADR 0007 names as the vector-generation source ("X-Wing
  vectors: draft-11 vectors generated once with BoringSSL (`xwing.h`) and
  Cloudflare CIRCL"). **This is a version gap, not an unsupported-API problem**:
  the crate compiles and exposes the right primitive operations, but its combiner
  construction must not be trusted as draft-11-conformant purely because the crate
  name matches — it must be checked line-by-line against the draft-11 text (key
  encoding, domain separator, SHA3-256 combiner input ordering) before being used as
  the reference adapter's X-Wing implementation, or X-Wing should be re-implemented
  directly over `ml-kem` + `x25519-dalek` in `pqcble-crypto` to guarantee draft-11
  conformance. Either path is a bounded, known piece of S0 work — it is exactly
  what ADR 0007's differential/vector gates exist to catch, and confirms that ADR's
  design (commit pinned vectors from two *other* independent implementations,
  rather than trusting any one crate's draft-version claim) is the correct one, not
  a gap in the ADR.
- **X-Wing vector sources (BoringSSL / CIRCL) were not independently fetched this
  pass** (bounded scope: this task named Rust-crate/KMP/Gradle sources, not a
  BoringSSL/CIRCL source audit). The datatracker confirms **draft-11** is current as
  of 2026-10-08, which is the version both upstream implementations must match
  before their generated vectors are trustworthy. **Remaining concrete follow-up**
  (explicitly named in the task as a required blocker to track): fetch
  `github.com/google/boringssl`'s `xwing.h` and `github.com/cloudflare/circl`'s
  X-Wing source and confirm both already implement draft-11 (not an older
  combiner ordering) before committing vectors generated from them. This is
  unresolved and should block the "X-Wing vectors" gate in ADR 0007's per-PR list
  until checked, not weakened.

## 8. Remaining toolchain pieces not separately re-verified

- **Rust stable channel / MSRV:** `rust-lang.org`'s homepage (fetched 2026-10-08)
  does not surface a specific current stable version number on its landing page;
  this pass did not fetch `forge.rust-lang.org`'s release page or `rustup`'s channel
  manifest to pin an exact stable version for `rust-toolchain.toml`. Combined with
  `ml-kem`/`x-wing`'s **MSRV 1.85+**, any stable channel pin must be ≥ 1.85.
  **Gap:** pin the exact current stable version at implementation time, not here.
- **`cargo-ndk`:** `crates.io/crates/cargo-ndk` did not render crate metadata
  through the fetch tool (crates.io's crate pages are JS-rendered and returned only
  the site shell). **Gap:** its current version and Android NDK/API-level support
  matrix is unverified this pass; check `crates.io/api/v1/crates/cargo-ndk` or its
  GitHub releases directly when pinning it in `rust-toolchain.toml`/CI.
- **rustc/cargo/rustup absent locally.** This is a **hard blocker**, not a
  documentation gap: none of ADR 0007's per-PR gates (`cargo fmt`, `cargo clippy -D
  warnings`, `cargo test` against both adapters, `cargo deny check`, `cargo miri
  test`, `cargo careful test`, the ACVP/Wycheproof/X-Wing/differential harnesses) nor
  Gobley's Cargo-build Gradle tasks can run without a Rust toolchain installed via
  `rustup` and pinned in `rust-toolchain.toml`. No ADR gate should be marked green,
  and S0 cannot be demonstrated per its "every applicable gate is green" done
  criterion, until `rustup`/`cargo` are installed on this machine (or S0's CI
  equivalent) and the pin is chosen (≥ 1.85 per the crate MSRVs found above).

## Recommendation (summary)

| Component | Recommended version | Status |
|---|---|---|
| Kotlin / KGP | 2.4.20 | Verified current stable, fully-supported tuple partner below |
| Gradle wrapper | 9.7.0 (not the installed 9.7.1) | Verified as KGP 2.4.20's fully-supported max |
| AGP | ≤ 9.3.1 GA (not 9.4.0, which is alpha) | Verified as KGP 2.4.20's fully-supported max |
| `:sdk` Android target plugin | `com.android.kotlin.multiplatform.library` (needs AGP ≥ 8.10.0) | Verified prerequisites; library-module-only |
| `:app` Android plugin | `com.android.application` (standard) | Verified scope exclusion of the library plugin |
| Compose Multiplatform | 1.12.1 | Verified; Android/iOS floors set by project, not CMP |
| Compose Compiler plugin | same version as Kotlin (2.4.20) | Verified same-version requirement |
| Gobley | 0.3.7 | Verified current stable |
| UniFFI | 0.29.4 | Verified, bundled by Gobley 0.3.7 |
| `kotlin("plugin.atomicfu")` | = Kotlin version (2.4.20) | Verified required companion |
| `aws-lc-rs` | latest 1.x, `fips`/`non-fips` features | Verified Cargo-feature seam; FIPS mobile cert gap unchanged |
| Reference ML-KEM | RustCrypto `ml-kem` (pure Rust) | Verified; MSRV 1.85+, unaudited |
| Reference X-Wing | RustCrypto `x-wing`, **re-verify against draft-11** or hand-roll | Verified draft-06 vs. current draft-11 gap |
| `mlkem-native` (C) | vendor + author FFI crate, or drop from day-one reference scope | Verified: no existing Rust crate wraps it |
| Rust stable / MSRV | unresolved, must be ≥ 1.85 | Not pinned this pass |
| `cargo-ndk` | unresolved | Not verified this pass (fetch tool limitation) |
| rustc/cargo/rustup | **absent locally** | Hard blocker to any ADR 0007 gate |

No ADR 0004/0007/0001 gate is recommended for weakening. The two open blockers
that must close before S0 can be demonstrated are: (1) install and pin a Rust
toolchain (`rustup` + `rust-toolchain.toml`, ≥ 1.85), and (2) resolve the X-Wing
draft-version/vector-source question (either verify `x-wing`-crate conformance
with draft-11, or implement the combiner directly, and confirm BoringSSL/CIRCL
vector sources are themselves at draft-11) before treating ADR 0007's X-Wing
vector gate as satisfiable.
