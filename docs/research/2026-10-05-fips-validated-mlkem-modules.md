# Research findings: FIPS-140-3-validated modules providing ML-KEM-768 for a mobile Rust core

Status: research draft, not an approved design. Supersedes §9.5 of
`2026-10-05-pqc-over-ble-findings.md` on the single point "FIPS 140-3: no
active certificate covering ML-KEM was confirmed. AWS-LC-FIPS v4.0 is 'in
process'." That statement is **out of date**: an *older* major version line
(AWS-LC 3.1.0, not v4.0) already carries an **Active** FIPS 140-3 certificate
that includes ML-KEM, and has since June 2026. The blocking gap is not
algorithm coverage, it's **operating environment (OE) coverage** — no
certificate found anywhere in CMVP's Active list, nor on the current Modules
In Process (MIP) list, combines ML-KEM with a tested or vendor-affirmed iOS or
Android OE. See §7 (Recommendation).

All data below was retrieved on **2026-10-05** directly from
`csrc.nist.gov` (CMVP certificate pages, the MIP list, and linked Security
Policy PDFs filed by each vendor), plus vendor GitHub/docs pages as noted.
CMVP certificate status, algorithm tables, and OE tables are living data and
can change at any time; re-verify before relying on this for a shipping
decision. Local working copies used to extract quotes are not part of this
repo; every citation below points at the canonical CSRC URL instead.

## 1. Summary table

