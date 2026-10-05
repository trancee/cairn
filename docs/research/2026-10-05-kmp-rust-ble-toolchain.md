# Research: Kotlin Multiplatform + Rust core + BLE toolchain viability

Status: research draft, not an approved design. No ADR exists yet. Any adoption
requires an ADR (Constitution O3), a formal model where relevant, and expert
review before being treated as a decision. All dates/versions below were
fetched live on 2026-10-05 against official sources (GitHub API/releases,
JetBrains/Kotlin docs, Google Android NDK docs, Apple developer docs) unless
explicitly marked SECONDARY/UNVERIFIED.

This answers ticket `03-kmp-rust-ble-toolchain.md`. It is consistent with the
resolved floors in `06-minimum-os-versions.md` (**Android 8 / API 26, iOS 13**)
and feeds the background-BLE research in `04-android-ios-background-ble.md`
(not duplicated here).

**Headline finding, stated up front:** the Android floor (API 26) is fine on
every layer checked. The iOS floor (iOS 13) is **not achievable** with the
current stable Kotlin/Native/Compose Multiplatform toolchain — the default
minimum has moved to iOS 15.0, with no supported path back to 13. This is the
single most consequential finding in this report and is restated in each
relevant section.

---

## 1. Rust↔Kotlin Multiplatform binding toolchains

### 1.1 Gobley (github.com/gobley/gobley, gobley.dev)

- **Status**: active, young. Org repo created 2025-02-28 (as a fork of an
  earlier project, see 1.2); underlying commit history traces back further
  because it's a fork. Last push 2026-10-02. 435 stars, ~74 open issues
  (type:issue). Source: `api.github.com/repos/gobley/gobley`.
- **Latest release**: **v0.3.7, published 2025-10-08**. Release cadence has
  been roughly monthly since v0.1.0 (2025-03-03) → v0.2.0 (2025-04-06) →
  v0.3.0 → v0.3.1…v0.3.7. Source: `github.com/gobley/gobley/releases`.
- **Build integration**: two Gradle plugins, `dev.gobley.cargo` (invokes
  `cargo build` and links the result) and `dev.gobley.uniffi` (runs UniFFI
  bindgen), plus `dev.gobley.rust` (toolchain/linker config). `Cargo.toml` is
  configured with `crate-type = ["cdylib", "staticlib"]`; docs state
  explicitly: "Gobley uses the static library file when building for iOS, and
  the dynamic library file for Android." Source: `gobley.dev/docs/tutorial/`,
  `gobley.dev/docs/gradle-plugins/cargo/`.
  - **Android**: the Cargo plugin derives target ABIs automatically from
    `android.defaultConfig.ndk.abiFilters` and builds a `.so` per ABI.
    Source: `gobley.dev/docs/gradle-plugins/cargo/`.
  - **iOS**: Gobley builds the Rust static library per Apple target and links
    it into the Kotlin/Native framework; the actual `.xcframework` assembly is
    delegated to Kotlin/Native's own Gradle tasks (e.g.
    `embedAndSignAppleFrameworkForXcode`), not something Gobley implements
    itself. No docs page or GitHub issue mentions "xcframework" at all (0
    search hits on `repo:gobley/gobley xcframework`) — **this is inferred from
    the tutorial's description of per-target static-lib builds, not an
    explicit, independently confirmed Gobley feature.**
- **Shared commonMain Kotlin — this is Gobley's headline differentiator**: the
  bindgen's documented output layout is genuinely multiplatform:
  ```
  <output>/androidMain/kotlin/<ns>/<ns>.android.kt
  <output>/commonMain/kotlin/<ns>/<ns>.common.kt
  <output>/jvmMain/kotlin/<ns>/<ns>.jvm.kt
  <output>/nativeMain/kotlin/<ns>/<ns>.native.kt
  <output>/stubMain/kotlin/<ns>/<ns>.stub.kt
  ```
  A `kotlin_multiplatform` boolean flag controls whether real `expect`/`actual`
  declarations are generated. Source: `gobley.dev/docs/bindgen/`.
- **Async/callback support**: Gobley is a UniFFI bindgen front-end, so it
  inherits UniFFI's core async machinery (Rust `async fn`/`Future` ⟷ Kotlin
  `suspend fun`, see §1.3). The tutorial's `Cargo.toml` pulls in
  `kotlin("plugin.atomicfu")` "to use atomic types used by the bindings,"
  consistent with real coroutine support rather than pure blocking+callback.
  **No Gobley-specific async doc page exists** (no `/docs/async`), so exact
  codegen fidelity for suspend functions is inferred from the UniFFI
  dependency rather than independently demonstrated in a Gobley example.
  Source: `gobley.dev/docs/tutorial/`.
- **Debugging story**: no integrated Rust-in-Kotlin debugging. Open issue
  #219, "Android debugging tips documentation," reports that external
  lldb/gdb attach works but is not integrated into Android Studio, and that
  NDK debugging tooling targets C/C++ via ndk-build/cmake, not Rust — no
  resolution yet. Related open issue #221 reports NDK debugging failing on
  recent Samsung devices. The `common-development-practices` doc states the
  only way to get one IDE for both languages is paid IntelliJ IDEA Ultimate;
  otherwise two separate IDEs/debuggers are used side by side. Source:
  `github.com/gobley/gobley/issues/219`, `#221`,
  `gobley.dev/docs/common-development-practices/`.
