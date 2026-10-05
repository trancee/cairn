# Packaging, distribution and export compliance

Answers ticket "Packaging, distribution and export compliance" for `pqcble` (KMP +
Rust/Gobley SDK, Compose Multiplatform reference app, Android 8+/iOS 15+, custom E2E
crypto over BLE using ML-KEM-768, X-Wing, X25519, AES-256-GCM, HKDF/HMAC-SHA-384 from
`aws-lc-rs`/`mlkem-native`/RustCrypto). **Not legal advice.** Export control and
software-licensing determinations are legally consequential and fact-specific (entity
structure, countries of distribution, exact cryptographic functionality shipped); have
a lawyer or export-control specialist review before shipping, and before relying on any
checklist item below.

Sourcing convention (same as `docs/research/2026-10-05-android-ios-background-ble.md`):
**Verified** = traced to a current, fetched first-party/primary source (Apple Developer
docs, Google `developer.android.com`/`support.google.com`/Play Console help, eCFR.gov
regulatory text, Apple's own citation of ANSSI, official GitHub `LICENSE`/`Cargo.toml`
files of the named crates/projects), with the citing URL given inline. **Community-
reported** / **Unverified** = blog posts, inference, or claims I could not trace to a
fetched primary artifact in this session — flagged explicitly wherever used.

## Executive summary

`pqcble` is a shipped binary cryptographic SDK, which puts it squarely inside three
overlapping compliance regimes: (1) normal KMP/Rust packaging mechanics (Maven Central
AAR + XCFramework/SPM), which are mostly solved problems with known multi-arch and
static/dynamic-linking pitfalls; (2) US EAR export-control law (5D002 / License
Exception ENC / §742.15 self-classification or notification), which applies to *any*
exporter of this code regardless of which app store is used, plus a France-specific
ANSSI declaration that Apple surfaces explicitly in App Store Connect and Google Play
does not surface at all; (3) Apple's App Privacy Manifest regime, which is a second,
separate obligation from export compliance, keyed to "required reason" API usage and
(for most SDKs) does not require a cryptographic signature unless the SDK is literally
named on Apple's list — `pqcble`, `aws-lc-rs`, `mlkem-native`, UniFFI, and Gobley are
not on that list as fetched on this date, though `BoringSSL`/`openssl_grpc` and
`OpenSSL` literally are, which is worth monitoring. On licensing, every dependency
checked is permissively licensed (Apache-2.0/MIT/ISC dual/triple, aws-lc-rs ISC AND
(Apache-2.0 OR ISC)) **except UniFFI and Gobley, which are MPL-2.0** — a weak,
file-level copyleft that is compatible with shipping inside a larger proprietary or
dual-licensed app but still carries source-disclosure obligations for *modified*
MPL-2.0-covered files specifically, which needs to be captured correctly in the
project's NOTICES file. Google Play has no analogue to Apple's export-compliance
questionnaire or CCATS/French-declaration upload step; the underlying EAR legal
obligation nonetheless still applies to the publisher independent of which store is
used. Bluetooth permission obligations are well-documented on both platforms and are
largely mechanical once `neverForLocation` is decided. The checklist below consolidates
concrete to-dos; the final section lists everything that could not be confirmed from a
primary source in this session.

---

## §1 KMP + Rust (Gobley) packaging & publishing

### 1.1 Maven Central publishing for KMP libraries

**Verified** — JetBrains' official Kotlin Multiplatform docs on publishing to Maven
Central describe generating a Sonatype/Central Portal user token, storing
`MAVEN_CENTRAL_USERNAME`/`MAVEN_CENTRAL_PASSWORD`/`SIGNING_KEY_ID`/`SIGNING_PASSWORD`/
`GPG_KEY_CONTENTS` as CI secrets, and running the `publishToMavenCentral` (or
`publishAndReleaseToMavenCentral`) Gradle task from a GitHub Actions release workflow
(`kotlinlang.org/docs/multiplatform/multiplatform-publish-libraries-to-maven.html`,
fetched 2026-10-05 after a redirect from
`jetbrains.com/help/kotlin-multiplatform-dev/multiplatform-publish-libraries.html`).
The doc shows the full `.github/workflows/publish.yml` shape and notes that a
deployment sits in "pending"/"validating" state on the Central Portal dashboard before
a manual or automatic "Publish" step actually releases the artifacts.

### 1.2 AAR format and native `.so` packaging (Android target)

**Verified** — Android Studio docs confirm an Android library module compiles to an
AAR, and "AAR files can contain C/C++ libraries for use by the app module's C/C++ code"
(`developer.android.com/studio/projects/android-library`, fetched 2026-10-05).
Native-library linkage into Gradle is done via `externalNativeBuild { cmake {...} }` or
an `ndkBuild` block pointing at a `CMakeLists.txt`/`Android.mk`
(`developer.android.com/studio/projects/gradle-external-native-builds`, fetched
2026-10-05) — not directly applicable to a prebuilt Gobley/Cargo `.so`, but confirms the
AAR's native-library packaging mechanism Gradle expects.

**Verified** — The Android NDK docs enumerate exactly four ABIs the NDK (and therefore
`jniLibs/<abi>/`) supports today: `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` (32-bit
ARM/Thumb-2/Neon; 64-bit ARM AArch64; x86 IA-32 with SSE/SSSE3; x86-64-v2). The same
page notes legacy ARMv5 (`armeabi`) and MIPS/MIPS64 ABIs were removed in NDK r17
(`developer.android.com/ndk/guides/abis`, fetched 2026-10-05). This matches the
`jniLibs/{arm64-v8a,armeabi-v7a,x86,x86_64}/lib<name>.so` layout the ticket describes;
`pqcble`'s Rust `cdylib` must be cross-compiled for these four targets (typically via
`cargo-ndk`, invoked by Gobley's Cargo Gradle plugin — see 1.3) and placed in the
matching `jniLibs` subfolder, either manually or by the Gobley/`dev.gobley.cargo`
plugin's generated tasks.

### 1.3 Gobley's packaging mechanics

**Verified** — Gobley's own README (`raw.githubusercontent.com/gobley/gobley/main/README.md`,
fetched 2026-10-05) describes itself as "a set of libraries and tools that help you mix
Rust and Kotlin using UniFFI," forked from the (now-unmaintained)
`uniffi-kotlin-multiplatform-bindings` project, currently supporting Android, Kotlin/JVM
and Kotlin/Native (no WASM yet), with features: "UniFFI Bindings Generation for Kotlin
Multiplatform," "KotlinX Serialization Support," and "Automatic building and linking of
Rust libraries to Kotlin projects."

**Verified** — Gobley's official tutorial (`gobley.dev/docs/tutorial`, fetched
2026-10-05) walks through the concrete mechanics:
- `Cargo.toml` sets `crate-type = ["cdylib", "staticlib"]`; the tutorial states
  explicitly: **"Gobley uses the static library file when building for iOS, and the
  dynamic library file for Android."** This is the authoritative statement on
  static-vs-dynamic choice per platform for this toolchain.