| Candidate | Cert # | Status (2026-10-05) | Has ML-KEM? | Mobile OE (iOS/Android) tested? | Usable from Rust? |
|---|---|---|---|---|---|
| AWS-LC Cryptographic Module (dynamic) | 5429 | Active | No (AWS-LC FIPS 2.0.0) | No — Amazon Linux/Ubuntu EC2 only | Yes, via `aws-lc-rs`, but wrong module version |
| **AWS-LC 3 Cryptographic Module (static)** | **5314** | **Active** | **Yes** — ML-KEM-512/768/1024 (FIPS 203) | **No** — Amazon Linux 2023 on Graviton4/Xeon metal only | Yes, via `aws-lc-rs`/`aws-lc-sys` *in principle*, but not on a mobile OE covered by the cert |
| AWS-LC 4 / AWS-LC 5 Cryptographic Module | — | **In Process** (MIP) | Unverified (not yet published) | Unverified | N/A until validated |
| BoringCrypto (Google, LLC) | 5104 | Active | No | No — Google-internal "Prodimage" Linux datacenter OE only | Only via internal Google toolchains |
| BoringCrypto (Zebra Technologies) | 5358 | Active | No | **Android 14**, but one specific handheld device only | No — vendor-locked rebuild, not reusable |
| BoringCrypto (Samsung/Motorola) | 5530 / 5520 | Active | No | **Android 15** on Pixel 8 (Tensor G3) only | No — vendor-locked rebuild |
| CryptoComply BoringCrypto Module (SafeLogic) | 5264 | Active | No | **Android 13** on 5 Pixel devices (Tensor/Snapdragon), with/without PAA | Only via SafeLogic's commercial C library, not idiomatic Rust |
| **CryptoComply Module based on AWS-LC FIPS (SafeLogic)** | **5525** | **Active**, validated 2026-09-16 | **Yes** (inherits AWS-LC FIPS 3.1.0's ML-KEM) | **No** — same Amazon Linux 2023 EC2 OEs as 5314 | Only via SafeLogic's commercial wrapper |
| Apple corecrypto Module 18.3 [Apple silicon, Kernel, SW, SL1] | 5387 | Active | No | iOS/iPadOS **18**, real devices (iPhone 11 Pro Max–iPad mini 7th gen) | No — not exposed to third-party Rust code at all (kernel-space) |
| Apple corecrypto Module 18.3 [Apple silicon, User, SW, SL1] | 5184 | Active | No | iOS/iPadOS 18, same device family | No direct Rust binding; only reachable via CryptoKit/Swift, and CryptoKit's ML-KEM/X-Wing API is **outside this boundary anyway** |
| Apple corecrypto Module OS 26 [Kernel/User] | — | **In Process** (Review / Pending Review) | **Unverified** — not yet published | Unverified | N/A until validated |
| OpenSSL FIPS Provider (generic/reference) | 4985 | Active | No (v3.1.2, predates OpenSSL 3.5's PQC support) | No | Yes via `openssl-sys`, but wrong version |
| OpenSSL FIPS Provider (The OpenSSL Corporation, 3.5-line) | — | **In Process** ("Comment Resolution - Lab", 2026-09-21) | Unverified | Unverified | N/A until validated |
| Oracle Linux 9 OpenSSL FIPS Provider / Red Hat Enterprise Linux 9 - OpenSSL FIPS Provider | multiple | Active (older) / In Process (RHEL9 resubmission) | No confirmed ML-KEM in any Active cert found | No — RHEL/OL server only | N/A for mobile |
| wolfCrypt (wolfSSL Inc.) | 4718 | Active, v5.2.1 | No | **Android 13** on Samsung Galaxy XCover Pro (Exynos 9611) | Yes via the `wolfssl`/`wolfcrypt-sys` Rust crates, wrong (non-PQC) module version |
| wolfCrypt (older, desktop-only) | 5041 | Active | No | No | N/A |
| wolfCrypt next-gen resubmission | — | **In Process** ("Pending Resubmission", 2026-04-16) | Unverified; wolfSSL markets PQC as a **separate, non-FIPS** product line today | Unverified | N/A until validated |
| Microsoft SymCrypt Cryptographic Library | 5313 | Active | No | No — Windows/Azure Linux server OEs only | No — not a mobile-targeted module |
| BC-FJA (Bouncy Castle FIPS Java API), multiple vendor rebuilds | 4943, 5612, 5900, 6485, 6854 etc. | Active (various) | No ML-KEM confirmed in checked certs | No mobile OS OE found (Linux/CentOS/RHEL JVM hosts) | No — Java API, not natively embeddable in a Rust core |
| Bouncy Castle BC-FJA/BC-FNA (newer submissions) | — | Various **In Process** states | Unverified | Unverified | N/A |
| PQShield PQCryptoLib-Core | — | **In Process** ("Comment Resolution - Lab") for FIPS 140-3; vendor claims a **separate CAVP** certification (algorithm-only, not module) for ML-KEM/ML-DSA/SHA-3/SHAKE | Vendor-claimed, CAVP-only so far | Vendor markets "maximum portability... enterprise servers, cloud, desktop, network devices" — **no mobile OS claim found** | Unverified, proprietary C library |
| Code Siren "Post-Quantum Cryptographic (PQC) Library for Mobile" | — | **In Process** ("Comment Resolution - Lab") | Unverified — no public Security Policy yet | Explicitly mobile-targeted by name, but no technical detail found on vendor's public site | **UNVERIFIED** |
| SafeLogic CryptoComply 140-3 FIPS Provider with PQC | — | **In Process** ("Comment Resolution - Lab") | Unverified (name suggests PQC, not yet confirmed which algorithms) | Unverified | N/A until validated |

Legend: **Active** = CMVP-issued certificate currently valid; **In
Process** = on the MIP list, not yet issued a certificate number;
**UNVERIFIED** = no primary source located to confirm or deny the claim.

## 2. AWS-LC-FIPS (`aws-lc-rs` / `aws-lc-sys`)

### 2.1 AWS-LC Cryptographic Module (dynamic) — cert 5429

- **Status / dates.** Active. Validated 2026-07-20. Sunset 2026-08-13 — wait,
  sunset date as shown on the certificate page is **8/13/2029** (five-year
  sunset from the FIPS 140-3 validation window), not 2026.
  Source: `https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/5429`
  (retrieved 2026-10-05): page shows "Status: Active", "Sunset Date:
  8/13/2029".
- **Module/version.** "AWS-LC Cryptographic Module (dynamic)", software
  version **AWS-LC FIPS 2.0.0**, per the linked Security Policy:
  `https://csrc.nist.gov/CSRC/media/projects/cryptographic-module-validation-program/documents/security-policies/140sp5429.pdf`
  (retrieved 2026-10-05).
- **Algorithms.** Approved-algorithm table lists AES-CBC/CCM/CMAC/CTR/ECB/GCM/
  GMAC/KW/KWP, Counter DRBG, HMAC-SHA-1/SHA-2 family, KAS-ECC-SSC (P-224/256/
  384/521 only — **no X25519/Curve25519 Diffie-Hellman in the approved
  boundary**), KDA HKDF, KDF SSH/TLS, PBKDF, SHA-1/SHA-2 family. **No ML-KEM
  entry anywhere in the algorithm table** (grepped for "ML-KEM", "KEM",
  "203" — no match).
- **OEs.** Tested Operational Environments: Amazon Linux 2, Amazon Linux
  2023, Ubuntu 22.04, all on EC2 (Intel Xeon and AWS Graviton3) — **server
  Linux only, no Android/iOS entry**. Vendor-Affirmed OE table: explicitly
  "N/A for this module" in the PDF.
- **License.** AWS-LC is Apache-2.0 / ISC (dual, per upstream repo), but the
  FIPS-validated `bcm.o` binary object itself is only meaningful as the exact
  artifact filed with CMVP — recompiling from the open-source tree does not
  reproduce a "validated" binary (see §6).
- **Verdict for this candidate.** Correct FIPS algorithms, but **no ML-KEM**
  and **no mobile OE**. Not a path to ML-KEM-under-validation.

### 2.2 AWS-LC 3 Cryptographic Module (static) — cert 5314 **← key finding**

This is the certificate that **corrects** the prior doc's claim. It has been
Active since well before this retrieval date and already includes ML-KEM.

- **Status / dates.** Active. Validated 2026-06-05. Sunset **6/4/2031**.
  Source: `https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/5314`
  (retrieved 2026-10-05).
- **Module/version.** "AWS-LC 3 Cryptographic Module (static)", software
  version **AWS-LC FIPS 3.1.0**. Security Policy:
  `https://csrc.nist.gov/CSRC/media/projects/cryptographic-module-validation-program/documents/security-policies/140sp5314.pdf`
  (retrieved 2026-10-05).
- **Algorithms — ML-KEM confirmed.** The approved-algorithm table contains
  **ML-KEM EncapDecap and ML-KEM KeyGen, parameter sets ML-KEM-512/768/1024**,
  cited against **FIPS 203**. It also lists AES-256-GCM, SHA-3 (224/256/384/
  512), ECDSA (P-224/256/384/521), EdDSA (**Ed25519 for signatures only**),
  and KAS-ECC-SSC — but KAS-ECC-SSC is scoped to **NIST P-curves only**; the
  PDF's non-approved/"not allowed" list explicitly names plain
  Diffie-Hellman and secp256k1, and separately **HMAC-SHA-3 is listed as
  non-approved** even though SHA-3 itself is approved. **There is no X25519
  (Curve25519) ECDH anywhere in the approved boundary of this module** — only
  Ed25519 signatures are present, and only for EdDSA, not key agreement.
- **Module identity / integrity.** Per the Security Policy (quoted from the
  PDF, p. ~9 and the cryptographic-boundary section): "The cryptographic
  boundary is defined as the AWS-LC 3 Cryptographic Module (static) which is
  a cryptographic library consisting of the `bcm.o` file (version AWS-LC
  FIPS 3.1.0). This file is statically linked to the userspace application
  during the compilation process." and the approved self-tests table lists
  "HMAC-SHA2-256 ... Message Authentication ... Module becomes operational
  ... Integrity test for bcm.o" as a power-up self-test. This means the
  validated artifact is the specific compiled `bcm.o` object (identified by
  its HMAC-SHA2-256 digest), not "the AWS-LC source code in general" — see
  §6 for what this means for recompiling on Android/iOS.
- **OEs.** Tested Operational Environment's Physical Perimeter (TOEPP) is "the
  general-purpose computer on which the module is installed" — concretely,
  **Amazon Linux 2023** on **AWS Graviton4 (ARMv9-A)** and **Intel Xeon
  Platinum 8375C**, both as EC2 bare-metal instances. **No Android, no iOS, no
  other mobile CPU/OS combination appears in the tested-OE table**, and the
  Vendor-Affirmed OE table is again "N/A for this module" — i.e. there is
  currently no vendor-affirmed path from this certificate to any other
  platform, mobile or otherwise.
- **License.** AWS-LC upstream is Apache-2.0/ISC
  (`https://github.com/aws/aws-lc`, retrieved 2026-10-05, `LICENSE` file in
  repo root lists Apache License 2.0 and ISC, consistent with BoringSSL's
  dual licensing that AWS-LC forked from). The FIPS-validated binary itself
  is not separately licensed, but is only "the validated module" for the
  exact build described in the Security Policy.
- **Constant-time evidence.** Not found inside the Security Policy PDF itself
  (Security Policies document algorithm/OE/self-test scope, not
  implementation-level side-channel claims). AWS-LC's ML-KEM implementation is
  known upstream to use the formally verified `mlkem-native` / `ml-kem` Rust
  or C code with constant-time proofs (per the prior sibling doc's §9.5,
  citing CBMC/HOL-Light proofs on the assembly) — but that claim is about
  AWS-LC's **source tree** in general, not specifically re-verified here
  against the exact `bcm.o` filed under cert 5314. Treat the "constant-time"
  claim for this specific certified binary as **UNVERIFIED** pending a direct
  code/audit citation tied to this cert number.
- **Rust usability.** `aws-lc-rs` (the Rust binding) exposes a `fips` Cargo
  feature, and its upstream repository is `https://github.com/aws/aws-lc-rs`.
  **UNVERIFIED**: I was not able to independently confirm from
  `aws/aws-lc-rs`'s own docs during this pass (time-boxed) whether enabling
  `fips` while cross-compiling for `aarch64-apple-ios` or
  `aarch64-linux-android`/`x86_64-linux-android` targets (a) successfully
  builds at all, and (b) if it builds, whether the resulting object is the
  bit-identical validated `bcm.o` or merely AWS-LC's FIPS-mode *source*
  recompiled for an untested OE (which would not be a validated module per
  §6). This is a concrete, bounded follow-up: inspect `aws-lc-rs`'s
  `aws-lc-fips-sys` build script and its stated supported-target list before
  treating "aws-lc-rs with fips feature" as equivalent to "shipping a
  validated module" on mobile.

### 2.3 AWS-LC 4 / AWS-LC 5 Cryptographic Module — MIP list, not yet Active

- Source: CMVP Modules In Process list,
  `https://csrc.nist.gov/projects/cryptographic-module-validation-program/modules-in-process/modules-in-process-list`
  (retrieved 2026-10-05; list self-reports "Last Updated: 10/5/2026"). Entries
  found: "AWS-LC 4 Cryptographic Module" (dynamic and static variants) at
  **Comment Resolution - CMVP**, and "AWS-LC 5 Cryptographic Module" (dynamic
  and static) at **Pending Review**, dated 10/5/2026 (i.e., submitted the same
  day as this retrieval — effectively brand new).
- **No algorithm or OE detail is public for In Process entries** — the MIP
  list gives only vendor, module name, and status/stage, not an algorithm or
  OE table (those are only published once a certificate issues). Any claim
  about what AWS-LC 4/5 will contain, including whether they add mobile OEs,
  is **UNVERIFIED** speculation and is not asserted here.

## 3. BoringCrypto / BoringSSL (Google)

There is no single "BoringCrypto certificate" — multiple vendors
independently submit their own compiled builds of the same BoringCrypto
source for validation against their own specific hardware/OS combination.
Certificates checked:

- **Cert 5104**, "BoringCrypto" (vendor: Google, LLC). Active. Software
  version **20240407**. Source:
  `https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/5104`
  and linked Security Policy (retrieved 2026-10-05). **No ML-KEM** in the
  algorithm table. OEs: Google-internal "Prodimage" Linux builds on AMD EPYC
  and ARM Neoverse-N1 — **datacenter servers only, no Android, no iOS**.
- **Cert 5358**, "BoringCrypto" (vendor: **Zebra Technologies Corporation**,
  not Google). Active, validated 2026-06-29 (updated 2026-08-27 and
  2026-09-02), sunset date per cert page is listed independently per vendor
  rebuild. Software version **2023042800**. **No ML-KEM.** Tested OE:
  **Android 14** on a Zebra TC58E handheld device (Qualcomm QCM4490) — a real,
  confirmed Android OE for a BoringCrypto rebuild, but vendor- and
  device-specific; this certificate cannot be cited by a third party shipping
  a different Android app.
- **Certs 5530 / 5520**, "BoringCrypto" (vendor: Samsung / Motorola). Active.
  Software version **20240805**. OEs: Google Pixel 8 (Google Tensor G3,
  64-bit) running **Android 15**. **No ML-KEM.**
- **Cert 5264**, "CryptoComply BoringCrypto Module" (vendor: **SafeLogic**,
  rebuild of BoringCrypto, not AWS-LC). Active, sunset **7/22/2029**. Security
  Policy (`140sp5264.pdf`, retrieved 2026-10-05) lists a "Building for
  Android" section (§11.1.1) and a tested-OE table with **5 Android 13**
  device/CPU combinations (Google Pixel 7 Pro / Tensor G2, Pixel 6 Pro /
  Tensor, Pixel 5a / Snapdragon 765, Pixel 4a / Snapdragon 730, Pixel 4 XL /
  Snapdragon 855), each tested both "With PAA" and "Without PAA" (i.e. with
  and without ARM crypto extensions). **No ML-KEM anywhere in this Security
  Policy.** This is the most convincing *precedent* that a BoringCrypto-based
  module can be FIPS-validated across a real, multi-device Android OE matrix
  — it simply does not yet carry ML-KEM.
- **MIP list**: three separate "BoringCrypto (Google, LLC)" submissions, all
  at **Comment Resolution - Lab** stage, plus a distinct "Android Kernel
  Cryptographic Module (Google, LLC)" at **Pending Review**. No algorithm/OE
  detail is public yet for any of these; whether any of them add ML-KEM or
  new mobile OEs is **UNVERIFIED**.
- **Rust usability.** BoringSSL/BoringCrypto is C/C++; Rust access would be
  via `bssl-sys`/similar FFI bindings (not independently investigated in this
  pass — **UNVERIFIED** whether any such binding is actively maintained for
  the specific validated BoringCrypto module versions above, as opposed to
  upstream-`HEAD` BoringSSL, which is explicitly *not* FIPS-validated per
  Google's own BoringSSL README guidance that only tagged FIPS snapshots are
  submitted for validation).

## 4. Apple corecrypto (behind CryptoKit)

- **Cert 5387**, "Apple corecrypto Module 18.3 [Apple silicon, Kernel,
  Software, SL1]". Active, sunset **7/8/2031**. Source:
  `https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/5387`
  (retrieved 2026-10-05). Tested OEs are **real Apple hardware**: iPhone 11
  Pro Max, iPhone 12, iPad (9th generation), iPad Air (4th generation), iPad
  mini (6th and 7th generation), all running **iOS/iPadOS 18**, specifically
  build **18.3**. **No ML-KEM or X-Wing entry anywhere in the algorithm
  table** (grepped the Security Policy PDF for "ML-KEM"/"X-Wing"/"Kyber" —
  zero matches).
- **Cert 5184**, "Apple corecrypto Module 18.3 [Apple silicon, User,
  Software, SL1]". Active, sunset **3/10/2031**. Same iOS/iPadOS 18.3 OE
  family. Same result: no ML-KEM/X-Wing.