- **Known pitfalls** (from issues/docs):
  - Release-mode Compose previews unsupported (`UnsatisfiedLinkError`) — issue
    #99.
  - Overload-resolution ambiguity bug on UniFFI trait methods — issue #274
    (open).
  - JNA/R8 interaction: the UniFFI plugin must auto-generate ProGuard rules
    for JNA reflection to survive R8 obfuscation on Android release builds.
  - Arm32 Android release checksum-check failure from JNA signed/unsigned
    mismatch — issue #252 (open).
  - WASM/JS targets unsupported — generated stub throws
    `NotImplementedError`.
  - A documented iOS linker pitfall: `___chkstk_darwin not found` when a C
    dependency targets **iOS ≥13** together with Rust ≥1.83 — a real,
    non-obvious cross-compilation gotcha that is directly relevant to this
    project's iOS floor discussion. Source:
    `gobley.dev/docs/cross-compilation-tips/`.
  - No Linux ARM64 build-host support yet; MinGW-on-ARM Windows unsupported.
- **Minimum Android API / iOS version**: **no explicit floor documented by
  Gobley itself anywhere in the crawled docs.** It inherits whatever
  `minSdk`/iOS deployment target the consumer's Gradle/Xcode project sets —
  which in practice means it inherits the Kotlin/Native floor described in
  §2.1 (iOS 15.0 as of current stable Kotlin), since Gobley cannot build an
  iOS target lower than what the installed Kotlin/Native compiler supports.

### 1.2 uniffi-kotlin-multiplatform-bindings (Trixnity) — superseded by Gobley

- Originally hosted on GitLab:
  `gitlab.com/trixnity/uniffi-kotlin-multiplatform-bindings`. The page exists
  (not a 404) but GitLab's JS-rendered shell could not be reduced to readable
  content by the fetch tool used in this research — its own last-commit date
  and star count were **not independently verified**.
- **Authoritative confirmation of status comes from Gobley's own README**:
  *"This project was forked from [UniFFI Kotlin Multiplatform bindings].
  Since the original project is no longer maintained, active development now
  continues here [Gobley]."* Source: `github.com/gobley/gobley` README.
- **Conclusion**: not a separate, actively maintained option — treat Gobley as
  its sole living continuation. A follow-up `gitlab.com/api/v4/projects/...`
  query would give an authoritative last-activity date if ever needed, but
  does not change the recommendation.

### 1.3 Plain UniFFI (github.com/mozilla/uniffi-rs) — baseline capability

- **Status**: mature and very active. Repo created 2020-06-10, 5,007 stars,
  294 open issues, last push 2026-10-05 (same day as this research). Source:
  `api.github.com/repos/mozilla/uniffi-rs`.
- **Current version**: **0.32.2** (crates.io `max_stable_version`, tag commit
  dated 2026-09-22). Note: `mozilla/uniffi-rs` does not use GitHub's formal
  Releases feature (`/releases/latest` returns empty) — version history lives
  in git tags + crates.io publishes only. Source: `crates.io/api/v1/crates/uniffi`,
  `api.github.com/repos/mozilla/uniffi-rs/tags`.
- **Does it produce shared commonMain Kotlin?** **No.** The official Kotlin
  bindings configuration page
  (`mozilla.github.io/uniffi-rs/latest/kotlin/configuration.html`) lists only
  `package_name`, `cdylib_name`, `generate_immutable_records`,
  `mutable_records`, `custom_types`, `external_packages`, `rename`, `android`,
  `android_cleaner`, `kotlin_target_version`, `disable_java_cleaner`,
  `omit_checksums` — **no `kotlin_multiplatform` or expect/actual option**.
  Plain UniFFI's Kotlin backend targets a single flat JVM/Android target;
  Swift bindings are generated completely separately with their own codegen
  path. This is exactly the gap Trixnity/Gobley's fork fills on top of
  UniFFI's core IR/scaffolding.
- **Async support**: officially documented and real, not blocking+callback.
  From the "Async/Future support" manual page: *"UniFFI supports exposing
  async Rust functions over the FFI. It can convert a Rust Future/async fn to
  and from foreign native futures (async/await in Python/Swift/Ruby, suspend
  fun in Kotlin etc.)"* — i.e. `suspend fun` is a first-class, native mapping.
  Async trait methods are supported via `async-trait` + `#[uniffi::export]`.
  Caveat: **cancellation is not built in** — cancelling a suspend/Task on the
  Kotlin/Swift side does not automatically cancel the underlying Rust future;
  libraries must implement their own cancel-flag/channel pattern. Source:
  `mozilla.github.io/uniffi-rs/latest/futures.html`.
- **Min Android API / iOS version**: none documented. The only related note
  is `disable_java_cleaner`'s mention that `java.lang.ref.Cleaner`
  availability is a JVM 8+ concern — a JVM-language-level constraint, not an
  Android API or iOS version floor.

### 1.4 Hand-written JNI (Android) + Kotlin/Native cinterop (iOS) — the manual alternative

- **`jni` crate** (`github.com/jni-rs/jni-rs`): active. Latest release
  **v0.22.4, published 2026-03-16**; repo last pushed 2026-07-30, not
  archived. Ongoing soundness fixes through 2026 (exception handling,
  `bind_java_type` null-checks). No codegen: you write a thin Rust
  `extern "system"` JNI layer against `jni::JNIEnv`, paired with hand-written
  Kotlin `external fun` declarations and `System.loadLibrary`. Full manual
  control, zero compile-time cross-language safety net; maintenance burden
  scales with API-surface size (a BLE transport/crypto API is not small).
  Source: `github.com/jni-rs/jni-rs/releases`, GitHub API.