- The Gradle module applies two plugins: `dev.gobley.cargo` ("builds and links the Rust
  library to the Kotlin application") and `dev.gobley.uniffi` ("generates the bindings
  using UniFFI... You can change the package name of the bindings inside the
  `uniffi {}` block"), plus `org.jetbrains.kotlin.plugin.atomicfu` "to use atomic types
  used by the bindings." Both Gobley Gradle plugins are published on Maven Central
  (`central.sonatype.com/artifact/dev.gobley.gradle/gobley-gradle` per the README badge).
- Rust code is exposed via `#[uniffi::export]` macros and `uniffi::setup_scaffolding!();`
  at the crate root; failing to call `setup_scaffolding!()` produces the documented
  error "Crate compose_app not found in libcompose_app.so" at Gradle sync time.

The tutorial does not explicitly name `cargo-ndk`, but the stated behavior ("Gobley uses
the... dynamic library file for Android") combined with Android's ABI set in §1.2
implies per-ABI cross-compilation is handled by the `dev.gobley.cargo` plugin's Gradle
tasks; the exact underlying cross-compilation tool was not independently verified by
fetching the plugin's source in this session (see Gaps).

### 1.4 iOS: XCFramework production and SPM/CocoaPods distribution

**Verified** — Apple's docs on creating a multi-platform binary framework bundle
(`developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle`,
fetched via the `.md` DocC alternate 2026-10-05) describe the two-step process:
1. `xcodebuild archive -destination "generic/platform=iOS" ...` (or Simulator/macOS/Mac
   Catalyst variants) to build per-platform archives.
2. `xcodebuild -create-xcframework -archive <path> -framework MyFramework.framework
   [-archive ... repeated] -output MyLibrary.xcframework`, or with `-library
   libMyLibrary.a -headers <path>` for static libraries built by non-Xcode tooling.

The same doc has a section "Avoid issues when using alternate build systems, common for
open source projects" that explicitly covers the Gobley/Cargo case: build one static
`.a` per platform (each a fat binary covering every architecture that platform/Simulator
combination needs), then feed those into `-create-xcframework -library ...`. It warns:
"Avoid wrapping a static library in a `.framework` bundle and omitting the `.a`
extension. Use the `-library` flag..." It also documents XCFramework signing:
`codesign --timestamp -s <identity> xcframeworks/MyLibrary.xcframework`, with an
Apple-Distribution/Apple-Development identity for Developer Program distribution, and a
hard failure in Xcode's build system if the signing certificate is later revoked.

**Verified** — Apple's docs on distributing binary frameworks as Swift packages
(`developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages`,
fetched via `.md`, 2026-10-05) confirm: host the `.xcframework` as a zipped artifact on
a server and declare a remote `binaryTarget(name:url:checksum:)` (checksum computed via
`swift package compute-checksum path/to/MyFramework.zip`), *or* commit the
`.xcframework` into the package repo directly and use a local/path-based binary target
with no checksum required. Both approaches are shown side-by-side in a sample
`Package.swift`. The doc flags a real tradeoff: "a Swift package that contains a binary
is less portable... limits the audience for your Swift package" (binary SPM targets are
Apple-platforms-only).

**Community-reported / not independently fetched this session** — CocoaPods
`vendored_frameworks`/`vendored_libraries` podspec keys are the standard mechanism for
distributing a prebuilt XCFramework via CocoaPods; this is widely documented CocoaPods
behavior but I did not fetch CocoaPods' own docs in this session to confirm current
syntax — flag for follow-up if CocoaPods distribution is in scope (SPM is very likely
sufficient given the project's KMP/Gobley stack and modern tooling expectations).

### 1.5 Known pitfalls

**Static vs. dynamic linking.** **Verified** (Gobley tutorial, §1.3): Gobley's own
documented design uses `staticlib` (`.a`) for iOS and `cdylib` (`.so`) for Android. This
is not optional/configurable guidance from the tutorial — it states Gobley "uses" one
per platform, matching each platform's native idiom (XCFrameworks commonly ship static
libraries or dynamic frameworks; Android AARs ship dynamic `.so` per ABI inside
`jniLibs/`). Tradeoff, **inference**: static linking into an XCFramework means Rust's
runtime (allocator, panic handler, `std`) is statically embedded into the host app's
single Mach-O binary — this avoids extra dyld load-time/codesigning overhead per
framework but means every consuming app duplicates the Rust runtime if more than one
XCFramework statically links the same Rust std; dynamic `.so` linking on Android means
the native library is loaded at runtime from `jniLibs/<abi>/libwhatever.so` and can
(with explicit configuration) be shared, but Android app bundles do not typically
deduplicate native libs across dependencies either.

**Bitcode.** **Verified** — the current Apple XCFramework/archive docs fetched in
§1.4 make no mention of bitcode at all, and Apple's public record is that Xcode 14
(released 2022) removed bitcode support for iOS/watchOS/tvOS submissions outright —
however, I did not fetch a current Apple release-notes page in this session confirming
the exact Xcode version/date; treat "bitcode is dead and irrelevant to a 2026-era KMP
SDK" as **community-reported / widely known but not re-verified against a freshly
fetched primary Apple source this session**. Practically: do not budget any engineering
time for bitcode support in the Rust/XCFramework toolchain.

**Symbol clashes between two UniFFI-generated SDKs statically linked together.**
**Community-reported / inference, not verified against a fetched primary source this
session.** This is a known class of problem with Rust `staticlib`s generally (not
specific to UniFFI): Rust does not apply versioned/namespaced symbol mangling the way
C++ does for templates, and two independent crates using the same crate name, the same
`extern "C"` exported symbol names (which UniFFI's generated FFI layer does use, with a
scaffolding-version-and-crate-name prefix to reduce — not eliminate — collision risk),
or the same transitively-linked dependency (e.g., two different apps' Rust cores both
statically linking `aws-lc-sys`/`ring` at different versions) can produce duplicate
symbol errors or silent ODR-style misbehavior at the linker or dyld level when both are
statically embedded into one host app. Mitigations commonly cited in the Rust FFI
community (unverified here): per-crate symbol prefixing/renaming via `#[no_mangle]`
overrides or `objcopy --redefine-syms`, linker version scripts on ELF/Android, or
preferring one shared dynamic library per vendor on Android (where ABI-versioned
`.so`s load independently) versus avoiding two independently-built Rust `staticlib`s in
one iOS app at all. **This should be flagged to a toolchain/build engineer before
`pqcble` ships if any consuming app is expected to also embed a second, unrelated
UniFFI-based Rust SDK.**

**Binary size.** **Community-reported / inference.** Rust's static `std`, plus
`aws-lc-rs`'s vendored C crypto (`aws-lc-sys`, a BoringSSL/OpenSSL-derived C codebase)
and `mlkem-native`'s C implementation, are known in the Rust ecosystem to meaningfully
increase binary size versus a pure-Kotlin/Swift dependency; standard mitigations (LTO,
`strip = true`, `panic = "abort"`, `opt-level = "z"`) are generic Cargo release-profile
knobs, not something fetched from a primary aws-lc-rs/mlkem-native source in this
session — flag as an engineering task to actually measure, not something to assume a
specific number for.

---

## §2 Apple App Store export compliance

**This is not legal advice.** Export control classification and self-classification
reporting are specific to the exact cryptographic functionality implemented, the
exporting entity, and the countries of distribution; verify with counsel/an
export-control specialist before relying on any of the following.

### 2.1 What Apple requires in App Store Connect

**Verified** — Apple's "Complying with Encryption Export Regulations" doc
(`developer.apple.com/documentation/security/complying-with-encryption-export-regulations`,
fetched via `.md`, 2026-10-05) states: uploading to TestFlight/App Store is an export of
encryption software subject to US export law "regardless of where your legal entity is
based," if distributed outside the US/Canada. Apps set the `ITSAppUsesNonExemptEncryption`
Info.plist boolean key — `NO` only if the app (including third-party libraries it links
against) uses no encryption or only forms exempt from documentation requirements,
otherwise `YES`. If export compliance documentation is required and approved, Apple
issues a code to place in the `ITSEncryptionExportComplianceCode` Info.plist key, which
bypasses the App Store Connect questionnaire on future submissions. **Important quoted
verbatim:** "If your app uses exempt forms of encryption, you might alternatively be
required to submit a year-end self-classification report to the U.S. government. (If
you use non-exempt encryption and provide documentation to Apple, the self-classification
report isn't necessary.)"

**Verified** — Apple's "Overview of export compliance" help page
(`developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance`,
fetched 2026-10-05) lists example apps needing a determination, including those using
"Proprietary or non-standard encryption algorithms," defined per the US Government as:
"any implementation of 'cryptography' involving the incorporation or use of proprietary
or unpublished cryptographic functionality, including encryption algorithms or
protocols that have not been adopted or approved by a duly recognized international
standards body (e.g., IEEE, IETF, ISO, ITU, ETSI, 3GPP, TIA, and GSMA) and haven't
otherwise been published." It explicitly disclaims Apple's role: "it's your
responsibility to review the [EAR] to determine whether your app's use of encryption
requires a formal classification (CCATS)... you're responsible for all liabilities
associated with misinterpretation of export regulations or claiming exemption
inaccurately." It also flags the France-specific requirement directly (see §2.4).

**Verified** — Apple's "Determine and upload app encryption documentation" page
(`developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation`,
fetched 2026-10-05): App Store Connect walks through a question flow under App
Information → App Encryption Documentation; once approved (Apple states ~2 business
days for complete submissions), Apple returns a key value for the Info.plist.

**Verified** — Apple's reference table "Export compliance documentation for encryption"
(`developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption`,
fetched 2026-10-05), reproduced below:

| Encryption algorithm in use | Required documentation |
|---|---|
| Encryption limited to that within the Apple OS | No documentation required in App Store Connect |
| Industry standard algorithm, not provided within the Apple OS | Upload French encryption declaration in App Store Connect (only if distributing in France) |
| Proprietary encryption algorithms not accepted by international standard bodies (IEEE, IETF, ITU, etc.) | Upload: US CCATS **and** French encryption declaration (France only) |

`pqcble` uses ML-KEM-768 (NIST FIPS 203, a published international standard),
X-Wing (an IETF-draft hybrid KEM combiner, published), X25519 (RFC 7748, published),
AES-256-GCM (NIST SP 800-38D, published), HKDF/HMAC-SHA-384 (NIST/IETF, published) — all
via `aws-lc-rs`/`mlkem-native`/RustCrypto rather than the OS's own crypto APIs. This
places it, on its face, in the **middle row** ("industry standard algorithm, not
provided within the Apple OS") rather than the proprietary/CCATS row, *provided* the
protocol composition (the custom E2E handshake/wire format gluing these primitives
together) is not itself considered "proprietary or unpublished cryptographic
functionality" under the US Government's definition quoted above — a determination this
research cannot make and that should be confirmed with counsel, since the custom
combination of standard primitives into a bespoke BLE handshake is exactly the kind of
fact pattern where "standard algorithm" vs. "proprietary protocol" lines get contested.

**On CCATS being mandatory vs. optional**: **Verified**, from the table above and from
Apple's overview page — CCATS is required documentation specifically for the
*proprietary/non-standard algorithm* row, not for the "industry standard" row. For an
app using only published standard algorithms (the apparent `pqcble` case), CCATS is not
listed as required by Apple; it is a BIS instrument that producers obtain voluntarily
(or that may be required for other reasons, e.g., §740.17(b) classification/self-
classification paths discussed below) rather than something Apple extracts for every
submission.

### 2.2 US BIS EAR framework

All of the following is **Verified**, fetched directly from the current eCFR text via
its render API (`ecfr.gov`, Title 15, Subtitle B, Chapter VII, Subchapter C, fetched
2026-10-05) — note eCFR blocks generic scraping of its HTML pages but its renderer API
endpoint returned full text.

**§742.15 "Encryption items"** (`ecfr.gov`, Part 742 §742.15): a license is required to
export/reexport items classified 5A002, 5A004, 5D002.a/.c.1/.d, or 5E002 "technology,"
to all destinations except Canada, *unless* a license exception applies. "Most
encryption items may be exported under... License Exception ENC... §740.17." Items
meeting the Category 5–Part 2 "mass market" Note 3 are reclassified to 5A992/5D992 and
fall out of §742.15/740.17 entirely. §742.15(b) — **"Publicly available encryption
source code"**: "Subject to the notification requirements of paragraph (b)(2)...
publicly available (see §734.3(b)(3)...) encryption source code classified under ECCN
5D002 is not subject to the EAR. Such source code is publicly available even if it is
subject to an express agreement for the payment of a licensing fee or royalty for
commercial production or sale of any product developed using the source code."
§742.15(b)(2) — **notification requirement for "non-standard cryptography"**: for
publicly available 5D002 source code that provides/performs "non-standard
cryptography," the exporter "must notify BIS and the ENC Encryption Request Coordinator
via email of the internet location... or provide each of them a copy," with repeat
notification each time cryptographic functionality is updated/modified or the hosting
URL changes (not required for other, non-functional updates at the same URL). Submit to
`crypt@bis.doc.gov` and `enc@nsa.gov`.

**§734.3(b)(3)** (the "publicly available" test referenced by §742.15(b)) was fetched
but the specific §734.3(b)(3) text (defining "publicly available technology and
software," e.g., published, generally accessible, or already in the public domain) was
not captured in the fetched excerpt — the fetch returned adjacent (b)(1) cross-referral
text about other-agency-controlled items rather than the (b)(3) publicly-available
definition itself (see Gaps).

**§740.17 "License Exception ENC"** (`ecfr.gov`, Part 740 §740.17): License Exception
ENC authorizes export/reexport/transfer of 5A002/5B002/5D002/5E002 items (and
cryptanalytic/forensic items under 5A004/5D002/5E002), except to Country Groups E:1/E:2.
Paragraph (a) ("No classification request or reporting required") covers certain
transfers to "private sector end users" for internal development/production, and to
"U.S. subsidiaries" — no self-classification report needed for these specific cases.
Paragraph (b) distinguishes: **(b)(1)** products where a *self-classification report* is
required (producer self-classifies, no 30-day pre-review, but an annual report to BIS is
needed) unless BIS has already issued a CCATS for that product, in which case no
self-classification report is required; **(b)(2)/(b)(3)** describe products requiring a
"thirty-day (30-day) classification request" to BIS before export — i.e., a stronger
review path than (b)(1). The fetched text did not fully enumerate exactly which product
categories fall in (b)(1) vs (b)(2) vs (b)(3) before truncating (see Gaps) — this
distinction (often summarized elsewhere as "(b)(1) = mass-market self-classifiable
items" vs "(b)(2)/(b)(3) = more sensitive government/enterprise items needing 30-day
review") should be confirmed against the full §740.17(b) text before relying on it.

**Annual self-classification report (§742.15(b) cross-referenced via Apple's own doc,
and via BIS's "How to file an Annual Self Classification Report" page linked directly
from Apple's docs, `bis.doc.gov/index.php/policy-guidance/encryption/4-reports-and-
reviews/a-annual-self-classification`)**: Apple's own encryption-compliance doc links
directly to this BIS page as the authority on when the annual report is triggered.
**Unverified in this session**: the live BIS URL now 301-redirects to a generic
`bis.gov` landing page about an unrelated IC-licensing rule (fetched 2026-10-05) rather
than the encryption-reporting content Apple's doc cites — BIS appears to have
reorganized/retired that specific URL. The commonly cited **February 1 annual deadline**
for self-classification reports under §740.17(e)(3) could not be re-confirmed against a
live BIS page in this session; treat the "Feb 1" deadline as **community-reported /
previously well-documented BIS practice, not re-verified against a current primary
source here** — confirm the current deadline and submission mechanics directly with BIS
or counsel before relying on it.

### 2.3 Does open-source status reduce the EAR burden?

**Verified** (§742.15(b), text above): publicly available encryption source code is, by
rule text, **"not subject to the EAR"** at all for classification/licensing purposes —
a stronger exemption than a license exception. The only residual obligation for such
code, *if* it implements "non-standard cryptography," is the §742.15(b)(2) email
notification to BIS/NSA (not a license, not an annual report, not a CCATS) before or
upon the code becoming publicly available, with repeat notice only on
functionality-changing updates or URL changes. **Community-reported / inference**: ML-
KEM, X25519, AES-GCM, HKDF/HMAC are all published/standardized primitives, which
arguably places even the "non-standard cryptography" notification requirement in doubt
for `pqcble` specifically if its *source code* (not just the binary SDK) is public —
but this project's status (Apache-2.0/MIT dual-licensed, "assume" per the task brief)
and whether the repository's source is actually public at time of distribution are
prerequisites to invoking §742.15(b) at all, and the notification-vs-exemption line for
a *novel protocol combining standard primitives* is exactly the kind of judgment call
that needs a lawyer, not inference from this research. I could not fetch the specific
2021 Federal Register notice described in the task (the EAR amendment narrowing
self-classification/review requirements for open-source/mass-market encryption) in this
session — `federalregister.gov` and `ecfr.gov`'s HTML endpoints both blocked automated
scraping outright (see Gaps); the eCFR renderer API excerpt of §742.15 shows an amendment
citation "86 FR 16488, Mar. 29, 2021" in its amendment history list, which is consistent
with (but not confirmed by content to be) the 2021 rule the task describes — flag as
**partially verified**: the citation exists in the amendment history, but I did not read
the Federal Register notice's text itself.

### 2.4 France / ANSSI

**Verified** — Apple's "Overview of export compliance" page states directly: "The
import and export of encryption apps distributed in France are also controlled by the
French Government. The main items of control for France are Secure Storage, Secure
Communications, and Security Anti-Virus applications. Exemptions include Banking and
Medical applications. For more information about these French controls, visit the
[ANSSI] website" (`ssi.gouv.fr`, as linked by Apple,
`developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-
compliance`, fetched 2026-10-05). `pqcble`'s BLE chat app is squarely "Secure
Communications," so the French requirement applies if the app is distributed on the
French App Store.

**Verified** — The export-compliance-documentation-for-encryption reference table
(§2.1 above) shows App Store Connect has a dedicated upload slot for a **"French
encryption declaration"** required specifically "if you're distributing your app on
the App Store in France," for *both* the "industry standard" and "proprietary" rows —
i.e., it's required even for apps using only standard published algorithms, as long as
France is a distribution territory. I did not fetch the ANSSI/`ssi.gouv.fr` site itself
or the French legal citation (Code pénal Article R.226-3, decree 2007-663) in this
session — Apple's own doc confirms the existence and App Store Connect mechanics of the
French declaration but not the underlying French statute's text (see Gaps).

### 2.5 CCATS: when mandatory vs. optional

**Verified** (synthesizing §2.1's table + §2.2): CCATS is Apple's *required*
documentation only for the proprietary/non-standard-algorithm row. For the apparent
`pqcble` case (standard algorithms, not Apple-OS-provided), Apple does not list CCATS as
required — French declaration is the only Apple-mandated upload (if distributing in
France). Independent of Apple's requirements, obtaining a CCATS from BIS is something an
exporter can pursue voluntarily for legal certainty (e.g., to avoid the ambiguity about
whether a custom E2E BLE protocol built from standard primitives counts as "standard" or
"non-standard" cryptography), but the fetched Apple/eCFR text does not establish CCATS
as mandatory outside that proprietary-algorithm row.

---

## §3 Google Play equivalent

**Verified** — I searched and fetched Google Play Console/Play Store help documentation
on the App content page, Data safety form, and related developer-answer pages
(`support.google.com/googleplay/android-developer/answer/9859455` and `/10787469`,
fetched 2026-10-05). None of these pages — nor the general App content policy-
declaration flow they describe (privacy policy, ads declaration, content ratings, target
audience, Data safety) — mention encryption export classification, CCATS, a French
encryption declaration, or any Apple-`ITSAppUsesNonExemptEncryption`-equivalent
Info.plist/manifest key or questionnaire. **This absence across the fetched official
Play Console help pages is itself the evidence** that Google Play does not operate an
analogous formal export-compliance declaration step the way Apple's App Store Connect
does. I did not find, in this session, any Play Console help page that affirmatively
states "Google Play does not require export compliance declarations" (i.e., this is an
absence-of-evidence finding, not a positive statement from Google) — flag as
**Verified by absence, not by an explicit Google statement**.

**This does not change the underlying legal obligation.** The EAR (§742.15, §740.17,
§742.15(b) notification) binds the *exporter* of the software — i.e., the publisher —
regardless of which distribution channel (Apple App Store, Google Play, direct
download, GitHub release) is used. Not being asked a compliance question by Google Play
does not exempt `pqcble`'s publisher from EAR self-classification, notification, or
annual-reporting obligations if they're otherwise triggered. This conclusion follows
directly from the EAR text itself (§2.2, which binds "exports or reexports" with no
store-specific carve-out) rather than from any Google statement.

---

## §4 Apple Privacy Manifest (`PrivacyInfo.xcprivacy`)

### 4.1 What a privacy manifest is and when it's needed

**Verified** — Apple's "Privacy manifest files" doc
(`developer.apple.com/documentation/bundleresources/privacy-manifest-files`, fetched via
`.md`, 2026-10-05): apps and third-party SDKs distributed as XCFrameworks, Swift
packages, or Xcode projects "can contain" a `PrivacyInfo.xcprivacy` property list
recording (a) data types collected, required on all platforms, and (b) "required
reasons" APIs used, required on iOS/iPadOS/tvOS/visionOS/watchOS. Quoted directly:
"You need to include a privacy manifest file in your third-party SDK if it's listed in
'SDKs that require a privacy manifest and signature'... **Otherwise**, include a privacy
manifest file in your third-party SDK if it uses a required reasons API, collects data
about the person using apps that include the third-party SDK, enables the app to
collect data about people using the app, or contacts tracking domains." The top-level
plist keys are `NSPrivacyTracking`, `NSPrivacyTrackingDomains`,
`NSPrivacyCollectedDataTypes`, and `NSPrivacyAccessedAPITypes`. For a statically-linked
SDK, the doc specifically notes: "If you distribute your third-party SDK as a static
library, use the support for static frameworks in Xcode 15 or later to bundle
resources... Create a framework target in Xcode that builds your product, set its
Mach-O type build setting to 'Static Library,' and add the privacy manifest file to
your target's bundle resources" — directly relevant since `pqcble`'s iOS artifact is a
Gobley-produced static XCFramework (§1.4/1.5).

### 4.2 Required-reason API categories and enforcement date

**Verified** — Apple's "Describing use of required reason API" doc
(`developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-
api`, fetched via `.md`, 2026-10-05): "**Starting May 1, 2024, apps that don't describe
their use of required reason API in their privacy manifest file aren't accepted by App
Store Connect.**" Each `NSPrivacyAccessedAPITypes` array entry needs
`NSPrivacyAccessedAPIType` (the category) and `NSPrivacyAccessedAPITypeReasons` (an
approved reason string per category). Critically: "For each executable or dynamic
library in an app that uses a required reason API, the bundle that includes the
executable or dynamic library needs to include a privacy manifest file that reports
the API... Your third-party SDK can't rely on the privacy manifest files for apps that
link the third-party SDK... to report your third-party SDK's use of required reasons
API" — i.e., `pqcble`'s own XCFramework/SPM package must ship its own
`PrivacyInfo.xcprivacy` if it itself calls a required-reason API; it cannot rely on the
host app declaring that usage on its behalf.

**Unverified in this session**: I could not fetch Apple's specific enumerated list of
required-reason API category string constants (e.g., `NSPrivacyAccessedAPICategoryFile
Timestamp`, `...SystemBootTime`, `...DiskSpace`, `...ActiveKeyboards`,
`...UserDefaults`) and their approved-reason code lists — the symbol reference pages
for these enum values render their content via client-side JavaScript/JSON that the
fetch tool could not retrieve even via the `.md` alternate link (which 404'd for the
specific category pages tried). The five-category list in the task brief (File
timestamp, System boot time, Disk space, Active keyboard, User defaults) matches
widely-circulated community summaries of Apple's WWDC23 announcement and is very likely
accurate, but should be treated as **community-reported, not independently re-verified
against Apple's live enumerated list in this session**.

**Applying this to `pqcble` (inference, since the exact category list is unverified)**:
- **User defaults / `NSUserDefaults`**: if the iOS side of the SDK or reference app
  persists BLE bonding state, device pairing keys, or session metadata via
  `UserDefaults`, that is very likely a required-reason API trigger (per the
  community-known category list) requiring an approved reason string (commonly a
  reason code like "CA92.1" for data used only by the app/its SDK on-device — exact
  codes unverified here).
- **System boot time (`CLOCK_MONOTONIC`/`mach_absolute_time`/`systemUptime`)**: if Rust
  timing code (e.g., for BLE connection-interval/backoff/replay-window logic) calls
  into `std::time::Instant` on iOS, which under the hood typically uses a monotonic
  clock API, this *could* fall under the "System boot time APIs" required-reason
  category depending on exactly which underlying syscall/API is used — this needs
  direct verification against the actual Rust std/`libc` call path Apple's linker sees,
  not assumed from Kotlin/Swift-level code only, since the required-reason-API
  enforcement reportedly operates on binary symbol usage, not source language
  (**community-reported mechanism; not verified against a fetched primary source
  describing binary/symbol-level detection in this session**).
- File timestamp, disk space, and active keyboard APIs seem unlikely to be triggered by
  a BLE crypto SDK's core logic absent some diagnostic/logging feature that reads file
  metadata.

### 4.3 Third-party SDK signature requirement

**Verified** — Apple's "Third-party SDK requirements" page
(`developer.apple.com/support/third-party-SDK-requirements/`, fetched 2026-10-05, raw
HTML since it's not a DocC page) states privacy manifests are required for all SDKs per
§4.1's general policy, but **signatures** are required specifically for SDKs on an
enumerated list. The full fetched list (as of 2026-10-05) is: Abseil, AFNetworking,
Alamofire, AppAuth, **BoringSSL / openssl_grpc**, Capacitor, Charts, connectivity_plus,
Cordova, device_info_plus, DKImagePickerController, DKPhotoGallery, FBAEMKit,
FBLPromises, FBSDKCoreKit, FBSDKCoreKit_Basics, FBSDKLoginKit, FBSDKShareKit,
file_picker, FirebaseABTesting, FirebaseAuth, FirebaseCore, FirebaseCoreDiagnostics,
FirebaseCoreExtension, FirebaseCoreInternal, FirebaseCrashlytics, FirebaseDynamicLinks,
FirebaseFirestore, FirebaseInstallations, FirebaseMessaging, FirebaseRemoteConfig,
Flutter, flutter_inappwebview, flutter_local_notifications, fluttertoast, FMDB,
geolocator_apple, GoogleDataTransport, GoogleSignIn, GoogleToolboxForMac,
GoogleUtilities, grpcpp, GTMAppAuth, GTMSessionFetcher, hermes, image_picker_ios,
IQKeyboardManager, IQKeyboardManagerSwift, Kingfisher, leveldb, Lottie, MBProgressHUD,
nanopb, OneSignal, OneSignalCore, OneSignalExtension, OneSignalOutcomes, **OpenSSL**,
OrderedSet, package_info, package_info_plus, path_provider, path_provider_ios, Promises,
Protobuf, Reachability, RealmSwift, RxCocoa, RxRelay, RxSwift, SDWebImage, share_plus,
shared_preferences_ios, SnapKit, sqflite, Starscream, SVProgressHUD, SwiftyGif,
SwiftyJSON, Toast, UnityFramework, url_launcher, url_launcher_ios,
video_player_avfoundation, wakelock, webview_flutter_wkwebview.

The doc also states: "Any version of a listed SDK, **as well as any SDKs that repackage
those on the list**, are included in the requirement." `aws-lc-rs`/`aws-lc` is a fork
lineage of BoringSSL/OpenSSL (confirmed in §6.1), but is packaged and distributed as its
own distinctly-named Rust crate/`aws-lc-sys` artifact, not literally "BoringSSL,"
"openssl_grpc," or "OpenSSL" as an iOS framework/library target name — **this is an
important edge case to monitor**: if Apple's enforcement tooling or future list updates
key off symbol/binary fingerprinting rather than just the artifact's declared name, a
statically-linked `aws-lc`-derived binary could plausibly be flagged even though it
ships as `aws-lc-rs`, not `BoringSSL.xcframework`. As of the fetched list, neither
`aws-lc-rs`, `aws-lc`, `mlkem-native`, `uniffi`, nor `gobley` appear by name, so no
signature requirement currently applies to `pqcble` by name-matching — but this should
be re-checked at ship time since Apple states it updates this list periodically, and
again if Apple's detection is fingerprint- rather than name-based (**the detection
mechanism itself — name-match vs. binary-fingerprint — was not confirmed from a fetched
primary source in this session; treat as open question, not resolved**).

### 4.4 Mandatory as of current date?

**Verified**: the enforcement date for required-reason-API privacy manifest *disclosure*
(not signature) is **May 1, 2024** per the directly-quoted text in §4.2, and that date
has passed as of this research's 2026-10-05 timestamp — meaning privacy-manifest
disclosure (for any required-reason API actually used) is unconditionally mandatory for
App Store Connect submissions today, for both the app and any third-party SDK/XCFramework
it embeds. The **signature** requirement in §4.3 is scoped to the enumerated SDK list;
an SDK not on that list (the current `pqcble` status) needs a privacy manifest only if it
triggers one of the three general triggers quoted in §4.1 (required-reason API use, data
collection, or tracking-domain contact), and does not need a binary signature.

---

## §5 Bluetooth permissions & Data Safety

### 5.1 iOS Info.plist keys

**Verified** — `NSBluetoothAlwaysUsageDescription`
(`developer.apple.com/documentation/bundleresources/information-property-list/
nsbluetoothalwaysusagedescription`, fetched via `.md`, 2026-10-05): available iOS
13.0+/iPadOS 13.0+/macOS 11.0+/tvOS 13.0+/visionOS 1.0+/watchOS 6.0+; "This key is
required if your app uses the device's Bluetooth interface." For deployment targets
earlier than iOS 13, Apple's doc says to **additionally** add
`NSBluetoothPeripheralUsageDescription`.

**Verified** — `NSBluetoothPeripheralUsageDescription`
(`.../nsbluetoothperipheralusagedescription`, fetched via `.md`, 2026-10-05): listed
availability iOS 6.0–13.0 (i.e., deprecated/superseded at 13.0); "For apps with a
deployment target of iOS 13 and later, use NSBluetoothAlwaysUsageDescription instead."
Required only if deployment target is earlier than iOS 13 **and** the app uses
Bluetooth-peripheral-accessing APIs.

**Applied to `pqcble`**: the project targets iOS 15+ per the task brief, which is well
above the iOS 13 cutover — so only `NSBluetoothAlwaysUsageDescription` is needed; the
legacy `NSBluetoothPeripheralUsageDescription` key is unnecessary.

### 5.2 Android Bluetooth permissions (API 31+ / `neverForLocation`)

**Verified** — Android's Bluetooth permissions guide
(`developer.android.com/develop/connectivity/bluetooth/bt-permissions`, redirected from
`developer.android.com/guide/topics/connectivity/bluetooth/permissions`, fetched
2026-10-05). For apps targeting Android 12 (API 31)+:
- `BLUETOOTH_SCAN` — required if the app looks for BLE devices.
- `BLUETOOTH_ADVERTISE` — required if the app makes the device discoverable.
- `BLUETOOTH_CONNECT` — required if the app communicates with already-paired devices.
- Legacy `BLUETOOTH`/`BLUETOOTH_ADMIN` should keep `android:maxSdkVersion="30"` for
  back-compat with pre-S devices.
- `ACCESS_FINE_LOCATION` is required **only if** the app derives physical location from
  scan results; otherwise, the doc says the app can "strongly assert" it never does so
  by setting `android:usesPermissionFlags="neverForLocation"` on the `BLUETOOTH_SCAN`
  declaration, and (if location isn't needed for any other purpose) drop
  `ACCESS_FINE_LOCATION` entirely, or cap it at `maxSdkVersion="30"`.
- `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` are all **runtime**
  permissions requiring explicit user approval via the system "Nearby devices" prompt.
- For apps targeting Android 11 (API 30) or lower: the legacy `BLUETOOTH` permission
  plus `ACCESS_FINE_LOCATION` (because on these OS versions "a Bluetooth scan could
  potentially be used to gather information about the location of the user") are
  required instead, and location permissions must additionally be requested at runtime.
- `BLUETOOTH_ADMIN` is needed to initiate local device discovery; apps supporting a
  background service on Android 10/11 also need `ACCESS_BACKGROUND_LOCATION` to
  discover Bluetooth devices from a background context.

**Applied to `pqcble`**: since this is a peer-to-peer BLE chat app with no stated need
to derive physical location from scan results, `neverForLocation` is the correct choice
on `BLUETOOTH_SCAN` for Android 12+, letting the app skip `ACCESS_FINE_LOCATION`
(or scope it to `maxSdkVersion=30` for the Android 8–11 range the project also
supports, where the legacy location-permission path is unavoidable per Android's own
doc).

### 5.3 Google Play Data Safety form and device identifiers

**Verified** — Play Console help on the Data safety form
(`support.google.com/googleplay/android-developer/answer/10787469`, fetched 2026-10-05,
including a follow-up fetch at `start_index=8000` for the FAQ body covering identifiers):
quoted directly: "the collection of an account name associated with an identifiable
person should be declared as a 'Personal identifier,' and the collection of a user's
Android Advertising ID should be declared as **'Device or other identifiers.'**" BLE MAC
addresses/device identifiers collected by `pqcble` (e.g., to maintain a bonded-peer
list) are the same class of "device identifier" Google's own example targets, and should
be disclosed under the Data safety section's "Device or other identifiers" data type if
collected/transmitted/stored by the app (as distinct from a purely ephemeral,
non-persisted in-session handle, which the same FAQ separately addresses: "If this use
is ephemeral, you do not need to include it in your form response"). The Data safety
form is completed in Play Console under **Policy and programs → App content → Data
safety**, is a single global declaration per package name covering all currently
distributed versions/regions, and developers are fully responsible for its accuracy per
the Play Developer Program's User Data policy (separately linked from this page) —
misrepresentation risks policy enforcement (blocked updates, removal).

**Applied to `pqcble`**: if the app persists peer BLE device identifiers (for
re-connection/bonding across sessions) rather than treating them as purely ephemeral
per-session handles, this should be declared as "Device or other identifiers" collection
in the Data safety form, with an accurate processing/sharing/deletion-mechanism
disclosure.

---

## §6 Licence notices for crypto dependencies

### 6.1 License matrix (all fetched directly from each project's own `LICENSE`/
`Cargo.toml` in this session, 2026-10-05)

| Dependency | License (verbatim SPDX from source) | Source fetched |
|---|---|---|
| `aws-lc-rs` (Rust crate) | `ISC AND (Apache-2.0 OR ISC)` | `raw.githubusercontent.com/aws/aws-lc-rs/main/LICENSE` |
| `aws-lc` (underlying C library) | New AWS-LC code: `Apache-2.0 OR ISC`. BoringSSL-derived code: historically `ISC`, newer Google contributions `Apache-2.0`. OpenSSL-derived code: `Apache-2.0`, with original SSLeay-copyright files also carrying `Apache-2.0` per the current NOTICE text. `mlkem-native`/`mldsa-native` code vendored in: `Apache-2.0 OR ISC OR MIT`. Third-party: Fiat Cryptography (`MIT`), s2n-bignum (`Apache-2.0 OR ISC OR MIT-0`, with ML-KEM/SHA3 code specifically `Apache-2.0 OR ISC OR MIT` per mlkem-native attribution), Jitter Entropy RNG (dual BSD-3-Clause/GPLv2, **AWS-LC elects BSD-3-Clause**), Keccak/AES reference code (public domain/CC0). Test-only deps (GoogleTest `BSD-3-Clause`, Go stdlib `BSD-3-Clause`, Wycheproof `Apache-2.0`) are explicitly **not** triggered by distributing linked `libcrypto`/`libssl`. | `raw.githubusercontent.com/aws/aws-lc/main/LICENSE` |
| `mlkem-native` | `Apache-2.0 OR ISC OR MIT` for library code (`mlkem/*`, `dev/*`); documentation under `CC-BY-4.0`; assorted test/benchmark-only files under MIT or public-domain-style licenses not relevant to distributed binaries | `raw.githubusercontent.com/pq-code-package/mlkem-native/main/LICENSE` |
| RustCrypto (`aes-gcm` checked as representative) | `Apache-2.0 OR MIT` (per crate `Cargo.toml` `license` field) — standard across RustCrypto's crates per project convention | `raw.githubusercontent.com/RustCrypto/AEADs/master/aes-gcm/Cargo.toml` |
| UniFFI (`mozilla/uniffi-rs`) | **MPL-2.0** (Mozilla Public License 2.0) | `raw.githubusercontent.com/mozilla/uniffi-rs/main/LICENSE` |
| Gobley (`gobley/gobley`) | **MPL-2.0** | `raw.githubusercontent.com/gobley/gobley/main/LICENSE` |

### 6.2 What redistribution requires

**Verified**, from the Apache-2.0 license text itself (fetched as part of the
`aws-lc-rs`/`mlkem-native`/`aws-lc` LICENSE files above, each of which reproduces the
full Apache-2.0 §4 "Redistribution" terms): redistributing Source or Object form
requires (a) giving recipients a copy of the License, (b) marking modified files as
changed, (c) retaining all copyright/patent/trademark/attribution notices from the
Source form (excluding ones not pertaining to the distributed parts), and (d) if the
original Work ships a `NOTICE` file, any redistributed Derivative Work "must include a
readable copy of the attribution notices contained within such NOTICE file." MIT and ISC
(also reproduced in full in the fetched `mlkem-native`/`aws-lc` LICENSE files) both
require only that "the above copyright notice and this permission notice" be included in
all copies/substantial portions — no NOTICE-file mechanism, no "mark changed files"
obligation.

**MPL-2.0 (UniFFI, Gobley) — the one copyleft outlier.** **Verified**, from the fetched
MPL-2.0 text itself: MPL-2.0 is a **file-level ("weak") copyleft** license — it grants
a royalty-free copyright and patent license over "Contributions" (defined as "Covered
Software of a particular Contributor") and explicitly contemplates "Larger Work"
(combining Covered Software with other material "that is not Covered Software," in
separate files). Practically, this means: (a) MPL-2.0-covered *source files* that
`pqcble` incorporates verbatim or modifies remain under MPL-2.0 and, if distributed,
their *source form* obligations (making modified MPL files' source available) apply to
those specific files — but (b) UniFFI/Gobley are build-time/codegen tools and Rust
crates linked into a compiled binary, not necessarily source files copied into
`pqcble`'s own repository; whether MPL-2.0's file-level copyleft is triggered at all
for `pqcble` depends on exactly how UniFFI/Gobley code ends up in the shipped artifact
(e.g., build-time-only tooling vs. a runtime support crate statically linked into the
`cdylib`/`staticlib`). This is precisely the kind of determination that needs legal
review, not inference: MPL-2.0 is explicitly designed to be compatible with being
combined into a proprietary "Larger Work" without copyleft-infecting the surrounding
proprietary code, provided the MPL-covered files themselves are not modified without
disclosing those specific file-level modifications, and the License itself (not just
notices) is made available for the Covered Software.

### 6.3 Building a combined NOTICES file

**Inference, following directly from the license texts fetched above** (not itself a
separate primary source, but a mechanical consequence of §6.2): a shipped `pqcble`
binary SDK (and the reference chat app) should ship a combined
`NOTICES`/`THIRD_PARTY_LICENSES` file/screen that, at minimum, includes:
1. The full Apache-2.0 license text (once), with per-dependency copyright attribution
   blocks reproduced for `aws-lc-rs`/`aws-lc` (which has an unusually detailed internal
   NOTICE-style LICENSE file itself, covering BoringSSL/OpenSSL/SSLeay/Fiat/s2n-bignum/
   Jitter-Entropy/Keccak provenance — that whole file's attribution section is the
   authoritative source to copy forward, not a paraphrase), `mlkem-native`, and
   whichever RustCrypto crates are actually linked (checking each crate's own
   `Cargo.toml`/`LICENSE-APACHE`/`LICENSE-MIT` pair, since the `aes-gcm` check here is
   representative of the workspace convention, not a guarantee every RustCrypto crate
   `pqcble` depends on uses identical wording).
2. The MIT and ISC license texts (once each), with attribution for `aws-lc`'s Fiat
   Cryptography (MIT), any RustCrypto MIT election, and the ISC portions of
   `aws-lc`/`aws-lc-rs`/`mlkem-native`.
3. A clearly separated section with the **full MPL-2.0 text** and an explicit statement
   of which components (UniFFI, Gobley) are MPL-2.0-licensed, a link to their unmodified
   upstream source (or `pqcble`'s own fork's source, if any UniFFI/Gobley files were
   modified) satisfying MPL-2.0's source-availability requirement for Covered Software.
4. The BSD-3-Clause Jitter Entropy RNG attribution, since AWS-LC's own LICENSE file
   flags that this component is dual-licensed and that AWS expressly elects BSD-3-Clause
   over GPLv2 for their distribution — `pqcble` inherits that same election by
   depending on `aws-lc`/`aws-lc-rs` as built, and should state so explicitly rather
   than silently omitting the GPL-avoidance rationale.

---

## Final checklist

### Packaging
- [ ] Confirm the Gobley/Cargo Gradle plugin cross-compiles Rust `cdylib`s for all four
      Android ABIs (`arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`) and places them under
      `jniLibs/<abi>/`.
- [ ] Confirm the iOS build produces one static `.a` per Apple platform/architecture
      combination actually shipped (device + Simulator, Apple Silicon + Intel Simulator
      if still supporting Intel Macs) and assembles them via
      `xcodebuild -create-xcframework -library ... -headers ...`.
- [ ] Sign the XCFramework with an Apple Distribution/Development identity
      (`codesign --timestamp -s <identity>`) before distribution.
- [ ] Decide SPM distribution mechanism: remote zipped XCFramework + `compute-checksum`
      binaryTarget, vs. committing the `.xcframework` directly with a local/path binary
      target; document the choice and checksum-rotation process for releases.
- [ ] Verify (toolchain-level) there is no Rust symbol/ODR collision risk if `pqcble`'s
      static Rust core is ever linked alongside another UniFFI-based Rust SDK in the
      same consuming iOS app; consider symbol-prefixing or documentation warning
      against double-linking.
- [ ] Measure actual shipped binary-size delta from the Rust/`aws-lc`/`mlkem-native`
      static linkage, and apply standard Cargo release-profile mitigations (LTO, strip,
      `panic=abort`) if the delta is material.
- [ ] Set up the Maven Central publishing pipeline (user token, GPG signing secrets,
      `publishToMavenCentral`/`publishAndReleaseToMavenCentral` CI workflow) per the
      JetBrains KMP docs.

### Apple export compliance
- [ ] Have counsel/export-control specialist confirm whether `pqcble`'s custom BLE
      handshake (combining ML-KEM-768/X-Wing/X25519/AES-256-GCM/HKDF via standard,
      published primitives) qualifies as "industry standard algorithm" rather than
      "proprietary/non-standard cryptography" under BIS's definition — this determines
      whether a CCATS is advisable.
- [ ] Set `ITSAppUsesNonExemptEncryption = YES` in Info.plist (the app uses non-OS
      encryption) unless/until an exemption determination is made with counsel.
- [ ] Upload the appropriate App Store Connect export-compliance documentation (at
      minimum, prepare for the "industry standard algorithm" row's requirements) before
      first submission.
- [ ] If distributing on the French App Store: prepare and upload the French
      encryption declaration in App Store Connect's App Encryption Documentation
      section (required even for standard-algorithm apps per Apple's own table).
- [ ] Determine, with counsel, whether §742.15(b)(2)'s BIS/NSA email notification for
      "non-standard cryptography" in publicly available source code applies, given the
      project's open-source status — send the notification to `crypt@bis.doc.gov` and
      `enc@nsa.gov` if it does, and repeat on functionality-changing updates or
      hosting-URL changes.
- [ ] Confirm with BIS/counsel whether an annual self-classification report
      (§740.17(e)(3)) is triggered, and reconfirm the current submission deadline and
      process directly with BIS (the "Feb 1" deadline and the specific BIS guidance URL
      could not be re-verified live in this session — the previously-known URL now
      redirects to an unrelated page).
- [ ] Re-run this whole analysis if/when the protocol/primitive set changes (e.g., if a
      non-standardized combiner or custom primitive is ever introduced).

### Google Play
- [ ] No Play-specific export-compliance form exists to fill out — but independently
      confirm and document the publisher's own EAR obligations (self-classification/
      notification/annual report) apply regardless of using Play as a distribution
      channel.

### Apple Privacy Manifest
- [ ] Ship a `PrivacyInfo.xcprivacy` inside the iOS XCFramework/SPM package itself (not
      just the reference app), per Apple's static-framework bundling instructions
      (Mach-O type "Static Library," privacy manifest added to target's bundle
      resources).
- [ ] Audit actual Rust/Kotlin/Swift code for required-reason API usage: `UserDefaults`
      (bonding-state persistence), monotonic/boot-time clocks (BLE timing/backoff
      logic), file-timestamp or disk-space queries (any diagnostics/logging feature),
      active-keyboard APIs (unlikely) — declare each with an approved reason code.
      Re-verify Apple's exact current category/reason-code list directly (could not be
      fetched in this session — see Gaps) before finalizing the plist.
- [ ] Confirm `aws-lc-rs`/`mlkem-native`/UniFFI/Gobley are still absent from Apple's
      "SDKs that require a privacy manifest and signature" list at ship time (and
      periodically thereafter) — re-fetch
      `developer.apple.com/support/third-party-SDK-requirements/`.

### Bluetooth permissions / Play Data Safety
- [ ] Add `NSBluetoothAlwaysUsageDescription` to iOS Info.plist (no need for the legacy
      peripheral-usage key given an iOS 15+ minimum target).
- [ ] Add Android manifest permissions: `BLUETOOTH_SCAN` with
      `android:usesPermissionFlags="neverForLocation"`, `BLUETOOTH_ADVERTISE`,
      `BLUETOOTH_CONNECT` (API 31+ path), plus legacy `BLUETOOTH`/`BLUETOOTH_ADMIN` with
      `maxSdkVersion="30"` and `ACCESS_FINE_LOCATION` with `maxSdkVersion="30"` for the
      Android 8–11 range this project also targets.
- [ ] Decide whether any persisted BLE peer/device identifier is truly ephemeral or is
      stored/bonded across sessions; if stored, declare "Device or other identifiers"
      in the Play Console Data Safety form with accurate sharing/retention/deletion
      answers.

### Licensing
- [ ] Build a combined `NOTICES`/`THIRD_PARTY_LICENSES` artifact covering Apache-2.0
      (with `aws-lc`'s detailed internal attribution block reproduced, not
      paraphrased), MIT, ISC, BSD-3-Clause (Jitter Entropy, with AWS's GPL-avoidance
      election noted), and a clearly separated **MPL-2.0 section** for UniFFI and
      Gobley.
- [ ] Have counsel confirm whether MPL-2.0's file-level copyleft is triggered for
      `pqcble`'s specific build (build-time codegen tool vs. statically-linked runtime
      support code) and, if any UniFFI/Gobley source files are modified, ensure their
      modified-file source is made available per MPL-2.0 §3.
- [ ] Verify every individual RustCrypto crate actually linked (not just `aes-gcm`, used
      here as a representative sample) carries the same `Apache-2.0 OR MIT` dual
      license before finalizing the NOTICES file.

---

## Gaps / unverified items

- **§740.17(b)(1) vs (b)(2) vs (b)(3)**: the fetched eCFR text for §740.17 truncated
  before fully enumerating which specific product/end-user categories fall under each
  sub-paragraph; the "(b)(1) = self-classification-only mass-market-adjacent items" vs.
  "(b)(2)/(b)(3) = 30-day BIS review" characterization in §2.2 is a reasonable reading
  of the fetched fragment but was not confirmed against the complete sub-paragraph text.
- **§734.3(b)(3)** ("publicly available" definition referenced by §742.15(b)): the fetch
  returned §734.3(b)(1)'s other-agency cross-referral text rather than the (b)(3)
  publicly-available-technology definition itself; re-fetch targeting that specific
  sub-paragraph before relying on the exact statutory definition of "publicly available."
- **2021 Federal Register rule** on mass-market/open-source encryption self-
  classification: both `federalregister.gov` and `ecfr.gov`'s standard HTML endpoints
  actively block automated/programmatic access in this environment (explicit anti-
  scraping notice encountered on both). I found a citation to "86 FR 16488, Mar. 29,
  2021" in §742.15's amendment history (via the eCFR renderer API, which was
  accessible), consistent with the task's description of a 2021 rule change, but did not
  read the notice's actual text — confirm its content via the Federal Register's
  official API (`federalregister.gov/developers/documentation/api/v1`) rather than
  scraping, per that site's own instructions.
- **BIS "Annual Self Classification Report" page and Feb 1 deadline**: the specific BIS
  URL Apple's own doc links to
  (`bis.doc.gov/index.php/policy-guidance/encryption/4-reports-and-reviews/a-annual-
  self-classification`) now redirects to an unrelated `bis.gov` landing page about IC
  export licensing — BIS appears to have reorganized its site. The commonly cited
  February 1 annual deadline could not be re-confirmed live; treat as
  community-reported pending a fresh BIS site search.
- **ANSSI / French Code pénal Article R.226-3, decree 2007-663**: confirmed indirectly
  via Apple's own documentation (which names ANSSI and the French requirement's scope:
  Secure Storage/Secure Communications/Security Anti-Virus apps, with Banking/Medical
  exemptions), but I did not fetch `ssi.gouv.fr` or the French statutory text itself in
  this session.
- **Bitcode removal timeline** (Xcode 14, 2022): stated in §1.5 as community knowledge;
  no current Apple release-notes/migration page confirming the exact version/date was
  fetched in this session.
- **Rust symbol-collision mitigation mechanics** (§1.5): the specific technical claims
  about UniFFI's generated FFI symbol naming scheme and mitigation techniques (symbol
  renaming, version scripts) are presented as community-reported Rust-FFI-ecosystem
  knowledge; I did not fetch UniFFI's own source to confirm its exact generated-symbol
  naming convention or a documented collision-avoidance mechanism.
- **Apple's required-reason API category enum list** (§4.2): Apple's symbol-reference
  pages for the specific category constants (`NSPrivacyAccessedAPICategoryFileTimestamp`,
  `...SystemBootTime`, `...DiskSpace`, `...ActiveKeyboards`, `...UserDefaults`) render
  their content via client-side JS/JSON not retrievable by the fetch tool in this
  session, including via the `.md` DocC alternate link (which 404'd for these specific
  sub-pages). The five-category list is widely known from Apple's WWDC23 announcement
  and developer community coverage but was not independently re-verified against
  Apple's live page content here.
- **Whether Apple's SDK-signature-requirement detection is name-based or binary-
  fingerprint-based** (§4.3): not confirmed from any fetched primary source; this
  affects whether `aws-lc-rs` (a distinctly-named fork of BoringSSL/OpenSSL) could ever
  be swept into the signature requirement despite not appearing by name on the current
  list.
- **CocoaPods `vendored_frameworks`/`vendored_libraries` current syntax** (§1.4): not
  fetched from CocoaPods' own docs in this session; only Apple's SPM-side binaryTarget
  mechanics were verified.
- **Exact `cargo-ndk` usage inside Gobley's Cargo Gradle plugin**: Gobley's tutorial
  confirms *that* per-platform static/dynamic artifacts are produced and linked
  automatically, but does not name `cargo-ndk` explicitly in the fetched tutorial
  excerpt, and the plugin's own source was not fetched to confirm the exact
  cross-compilation tool invoked under the hood.
