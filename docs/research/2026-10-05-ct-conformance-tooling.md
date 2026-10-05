# Research findings: constant-time and conformance tooling for the `pqcble-r1` Rust core

Status: research draft, not an approved CI design. All findings below were
gathered on **2026-10-05** against primary sources (GitHub repos/workflow
files, IETF datatracker, docs.rs, crates.io where reachable). Every claim is
cited inline with an exact URL; anything that could not be confirmed against
a primary source is marked **UNVERIFIED** and listed again in the gaps
section at the end. Re-verify before this gates a release, since CI
workflows, draft versions, and test-vector coverage are living data.

## Summary

The Rust core (`pqcble-wire`, `pqcble-crypto`, `pqcble-proto`, `pqcble-ffi`)
ships to Android (arm64-v8a, armeabi-v7a, x86_64 via `cargo-ndk`) and iOS
(arm64, sim-arm64). Most constant-time and formal-verification tooling in
this space — Valgrind-based CT testing, SAW/HOL-Light/CBMC proofs, Microwalk
— runs **only on x86_64/aarch64 Linux CI hosts** compiling **portable C or
native Rust/std binaries**, not on actual Android-NDK- or iOS-toolchain-built
artifacts. This is the central finding: **upstream proofs from `aws-lc-rs`
(AWS-LC) and `mlkem-native` do not transfer to our Android/iOS cross-compiled
binaries** — different compiler (NDK clang vs Xcode clang vs the exact
Clang-10/14 configurations verified), different flags, different ABI. They
are still valuable as upstream confidence and as host-side regression gates
for any vendored/forked C, but they cannot be presented as proof that the
shipped mobile binaries are constant-time or correct.

Concretely:
- **dudect-bencher** is easy to wire into CI as a plain Cargo binary on the
  x86_64 Linux host, but neither its upstream docs nor `mlkem-native`'s own
  practice document GH-hosted-runner noise behavior; no adopters were found
  among RustCrypto/dalek-cryptography crates for our primitives.
- **Valgrind CT testing** (as practiced by `mlkem-native`, a *patched*
  Valgrind from the KyberSlash paper, not classic `ctgrind`) runs on both
  `ubuntu-latest` (x86_64) and `ubuntu-24.04-arm` (aarch64) GH-hosted
  runners — host Linux only, never Android/iOS.
- **Binary-level checkers** (Microwalk, BINSEC/Rel) are x86-only or
  insufficiently documented for ARM; neither covers Android/iOS binaries.
  "Pitchfork" could not be located as a real CT tool at all.
- **Miri** is useful for pure-logic UB bugs in `pqcble-wire`/`pqcble-proto`
  but explicitly warns it is *"not suited for cryptographic use"* and has
  minimal FFI support, so it cannot meaningfully exercise `pqcble-ffi`/UniFFI
  or randomness paths. **cargo-careful** is the better fit for FFI-crossing
  code since it supports real C FFI and runs faster, though explicit
  Android/iOS cross-target support is undocumented. **cargo-fuzz**/libFuzzer
  is restricted by its own README to x86_64/aarch64 Unix hosts — practical on
  the Linux CI runner, not an on-device mobile fuzzing story.
- **Test vectors**: NIST's own `usnistgov/ACVP-Server` repo is confirmed as
  the authoritative source for ML-KEM keyGen/encapDecap JSON vectors (exact
  directories found); AES-GCM/HMAC/HKDF("KDA") directory names were not
  individually enumerated in this pass (follow-up needed). The X-Wing draft
  (-11, current, matches ADR 0001) ships **no official test vectors of its
  own** — conformance vectors must come from an implementation (BoringSSL,
  CIRCL, or RustCrypto's `KEMs/x-wing`, the latter stuck at draft -06 and
  explicitly unaudited). Wycheproof (C2SP fork) **now lists ML-KEM among its
  covered algorithms** — contrary to its historical "no PQ KEM vectors"
  reputation — in addition to confirmed AES-GCM/HKDF/HMAC/X25519 coverage;
  exact vector-file paths/schema depth were not opened in this pass.
- **Upstream proofs**: AWS-LC's SAW/Coq/NSym proof set (`awslabs/aws-lc-verification`)
  covers only SHA-2, HMAC-SHA-384, AES-KW(P)-256, AES-GCM-256 — **no
  ML-KEM, no X25519** — and only on named server CPU targets (SandyBridge+/
  Skylake x86-64, Neoverse-N1/V1 aarch64), explicitly not Android/iOS.
  AWS-LC's own README states ML-KEM assurance is delegated entirely to
  `mlkem-native`'s CBMC + HOL-Light (via s2n-bignum) proofs, which in turn
  run on x86_64/aarch64 Linux and native macOS CI hosts only — again, no
  Android NDK or iOS-toolchain build anywhere in mlkem-native's CI matrix.

---

## 1. Timing tests: `dudect` / `dudect-bencher`