- **Apple corecrypto Module OS 26** — two entries on the MIP list: "[Apple
  silicon, Kernel/User, Software, SL1]" at **Review** (dated 7/30–7/31/2026
  on the MIP list) and "[Apple Silicon, Secure Key Store, Hardware,
  SL2/PHY3]" at **Pending Review**. Source: MIP list, same URL as §2.3,
  retrieved 2026-10-05. **This is the corecrypto line that would align
  version-wise with iOS/macOS 26, where CryptoKit's `MLKEM768` and
  `XWingMLKEM768X25519` APIs are documented as available** (per the prior
  sibling doc's §9.5). Because this cert has **not yet been issued**, there
  is currently **no primary-source confirmation that ML-KEM/X-Wing will even
  be inside the validated corecrypto boundary** once it completes — CryptoKit
  exposing an API is not proof that the underlying implementation sits inside
  the FIPS-validated cryptographic boundary (Apple has historically kept some
  CryptoKit primitives, e.g. Curve25519 variants in some versions, formally
  outside the corecrypto FIPS boundary even while the API was public). This
  is marked **UNVERIFIED** until the OS 26 certificate is issued and its
  algorithm table is published.
- **Apple's own certifications page.** I attempted
  `https://support.apple.com/guide/certifications/` during this research
  pass; it returned a generic landing page without an actionable per-module
  statement I could pin to a specific corecrypto version or algorithm list.
  Any claim about Apple's official (non-CMVP) public positioning on
  ML-KEM/X-Wing FIPS status beyond what the CMVP certificate itself states is
  **UNVERIFIED**.
- **Rust usability.** corecrypto (kernel-space cert 5387) is not reachable
  from third-party app code at all. corecrypto (user-space cert 5184) is only
  reachable indirectly via Apple's Swift/Objective-C frameworks (e.g.
  CryptoKit, Security framework); there is no supported C/Rust FFI directly
  into the validated corecrypto boundary. Even if OS 26's corecrypto cert
  eventually includes ML-KEM, a Rust core would have to call into CryptoKit
  via a Swift shim, not link the validated module directly — a materially
  different "embedding" story than linking a C library from Rust.