- **Kotlin/Native cinterop** (official Kotlin feature, not a separate repo):
  a `.def` file (`headers`, `staticLibraries`, `libraryPaths`, `compilerOpts`,
  `linkerOpts`, `package`, …) declares a C header plus a Rust-produced
  static/dynamic library; the `cinterop` tool turns this into a `.klib` with
  Kotlin bindings (C structs → field-accessor classes, pointers →
  `CPointer<T>`, typedefs → `typealias`). A Kotlin/Native target's
  `binaries { framework { ... } }` DSL then produces an Obj-C/Swift-compatible
  `.framework`, and the Kotlin Multiplatform Gradle plugin's `XCFramework`
  support combines per-arch frameworks into an XCFramework. This is the
  built-in, no-third-party-dependency mechanism for exposing a Rust
  `cdylib`/`staticlib` + hand-authored C header to Kotlin/Native (iOS)
  consumers and ultimately to Swift. Source:
  `kotlinlang.org/docs/native-c-interop.html`,
  `kotlinlang.org/docs/native-definition-file.html`,
  `kotlinlang.org/docs/multiplatform/multiplatform-build-native-binaries.html`.
- **Assessment**: this pairing (hand-written JNI + hand-written C header
  consumed via cinterop) is the standard "no generator" baseline. It gives
  full control (useful for an async BLE transport with callbacks/streams) at
  the cost of maintaining two separate, hand-synchronized FFI surfaces with no
  compile-time check that Rust and Kotlin signatures agree.

### 1.5 Supporting build-glue tools

| Tool | Latest version/date | Status | Relevance |
|---|---|---|---|
| **cargo-ndk** (`bbqsrc/cargo-ndk`) | v4.1.2, 2025-08-09; repo pushed 2026-09-14 | Active, MSRV Rust 1.86 | **High.** Cross-compiles Rust to all Android ABIs, auto-detects the installed NDK, exposes `CARGO_NDK_ANDROID_PLATFORM`/`ANDROID_PLATFORM` for target API level, emits Gradle-ready `jniLibs/<abi>/*.so`. Typically wired into Gradle via an `Exec` task before `preBuild`/`merge*JniLibs`. No hardcoded API ceiling — wraps whatever NDK is installed. |
| **Corrosion** (`corrosion-rs/corrosion`) | v0.6.1, 2026-01-17 | Active, requires CMake ≥3.15 | **Low.** Integrates Rust crates into a CMake build. A Gradle(Android)+Xcode(iOS) KMP project has no CMake build to integrate into unless an intermediate CMake/C++ layer already exists. |
| **uniffi-bindgen-cs** (`NordSecurity/uniffi-bindgen-cs`) | active, pushed 2026-06-23 | Active | **Not applicable** — confirmed C#/.NET target only, no Kotlin bearing. |
| **Diplomat** (`rust-diplomat/diplomat`) | v0.16.1, 2026-08-20; pushed 2026-09-19 | Active, pre-1.0 | **Medium.** Targets C, C++, Dart, JS/TS, C#, **Kotlin (via JNA)**, Python. Built by the ICU4X/Unicode project, tuned for data/text APIs rather than async/callback-heavy transport APIs. `diplomat-runtime` is explicitly still stabilizing (its own 0.16.1 notes discuss avoiding multiple copies of the runtime linked into one binary — a real risk if the app embeds other Rust-FFI libraries). No confirmed idiomatic Kotlin/Native (iOS) output — iOS would likely need a separate pipeline anyway. |
| **flapigen-rs** (`Dushistov/flapigen-rs`) | v0.11.0, 2026-04-04; repo pushed 2026-10-04, 65 open issues | Active commits, slow release cadence | **Medium-low.** `foreign_class!` macro generates JNI glue + **Java** (not idiomatic Kotlin) code; Kotlin consumption is via calling generated Java classes, not a direct, documented Kotlin target. |
| **rifgen** (`Dushistov/rifgen`) | original repo now 404; crate repo field now points to a community fork `Kofituo/rifgen`, last published 2023-06-08 | **Abandoned/orphaned** | Effectively dead; flapigen's companion interface generator has forked away from the original author. |
| **swift-bridge** (`chinedufn/swift-bridge`) | v0.1.59, 2026-01-06; pushed 2026-09-05 | Active | **Swift-only**, confirmed via README (Rust↔Swift types only, no Kotlin/JVM). Could be paired with hand-written JNI (§1.4) for a "two separate manual pipelines" architecture: swift-bridge auto-generates Swift+C glue for iOS, JNI hand-written for Android — avoids cinterop but means maintaining two divergent FFI codegen models with different Rust-side module shapes (`#[bridge]` vs. plain `extern "C"`). |
| **cargo-lipo** (`TimNN/cargo-lipo`) | last commit 2024-05-27 | **Deprecated**, confirmed in README ("please consider this project deprecated / passively maintained") | **Avoid.** The README itself explains why: Apple's arm64 iOS-simulator target means a classic lipo "fat binary" can hold only one arm64 variant (device *or* simulator, not both), which is precisely what made XCFrameworks (per-platform/arch bundles, not single fat binaries) the modern replacement. |
| **"cargo-xcframework"** | no canonical actively maintained generic tool found | — | GitHub search turned up only one-off, app-specific repos (e.g. `boltffi/boltffi`, `livekit/livekit-uniffi-xcframework`), not a reusable Cargo subcommand. De facto modern approach: script `xcodebuild -create-xcframework` directly from per-arch `cargo build --target <ios-triple>` outputs, or rely on Kotlin/Native's own XCFramework Gradle task when using cinterop (§1.4). This negative finding is based on GitHub search coverage, not an exhaustive crates.io audit — flagged as a soft gap. |

### 1.6 Comparison summary