**What it is.** `dudect` is Reparaz, Balasch, Verbauwhede's statistical
constant-time testing methodology ("dude, is my code constant time?",
https://eprint.iacr.org/2016/1123.pdf), reference C implementation at
`oreparaz/dudect` (https://github.com/oreparaz/dudect). It uses a Welch's
t-test over two input classes (e.g. fixed vs. random) and flags a leak when
`|t| > ~4.5-5`; the README documents it demonstrating a leak in a
deliberately-broken curve25519-donna variant, and states a clean run never
terminates on its own — you Ctrl-C it once confidence is high enough.

**Rust port.** `dudect-bencher` (https://github.com/rozbb/dudect-bencher,
published on crates.io/docs.rs) wraps the same statistic in a harness
(`CtRunner`, `Class::Left/Right`, `ctbench_main!`). It builds a **standalone
binary** (run via `cargo run --release --example ...`), not a `#[bench]`
integration.

**CI practicality / flakiness — UNVERIFIED.** Neither the original `dudect`
README nor `dudect-bencher`'s README make any claim about behavior on
shared/virtualized CI cores (GitHub-hosted runners use shared vCPUs with
noisy-neighbor effects and no performance-governor control). The tool's
`--continuous` mode lets it keep accumulating samples until confident, which
is the generic mechanism for tolerating noise, but convergence time on a
noisy VM is unbounded and not discussed by either author. Treat "GH-hosted
runners are too noisy for dudect to be fast/stable" as an **inferred risk**,
not a sourced fact.

**Adoption among our primitives — not found.** No dudect-bencher usage was
found wired into RustCrypto's `ml-kem`, `x25519-dalek`, or `aes-gcm` crates,
nor in dalek-cryptography repos, in the searches performed. `mlkem-native`'s
own public benchmark dashboard
(https://pq-code-package.github.io/mlkem-native/dev/bench/, linked from its
README) is a **performance** benchmark, not a dudect-style CT test; its CT
testing instead uses patched Valgrind (§2). Absence-of-evidence here is not
exhaustive — only a handful of targeted searches were run.

**Target applicability.** Plain Cargo binary with `std` + timers — runs
trivially on the x86_64 Linux CI host. Meaningful mobile-target results would
require on-device execution (different CPU timing characteristics), which
GH-hosted runners do not provide natively; no primary source addresses
running dudect against Android/iOS binaries.

**Verdict: usable as an advisory/nightly check on the x86_64 Linux host
only, with unverified noise characteristics. Not a hard per-PR gate given the
unverified flakiness risk, and does not validate Android/iOS builds.**

---

## 2. Secret taint checking: Valgrind / ctgrind, and `mlkem-native`'s practice

**Org correction.** The project lives at **`pq-code-package/mlkem-native`**
(https://github.com/pq-code-package/mlkem-native), a PQCA/Linux
Foundation-supported fork of the ML-KEM reference implementation — not
`pq-crystals` or `formosa-crypto`.

**CI structure.** Top-level dispatcher
`.github/workflows/all.yml` (https://github.com/pq-code-package/mlkem-native/blob/main/.github/workflows/all.yml)
fans out to `base`, `ci`, `cbmc`, `ct-test`, `hol-light`, `slothy`,
`baremetal`, `zephyr`, plus libOQS/AWS-LC/Pavona integration jobs.

**Valgrind CT job.**
`.github/workflows/ct-tests.yml` (https://github.com/pq-code-package/mlkem-native/blob/main/.github/workflows/ct-tests.yml)
runs job `check-ct-varlat` on a matrix of `system: [ubuntu-latest,
ubuntu-24.04-arm]` (i.e. **x86_64 and aarch64 Linux GH-hosted runners**)
crossed with 8 compiler variants (clang 6/21/22/23, gcc 48/14/15/16) and 7
optimization levels (`-Oz -Os -O3 -Ofast "-O3 -ffast-math" -O2 -O1 -O0`). The
workflow comment states it uses *"the patched Valgrind from the KyberSlash
paper to detect divisions"* — i.e. a **bespoke patched Valgrind build**
(`valgrind-varlat`) that flags variable-latency division instructions, **not
classic `ctgrind`'s memcheck/`crypto_declassify` origin-tracking approach**.

**The actual invocation.**
`.github/actions/ct-test/action.yml` (https://github.com/pq-code-package/mlkem-native/blob/main/.github/actions/ct-test/action.yml)
runs the functional test binary as `tests func
--exec-wrapper="valgrind --error-exitcode=1 $VALGRIND_FLAGS"
--cflags="-DMLK_CONFIG_CT_TESTING_ENABLED ..."`, with a custom
`--variable-latency-errors=yes` flag, and explicitly disables AArch64 SHA3
extension instructions because they are "not yet supported by valgrind."

**Architecture coverage — direct answer.** Valgrind CT testing in
mlkem-native runs on **both x86_64 Linux and aarch64 Linux GH-hosted
runners**, but this is **host-Linux-process testing of the portable C
source**, not execution on an actual Android device/emulator or iOS
device/simulator. mlkem-native's full `ci.yml`
(https://github.com/pq-code-package/mlkem-native/blob/main/.github/workflows/ci.yml)
matrix was checked end-to-end: `macos-latest`/`xcode-27`/`macos-15-intel`
(native macOS, aarch64 + x86_64), `ubuntu-24.04-arm`/`ubuntu-latest` (native
+ cross for aarch64/aarch64_be/x86_64/riscv32/riscv64, PPC64LE POWER7/8) —
**no Android NDK cross-target and no iOS-simulator/device cross-target
anywhere**. The macOS jobs build **native macOS binaries**, not iOS
cross-builds.

**`ctgrind` itself — UNVERIFIED.** Adam Langley's original
`agl/ctgrind` (classic Valgrind-memcheck + `crypto_declassify`/
`crypto_classify` annotations) returned a GitHub error ("You can't perform
that action at this time") on direct fetch in this session; could not
confirm current maintenance state, whether archived, or whether it still
builds against modern Valgrind. Do not cite it as actively maintained
without re-checking.

**Verdict: Valgrind-based CT testing (the KyberSlash-patched variant used by
mlkem-native) is a solid, CI-template-ready gate on x86_64 + aarch64 Linux
hosted runners for vendored/forked portable C. It validates the reference C
source, not our actual Android-NDK or iOS-toolchain-compiled binaries — plan
to either (a) accept this as an upstream-confidence signal only, or (b) build
our own Valgrind-in-QEMU-or-equivalent harness if we want host-side CT
coverage of NDK-produced object code (not confirmed feasible — Valgrind does
not target Android directly, see below).**

---

## 3. Binary-level/static CT checkers

- **Microwalk** (https://github.com/microwalk-project/Microwalk): dynamic
  binary instrumentation via Intel **Pin**, combined with statistical
  leakage localization. README states explicitly it instruments **x86
  binaries** (build output under `obj-intel64`), ships Docker images and
  GitHub Actions templates (linked `example-c`/`example-js` repos show
  working GH Actions integration) — practical on an **x86_64 Linux hosted
  runner**. **No ARM/AArch64 support is documented anywhere**; it is also
  .NET 8-hosted, Windows/Linux only. **Not applicable to Android
  arm64/armeabi-v7a or iOS arm64/sim-arm64 binaries.**
- **BINSEC/Rel** (https://github.com/binsec/binsec): top-level README only
  points to https://binsec.github.io/ and an `INSTALL.md`/`doc` folder with
  no architecture/CI specifics visible from the landing page alone.
  **UNVERIFIED**: known in academic literature as an OCaml-based,
  x86/x86-64-focused relational symbolic executor, not packaged for drop-in
  CI use, but ARM support and CI-friendliness were not confirmed from a
  primary source in this pass — needs a deeper fetch of `INSTALL.md`/`doc/`
  before any recommendation.
- **ctgrind** — see §2; **UNVERIFIED** current state (fetch failed).
- **"Pitchfork"** — `https://github.com/trailofbits/pitchfork` returned
  **404**. **Could not locate a real CT-checking tool under this name/org at
  all.** Do not cite "Pitchfork" in a CI recommendation without first
  identifying its actual, correct source location.
- **`subtle` crate** (https://docs.rs/subtle/latest/subtle/): states
  verbatim *"This crate represents a 'best-effort' attempt, since
  side-channels are ultimately a property of a deployed cryptographic system
  including the hardware it runs on, not just of software"* and carries an
  explicit **"USE AT YOUR OWN RISK"** warning; it relies on bitwise ops plus
  a volatile-read barrier to block compiler reintroduction of branches. This
  is a **design-pattern mitigation**, not a verification/checking tool —
  `subtle` does not test or prove CT behavior.
- **`constant_time_eq`** (https://docs.rs/constant_time_eq/latest/constant_time_eq/):
  documents the same scope limit (time independent of input content/diff
  position, but *can* depend on memory address/length). No CI/testing
  strategy described on the docs page itself — **UNVERIFIED** regarding its
  own test-suite specifics (would need the repo's test directory, not
  fetched here).

**Verdict: Of the binary-level tools surveyed, only Microwalk has a clearly
documented, CI-template-ready workflow, and it is x86-only (Intel Pin) —
usable only against an x86_64 Linux-host build of our code (e.g. a
non-mobile debug build compiled for the CI runner), never against the actual
Android arm64/armeabi-v7a or iOS arm64 artifacts we ship. BINSEC and
"Pitchfork" are not currently recommendable: the former needs deeper
verification, the latter could not be located at all.**

---

## 4. UB detection and fuzzing: Miri, `cargo-careful`, `cargo-fuzz`, AFL++

**Miri** (https://github.com/rust-lang/miri). Confirmed from the README:
detects OOB/UAF access, uninitialized-data misuse, intrinsic precondition
violations, misalignment, type-invariant violations, data races, and
(experimentally) Stacked/Tree Borrows violations, plus memory leaks. Key
caveats quoted directly from the README:
- *"Miri runs the program as a platform-independent interpreter, so the
  program has no access to most platform-specific APIs or FFI... System API
  support varies between targets."* It supports "cross-interpretation"
  (emulating another target's layout/endianness) **on the host**, which is
  not the same as executing a real cross-compiled Android/iOS binary.
- *"the 'fake' system RNG APIs make Miri not suited for cryptographic use!
  Do not generate keys using Miri."* — directly relevant: restrict Miri to
  logic/UB testing in `pqcble-wire`/`pqcble-proto`, never to keygen-path
  correctness or randomness behavior.
- FFI support is minimal ("a few APIs have been implemented... most have
  not... Miri currently does not support networking") — bears directly on
  `pqcble-ffi` (UniFFI): Miri is unlikely to interpret through genuine
  FFI/UniFFI-generated glue.
- no_std+alloc compatibility is **reasonably inferred** (Miri interprets
  standard MIR regardless of `#![no_std]`) but the README does not use the
  literal phrase "no_std" — mark the explicit no_std guarantee as
  **UNVERIFIED**.
- Practically runs on the **x86_64 Linux CI host only** (needs a
  Miri-specific nightly sysroot built for the host interpreter); "targets"
  other than the host are emulated, not really executed.

**`cargo-careful`** (https://github.com/RalfJung/cargo-careful). README
confirms it rebuilds `std` with debug assertions and extra rustc checks
(`-Zstrict-init-checks`, `-Zextra-const-ub-checks`), needs recent nightly,
and distinctively **"works on all code, supports using arbitrary system and
C FFI functions, and is much faster"** than Miri — a better fit than Miri
for exercising the FFI/UniFFI boundary. It supports an experimental
sanitizer mode (`-Zcareful-sanitizer=<sanitizer>`, e.g. AddressSanitizer)
and auto-enables Apple's Main Thread Checker "on macOS, iOS, tvOS and
watchOS targets" (a UI-thread check, unrelated to crypto CT). Because it
uses the real target's rustc codegen plus a careful-mode sysroot, it is
plausible it can target `aarch64-linux-android`/`aarch64-apple-ios`, but the
README does not walk through such an example — **UNVERIFIED**: no explicit
confirmation of an end-to-end Android/iOS cross-target workflow.

**`cargo-fuzz`** (https://github.com/rust-fuzz/cargo-fuzz). README states
plainly: *"Note: libFuzzer needs LLVM sanitizer support, so this only works
on x86-64 and Aarch64, and only on Unix-like operating systems (not
Windows)."* Practical on the x86_64 Linux GH-hosted runner (and, per the
README, would work on an aarch64 Linux runner too), but no official story
for on-device Android/iOS fuzzing. Requires nightly + a C++11 compiler.

**AFL++** (https://github.com/AFLplusplus/AFLplusplus) — **UNVERIFIED**, not
independently fetched in this research pass; general knowledge suggests
broad Linux/x86_64 support plus partial ARM support via QEMU mode, but no
primary-source citation obtained here.

**no_std/alloc-only + FFI-boundary fuzzing caveats — gap.** Neither the Miri
nor cargo-fuzz README documents known issues specifically fuzzing
`no_std + alloc`-only crates or crossing a UniFFI boundary; recommend a
follow-up search of `rust-fuzz/cargo-fuzz` issues if this nuance matters.

**Verdict: Run Miri on `pqcble-wire`/`pqcble-proto` pure-Rust logic only
(never on keygen/RNG paths); use `cargo-careful` for anything crossing the
`pqcble-ffi`/UniFFI boundary since it supports real FFI and is faster;
`cargo-fuzz` targets for codec/state-machine fuzzing on the x86_64 Linux
host (and aarch64 Linux host if available) — none of these three validate
actual Android/iOS cross-compiled binaries; they are host-side logic/UB
gates only.**

---

## 5. Test vectors / conformance

### NIST ACVP (official source of truth)

Confirmed directly against `usnistgov/ACVP-Server`
(https://github.com/usnistgov/ACVP-Server): exact directories
`gen-val/json-files/ML-KEM-keyGen-FIPS203/` and
`gen-val/json-files/ML-KEM-encapDecap-FIPS203/` exist (plus a
`-tr1` revision variant, `ML-KEM-encapDecap-FIPS203-tr1/`), each containing
`registration.json`, `prompt.json`, `expectedResults.json`. Example content
confirmed: `registration.json` for keyGen shows `"algorithm": "ML-KEM",
"mode": "keyGen"`, `"parameterSets": ["ML-KEM-512","ML-KEM-768", ...]`. This
is the NIST-published source of truth, not a third-party wrapper.

**Not yet enumerated — follow-up needed.** Exact directory names for
AES-GCM, HMAC, and KDA/HKDF ("KAS-KDF-Onestep" or similar) under
`gen-val/json-files/` were **not individually confirmed** in this pass.
**UNVERIFIED**, straightforward follow-up: `search_code` scoped to
`path:gen-val/json-files` for `AES-GCM`, `HMAC`, `KDA`.

**Maintained Rust ACVP client/harness crate — UNVERIFIED.** A crates.io API
query for "acvp" returned HTTP 403 (bot-protection on the bare endpoint) in
this session; existence of a maintained Rust ACVP harness crate could not be
confirmed or denied. Needs a different lookup path (browser-rendered
crates.io search or `cargo search acvp`).

### X-Wing draft test vectors

Current draft version confirmed as **-11**, dated 23 September 2026,
expiring 27 March 2027 — https://datatracker.ietf.org/doc/draft-connolly-cfrg-xwing-kem/
— matching ADR 0001's cited version 11; **no newer version exists** as of
this research. Source/working-area repo:
https://github.com/dconnolly/draft-connolly-cfrg-xwing-kem (the I-D source,
not a reference-implementation repo).

Reading the draft body (sections 5.2–6, References, Appendix A/B): **there
is no "Test Vectors" appendix in draft -11.** Appendix A lists third-party
implementations; Appendix B is a Python reference spec (`xwing.py`)
explicitly marked *"not production ready... leaks the private key by its
runtime."* **The X-Wing draft itself ships no official numeric test
vectors** — conformance vectors must come from an implementation.

Appendix A's implementation list (candidate vector sources): Apple
CryptoKit (`XWingMLKEM768X25519`), Google BoringSSL
(`include/openssl/xwing.h`), Cloudflare CIRCL (Go, PR #471), Filippo's
`mlkem768` (Go), `rugo/xwing-kem.rs` (Rust, **the draft itself notes this
implements the older -00 version**), **RustCrypto `KEMs/x-wing`** (Rust),
and Orion (Rust).

Checked RustCrypto's x-wing crate README directly
(https://github.com/RustCrypto/KEMs/blob/master/x-wing/README.md): states
*"Current implementation matches the [draft RFC] version **06**"* and
carries an explicit **"⚠️ Security Warning: The implementation contained in
this crate has never been independently audited!"** — concrete finding for
ADR 0001: the most relevant pure-Rust X-Wing crate **lags the spec (06 vs.
our target 11) and is unaudited**; any vector/conformance harness built
against it needs revalidation against -11 semantics (combiner label, sizes,
etc.) before trusting it as an oracle.

### Wycheproof

Current, actively-maintained repo is the C2SP fork
(https://github.com/C2SP/wycheproof), confirmed from its README: *"We're in
the process of revitalizing development and maintenance of Project
Wycheproof as a C2SP project..."* The README's algorithm-coverage list
confirms AES-GCM, HKDF, HMAC, X25519/X448, and — **correcting the historical
assumption** — **ML-KEM (CRYSTALS-Kyber) is now explicitly listed** as a
covered algorithm. This is a change from Wycheproof's historical "no
post-quantum KEM vectors" reputation; **the exact vector file path/schema
under `testvectors_v1/` for ML-KEM was not opened in this pass** —
**UNVERIFIED in depth** (does it cover ML-KEM-768 specifically? does it
include implicit-rejection / invalid-ciphertext edge cases? no
X-Wing-combiner-level vectors are expected, since Wycheproof vectors are
generally per-primitive, not per-hybrid-combiner). Follow-up: fetch
`testvectors_v1/*mlkem*` directly.

**Verdict: NIST ACVP (ML-KEM confirmed; AES-GCM/HMAC/HKDF to be enumerated)
is the primary conformance oracle. Wycheproof is a strong secondary
edge-case source, now plausibly covering ML-KEM too (needs depth check).
X-Wing itself has no spec-level vectors — build our own vectors by
cross-checking against BoringSSL/CIRCL (both ahead of RustCrypto's x-wing
crate, which is both behind and unaudited).**

---

## 6. What upstream already proves (and what does not transfer to us)

### AWS-LC / `aws-lc-rs`

The dedicated proofs repo is **`awslabs/aws-lc-verification`** (not
`aws/aws-lc-verification`, which 404s) — confirmed via `aws/aws-lc`'s own
`tests/ci/*.sh` scripts, which all `git clone
https://github.com/awslabs/aws-lc-verification.git` (e.g.
`aws/aws-lc:tests/ci/run_formal_verification.sh`,
`aws/aws-lc:.github/workflows/image-build-formal-verification.yml`).

The verified-code table in
https://github.com/awslabs/aws-lc-verification/blob/master/README.md lists
only **SHA-2 (384/512)**, **HMAC-SHA-384**, **AES-KW(P)-256**,
**AES-GCM-256** as SAW/NSym-verified (ECDSA/ECDH/P-384 rows exist in the
markdown source but are HTML-commented out — disabled/retired). **There is
no ML-KEM row and no X25519 row at all.** This directly means **AWS-LC's SAW
proofs do not cover two of our five primitive families (ML-KEM, X25519)**.

The same README states where ML-KEM assurance actually comes from instead:
*"Our production implementation of ML-KEM lies in the [mlkem-native]
repository... This repo includes code from s2n-bignum, and adds proof of
memory- and type-safety for the C components using CBMC."* — i.e. **ML-KEM
assurance in AWS-LC is delegated entirely to `mlkem-native`'s own CBMC +
HOL-Light/s2n-bignum proofs** (below), not to the `aws-lc-verification` SAW
harness.

**Verified platforms** (same README's Platform table): **SandyBridge+ and
SandyBridge–Skylake (x86-64, Clang 10)**, and **neoverse-n1/neoverse-v1
(aarch64 server CPUs, Clang 10/14)**. These are specific **server-class**
Linux configurations. **There is no Android-NDK or iOS-toolchain build
configuration anywhere in this table.** This confirms directly: **AWS-LC's
formal-verification results do not transfer to Android (arm64-v8a/
armeabi-v7a/x86_64 via cargo-ndk) or iOS (arm64/sim-arm64) cross-compiled
binaries** — different compiler (NDK clang / Xcode clang vs. the exact
Clang-10/14 build-script configurations referenced in
`SAW/scripts/x86_64/build_llvm.sh`/`build_x86.sh`), different flags,
different ABI; the verification's own stated scope ("applies to any
compiler producing semantically equivalent code" under the *stated* compile
switches) cannot be assumed to extend to NDK/iOS-toolchain-produced code
without independent validation.

`aws-lc-rs`'s own README
(https://github.com/aws/aws-lc-rs/blob/main/aws-lc-rs/README.md) documents
FIPS vs. non-FIPS feature flags and build requirements (CMake/Go/bindgen
for FIPS builds only) but **does not itself document explicit Android/iOS
cross-compilation support or pre-built mobile binaries** in the portion
fetched. **UNVERIFIED**: whether `aws-lc-rs` officially supports
`cargo-ndk`-built Android targets or iOS arm64/sim-arm64 targets needs a
dedicated fetch of its platform-support docs/CI matrix — do not assume
parity with `aws-lc`'s own C-level CI, which (per
`aws/aws-lc:tests/ci/README.md`) is Linux/x86/aarch64 CodeBuild-centric with
no Android/iOS entries visible in the fetched excerpt.

AWS-LC's own (non-formal) CT testing practice beyond the SAW Docker
environments — **UNVERIFIED**, not independently confirmed in this pass
whether `aws/aws-lc` runs Valgrind/ctgrind internally; would need a
dedicated fetch of its `tests/` directory/CT-specific docs.

### `mlkem-native`

Confirmed org/repo: https://github.com/pq-code-package/mlkem-native
(PQCA/Linux Foundation), used downstream by **libOQS (since 0.13.0)**,
**AWS-LC (since v1.50.0)**, and **rustls (since v0.23.28, via AWS-LC as
default provider)** — all stated directly in the README.

Verification inventory (README + linked `proofs/cbmc`, `proofs/hol_light`
dirs):
- **CBMC**: proves memory-safety (no overflow) and type-safety for all C
  code in `mlkem/src/*` and `mlkem/src/fips202/*` via function
  contracts/loop invariants. CI job
  `.github/workflows/cbmc.yml` (https://github.com/pq-code-package/mlkem-native/blob/main/.github/workflows/cbmc.yml)
  runs per ML-KEM parameter set (k=2/3/4, i.e. 512/768/1024) on a
  **self-hosted EC2 `r8g.xlarge` "ubuntu (aarch64)"** runner — **not** a
  standard GH-hosted runner, requires an `AWS_GITHUB_TOKEN` secret, and is
  guarded by `if: github.repository_owner == 'pq-code-package' && !fork`
  (does not run on forks/external PRs).
- **HOL-Light** (via s2n-bignum infrastructure, cross-referenced from
  `awslabs/aws-lc-verification`'s README): proves AArch64 and x86_64
  assembly functionally correct, memory-safe, **and of secret-independent
  timing (constant-time) at the object-code level** — the formal,
  machine-checked CT guarantee for the hand-written ASM backends. CI
  workflow
  `.github/workflows/hol_light.yml` (https://github.com/pq-code-package/mlkem-native/blob/main/.github/workflows/hol_light.yml)
  runs a bytecode-freshness check plus per-proof-target matrix jobs
  (NTT/INTT/poly_tomont/Keccak-f1600 variants, etc.) all on
  **`ubuntu-24.04-arm` (aarch64 Linux hosted runner)** — note even the
  **x86_64 assembly's** HOL-Light proofs are *checked* by cross-tooling
  running on an aarch64 host, not executed on x86_64 silicon; gated to the
  upstream repo only.
- **Valgrind CT testing**: see §2 in full — `ubuntu-latest` (x86_64) +
  `ubuntu-24.04-arm` (aarch64), KyberSlash-paper-patched Valgrind targeting
  variable-latency division ops, across many compiler/opt-level
  combinations.

**Android/iOS-specific CI — confirmed absent.** The full functional-test
matrix in
`.github/workflows/ci.yml` (https://github.com/pq-code-package/mlkem-native/blob/main/.github/workflows/ci.yml)
enumerates `macos-latest`/`xcode-27`/`macos-15-intel` (native macOS, aarch64
+ x86_64), `ubuntu-24.04-arm`/`ubuntu-latest` (native + cross for
aarch64/aarch64_be/x86_64/riscv32/riscv64, PPC64LE POWER7/8). **No Android
NDK cross-target and no iOS device/simulator cross-target appear anywhere.**
This means `mlkem-native` is verified only as **portable, generically
compiled C on Linux/macOS hosts** — using it inside `pqcble-crypto`'s
reference adapter for Android/iOS means **our own Android-NDK and
iOS-toolchain builds of this exact C code have not been independently
CT-tested or formally verified by upstream**: the CBMC/HOL-Light proofs are
over specific (mostly aarch64-Linux-hosted-toolchain) object code, and the
KyberSlash-patched-Valgrind CT tests only run x86_64/aarch64 Linux-native
builds. **This is the same "proofs don't transfer to differently-compiled
binaries" gap as AWS-LC, and it applies to our reference adapter exactly as
it does to AWS-LC's production ML-KEM.**

---

## Summary table: tool → target applicability (confirmed)

| Tool | x86_64 Linux CI host | Android arm64-v8a/armeabi-v7a/x86_64 | iOS arm64/sim-arm64 | CI practicality |
|---|---|---|---|---|
| dudect-bencher | Yes (plain cargo binary) | Not demonstrated | Not demonstrated | Easy to add; GH-runner noise/flakiness unsourced |
| Valgrind (mlkem-native's KyberSlash-patched variant) | **Yes** (`ubuntu-latest`) | No | No | Fully templated; also runs on aarch64 Linux (`ubuntu-24.04-arm`) hosted runner |
| ctgrind (agl) | Unverified (repo fetch failed) | No | No | Maturity unverified |
| Microwalk | Yes (x86 Pin-based), CI templates exist | **No** (Pin = x86/x86-64 only) | No | Practical on x86_64 host only |
| BINSEC/Rel | Unverified (need deeper doc fetch) | Unverified | Unverified | Unverified |
| "Pitchfork" | **Not found** at expected URL (404) | — | — | Could not verify existence/location at all |
| Miri | Yes (interpreter on host) | No (interpreter, not real codegen; "not suited for cryptographic use") | No | Good for UB logic bugs in `pqcble-wire`/`pqcble-proto`; avoid for FFI/UniFFI or RNG paths |
| cargo-careful | Yes | Unverified (no explicit cross-target doc) | Explicit iOS awareness only for Main Thread Checker, not CT | Faster than Miri, supports real FFI |
| cargo-fuzz/libFuzzer | Yes (x86_64 and aarch64 per README) | Plausible on aarch64 Linux host only, not on-device | No | Needs nightly + sanitizer support |
| AFL++ | Likely, unverified in this pass | Unverified | Unverified | Needs follow-up fetch |
| NIST ACVP vectors (ML-KEM confirmed; AES-GCM/HMAC/HKDF dirs not yet enumerated) | Source-of-truth JSON, usable anywhere a harness can load JSON | Same (data-only) | Same | Need a harness; no confirmed maintained Rust ACVP crate (crates.io API check blocked) |
| X-Wing draft vectors | **None shipped in draft -11 itself** | — | — | Must derive from an implementation (BoringSSL/CIRCL/RustCrypto x-wing — the latter stuck at draft -06, unaudited) |
| Wycheproof | AES-GCM/HKDF/HMAC/X25519/X448 and now ML-KEM confirmed listed | Data-only | Data-only | Active C2SP-maintained project; ML-KEM depth unverified |
| AWS-LC SAW/NSym proofs | SHA-2/HMAC/AES-KWP/AES-GCM only, on SandyBridge+/Neoverse-N1/V1 Linux builds — **no ML-KEM/X25519** | **Not covered** | **Not covered** | Re-verification needed for cross-compiled mobile artifacts |
| mlkem-native CBMC/HOL-Light/Valgrind | Yes (x86_64 + aarch64 Linux, partly via self-hosted EC2) | **Not covered** — "portable C" assumption only | **Not covered** | Same cross-compilation transfer gap as AWS-LC |

---

## Recommended CI gate list

**Per-PR (fast, must pass on every push):**
- `cargo test` + `cargo clippy` (standard, not detailed here) for all crates.
- `cargo +nightly careful test` for `pqcble-crypto`/`pqcble-ffi` (FFI/UniFFI
  boundary coverage; faster than Miri, supports real C FFI) — **target:
  x86_64 Linux CI host only**; this does not validate Android/iOS codegen.
- `cargo +nightly miri test` for `pqcble-wire`/`pqcble-proto` pure-Rust logic
  (excluding any RNG/keygen path, per Miri's own "not suited for
  cryptographic use" warning) — **x86_64 Linux CI host only**.
- NIST ACVP-vector-driven known-answer tests (KAT) for ML-KEM-768
  keyGen/encapDecap against `usnistgov/ACVP-Server`'s
  `gen-val/json-files/ML-KEM-*-FIPS203/` fixtures, run against both the
  `aws-lc-rs` adapter and the `mlkem-native`-based reference adapter —
  **x86_64 Linux CI host**; cheap, deterministic, high value, should gate
  every PR touching `pqcble-crypto`.
- Wycheproof-vector KATs for AES-256-GCM, HKDF/HMAC-SHA-384, X25519 (and
  ML-KEM once the exact vector path/schema is confirmed, see gap #8) —
  **x86_64 Linux CI host**.
- Build matrix smoke test: compile (not full CT/UB test) for all 5 shipping
  targets (`aarch64-linux-android`, `armv7-linux-androideabi`,
  `x86_64-linux-android` via `cargo-ndk`; `aarch64-apple-ios`,
  `aarch64-apple-ios-sim`) to catch cross-compilation breakage early, even
  though this gate proves nothing about CT/UB.

**Nightly (slower, broader, allowed to be flaky without blocking merges):**
- `dudect-bencher` runs for the hand-rolled/most CT-sensitive code paths in
  `pqcble-crypto` (e.g. any branch-prone glue around the `CryptoBackend`
  trait, X-Wing combiner logic) — **x86_64 Linux CI host**, advisory only
  given the unsourced noise/flakiness risk (gap #1/#2); do not hard-fail PRs
  on it, track trend over time instead.
- `cargo fuzz` targets for `pqcble-wire` codec parsing and `pqcble-proto`
  state-machine transitions, running for a bounded nightly time budget —
  **x86_64 Linux CI host** (and aarch64 Linux host if runner available,
  per cargo-fuzz's own x86_64/aarch64 Unix constraint).
- If we vendor/fork any C from `mlkem-native` for the reference adapter,
  mirror its own CI practice: run the **KyberSlash-patched Valgrind CT test**
  against our vendored copy on both `ubuntu-latest` and `ubuntu-24.04-arm`
  GH-hosted runners (mirrors
  `pq-code-package/mlkem-native/.github/workflows/ct-tests.yml`) — this is
  a host-Linux-only gate, still useful as a regression check on the C
  source even though it does not validate the NDK/iOS-built artifact.
- Microwalk run against an x86_64 Linux-host debug build of the crypto core
  (not the shipping Android/iOS binaries) as a secondary, lower-confidence
  binary-level CT signal — optional, given Microwalk's narrow (x86-only)
  applicability and today's unclear value-add over the Valgrind gate above.

**Pre-release (manual or release-branch-only, highest cost, full coverage
expected before cutting a release):**
- Full ACVP conformance run across **all** confirmed algorithm families once
  AES-GCM/HMAC/KDA directory names are enumerated (gap #6), not just
  ML-KEM, against both `CryptoBackend` adapters.
- Full Wycheproof edge-case run (including ML-KEM vectors once their exact
  path/depth is confirmed, gap #8) against both adapters.
- Manual/documented review step: re-confirm whether `aws-lc-rs` publishes
  any Android/iOS build/CT guidance (gap #9) and whether upstream
  `mlkem-native`/AWS-LC have added Android-NDK or iOS-toolchain CI jobs
  since this research was written — **upstream proofs do not currently
  cover our actual shipping targets, so this must be re-checked before every
  release, not assumed stable.**
- If resourced: an actual on-device timing/CT smoke test on representative
  Android (arm64-v8a) and iOS (arm64) hardware for the X-Wing
  encapsulate/decapsulate hot path, since none of the surveyed tools
  (Valgrind, Microwalk, dudect) run against real mobile-target binaries —
  this is the one gap no existing tool closes, and would need bespoke
  harness work outside anything found in this research pass.
- X-Wing conformance cross-check against at least two independent
  implementations (e.g. BoringSSL's `xwing.h` and Cloudflare CIRCL) since
  the draft itself ships no vectors and RustCrypto's crate lags the spec
  version and is unaudited.

---

## Explicit list of UNVERIFIED items (follow-up needed before this gates a release)

1. dudect-bencher/mlkem-native-style dudect adoption in RustCrypto/dalek-cryptography
   repos — not found in the searches run; not exhaustively ruled out.
2. GH-hosted-runner noise/flakiness specifically for dudect-style statistical
   CT testing — no primary source addresses this; purely inferred risk.
3. `agl/ctgrind` current state — repo fetch failed ("can't perform that
   action"), could not confirm if archived/renamed/removed.
4. BINSEC/Rel's actual ARM support and CI-friendliness — only the top-level
   GitHub landing page was fetched; `INSTALL.md`/`doc/` not yet read.
5. "Pitchfork" as a CT tool — could not locate at the guessed URL (404);
   needs correct repo identification before citing it anywhere.
6. Exact NIST ACVP JSON directory names for AES-GCM, HMAC, and KDA/HKDF
   (only ML-KEM keyGen/encapDecap dirs were directly confirmed by search).
7. Existence of a maintained Rust ACVP client/harness crate — crates.io API
   query returned HTTP 403 in this sandbox; needs a different lookup method.
8. Wycheproof's exact ML-KEM test-vector file path/coverage depth under
   `testvectors_v1/` (README confirms the algorithm is listed, but the
   specific schema/vector file was not opened).
9. `aws-lc-rs`'s explicit Android/iOS cross-compilation support
   documentation (README excerpt fetched did not reach a
   platform-support/CI-matrix section).
10. AFL++'s architecture support — not fetched in this session at all.
11. Whether `cargo-careful` has an explicit, documented end-to-end
    Android/iOS cross-target workflow (plausible given real-codegen design,
    but not confirmed in the README).
12. Whether `aws/aws-lc` runs Valgrind/ctgrind internally outside the
    SAW/NSym formal-verification Docker environments — not confirmed in this
    pass.