## 5. OpenSSL 3.5 FIPS provider

- **Cert 4985**, generic "OpenSSL FIPS Provider" (the reference validation
  many downstream vendors rebuild from). Software version **3.1.2** — this
  predates OpenSSL 3.5.0 (released 2025-04-08 per OpenSSL's own release
  notes), which is the first OpenSSL release to add ML-KEM/ML-DSA/SLH-DSA
  support. **No ML-KEM anywhere in this certificate's algorithm table**, by
  construction (the validated source is older than PQC support).
- **OpenSSL 3.5.0 release notes**, `https://openssl-library.org/news/`
  (retrieved earlier in this research session): confirms "Support for PQC
  algorithms (ML-KEM, ML-DSA and SLH-DSA)" was added to the **default**
  provider, and that TLS keyshares now prefer `X25519MLKEM768` by default.
  This is a statement about the *default* provider's feature set, not a
  statement about FIPS-provider scope — OpenSSL's own `README-FIPS.md`
  (`https://github.com/openssl/openssl/blob/master/README-FIPS.md`, fetched
  earlier) states the general rule that the FIPS provider can only be built
  from specific source versions that have completed CMVP validation; a
  newer OpenSSL release's algorithms are not automatically "in the FIPS
  provider" just because they exist in the same repo.