| Dimension | Gobley | Trixnity uniffi-kotlin-multiplatform-bindings | Plain UniFFI | Manual JNI + cinterop |
|---|---|---|---|---|
| Status | Active | Unmaintained (superseded by Gobley) | Active, mature | N/A (built-in Kotlin feature + a crate) |
| Latest version | v0.3.7 (2025-10-08) | — | 0.32.2 (2026-09-22) | jni-rs 0.22.4 (2026-03-16) |
| Shared commonMain Kotlin | **Yes**, documented | Presumably (not independently verified) | **No** — JVM/Android only | N/A — you write commonMain `expect`/platform `actual` by hand |
| Android per-ABI `.so` | Auto, via Cargo Gradle plugin | Unknown | N/A (not a build tool) | Manual, typically via cargo-ndk |
| iOS XCFramework | Delegated to Kotlin/Native tooling (not independently confirmed as a Gobley feature) | Unknown | N/A | Delegated to Kotlin/Native's `XCFramework` Gradle task |
| Async (Rust async fn → Kotlin suspend) | Inherited from UniFFI, not independently documented for Gobley | Unknown | **Yes, documented**, no built-in cancellation | Fully manual — you design the callback/coroutine bridge yourself |
| IDE debugging across languages | No integrated story; external lldb/gdb only | Unknown | N/A | Same — no generator-provided debugging story either way |
| Documented min Android API / iOS version | None — inherits consumer project's settings (and therefore Kotlin/Native's floor, §2.1) | Unknown | None | N/A — bounded only by jni-rs's own Android NDK support and Kotlin/Native's floor |

---

## 2. Minimum OS floor verification

This is the section most load-bearing for `06-minimum-os-versions.md`. **Short
version: Android 8 / API 26 is still fully supported everywhere checked.
iOS 13 is not supported anywhere in the current stable KMP toolchain.**

### 2.1 Kotlin/Native minimum iOS deployment target

- **Current stable Kotlin**: **2.4.20**, released 2026-09-07 (next:
  2.4.21-RC 2026-09-30, 2.5.0-Beta1 2026-09-23; 2.5.0 stable planned December
  2026). Source: `kotlinlang.org/docs/releases.html`,
  `github.com/JetBrains/kotlin/releases`.
- **Current documented default minimum Apple target versions**
  (`kotlinlang.org/docs/native-target-support.html`, "Supporting lower Apple
  target versions"):

  | Platform | Default minimum |
  |---|---|
  | iOS / tvOS | **15.0** |
  | macOS | 12.0 |
  | watchOS | 8.0 |

  The same page's target tier table explicitly describes `iosArm64` /
  `iosSimulatorArm64` / `iosX64` as "Apple iOS and iPadOS **15.0** and later."

- **Timeline of the floor increases**, confirmed from Kotlin's own release
  notes and linked YouTrack tickets:

  | Kotlin version | Date | Change | Source |
  |---|---|---|---|
  | pre-2.3.0 | — | Default min iOS/tvOS = 12.0 | `kotlinlang.org/docs/whatsnew23.html` (states the *from* value) |
  | **2.3.0** | 2025-12-16 | iOS/tvOS **12.0 → 14.0**; watchOS 5.0 → 7.0 (`KT-80620`, `KT-80624`) | `kotlinlang.org/docs/whatsnew23.html` §"Changes to Apple target support" |
  | **2.4.0** | 2026-06-03 | iOS/tvOS **14.0 → 15.0**; macOS 11.0→12.0; watchOS 7.0→8.0 (`KT-84826`); release notes tie this to "Kotlin 2.4.0 compiler supports Xcode 26.4" | `kotlinlang.org/docs/whatsnew24.html` §"Changes to Apple target support" |
  | **2.4.20** | 2026-09-07 | No further default-floor change; `KT-87187` ("Bump Apple deployment targets to match Xcode 27") tracks build-tooling/CI compatibility and deprecates `watchosArm32` ahead of removal in 2.5.0 | `kotlinlang.org/docs/whatsnew2420.html` |

- **Override mechanism exists but is explicitly unsupported**:
  ```kotlin
  binaries.configureEach {
      freeCompilerArgs += "-Xoverride-konan-properties=minVersion.ios=14.0"
  }
  ```
  JetBrains' own warning: *"such a setup is not guaranteed to successfully
  compile and can break your app during building or at runtime."* No JetBrains
  example or doc demonstrates overriding below 12.0/14.0 — **there is no
  documented path, supported or unsupported, back to iOS 13.0.** Kotlin 2.3.0
  removed iOS 13 support outright with no stated fallback guarantee. Source:
  `kotlinlang.org/docs/whatsnew23.html`, `native-target-support.html`.

- **Root cause**: this is Apple/Xcode-toolchain-driven, not an arbitrary
  JetBrains choice. 2.3.0's notes say the 12.0→14.0 bump was because "usage of
  older versions is already very limited... opens an opportunity to support
  Mac Catalyst"; 2.4.0's notes tie the 14.0→15.0 bump directly to adding Xcode
  26.4 compiler support; 2.4.20 already has `KT-87187` tracking a further bump
  to match Xcode 27, due to land with the 2.5.0 line (Dec 2026). **Apple's own
  Xcode 26/27 release notes were not independently retrievable** via this
  research's fetch tooling (JS-rendered pages returned empty content after two
  attempts at `developer.apple.com/documentation/xcode-release-notes/...`) —
  flagged as **UNVERIFIED from Apple's primary source directly**, though the
  causal chain is well evidenced from Kotlin's side.

- **Consequence for this project**: to target iOS 13 you would need to either
  (a) pin to Kotlin ≤2.2.x (predating the Dec 2025 floor bump) and forgo every
  Kotlin/Compose feature and fix from 2.3.0 onward indefinitely, or (b) use the
  unsupported override flag and accept JetBrains' own "may not compile or may
  break at runtime" disclaimer, with no demonstrated precedent of it working
  below 14.0. Neither is a sound footing for a security-sensitive SDK that
  will need ongoing Kotlin upgrades.

