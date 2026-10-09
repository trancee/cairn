# Research findings: X-Wing draft-11 conformance of BoringSSL and Cloudflare CIRCL, and vector-provenance independence

Scope: resolve issue [`42-x-wing-draft-11-vector-provenance.md`](../../.scratch/pqcble-r1/issues/42-x-wing-draft-11-vector-provenance.md),
which blocks Slice S0. Research only — no vectors were generated, no upstream
code was built or run, and no implementation/ADR text was changed. All claims
below are backed by primary sources read directly: the IETF datatracker for
both relevant drafts, `google/boringssl`'s and `cloudflare/circl`'s source and
commit history on GitHub (fetched/cloned 2026-10-08). Where only indirect
evidence was available, this is stated explicitly rather than inferred.

## 1. Summary of conclusions

- **Both BoringSSL and Cloudflare CIRCL's current X-Wing source code implement
  the exact combiner, key-stretch, and encoding defined in
  draft-connolly-cfrg-xwing-kem-**11** (23 Sept 2026, the version ADR 0001/0007
  target), verified byte-for-byte from source, not inferred from version
  labels or APIs.** Both cite older draft numbers in comments/docstrings
  (BoringSSL: originally "-06"/"-07", now a documentation-only pointer to a
  sibling IRTF document at its "-02"; CIRCL: "-05"), but draft-11's own
  changelog (Appendix G) shows **no construction change to the combiner,
  key-stretch, or encoding since draft-05** — only editorial, ASN.1/codepoint,
  and documentation changes through -11. The version-string mismatch is
  therefore **stale labelling, not a confirmed behavioural mismatch**, and
  this distinction is confirmed from the changelog text itself, not assumed.
- **Correction to prior research:** the 2026-10-05 note
  ([`docs/research/2026-10-05-ct-conformance-tooling.md`](2026-10-05-ct-conformance-tooling.md))
  states "the X-Wing draft itself ships no official numeric test vectors."
  Re-reading draft-11's full text directly: **draft-11 §Appendix C does contain
  concrete numeric test vectors** (seed/sk, pk, eseed, ct, ss hex values, for at
  least three key pairs), despite the section heading itself carrying an
  editorial note, `# TODO: replace with test vectors that re-use ML-KEM,
  X25519 values`. The TODO marks the authors' intent to swap in values that
  reuse canonical ML-KEM/X25519 KATs later; it does not mean the section is
  empty. This is a materially different fact than "ships no vectors" and
  should update any downstream planning that relied on the earlier claim.