- **MIP list**: "OpenSSL FIPS Provider" filed by **"The OpenSSL
  Corporation"** itself (as distinct from the generic/vendor-rebuilt
  cert 4985 lineage) is at **Comment Resolution - Lab**, dated 2026-09-21.
  This is presumably the first OpenSSL-project-controlled FIPS submission
  built from a 3.5-line (PQC-capable) source tree, but **this is
  UNVERIFIED** — the MIP list gives no algorithm detail, and I found no
  public statement from the OpenSSL project confirming ML-KEM is inside this
  specific pending FIPS-provider boundary (as opposed to only the default
  provider).
- Also on MIP: "Red Hat Enterprise Linux 9 - OpenSSL FIPS Provider" at
  **Comment Resolution - CMVP**, and "Oracle OpenSSL FIPS Provider" at
  **Comment Resolution - Lab** — both downstream rebuilds, both unverified
  for ML-KEM content, both (by nature of RHEL/Oracle Linux) **server-only,
  not mobile-relevant** even once validated.
- **Rust usability.** `openssl-sys`/`openssl` crates bind to OpenSSL's C API
  and can select the FIPS provider at runtime if present; cross-compiling
  OpenSSL (and specifically its FIPS provider object) for iOS/Android is
  possible in principle but is a known source of friction (OpenSSL's FIPS
  module requires its own build-time self-test/provenance steps per
  `README-FIPS.md`) and, as above, there is currently **no Active FIPS
  provider certificate with ML-KEM to even attempt this with**.

## 6. wolfCrypt FIPS (wolfSSL)

- **Cert 4718**, "wolfCrypt" (vendor: wolfSSL Inc.). Active, sunset
  **7/10/2029**, software version **v5.2.1**. Source:
  `https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718`
  and Security Policy (retrieved 2026-10-05). OEs include several
  Linux/Windows desktop/server combinations, and notably **Android 13** on a
  **Samsung Galaxy XCover Pro (Exynos 9611, no PAA)** — confirming wolfCrypt
  has at least one genuine validated Android OE. **No ML-KEM** in this
  certificate's algorithm table.
- **Cert 5041**, older "wolfCrypt" cert. Active, but OEs are Linux/Windows
  desktop hardware only, no mobile relevance; superseded for this purpose by
  cert 4718.
- **MIP list**: "wolfCrypt (wolfSSL Inc.)" at **Pending Resubmission**, dated
  2026-04-16 — presumably wolfSSL's next validated module line, status/
  algorithm content not public.
- **Vendor's own FIPS page**, `https://www.wolfssl.com/license/fips/`
  (retrieved 2026-10-05): states "wolfSSL has defined the wolfCrypt FIPS
  boundary specifically around a subset of the wolfCrypt algorithms... For
  post-quantum security, wolfSSL has you covered with a reliable, adaptable
  codebase to keep you ready for future cryptographic standards. [Learn
  more]" — the "Learn more" link goes to
  `https://www.wolfssl.com/products/wolfcrypt-post-quantum/`, a page that
  only lists **non-FIPS product integrations** (wolfMQTT, wolfBoot, wolfSSH,
  wolfHSM, curl, Apache, Lighttpd, Nginx, Stunnel, STM32CubeIDE, NXP). This is
  a direct vendor admission, as of this retrieval, that **wolfCrypt's current
  post-quantum support is a separate, non-FIPS-validated product line**,
  consistent with the Active certificate's lack of ML-KEM and the "Pending
  Resubmission" MIP status for whatever comes next.