### 2.2 Compose Multiplatform minimum OS requirements

- **Current stable Compose Multiplatform**: **1.12.1**, released 2026-09-22
  (1.12.0: 2026-08-25). Source:
  `github.com/JetBrains/compose-multiplatform/releases`.
- **Official, explicit supported-platforms table** (this is the single most
  directly authoritative data point in this whole report — a dedicated
  JetBrains compatibility page, not an inference):

  > Compose Multiplatform 1.12.1 supports the following platforms:
  >
  > | Platform | Minimum version |
  > |---|---|
  > | Android | Android 5.0 (API level 21) |
  > | iOS | **iOS 14** |
  > | macOS | macOS 13 arm64 |
  > | Windows | Windows 10 (x86-64, arm64) |
  > | Linux | Ubuntu 20.04 (x86-64, arm64) |

  Source: `kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html`
  (the URL `jetbrains.com/help/kotlin-multiplatform-dev/compose-compatibility-and-versioning.html`
  redirects here), section "Supported platforms".

- **Reading this alongside §2.1**: Compose Multiplatform's own doc states a
  minimum iOS of 14, which is *looser* than Kotlin/Native's current compiler
  default of 15.0 — this is believable because Compose Multiplatform's stated
  floor is a UI-framework compatibility claim checked against whatever Kotlin
  version its own build pins, and may simply not have been bumped to reflect
  Kotlin 2.4.0's 15.0 default yet, or may rely on the override mechanism
  internally. **Practical floor for a project built with the current stable
  Kotlin/Native compiler is still iOS 15.0** (§2.1), because Compose
  Multiplatform's iOS target is compiled through Kotlin/Native and inherits
  its default deployment target unless explicitly overridden (unsupported).
  Either way, **iOS 13 is below both figures** and is not achievable.
- **Android**: Compose Multiplatform's own floor (API 21) is well below this
  project's target (API 26) — **no constraint here** from Compose
  Multiplatform itself.
- Also confirmed from the same page: Compose Multiplatform 1.8.0+ requires at
  least **Kotlin 2.1.0**, and recommends **Kotlin 2.2.20+** for projects
  targeting "platforms with rapidly evolving support, such as iOS" — i.e.
  JetBrains' own guidance nudges iOS-targeting projects toward newer Kotlin,
  which is exactly the direction that keeps raising the iOS floor.

### 2.3 Gobley / UniFFI Kotlin bindings — no independent floor

As noted in §1.1 and §1.3, **neither Gobley nor plain UniFFI document their
own minimum Android API level or iOS version.** Both are bindgen/build-glue
layers that inherit whatever floor the consumer's Android Gradle Plugin
(`minSdk`) and Kotlin/Native compiler (iOS deployment target, §2.1) impose.
The practical floor they impose is therefore identical to §2.1/§2.2: API 21
(Android, no issue) and iOS 15.0 (current Kotlin/Native default, a real
problem for an iOS-13 target).

### 2.4 Android NDK minimum supported API level

- **Current stable NDK**: **r30**, released 2026-09-08 (r29: 2025-10-06; LTS
  line is **r27**, July 2024). Source: `github.com/android/ndk/releases`,
  `developer.android.com/ndk/downloads/revision_history`.
- **Authoritative compatibility table** (NDK project wiki,
  `Compatibility.md`): the last API level drop was **API 19/20 (KitKat)**,
  supported through r25 only. NDK r26's changelog states explicitly: *"KitKat
  (APIs 19 and 20) is no longer supported. The minimum OS supported by the NDK
  is Lollipop (API level 21)."* Source: `github.com/android/ndk.wiki`
  `Changelogs/Changelog-r26.md`.
- **No subsequent changelog (r27, r28, r29, r30) raises this floor further** —
  checked all four for API-level/minimum-OS language; their changes are
  LLVM/toolchain updates, 16KB page-size alignment, CMake minimum-version
  bumps, not target-API floor changes.
- **Conclusion**: NDK floor is **API 21**, unchanged since September 2023
  through the current r30 (September 2026). **Android 8.0 / API 26 is
  comfortably buildable** on every current and recent NDK — this is a
  non-issue for `cargo-ndk`-based builds.

### 2.5 Net verdict on floors

| Layer | Project target | Actually supported (current stable, 2026-10-05) | Verdict |
|---|---|---|---|
| Android NDK (cargo-ndk builds) | API 26 | API 21+ (unchanged since NDK r26, Sept 2023) | ✅ Fine |
| Compose Multiplatform Android | API 26 | API 21+ (official table, CMP 1.12.1) | ✅ Fine |
| Kotlin/Native iOS deployment target | iOS 13 | **iOS 15.0 default** (Kotlin 2.4.0+, current stable 2.4.20) | ❌ **Not supported**, no safe override path |
| Compose Multiplatform iOS | iOS 13 | Documented floor iOS 14, but inherits Kotlin/Native's compiled-against floor (15.0) in practice | ❌ **Not supported** |
| Gobley / UniFFI Kotlin bindings | iOS 13 | No own floor — inherits Kotlin/Native's 15.0 | ❌ **Not supported** (same root cause) |