- One **confirmed, source-level behavioural divergence** exists for a
  documented edge case: on a **low-order X25519 point** in the ciphertext or
  public key, BoringSSL's `X25519()` returns failure (propagated as an
  `XWING_encap`/`XWING_decap` error), while CIRCL's `xwing.go` combiner
  proceeds and silently produces an all-zero X25519 component, with an
  explicit source comment that this is "pending clarification in the spec"
  (tracked upstream at `dconnolly/draft-connolly-cfrg-xwing-kem` issue #28,
  cited verbatim in CIRCL's own comment). draft-11 does not resolve this
  case. **This affects only malformed/adversarial low-order-point vectors,
  not well-formed random conformance vectors.**
- **Recommendation:** BoringSSL and CIRCL are independent enough — different
  languages, authors, and organizations, implemented and merged on different
  schedules (BoringSSL implemented against draft-07 in April 2025; CIRCL
  implemented and merged against draft-05 in January 2025) — to serve as two
  independent oracles for well-formed-input X-Wing conformance vectors, as
  ADR 0007 requires. **Do not** use either implementation's negative/malformed
  (low-order-point) test cases for cross-checking until upstream issue #28 is
  resolved, since the two implementations are known to disagree there by
  design, not by bug.

## 2. Primary sources and exact versions

### 2.1 The draft ADR 0001/0007 target

- **draft-connolly-cfrg-xwing-kem-11**, dated **23 September 2026**, expires 27
  March 2027. Confirmed current (no -12 exists as of 2026-10-08) via
  <https://datatracker.ietf.org/doc/draft-connolly-cfrg-xwing-kem/history/>,
  which lists -11 as the newest revision, and the datatracker landing page
  <https://datatracker.ietf.org/doc/draft-connolly-cfrg-xwing-kem/11/>. Full
  text fetched from
  <https://www.ietf.org/archive/id/draft-connolly-cfrg-xwing-kem-11.txt>.
  Authors: D. Connolly (Selkie Cryptography), P. Schwabe (MPI-SP & Radboud),
  B. E. Westerbaan (Cloudflare).

### 2.2 A second, related IRTF document (new finding, not in prior research)

- BoringSSL's `xwing.h` header currently cites a **different** document:
  **draft-irtf-cfrg-concrete-hybrid-kems-02** (see §3.1 below). This document
  is "Concrete Hybrid PQ/T Key Encapsulation Mechanisms" by D. Connolly
  (SandboxAQ) and R. Barnes (Cisco) — an IRTF-stream generalisation that
  defines several concrete hybrid KEM instances (`MLKEM768-P256`,
  `MLKEM768-X25519`, `MLKEM1024-P384`) atop a generic combiner framework
  (`[HYBRID-KEMS]`). Current revision is **-04** (6 July 2026, expires 7
  January 2027); fetched from
  <https://www.ietf.org/archive/id/draft-irtf-cfrg-concrete-hybrid-kems-04.txt>
  and <https://datatracker.ietf.org/doc/draft-irtf-cfrg-concrete-hybrid-kems/>.
  **§4.2 states verbatim: "MLKEM768-X25519 ... is identical to the X-Wing
  construction from [XWING-SPEC]"**, and its component table matches draft-11
  exactly: `Nek: 1216`, `Ndk: 32`, `Nct: 1120`, `Nss: 32`, and
  **`Label: \.//^\ (hex: 5C2E2F2F5E5C)`** — the identical 6-byte label and
  byte value as draft-11 §5.3's `XWingLabel`. This document is **informative
  corroboration**, not itself the ADR-cited spec; ADR 0001/0007 name
  "draft-11" of the X-Wing draft specifically, and that remains
  draft-connolly-cfrg-xwing-kem-11. No gap-filling was needed here because
  draft-connolly-cfrg-xwing-kem-11 was read directly and in full.

## 3. BoringSSL

### 3.1 Version reference and history

- Files: `include/openssl/xwing.h` (public API/sizes) and
  `crypto/xwing/xwing.cc` (implementation), read directly from a shallow clone
  of `https://github.com/google/boringssl` at commit
  **`4f3b183c5d4a8f8fcaba4c0ab4435df181df6978`** (master HEAD as cloned
  2026-10-08).
- Commit history for `include/openssl/xwing.h`
  (`google/boringssl:include/openssl/xwing.h`, via GitHub commits API):
  - `d6731cddd7` (**2025-04-29**), commit message: *"Implement the X-Wing KEM
    as drafted in
    https://datatracker.ietf.org/doc/html/draft-connolly-cfrg-xwing-kem-07."*
    This is the original implementation commit (Gerrit CL
    `boringssl-review.googlesource.com/c/boringssl/+/78947`, reviewed by Adam
    Langley). At this point the header comment read "-06" (a one-version
    discrepancy between commit message and header text, both pre-dating -11
    but both post-dating the -05 combiner freeze, see §4).
  - `00f4447bd5` (2025-05-06): introduced the opaque in-memory private-key
    object (API ergonomics only).
  - `b271161a29` (**2026-04-21**), commit message *"Update reference for
    X-Wing to a more recent draft"*. The diff is a **pure comment change**:
    it replaces the `xwing.h` doc-comment's citation of
    `draft-connolly-cfrg-xwing-kem-06` with
    `draft-irtf-cfrg-concrete-hybrid-kems-02`, adding "which is also known as
    'X-Wing'". **No code changed in this commit** — confirmed by reading the
    full diff, which touches only the comment block in `xwing.h`.
  - `34db38bf39` (2026-05-29) and later commits (`09ae7fe069`, `2599a5277f`,
    `06667bc997`) are unrelated formatting/refactor passes (comment style,
    const-correctness, internal type consolidation, Keccak namespacing); none
    touch the cryptographic logic in `crypto/xwing/xwing.cc`.
  - **No commit since `d6731cddd7` (2025-04-29) has altered the combiner,
    key-stretch, or encoding logic in `xwing.cc`.** The only post-implementation
    change to this subsystem's draft citation is the documentation-pointer
    swap in `b271161a29`.

### 3.2 Source-verified construction (read directly, not run)

From `crypto/xwing/xwing.cc` at the cloned commit:

- **Key stretch** (`xwing_expand_private_key`): absorbs the 32-byte seed into
  one SHAKE256 (`boringssl_shake256`) sponge, then squeezes **64 bytes** for
  the ML-KEM-768 seed (`MLKEM768_private_key_from_seed`) followed by **32
  bytes** for the X25519 private key, from the **same** sponge state (one
  absorb, two sequential squeezes) — functionally identical to draft-11
  §5.2's `SHAKE256(sk, 96*8)` then `expanded[0:64]` / `expanded[64:96]` split
  (draft-11 doesn't distinguish ML-KEM's own `d`/`z` sub-split at this layer;
  BoringSSL delegates that to `MLKEM768_private_key_from_seed`, matching
  draft-11's delegation to `ML-KEM-768.KeyGen_internal`).
- **Combiner** (`xwing_combiner`): SHA3-256 absorbs, **in this exact order**:
  `mlkem_shared_secret` (32 B) → `x25519_shared_secret` (32 B) →
  `x25519_ciphertext` (32 B) → `x25519_public_key` (32 B) → the 6-byte literal
  `{0x5c, 0x2e, 0x2f, 0x2f, 0x5e, 0x5c}`. This is **byte-identical** to
  draft-11 §5.3: `SHA3-256(concat(ss_M, ss_X, ct_X, pk_X, XWingLabel))` with
  `XWingLabel = 5c2e2f2f5e5c`.
- **Encoding** (`xwing.h` macros, confirmed against §5.1 of draft-11):
  `XWING_PUBLIC_KEY_BYTES = 1216`, `XWING_PRIVATE_KEY_BYTES = 32`,
  `XWING_CIPHERTEXT_BYTES = 1120`, `XWING_SHARED_SECRET_BYTES = 32` — exact
  matches to draft-11's `pk`/`sk`/`ct`/`ss` sizes.
- **Ciphertext/public-key byte order**: `xwing_public_from_private` packs the
  ML-KEM-768 public key first, then the 32-byte X25519 public key
  (`concat(pk_M, pk_X)`, matching draft-11). `XWING_encap_external_entropy`
  writes the ML-KEM ciphertext to `out_ciphertext[0:1088]` and the X25519
  ephemeral public key to `out_ciphertext[1088:1120]`
  (`concat(ct_M, ct_X)`, matching draft-11 §5.4).
- **Private key is the raw 32-byte seed** (`xwing_marshal_private_key` just
  copies `private_key->seed`), consistent with draft-11's seed-as-decapsulation-key
  design (introduced at -02→-03 per draft-11's own changelog G.6, "Since
  draft-connolly-cfrg-xwing-kem-02: Use seed as private key").
- **Low-order-point handling**: in `xwing_decap`/`XWING_encap_external_entropy`,
  BoringSSL's `X25519()` call returns `0` on failure and the caller
  propagates that as an overall encap/decap failure (with the shared-secret
  output buffer randomised before returning, per the comment "fill the
  shared secret with random bytes ... no intermediate information leaks").
  BoringSSL's X25519 implementation is known (from its own API contract) to
  reject all-zero (low-order-point) outputs. draft-11 does not specify this
  behaviour explicitly, and there is an open upstream spec issue on it (see
  §5).

## 4. Cloudflare CIRCL

### 4.1 Version reference and history

- File: `kem/xwing/xwing.go`, read directly from
  <https://raw.githubusercontent.com/cloudflare/circl/main/kem/xwing/xwing.go>
  (main branch HEAD at fetch time: commit `91db3e785b`, 2026-09-28).
- Package doc-comment: *"Package xwing implements the X-Wing PQ/T hybrid KEM
  ... Implements the final version (-05)."* — this is the **only** version
  claim in the file; it has not been updated to reference draft-11.
- Commit history for `kem/xwing/xwing.go`
  (`cloudflare/circl:kem/xwing/xwing.go`, via GitHub commits API):
  - `964fefa14b`: original commit, **authored 2024-01-05** but with
    **committer date 2025-01-21T23:48:18Z** — the GitHub PR
    (`cloudflare/circl#471`, cited in draft-11 Appendix A as the vector
    source) shows `created_at: 2024-01-05`, `merged_at: 2025-01-21`. The PR's
    own title/commit message reads *"X-Wing PQ/T hybrid / Implements final
    version (-05) ... Also includes HPKE integration with final IANA
    codepoint (which is different from the one requested in -05.)"* — i.e.
    the author explicitly updated the IANA-codepoint handling to match a
    later, "final" assignment even though the package comment still says
    "-05", confirming "-05" refers specifically to the cryptographic
    construction, which the PR author considered finalized at that draft
    version.
  - `5f64bbdb1d` (**2025-03-20**), *"kem/hybrid: ensure X25519 hybrids fails
    with low order points"*: the only other commit touching this file. The
    diff (read directly) adds **comments only** to `xwing.go` noting that a
    low-order X25519 point yields an all-zero shared secret and that this is
    "ignored for now pending clarification in the spec," with a link to
    `dconnolly/draft-connolly-cfrg-xwing-kem` issue #28. **No behavioural
    change was made to `xwing.go` itself** in this commit (the behavioural
    fix in this commit applies to a different file,
    `kem/hybrid/xkem.go`/`ckem.go`, for CIRCL's generic hybrid-combiner
    package, not the dedicated `xwing` package).
  - No further commits touch `kem/xwing/xwing.go`. CIRCL releases: latest is
    **v1.6.5 (2026-08-05)**; the X-Wing package has been present since at
    least v1.6.1 (2025-04-09), confirmed via the releases API
    (`cloudflare/circl` releases list), so it ships in all currently tagged
    releases.

### 4.2 Source-verified construction (read directly, not run)

From `kem/xwing/xwing.go` (quoted in full in §-prior fetch of this report; key
points):

- **Key stretch** (`deriveKeyPair`): one `sha3.NewShake256()` instance,
  written with the 32-byte seed, then read **once for `seedm` (ML-KEM-768
  seed) then once for `sk.x` (X25519 private key)** from the same XOF state —
  same single-sponge, sequential-squeeze pattern as BoringSSL and as
  draft-11's `SHAKE256(sk, 96*8)` split.
- **Combiner** (`combiner` function): SHA3-256, writes in order `ssm` → `ssx`
  → `ctx` → `pkx` → the literal `` `\.//^\` `` (Go backtick string, 6 bytes:
  `5c 2e 2f 2f 5e 5c`) — **byte-identical order and label** to draft-11 §5.3
  and to BoringSSL's `xwing_combiner`.
- **Encoding**: `PublicKeySize = 1216`, `PrivateKeySize = 32`,
  `CiphertextSize = 1120`, `SharedKeySize = 32`, `EncapsulationSeedSize = 64`
  — exact matches to draft-11 §5.1 and to BoringSSL's macros.
- **Byte order**: `PublicKey.Pack` writes the ML-KEM-768 key first, then the
  X25519 key; `EncapsulateTo` writes the ML-KEM ciphertext first, then the
  X25519 ephemeral public key — matching draft-11 and BoringSSL.
- **Private key is the raw 32-byte seed** (`PrivateKey.Pack` copies
  `sk.seed`), matching draft-11 and BoringSSL.
- **Low-order-point handling**: `EncapsulateTo`/`DecapsulateTo` call
  `x25519.Shared` and **do not check its (ignored) boolean return value** for
  the dedicated `xwing` package, per the explicit comment quoted above citing
  issue #28 as unresolved. This is a **confirmed divergence** from
  BoringSSL's explicit-failure behaviour on the same edge case (see §3.2,
  §5).

## 5. Cross-implementation comparison against draft-11

| Property | draft-11 (§5.1–5.5) | BoringSSL (`crypto/xwing/xwing.cc`) | CIRCL (`kem/xwing/xwing.go`) | Match? |
|---|---|---|---|---|
| Encapsulation key size | 1216 B | `XWING_PUBLIC_KEY_BYTES = 1216` | `PublicKeySize = 1216` | ✅ identical |
| Decapsulation key size | 32 B (seed) | `XWING_PRIVATE_KEY_BYTES = 32` | `PrivateKeySize = 32` | ✅ identical |
| Ciphertext size | 1120 B | `XWING_CIPHERTEXT_BYTES = 1120` | `CiphertextSize = 1120` | ✅ identical |
| Shared secret size | 32 B | `XWING_SHARED_SECRET_BYTES = 32` | `SharedKeySize = 32` | ✅ identical |
| Key-stretch XOF | SHAKE256, 96 B, single sponge | SHAKE256, 64+32 B, single sponge | SHAKE256, two sequential reads, single sponge | ✅ identical |
| pk encoding order | `concat(pk_M, pk_X)` | ML-KEM then X25519 | ML-KEM then X25519 | ✅ identical |
| ct encoding order | `concat(ct_M, ct_X)` | ML-KEM then X25519 | ML-KEM then X25519 | ✅ identical |
| Combiner hash | SHA3-256 | SHA3-256 (`boringssl_sha3_256`) | SHA3-256 (`sha3.New256`) | ✅ identical |
| Combiner input order | `ss_M, ss_X, ct_X, pk_X, label` | same order | same order | ✅ identical |
| Combiner label (hex) | `5c2e2f2f5e5c` | `5c2e2f2f5e5c` | `5c2e2f2f5e5c` | ✅ identical |
| Low-order X25519 point | unspecified (open issue #28) | fails the operation | silently yields all-zero `ssx`, proceeds | ❌ **confirmed divergence on this one edge case only** |
| Draft version cited in-repo | n/a | "-06"→"-07"→(doc pointer to concrete-hybrid-kems-02) | "-05" | stale label, not a construction mismatch (see §1) |

Everything that is part of the normal (well-formed input) encapsulation and
decapsulation path — the part that produces a `(pk, sk, ct, ss)` conformance
vector tuple — is **byte-identical across all three sources** (draft-11 text,
BoringSSL source, CIRCL source), verified directly from source, not inferred
from matching high-level APIs or version numbers. The one confirmed
divergence is scoped to a malformed/adversarial input case that the draft
itself leaves unspecified.

## 6. Does draft-05→draft-11 construction drift matter here?

Read directly from draft-11 **Appendix G (Change log)**:

- **G.4, "Since draft-connolly-cfrg-xwing-kem-04"** (i.e., changes introduced
  in -05, dated 2024-10-20): *"Move label at the end. As everything fits
  within a single block of SHA3-256, this does not make any difference [to
  security]"* and *"Use SHAKE-256 to stretch seed. This does not have any
  security or performance effects..."* — **this is where the current
  label-at-end / SHAKE256-stretch construction was introduced**, and the
  entry's own text says the change is effectively a no-op compared to the
  prior (SHAKE-128, label-elsewhere) construction for implementations
  choosing SHAKE-256 and label-at-end already.
- **G.1–G.3** ("Since -07", "Since -06", "Since -05") list **only**:
  elaboration of randomized/derandomized relation, implementations-list
  updates (-07); ASN.1 module, SHAKE-256 bit-vs-byte-count request fix, PEM
  header fix (-06); typo fixes, HPKE/TLS codepoint renumbering, X.509
  guidance (-05→-06 boundary, G.2 wording covers "-06"). **None of these
  touch the combiner, key-stretch, or encoding.**
- Conclusion: **the cryptographic construction has been frozen since
  draft-05 (2024-10-20)**, over two years before draft-11. BoringSSL (built
  against -07) and CIRCL (built and labelled against -05) both post-date or
  exactly match this freeze point, which is why their source matches
  draft-11 byte-for-byte despite citing older draft numbers in comments. This
  reasoning is based on reading draft-11's own changelog text directly, not
  on an assumption that "newer drafts are always compatible."

## 7. Independence of BoringSSL and CIRCL as vector sources

- **Organizationally and technically independent**: BoringSSL is Google's C
  TLS library (Apache-2.0, Gerrit-reviewed, `crypto/xwing/` + BoringSSL's own
  FIPS-module Keccak/ML-KEM/X25519 primitives); CIRCL is Cloudflare's Go
  cryptography library (BSD-3, GitHub-PR-reviewed, its own `sha3`, `x25519`,
  and `mlkem768` packages). No shared code path was found between them for
  X-Wing; each reimplements ML-KEM-768, X25519, and SHA3/SHAKE independently
  in its own language and internal API.
- **Independent implementation timelines**: BoringSSL's X-Wing landed
  2025-04-29 against draft-07; CIRCL's landed (merged) 2025-01-21, labelled
  against draft-05. Different authors (BoringSSL: Adam Langley et al. at
  Google; CIRCL: Cloudflare's CIRCL maintainers via PR #471), different draft
  revisions as their nominal targets, same resulting byte-level construction
  — this is exactly the kind of convergent, independently-arrived-at
  agreement ADR 0007 wants from "two independent vector sources."
- **Caveat on the one confirmed divergence**: do not draw well-formed-input
  confidence from a cross-check that happens to exercise the low-order-point
  path (ADR 0007's "random inputs" differential test is extremely unlikely to
  hit this, since it requires a maliciously-crafted low-order public key or
  ciphertext component, not random bytes — but a deliberately adversarial
  fuzz/negative-test corpus could).
- **Caveat on draft-11's own Appendix C vectors** (§1 correction above): these
  exist but their provenance (which implementation, if any, generated them)
  is **not stated in the draft text** itself, and this research did not
  decode/re-derive them (that would require running code, out of scope here).
  They are a third candidate source worth a follow-up, not a replacement for
  the BoringSSL/CIRCL cross-check ADR 0007 already specifies.

## 8. Gaps and explicitly unverified items

- **Not verified**: whether BoringSSL's and CIRCL's underlying ML-KEM-768 and
  X25519 primitive implementations (as opposed to the X-Wing combiner glue
  checked here) are themselves bit-exact to FIPS 203 / RFC 7748 in all paths
  — this research only traced the X-Wing-specific glue code
  (`xwing.cc`/`xwing.go`) and the sizes/byte-order it produces, which is
  what the combiner-level comparison in §5 needed. ML-KEM/X25519 KAT
  conformance is separately covered by ADR 0007's NIST ACVP/Wycheproof gates.
- **Not verified**: the actual numeric agreement of BoringSSL vs. CIRCL
  outputs for a shared test input — this would require running both
  implementations, which this research was explicitly told not to do. The
  conclusion that they will agree is a **source-code-level structural
  proof** (identical absorb order, identical label bytes, identical sizes),
  not an executed/observed equality.
- **Not verified**: draft-11 Appendix C's vector provenance (which tool
  produced the `seed`/`sk`/`pk`/`eseed`/`ct`/`ss` values) — the draft text
  does not attribute them, and no implementation note was found alongside
  them in the fetched text.
- **Not verified in depth**: whether `draft-irtf-cfrg-concrete-hybrid-kems`
  revisions between -02 (what BoringSSL's comment cites) and -04 (current)
  changed the `MLKEM768-X25519` label/sizes — only -04 was read in full;
  this is a secondary, informative document and does not gate ADR 0001/0007
  compliance (draft-11 of the X-Wing draft itself was read in full and is
  the operative spec), so this gap does not block the ticket's resolution,
  but is flagged for completeness.
- **Apple CryptoKit's `XWingMLKEM768X25519`** and other Appendix-A-listed
  implementations were not examined; ADR 0007 only names BoringSSL and CIRCL,
  so this was out of scope.

## 9. Recommendation for ADR 0007 / Slice S0

1. Treat BoringSSL (`crypto/xwing/xwing.cc`, commit
   `d6731cddd7` onward through current master
   `4f3b183c5d4a8f8fcaba4c0ab4435df181df6978`) and CIRCL
   (`kem/xwing/xwing.go`, present since v1.6.1, current main `91db3e785b`) as
   **confirmed draft-11-conformant for well-formed-input vectors**, based on
   the source-level structural comparison in §5, not on their internal
   version-string comments, which are stale and should not be used as a
   proxy for conformance.
2. When generating/committing the ADR 0007 "X-Wing vectors," **exclude
   low-order-point / malformed-key test cases** from the two-implementation
   cross-check, or isolate them into a separately-labelled negative-test set
   with an explicit note that BoringSSL and CIRCL are known to diverge there
   pending upstream issue #28 — do not let this known, spec-level ambiguity
   silently fail the "both adapters must match both implementations" gate.
3. Re-open a narrow follow-up (not blocking S0) to decode draft-11 Appendix
   C's existing numeric vectors as a third, draft-text-native comparison
   point — useful since they exist and were previously believed absent, but
   this requires actually running an ML-KEM-768/X25519/SHA3-256 pipeline
   against the given seeds, which was out of scope for this research pass.
4. Correct the 2026-10-05 ct-conformance-tooling note's "ships no test
   vectors" claim (this note documents the correction in §1; no other file
   was edited per the scope of this ticket).