- **Rust usability.** The `wolfssl`/`wolfcrypt-sys` Rust crates bind
  wolfCrypt's C API and could plausibly link the validated FIPS object
  on Android (precedent exists per cert 4718's Android 13 OE) — but again,
  the currently validated version has no ML-KEM.

## 7. Android Conscrypt / BoringSSL on Android

- Android's system TLS stack (Conscrypt) is backed by BoringSSL, but I found
  **no CMVP certificate specifically named "Conscrypt"** in the active-list
  dump checked during this research pass. The closest primary-source
  confirmations of BoringCrypto-on-Android validation are the **device/vendor
  -specific** certs already covered in §3 (Zebra TC58E/Android 14, Samsung/
  Motorola Pixel 8/Android 15, SafeLogic's Pixel-device matrix/Android 13) —
  none of which is a generic "any Android device" certificate, and none of
  which has ML-KEM.
- **Google Play system updates / Project Mainline** relationship to any FIPS
  claim: **UNVERIFIED**. I did not find a primary CMVP or Google source
  during this pass tying Conscrypt's Mainline-module updatability to a
  specific, currently-Active FIPS certificate that a third-party app could
  cite. Treat any claim that "Android ships a reusable, generically-citable
  FIPS-validated BoringSSL for all apps" as unconfirmed.

## 8. Other candidates noted for completeness

- **Microsoft SymCrypt Cryptographic Library**, cert **5313**. Active.
  Security Policy (`140sp5313.pdf`, retrieved 2026-10-05) lists OEs as
  Windows and **Azure Linux** virtual machines/servers (Intel Xeon, Azure
  `Standard_D4ps_v5` ARM instances) — **no ML-KEM, no mobile OS**. Not
  realistically embeddable in an Android/iOS Rust core; noted only for
  completeness per the task's explicit mention.
- **Oracle** (beyond the OpenSSL-FIPS-provider rebuilds already covered):
  Oracle Linux 9 NSS, GnuTLS, libgcrypt, and Kernel Crypto API modules all
  appear on the active list — all server/OS-kernel-oriented, no ML-KEM
  confirmed, no mobile relevance.
- **Cisco**: multiple active certs (CiscoSSL FIPS Provider, Cisco FIPS
  Provider 3.1.2 based on the OpenSSL FIPS Provider, Cisco ASA/Firepower
  modules, Cisco FIPS Object Module, Cisco Go Cryptographic Module based on
  the Geomys Go Cryptographic Module) — all are network-appliance or
  server-targeted; none reviewed showed ML-KEM, none is mobile-relevant.
- **Red Hat** (beyond OpenSSL rebuilds): RHEL 8/9 NSS, Kernel Cryptographic
  API, libgcrypt, gnutls modules — all RHEL-server-targeted, no ML-KEM
  confirmed, no mobile relevance.
- **Bouncy Castle (BC-FJA / BC-FNA)**: multiple active certs under different
  vendor names (plain "BC-FJA", VMware's BC-FJA, Keysight's BC-FJA for
  Network Visibility), cert **4943** checked directly — Security Policy
  (`140sp4943.pdf`, retrieved 2026-10-05) shows OEs as **Linux/CentOS/RHEL
  JVM hosts only**, no ML-KEM found in the sections grepped, and **no mobile
  OS OE**. Bouncy Castle is also fundamentally a **Java API** (BC-FJA = "FIPS
  Java API"); even where a cert exists it is not natively embeddable in a
  Rust core without a JVM bridge, which is a poor fit for this project's
  architecture regardless of algorithm/OE status. Newer Bouncy Castle
  submissions are present on the MIP list in various In-Process states;
  none was confirmed to add ML-KEM or mobile OEs during this pass
  (**UNVERIFIED**).
- **PQShield PQCryptoLib-Core**: on the MIP list at **Comment Resolution -
  Lab** for FIPS 140-3. Separately, PQShield's own site states (retrieved
  2026-10-05, `https://pqshield.com/pqcryptolib-core-3-5-1-achieves-cavp-certification/`):
  "PQCryptoLib-Core v3.5.1 has officially achieved NIST CAVP certification...
  covers a combination of classical and post-quantum algorithms including
  ML-KEM, ML-DSA, SHA-3 and SHAKE... PQCryptoLib-Core is a software solution
  built for maximum portability and high performance across different OS
  platforms, covering enterprise servers, cloud infrastructure, desktop
  engineering systems and network devices." Two important caveats: (1) **CAVP
  certification is algorithm-level testing only, not a module-level FIPS
  140-3 certificate** — the FIPS 140-3 module certificate (which is what
  "validated module" actually requires) is still In Process; (2) the vendor's
  own portability claim explicitly lists servers/cloud/desktop/network
  devices and **does not mention Android or iOS** — any mobile applicability
  is **UNVERIFIED**, not vendor-claimed.
- **Code Siren "Post-Quantum Cryptographic (PQC) Library for Mobile"**: on
  the MIP list at **Comment Resolution - Lab**, explicitly named for mobile.
  This is the single most on-point in-process candidate by name alone. I
  could not find a public product page, source repository, or Security
  Policy draft describing its algorithm scope, supported OS versions, or
  license during this pass (the vendor's public site,
  `https://codesiren.com`, retrieved 2026-10-05, shows only a product called
  "Polynom Enterprise" — a collaboration tool — with no visible PQC library
  documentation). **Everything about this candidate beyond its name and MIP
  status is UNVERIFIED.** Worth re-checking periodically as it progresses
  through CMVP review.
- **SafeLogic CryptoComply 140-3 FIPS Provider with PQC**: on the MIP list at
  **Comment Resolution - Lab**. Distinct from the already-Active cert 5525
  (CryptoComply based on AWS-LC FIPS, §2's inherited-ML-KEM module). Whether
  this is a different/newer submission with its own independent PQC
  algorithm set, and whether it targets mobile OEs, is **UNVERIFIED** —
  no algorithm/OE table is public pre-certification.

## 9. Implementation Guidance: operating environment, self-tests, and recompilation

- **The validated artifact is a specific compiled binary, not "the source
  code".** Every Security Policy inspected in this research (AWS-LC 3.1.0,
  AWS-LC 2.0.0, CryptoComply/AWS-LC, CryptoComply/BoringCrypto) defines the
  cryptographic boundary as a specific object file (e.g. `bcm.o`) identified
  by version string and protected by a power-up **software/firmware
  integrity test** — an HMAC-SHA2-256 digest computed over the object and
  compared against a value stored inside the module (quoted directly from
  cert 5314's Security Policy, §2.2 above: "Module becomes operational ...
  Integrity test for bcm.o"). This self-test is precisely the mechanism that
  makes "just recompile the same source for a different OS/architecture"
  **not** a validated configuration: a rebuild targeting
  `aarch64-apple-ios` or `aarch64-linux-android` produces a different
  compiled object (different compiler, different ABI, different linked
  libc), which will either (a) fail to match the embedded reference digest if
  naively copied from the x86_64/aarch64-Linux build, or (b) if rebuilt from
  scratch, produce a binary that was never submitted to a testing lab and
  therefore carries **no certificate number at all** — it is simply "code
  derived from a validated module", not "a validated module".
- **Tested Operational Environment (TOE) vs. Vendor-Affirmed OE.** FIPS 140-3
  Security Policies distinguish a "Tested Operational Environment's Physical
  Perimeter" (TOEPP) — the literal hardware/OS/compiler combination the lab
  exercised — from a (much rarer) "Vendor-Affirmed Operational Environment"
  table, where CMVP Implementation Guidance permits a vendor to *affirm*
  (without re-testing in a lab) that the module behaves identically on a
  closely related, untested platform. For every ML-KEM-capable certificate
  checked in this research (5314, 5525), **the Vendor-Affirmed OE table is
  explicitly empty ("N/A for this module")** — meaning there is currently
  **no CMVP-recognized path, affirmed or tested, from any ML-KEM-capable
  certificate to any Android or iOS build.**
- **General-purpose-computer (GPC) porting rule.** The FIPS 140-3
  Implementation Guidance document (NIST CSRC,
  `https://csrc.nist.gov/csrc/media/Projects/cryptographic-module-validation-program/documents/fips%20140-3/FIPS%20140-3%20IG.pdf`,
  retrieved 2026-10-05) formalizes the "Software Cryptographic Module (SCM)"
  / "General-Purpose Computer (GPC)" relationship in its Operational
  Environment section (IG terms "GPC: General Purpose Computer" and "A
  Software Cryptographic Module (SCM) requires the use of an underlying
  General-Purpose Computer (GPC)..."). In practice, and consistent with every
  Security Policy inspected, CMVP's working model is that a software
  module's validation is tied to its tested OE class; mobile ARM64 Android
  and iOS environments are architecturally and OS-wise distinct enough from
  the tested Amazon-Linux-on-EC2 or Windows/Azure-Linux environments found in
  every certificate above that none of them currently qualifies as "the same
  OE" by inspection, and none has been affirmed as equivalent by any vendor
  in the certificates checked. **I was not able to locate, within the time
  budget of this research pass, the single specific IG paragraph number
  (equivalent to the old FIPS 140-2 IG G.5 "porting" rule) that most
  precisely states the mobile-porting test; this specific citation is
  therefore marked UNVERIFIED pending a closer reading of the ~250-page IG
  document.** The operational conclusion — "no current cert covers
  Android/iOS, tested or affirmed, for any ML-KEM module" — is independently
  confirmed from every Security Policy's own OE tables regardless of the
  exact IG citation.
- **Self-tests required to legitimately claim "uses a validated module."**
  Every Security Policy inspected lists both **power-up self-tests**
  (cryptographic algorithm self-tests (CASTs) plus the module integrity/HMAC
  test, run automatically before any operation) and **conditional
  self-tests** (e.g. pairwise consistency tests on key generation, continuous
  DRBG health tests) that must execute and pass, unmodified, every time the
  module initializes, as a condition of being "in the Approved mode of
  operation" — a configuration that itself typically requires specific
  vendor-documented API calls or build flags (e.g. AWS-LC's FIPS build mode,
  wolfCrypt's default self-test entry point mentioned on wolfSSL's own FIPS
  page: "We implemented a default entry point to run self-tests
  automatically... compliant with FIPS 140-3 Implementation Guidance 9.10").
  Simply linking a FIPS-capable library without invoking/confirming these
  self-tests, or building with different compiler flags than the validated
  configuration, forfeits any legitimate "validated module" claim even if the
  resulting binary is functionally correct.

## 10. Recommendation

Given the project's backend/crypto-provider seam (Constitution-level decision:
"FIPS" = FIPS-approved algorithms now, CMVP-validated module later, behind a
swappable backend):

1. **No candidate today supports "validated module" on both iOS and Android
   from a Rust core.** Every certificate that includes ML-KEM (AWS-LC 3
   static, cert 5314; SafeLogic CryptoComply/AWS-LC, cert 5525) is tested
   exclusively on **Amazon Linux 2023 server EC2 instances**, with no
   mobile OE, tested or vendor-affirmed. Every certificate that has a real,
   confirmed mobile OE (BoringCrypto on Android — Zebra/Samsung/Motorola/
   SafeLogic rebuilds; wolfCrypt on Android; Apple corecrypto on iOS) has
   **no ML-KEM**. There is currently **zero overlap** between "has ML-KEM"
   and "has a mobile OE" in CMVP's Active list.
2. **The near-term blocking gap is OE coverage, not algorithm support.**
   This is the main correction to the prior doc's framing: it's not that
   "FIPS doesn't have ML-KEM yet" (it does, and has since mid-2026 per cert
   5314) — it's that **no vendor has yet paid to re-validate an
   ML-KEM-capable module specifically on Android/iOS hardware**. This could
   change at any time (e.g. if Apple's OS 26 corecrypto submission completes
   and includes ML-KEM, or if AWS-LC 4/5 add a mobile-affirmed OE, or if
   Code Siren's mobile-named PQC library or PQShield's PQCryptoLib-Core
   complete FIPS 140-3 validation) — this doc should be re-checked against
   live CMVP data periodically, not treated as a one-time answer.
3. **Most realistic eventual path, in order of plausibility:**
   - **Apple corecrypto OS 26** (In Process) is the single candidate most
     likely to eventually combine ML-KEM with a genuine iOS OE, simply
     because Apple already ships CryptoKit's `MLKEM768`/`XWingMLKEM768X25519`
     APIs on that OS version and already has a strong, multi-cycle track
     record of validating corecrypto on real iPhone/iPad hardware (certs
     5387, 5184). But (a) this is currently unverified speculation about
     cert *content* until the cert issues, (b) even if it issues with
     ML-KEM, Rust can only reach it through a Swift/CryptoKit shim, not
     direct FFI, which complicates the "Rust core" architecture, and (c) it
     only solves iOS, not Android.
   - **AWS-LC 4/5** (In Process) or a future AWS-LC re-submission that adds a
     mobile-affirmed OE is the most plausible path for **Android**, given
     AWS-LC 3.1.0 already has ML-KEM and `aws-lc-rs` is a maintained,
     idiomatic Rust binding — but as of this retrieval there is no
     indication (confirmed or rumored from a primary source) that AWS-LC's
     FIPS line is being extended to mobile OEs; this is purely an
     architectural "closest fit" observation, not evidence of a roadmap.
   - **Code Siren's "PQC Library for Mobile"** is the only MIP entry
     explicitly targeting mobile by name, but is currently a near-total
     information void (no public docs, no Security Policy draft found); it
     should be tracked but not relied upon.
   - **wolfCrypt's PQC resubmission** (Pending Resubmission on MIP) is worth
     tracking given wolfCrypt's precedent of real Android OEs (cert 4718),
     but wolfSSL's own marketing currently and explicitly separates "FIPS"
     from "post-quantum" as different product lines, suggesting this is not
     imminent.
4. **Honest interim claim supportable today:** the project can truthfully say
   it **uses FIPS-approved algorithms** (ML-KEM-768 per FIPS 203, AES-256-GCM,
   HKDF/HMAC-SHA-2 per SP 800-56C/SP 800-108, SHA-2/3) implemented via
   audited, constant-time open-source libraries, consistent with the
   Constitution's decision wording. It **cannot** today truthfully claim to
   use "a FIPS 140-3 validated cryptographic module" for the mobile Rust
   core, on either platform, because:
   - No Active certificate anywhere in CMVP's list combines ML-KEM with an
     Android or iOS tested/affirmed OE.
   - Even the X25519 half of the project's ML-KEM-768 + X25519 hybrid has no
     home inside the one ML-KEM-capable certificate found (cert 5314 has no
     X25519 in its approved boundary at all) — so a literal "validated
     module for the whole hybrid" claim is unreachable even hypothetically
     with today's certificates, regardless of OE.
   - The backend-seam design is exactly the right mitigation for this: keep
     the crypto-provider interface swappable now, and revisit this document
     when (a) Apple's OS 26 corecrypto cert issues, (b) AWS-LC's MIP
     submissions resolve, or (c) either mobile-named In-Process module
     (Code Siren, PQShield, SafeLogic's "with PQC" FIPS provider) reaches
     Active status — whichever happens first will most likely determine
     the actual migration path.