**This directly contradicts the floor recorded in `06-minimum-os-versions.md`.**
That ticket already flagged this exact check as a dependency ("KMP/CMP/UniFFI
support for iOS 13 must be verified") — this research confirms the floor
cannot be met with the current toolchain. Concrete options, in order of
least disruptive:
1. **Raise the iOS floor to iOS 15** to match Kotlin/Native's and Compose
   Multiplatform's current defaults with zero toolchain gymnastics. This is
   the only option with no "unsupported/may break" caveat attached anywhere
   in the sources reviewed.
2. Pin the whole project to **Kotlin ≤2.2.x** (last line supporting iOS 12 by
   default) and accept forgoing all Kotlin/Compose language and library
   improvements, security fixes, and tooling updates from late 2025 onward,
   indefinitely, for the life of the product. This is a significant,
   compounding maintenance cost and a bad fit for a security-sensitive SDK
   that needs to track upstream fixes.
3. Use `-Xoverride-konan-properties=minVersion.ios=13.0` against a newer
   Kotlin/Native compiler. JetBrains explicitly disclaims this path; no
   example anywhere goes below 14.0; treat as **not viable for production**
   without extensive, repeated verification on every Kotlin upgrade.

---

## 3. KMP BLE libraries

### 3.1 Kable (github.com/JuulLabs/kable)

- **Latest release**: **0.45.0, published 2026-09-15** (prior: 0.44.3,
  2026-07-22). Repo: 1,197 stars, 115 forks, not archived, last push
  2026-10-05, 73 open issues. Very actively maintained (commits as recent as
  2026-09-28). Source: `api.github.com/repos/JuulLabs/kable`,
  `.../releases`.
- **Central role**: confirmed, this is Kable's entire purpose — scan,
  connect, GATT-client characteristic/descriptor read/write/notify. Source:
  README (`raw.githubusercontent.com/JuulLabs/kable/master/README.md`).
- **Peripheral / GATT server**: **not supported in any released version.**
  Open **draft** PR #1224, "Add `kable-server` module (BLE peripheral role /
  GATT server)," opened 2026-07-18 by maintainer `twyatt`, last updated
  2026-09-29, `merged_at: null`. Proposed design: `com.juul.kable.server`
  package with a `GattServer{}` DSL backed by
  `BluetoothGattServer`/`BluetoothLeAdvertiser` on Android and
  `CBPeripheralManager` on Apple (watchOS explicitly excluded — peripheral-role
  CoreBluetooth initializers are `API_UNAVAILABLE` there); JVM (btleplug) and
  JS/wasmJs noted as central-only, unsupported for server role. Source:
  `api.github.com/repos/JuulLabs/kable/pulls/1224`.
- **L2CAP CoC**: **not supported in any released version.** Open PR #1231,
  "Add L2CAP channel support," opened 2026-07-20, last updated 2026-09-22,
  `merged_at: null`. Adds `L2CapSocket`,
  `AndroidPeripheral.openL2CapChannel`/`openInsecureL2CapChannel` (via
  `BluetoothDevice.createL2capChannel`), and `CoreBluetoothPeripheral.openL2CapChannel`
  (via `CBL2CAPChannel`); closes older issues #810, #588, #1023. Source:
  `api.github.com/repos/JuulLabs/kable/pulls/1231`.
- **iOS state restoration**: **supported, merged, opt-in.** PR #561, "Make
  `CentralManager` state restoration opt-in," merged 2023-09-06. Usage:
  `CentralManager.configure { stateRestoration = true }` (default `false`).
  Source: `api.github.com/repos/JuulLabs/kable/pulls/561`, issue #277.
- **Android foreground-service caveats**: no maintainer-documented caveat
  found. One open bug report, issue #332 (2022-05-27, still open): an
  intermittent NPE in `AndroidPeripheral.<init>`/`BluetoothDeviceKt.close`
  specifically reported when scanning/connecting from a foreground service on
  Android 10+. This is a bug report, not an acknowledged, documented
  limitation — **treat as an open risk to validate on-device**, not a known
  blocker. Source: `api.github.com/repos/JuulLabs/kable/issues/332`.

### 3.2 "Blue Falcon" — two repos, only one is real

- **`Monkopedia/blue-falcon`** is a **fork** of the real project (`"fork":
  true`, `parent.full_name: Reedyuk/blue-falcon`), 0 stars, issues disabled,
  stale since 2026-04-06 — adds a Linux BlueZ/sdbus-kotlin engine. Not the
  canonical project. Source: `api.github.com/repos/Monkopedia/blue-falcon`.
- **`Reedyuk/blue-falcon`** (homepage `bluefalcon.dev`) is the canonical,
  **currently very actively developed** project: 488 stars, 65 forks, 11 open
  issues, not archived, Apache-2.0, created 2019-08-15, **last push
  2026-10-05** (same day as this research). Most recent releases: 3.7.13
  (2026-10-02), 3.7.12 (2026-10-01), 3.7.11 (2026-09-28), 3.7.10
  (2026-09-19), 3.7.9 (2026-09-16) — near-daily cadence currently. Source:
  `api.github.com/repos/Reedyuk/blue-falcon`, `.../releases`.
- **Peripheral / GATT server**: **supported since 3.7.0 (2026-08-06),
  production-labeled by the project itself.** README: *"Peripheral / GATT
  Server — Advertising, local services, multi-central sessions, and targeted
  notifications on Android, iOS, and macOS (3.7.0+)"* and *"Production
  GATT-server backends are available on Android, iOS, and macOS; the other
  Central platforms do not currently provide this server API."* The
  `dev.bluefalcon:blue-falcon-peripheral:3.7.13` module exposes a
  service/characteristic/descriptor tree, advertising, per-connected-central
  `PeripheralSession`, subscription tracking, `maximumUpdateValueLength`, and
  `session.notify()`. Supporting closed issues: #238 (Android GATT server
  backend), #240 (Apple peripheral backend), #242 (multiplatform peripheral
  examples), #235 (extract peripheral APIs into dedicated module), #256/#281
  (README docs). Several open issues (#308, #303) show active hardening of
  callback/operation ownership — i.e. functional but still young/evolving,
  not battle-tested the way Kable's central-role code is. Source:
  `raw.githubusercontent.com/Reedyuk/blue-falcon/master/README.md`,
  `api.github.com/search/issues?q=repo:Reedyuk/blue-falcon+peripheral`.
- **L2CAP**: supported and actively iterated — closed issues #219 ("Finish
  out l2cap support"), #226 (fix 2-byte SDU-length prepend/strip in an RPi
  L2CAP engine), #189 (original "L2Cap support"); several open issues (#295,
  #304, #306, #309) around teardown/ownership hardening, again indicating
  functional-but-maturing rather than stable-for-years.
- **iOS state restoration**: **could not verify.** No README section or
  closed/merged PR documents `CBCentralManager`/`CBPeripheralManager`
  background restoration (`restoreIdentifier`/`willRestoreState`). One
  tangentially related closed issue (#231, "dual-role and multi-peer BLE"
  scoping discussion) references background/multi-peer concerns but not CB
  state restoration specifically. **UNVERIFIED** — would need direct
  inspection of the iOS engine source (`library/*/src/iosMain`) to confirm
  one way or the other.
- **Android foreground-service caveats**: **could not verify.** No issue
  matched the exact phrase "foreground service".
- **Context (issue #231, closed)**: as recently as the 3.5.0 line, a team
  evaluating simultaneous central+peripheral ("dual role") multi-peer use
  found real gaps (e.g. `CharacteristicWriteRequest` lacking a
  `remoteCentralId` to identify which connected central issued a request) —
  useful signal that the peripheral/server API, while shipping, is still
  actively maturing and worth a hands-on spike before committing.

### 3.3 Other current KMP BLE libraries

- A GitHub topic search (`topic:bluetooth-low-energy topic:kotlin-multiplatform`)
  returned 11 repos; apart from Kable/Blue-Falcon, hits were application
  repos (e.g. `meshtastic/Meshtastic-Android`), not general-purpose
  peripheral/GATT-server libraries. No other actively maintained, general KMP
  BLE peripheral/server library was found. GitHub code search was not
  available in this session (401/auth-gated), so a cross-repo code-pattern
  search (e.g. for `GattServer`/`advertise` usage outside named repos) was
  **not performed** — a soft gap if an exhaustive sweep is ever needed.

### 3.4 Native API confirmation (context for any expect/actual fallback)

- **Android `BluetoothGattServer`**: "Public API for the Bluetooth GATT
  Profile server role... allowing applications to create Bluetooth Smart
  services and characteristics," obtained via
  `BluetoothManager.openGattServer(...)`. Source:
  `developer.android.com/reference/android/bluetooth/BluetoothGattServer`.
- **Android `BluetoothLeAdvertiser`**: "provides a way to perform Bluetooth LE
  advertise operations," via `BluetoothAdapter.getBluetoothLeAdvertiser()`.
  Source:
  `developer.android.com/reference/android/bluetooth/le/BluetoothLeAdvertiser`.
  Neither reference page states an explicit foreground-service prohibition or
  caveat — **the Android reference docs fetched here say nothing about
  foreground services either way**; this would need the separate
  background-execution guide (see `04-android-ios-background-ble.md` for the
  dedicated background/foreground-service research track — not duplicated
  here).
- **Apple `CBPeripheralManager`**: official docs confirm it "manages and
  advertises peripheral services exposed by this app" (service/characteristic
  publishing, `startAdvertising`), and explicitly states peripheral-role
  advertising is **unavailable on watchOS/tvOS/visionOS** ("you can't
  advertise services using a CBPeripheralManager object because support for
  doing so is unavailable"). It also documents the `bluetooth-peripheral`
  background mode requirement: without it, published GATT services are
  disabled while the app is backgrounded/suspended. Source:
  `developer.apple.com/documentation/corebluetooth/cbperipheralmanager`.

### 3.5 Conclusion for §3

**No current KMP library covers central + peripheral + GATT-server + L2CAP
with the maturity this project needs out of the box.** Two real options:

- **Kable** is the de facto standard for **central-role only**, has years of
  production use, opt-in iOS state restoration, but peripheral/server and
  L2CAP are both mid-flight, unmerged, maintainer-authored PRs (#1224, #1231)
  — not shippable today, and "merging soon" is plausible but not guaranteed.
- **Reedyuk/blue-falcon** already ships peripheral/GATT-server (Android, iOS,
  macOS) and L2CAP as of its 3.7.x line, under very active, near-daily
  development — but it is smaller (488★ vs. Kable's 1,197★), newer in this
  feature area (3.7.0 shipped 2026-08-06), still visibly hardening
  connection/callback lifecycle issues, and has unverified iOS
  state-restoration and Android foreground-service support.

If the project needs peripheral/GATT-server + L2CAP **today**, the realistic
choices are: (a) adopt Blue-Falcon's `blue-falcon-peripheral` module and plan
for a hands-on validation spike (state restoration, foreground service,
connection-lifecycle edge cases are all unverified from docs alone), or (b)
stay on Kable for central-role and write **platform-specific `expect`/`actual`
code directly against `CBPeripheralManager`** (iOS) and
**`BluetoothGattServer`/`BluetoothLeAdvertiser`** (Android) for the
peripheral/server side, revisiting Kable's own PRs (#1224, #1231) periodically
as merge candidates.

---

## Recommendation

1. **Binding toolchain**: adopt **UniFFI + Gobley** as the primary Rust↔KMP
   bridge, not plain UniFFI alone and not hand-written JNI/cinterop from
   scratch. Rationale: Gobley is the only actively maintained option that
   produces genuine shared `commonMain` Kotlin (real `expect`/`actual`), wires
   Gradle↔Cargo automatically per-ABI for Android, and inherits UniFFI's
   documented (if cancellation-less) async-fn-to-suspend-fun support — which
   matters for a protocol core that will expose async send/receive
   operations. Budget explicitly for its known rough edges: no integrated
   Rust debugger in Android Studio/Xcode (plan on lldb/gdb attach plus
   separate IDEs), broken release-mode Compose previews (#99), and the
   documented `chkstk_darwin` iOS linker pitfall on newer Rust+iOS≥13
   combinations. Treat `cargo-ndk` as the standard companion for Android
   cross-compilation (already effectively assumed by Gobley's Cargo plugin
   under the hood) and Kotlin/Native's own `XCFramework` Gradle task as the
   iOS packaging story — do not add cargo-lipo (dead) or chase a
   "cargo-xcframework" tool that does not canonically exist. Keep
   hand-written JNI + cinterop as a documented fallback only for any
   narrow surface that UniFFI/Gobley genuinely cannot express (e.g. unusual
   callback shapes), not as the primary approach — it has no tooling
   advantage over Gobley and strictly more hand-maintenance burden.

2. **iOS 13 floor: not achievable, must be revisited.** This is the most
   important actionable finding in this report. Every layer in the KMP/CMP
   toolchain checked (Kotlin/Native compiler default, Compose Multiplatform's
   own documented table) places the floor at iOS 14–15 today, and Kotlin/Native
   2.4.0+ (current stable line) specifically requires iOS 15.0 with no
   supported override below 14.0. Recommend raising the project's iOS floor
   to **iOS 15** to match current tooling defaults with zero unsupported
   flags, and feeding this back into `06-minimum-os-versions.md` as a
   contradicted assumption requiring a re-decision (the ticket already
   anticipated this check might fail this way). The alternative — pinning to
   Kotlin ≤2.2.x forever — is not a credible long-term posture for a
   security-relevant SDK that must track upstream fixes.
   The **Android 8 / API 26** floor, by contrast, is solid: NDK, Compose
   Multiplatform's own Android floor (API 21), and Gobley/UniFFI all clear it
   with no caveats.

3. **BLE library**: do not rely on any single current KMP BLE library to cover
   the full central+peripheral+GATT-server+L2CAP surface. Use **Kable** for
   the central/client role (mature, widely used, opt-in state restoration
   already shipped) and plan **platform-specific `expect`/`actual` code**
   (`CBPeripheralManager` on iOS, `BluetoothGattServer` +
   `BluetoothLeAdvertiser` on Android) for the peripheral/GATT-server/L2CAP
   side, rather than betting the schedule on Kable's unmerged #1224/#1231 PRs
   landing, or on Blue-Falcon's newer, still-hardening peripheral module as
   the sole implementation. Re-evaluate Blue-Falcon and Kable's peripheral PRs
   at implementation time — both are moving targets and this assessment has a
   short shelf life (Kable's PRs were both updated within the last two weeks
   of this research; Blue-Falcon is shipping multiple releases per week).

---

## Open questions / unverified

- **Gobley's iOS XCFramework automation** is inferred from its tutorial's
  description of per-target static-lib builds; no doc page or GitHub issue
  uses the term "xcframework" at all. Treat as "delegated to standard
  Kotlin/Native tooling," not an independently confirmed Gobley capability.
- **Gobley's async/suspend-fun fidelity** specifically (as opposed to plain
  UniFFI's documented behavior) has no dedicated doc page — inferred from the
  `atomicfu` plugin dependency in the tutorial, not directly demonstrated.
- **Trixnity's original GitLab repo** (`gitlab.com/trixnity/uniffi-kotlin-multiplatform-bindings`)
  last-commit date, star count, and any archival banner text were not
  independently retrievable (GitLab's JS-rendered page didn't reduce to
  readable markdown via the fetch tool used). Gobley's own README's
  characterization ("no longer maintained") was taken at face value; a
  `gitlab.com/api/v4/projects/...` query would give an authoritative
  timestamp if ever needed.
- **Apple's own Xcode 26/27 release notes** (minimum deployment target /
  simulator support implications) were not retrievable via this research's
  fetch tooling (JS-rendered pages returned empty content on two attempts).
  The causal link between Xcode version support and Kotlin/Native's iOS floor
  bumps is well evidenced from Kotlin's own release notes, but not
  cross-checked against Apple's primary text directly.
- **"cargo-xcframework" non-existence** is a negative finding based on GitHub
  repository search coverage, not an exhaustive crates.io audit — flagged as
  a soft gap, not expected to change the recommendation.
- **Diplomat's and flapigen-rs's actual Kotlin-output quality** for
  async/callback-heavy APIs (as opposed to ICU4X-style data APIs) was not
  hands-on verified — assessed from README language-support lists only. Low
  priority to revisit given Gobley is the primary recommendation, but noted
  in case Gobley proves unworkable for some narrow part of the API surface.
- **Blue-Falcon's iOS CoreBluetooth state-restoration support** and **Android
  foreground-service compatibility**: no documentation found either way
  (neither confirming nor denying support) — requires direct source
  inspection (`library/*/src/iosMain`) or a hands-on device spike before
  relying on it for the peripheral/server role.
- **Kable's foreground-service behavior**: issue #332 (intermittent NPE on
  Android 10+ when scanning/connecting from a foreground service) is an open,
  unresolved bug report, not a documented, acknowledged limitation — status
  should be re-checked immediately before implementation, and validated on
  real devices regardless (this overlaps with the device-verification needs
  flagged in `04-android-ios-background-ble.md`).
- **GitHub code search** was unavailable (auth-gated/401) during this
  research, so an exhaustive cross-repo search for other KMP BLE
  peripheral/GATT-server implementations beyond named-repo and topic search
  was not performed.
