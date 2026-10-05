# Research findings: FIPS/CNSA conformance of hybrid ML-KEM-768 + X25519 key establishment

Status: research draft, not an approved design. No ADR exists yet. Any adoption
requires an ADR (Constitution O3), a formal model, and expert review (S6). This
document is input to `pqcble-r1` suite selection; it does not itself select a
suite.

All claims below are sourced from primary documents that were fetched and
read in full (NIST SP/FIPS PDFs converted with `pdftotext`, the IETF
datatracker HTML for `draft-connolly-cfrg-xwing-kem`, the NSA CNSA 2.0 FAQ PDF
retrieved via the Wayback Machine after `media.defense.gov` blocked direct
fetches, and the live CMVP `SP 800-140C`/`SP 800-140D` web pages). Anything
not directly confirmed in a primary source is explicitly marked
**UNVERIFIED**.

## 1. Summary

1. **Hybrid ML-KEM-768 + X25519 key establishment can be FIPS-conformant**,
   provided the combiner is built from an SP 800-56C Rev. 2 key-derivation
   method (or an SP 800-133 Rev. 2 key-combination method) and at least one
   component (ML-KEM-768) is itself approved. NIST SP 800-227 (final,
   September 2025) says this explicitly and uses **X-Wing by name** as its
   running example of a PQ/T hybrid KEM (SP 800-227 §4.6).
2. **X-Wing's concrete combiner — `SHA3-256(ss_M || ss_X || ct_X || pk_X ||
   label)` — is structurally the same construction SP 800-227 calls out as
   its recommended, IND-CCA-preserving combiner** `KeyCombineCCA_H` (SP
   800-227 §4.6.3, Eq. 15/16), because SHA3-256 is an approved "Option 1"
   auxiliary hash function for SP 800-56C Rev. 2 one-step key derivation (SP
   800-56C Rev. 2 §4.1, §4.2, Table 1). This is a direct, non-obvious finding:
   SP 800-227 does not merely tolerate X-Wing-style combiners, it uses X-Wing
   as the worked example of an approved construction.
3. **X25519 itself is not an approved SP 800-56A key-establishment primitive.**
   SP 800-186 (Feb 2023) lists Curve25519/Curve448/W-25519/W-448/E448 only as
   "alternative representations... not to be used for ECDSA or EdDSA
   directly" and does **not** place them in the "EC key establishment (see SP
   800-56A)" row that P-224/256/384/521 occupy (SP 800-186 Table 2, §3.1.2).
   X25519 is therefore the "auxiliary"/non-approved input `T` in SP 800-56C
   Rev. 2's hybrid shared secret `Z' = Z || T` (SP 800-56C Rev. 2 §2), and CMVP
   confirms this split in practice: SP 800-140D's "Key Agreement" section
   lists only SP 800-56A Rev. 3 and SP 800-56B Rev. 2 — no X25519/RFC 7748
   reference — while ML-KEM (FIPS 203) and SP 800-227 are listed separately
   under "Key-Encapsulation Mechanism" (CMVP SP 800-140D web page, §6.2.6,
   §6.2.10).
4. **HKDF (RFC 5869) is explicitly CMVP-approved** as a "Key Agreement Key
   Derivation" method, alongside SP 800-56C Rev. 2 (CMVP SP 800-140D web page,
   §6.2.7). KMAC and HMAC are approved MAC/auxiliary-function building blocks
   for SP 800-56C one-step and two-step KDFs (SP 800-56C Rev. 2 §4.1, §5.1).
5. **ChaCha20-Poly1305 is confirmed absent from every CMVP-approved-algorithm
   list fetched** (SP 800-140C web page, §6.2.2 Block Cipher / §6.2.6 Message
   Authentication — AES, Triple-DES, SKIPJACK(decrypt-only), HMAC, KMAC,
   Ascon-AEAD128; no ChaCha20, no Poly1305 anywhere). AES-256-GCM (or
   Ascon-AEAD128) is required if FIPS 140-3 module validation is a goal.
6. **SP 800-38D Appendix C permits 32-bit and 64-bit (short) GCM tags** under
   strict per-packet-length and per-key-invocation-count limits (Tables 1–2);
   the standard tag set is {96,104,112,120,128} bits, with {32,64} bits
   requiring Appendix C's extra bookkeeping (SP 800-38D §"tag bit length t",
   Appendix C).
7. **SP 800-107 Rev. 1 sets a hard floor of 32 bits and a "commonly
   acceptable" floor of 64 bits for truncated HMAC MacTags**, independent of
   purpose (§5.3.3, §5.3.5). It does not special-case "identification" vs
   "authentication" tags; an 8-byte (64-bit) truncated PRF tag sits exactly at
   the document's own "commonly acceptable" line, and a shorter tag (e.g., 4
   bytes / 32 bits) is the documented floor, not a recommended value.
8. **CNSA 2.0 does not require hybrid key establishment for NSS**, and
   explicitly discourages ad hoc/non-standardized hybrids on NSS mission
   systems pending NSA-blessed designs; it tolerates vendor/commercial hybrid
   deployment for interoperability reasons (CNSA 2.0 FAQ, media.defense.gov,
   "Hybrids" section).
9. **SP 800-107 Rev. 1 is itself in the middle of a NIST-announced withdrawal**
   (Planning Note, Dec 2022) and **SP 800-56C Rev. 2 is flagged for revision**
   (Planning Note, Jan 2026) — both are still the live, citable "final" text
   as of this writing, but neither is frozen; this is a dependency risk flagged
   for `pqcble-r1`, not just an academic footnote.

## 2. Can hybrid ML-KEM-768 + X25519 be FIPS-conformant, and what is the exact mechanism?

### 2.1 SP 800-227's own hybrid construction (§4.6)

SP 800-227 (NIST SP 800-227, published September 2025,
<https://csrc.nist.gov/pubs/sp/800/227/final>) devotes §4.6 ("Multi-Algorithm
KEMs and PQ/T Hybrids") to exactly this question, and names X-Wing as its
example:

> "the migration to post-quantum key-establishment techniques might initially
> include multi-algorithm solutions that combine one new post-quantum
> algorithm with one tried-and-tested but quantum-vulnerable (or traditional)
> algorithm. This is sometimes referred to as hybrid post-quantum/traditional
> (PQ/T) key establishment. For example, X-Wing KEM is a hybrid PQ/T KEM
> built from two components: ML-KEM (a lattice-based post-quantum KEM) and
> X25519 (a traditional Diffie-Hellman-style key exchange)" (SP 800-227
> §4.6, p.26).

The document specifies a generic **composite KEM** construction `C[Π1, Π2]`
(SP 800-227 §4.6.1, Eqs. 9–10):

```
KeyGen:    (ek1,dk1) ← Π1.KeyGen(p1);  (ek2,dk2) ← Π2.KeyGen(p2)
           ek := ek1 || ek2;  dk := dk1 || dk2

Encaps:    (K1,c1) ← Π1.Encaps(p1,ek1);  (K2,c2) ← Π2.Encaps(p2,ek2)
           K ← KeyCombine(K1, K2, c1, c2, ek1, ek2, p)
           c := c1 || c2

Decaps:    K1' ← Π1.Decaps(p1,dk1,c1);  K2' ← Π2.Decaps(p2,dk2,c2)
           K' ← KeyCombine(K1', K2', c1, c2, ek1, ek2, p)
```

The only step this document constrains is `KeyCombine`: "an approved key
combiner discussed in Sec. 4.6.2 **shall** be used" (SP 800-227 §4.6.1, p.27,
emphasis NIST's).

### 2.2 The two approved families of combiners (§4.6.2)

SP 800-227 §4.6.2 says there are exactly two approved routes:

1. **Key combiners from key-derivation methods approved in SP 800-56C Rev. 2.**
2. **Key combiners from key-combination methods approved in SP 800-133 Rev. 2.**

For route 1, SP 800-227 explicitly cross-references SP 800-56C Rev. 2's own
"hybrid shared secret" provision (see §3 below) and generalizes it to `t > 1`
shared secrets:

> "This publication approves the use of the key combiner (14) for any `t > 1`
> if at least one shared secret (i.e., Sj for some j) is generated from the
> key-establishment methods in SP 800-56A or SP 800-56B **or an approved
> KEM**." (SP 800-227 §4.6.2, p.29)

i.e. one of the two input secrets must come from an SP 800-56A/B scheme *or*
an approved KEM (ML-KEM qualifies as the latter) — the other secret (here,
the X25519 shared secret) is permitted to be generated "in some other (not
necessarily approved) manner" (same page). This is the mechanism asked for
in Q1: **the non-approved/legacy component is folded in as the auxiliary
"other" input to an approved KDF; it does not itself need to be approved, as
long as the KDF and at least one other input are.**

For route 2, SP 800-133 Rev. 2 provides three approved methods — concatenate,
XOR, or HMAC-extract — but **requires every component key to have been
generated by an approved method** (SP 800-133 Rev. 2 §6.3, "the component
symmetric keys... shall be generated and/or established independently...
using approved methods"). Because X25519's shared secret is not approved,
route 2 cannot directly combine `(K_MLKEM, K_X25519)` — route 1 (an SP
800-56C KDM) is the only route that tolerates a non-approved auxiliary
secret. SP 800-227 flags this itself when it later singles out HKDF/KMAC-style
one-step KDFs (not SP 800-133 concatenation) as the IND-CCA-preserving choice
(§4.6.3, discussed in §4 below).

## 3. The exact construction NIST requires

### 3.1 SP 800-56C Rev. 2's hybrid `Z' = Z || T`

SP 800-56C Rev. 2 (final, August 2020, Planning Note 01/06/2026 announcing a
revision is in progress,
<https://csrc.nist.gov/pubs/sp/800/56/c/r2/final>) states its scope
explicitly:

> "In addition to the currently approved techniques for the generation of
> the shared secret Z as specified in SP 800-56A and SP 800-56B, this
> Recommendation permits the use of a 'hybrid' shared secret of the form
> `Z' = Z || T`, a concatenation consisting of a 'standard' shared secret Z
> that was generated during the execution of a key-establishment scheme (as
> currently specified in [SP 800-56A] or [SP 800-56B]) followed by an
> auxiliary shared secret T that has been generated using some other method.
> The content, format, length, and method used to generate T must be known
> and agreed upon by all parties... The key-derivation methods specified in
> this Recommendation will process a hybrid Z' in the same way they process
> a standard Z." (SP 800-56C Rev. 2 §2, "Scope and Purpose")

This is the exact mechanism: a classical ECDH secret `T` (X25519 in our
case) is concatenated *after* an approved secret `Z` (here, generalized by SP
800-227 to an ML-KEM shared secret), and the resulting `Z'` is fed unmodified
into an approved KDM — either one-step or two-step.

### 3.2 One-step vs. two-step KDMs

SP 800-56C Rev. 2 §4 ("One-Step Key Derivation") specifies:

```
K ← KDF(Z, OtherInput)
```

where `KDF` depends on a chosen auxiliary function `H`:

- **Option 1**: `H(x) = hash(x)` — any approved FIPS 180-4 or FIPS 202 hash
  (SHA-1/224/256/384/512/512-t or SHA3-224/256/384/512) (§4.1, Table 1).
- **Option 2**: `H(x) = HMAC-hash(salt, x)` (§4.1, Table 2).
- **Option 3**: `H(x) = KMAC#(salt, x, H_outputBits, "KDF")` using KMAC128 or
  KMAC256 (§4.1, Table 3).

§5 ("Two-Step Key Derivation") is the extraction-then-expansion form:

```
K ← Expand(Extract(salt, Z), FixedInfo)
```

where `Extract` is an HMAC- or KMAC-based randomness extractor (§5.1, Tables
4–5) and `Expand` reuses the SP 800-108 Rev. 1 families (counter, feedback,
double-pipeline, or KMAC mode — see §5 below). §4.1 is explicit that
"extraction is performed with all shared secrets as the input" when
multiple secrets (`S1...St`) are combined this way (also echoed in SP 800-227
§4.6.2, p.29).

**Answer to Q2**: NIST does *not* require HKDF specifically — any of the
three auxiliary-function options (plain approved hash, HMAC, or KMAC) is an
approved one-step KDM, and the two-step extract-then-expand construction
(which is what RFC 5869 HKDF implements) is also approved and is separately
listed by CMVP (§6 below). What is required is: (a) the shared secrets are
concatenated/combined as `Z' = Z || T` (or the generalized `(S1,...,St)`
form), (b) the KDM itself — not the underlying classical DH step — is one of
SP 800-56C's enumerated forms, and (c) at least one `Sj` originates from an
approved scheme or KEM.

## 4. Is X-Wing's SHA3-256 combiner an acceptable FIPS combiner?

### 4.1 The current X-Wing construction (draft -11, fetched 2026-10-05)

The latest IETF datatracker revision is **draft-connolly-cfrg-xwing-kem-11**
(dated 2026-09-23; expires 2027-03-27;
<https://datatracker.ietf.org/doc/draft-connolly-cfrg-xwing-kem/>). Its
combiner (§5.3) is:

```python
def Combiner(ss_M, ss_X, ct_X, pk_X):
    return SHA3-256(concat(ss_M, ss_X, ct_X, pk_X, XWingLabel))
```

where `XWingLabel` is a fixed 6-byte ASCII domain separator (`5c2e2f2f5e5c`
hex, i.e. `\./` `/^\`). `ss_M` is the ML-KEM-768 shared secret, `ss_X` is the
X25519 shared secret, `ct_X` is the X25519 "ciphertext" (ephemeral public
key), and `pk_X` is the recipient's long-term X25519 public key.

### 4.2 Why this matches SP 800-56C's "Option 1" one-step KDF

SP 800-227 §4.6.3 constructs, as its worked example for an IND-CCA-preserving
combiner, exactly this shape:

> "Let H denote a hash function from the SHA-3 family, which is approved for
> use in one-step key derivation in SP 800-56C. Define the key combiner
> `KeyCombineCCA_H` as follows... `Output: H(K1, K2, c1, c2, ek1, ek2,
> domain_sep)`. The domain separator `domain_sep` should be used to uniquely
> identify the composite scheme in use (e.g., Π1, Π2, order of composition,
> choice of parameter set, key combiner, KDF)." (SP 800-227 §4.6.3, p.31–32)

This is, field-for-field, X-Wing's combiner: `K1=ss_M`, `K2=ss_X`, `c1`→the
ML-KEM ciphertext is *not* included by X-Wing (a deliberate, documented
deviation — see §4.3), `c2=ct_X`, `ek2=pk_X` (X-Wing omits `ek1`, the ML-KEM
public key, from the hash), `domain_sep=XWingLabel`. SHA3-256 is listed
verbatim as an approved Option-1 auxiliary hash function in SP 800-56C Rev.
2 Table 1 (§4.2, p.15: "SHA3-256 | 136/1088 | 256 | ... | 112 ≤ s ≤ 256").

**Conclusion for Q3, first half**: X-Wing's combiner is not raw/uninterpreted
SHA3-256 in the FIPS sense — it is a direct instantiation of SP 800-56C Rev.
2's approved one-step KDM with Option 1 (`H(x)=hash(x)`, hash=SHA3-256). SP
800-227 presents essentially this exact formula as its model approved
combiner. **There is no requirement that the combiner be HKDF or an
extract-then-expand construction; a single-call approved hash (SHA3-256) on
the concatenated, length-fixed inputs is an approved one-step KDM under SP
800-56C Rev. 2 §4.**

### 4.3 Caveats SP 800-227 itself raises about X-Wing's specific shortcuts

Two qualifications, both from primary sources, temper the conclusion above:

1. **Omitting the ML-KEM ciphertext from the hash is X-Wing-specific, not
   generically approved.** SP 800-227 warns: "As shown in [25], the
   straightforward key combiner `K ← KDF(K1, K2)` that only uses the two
   shared secret keys... does not preserve IND-CCA security, regardless of
   the properties of the KDF" (§4.6.3, p.31) and recommends including
   ciphertexts/encapsulation keys. X-Wing's own security considerations
   section concedes this is tied to ML-KEM's specific Fujisaki-Okamoto
   structure: "The security of X-Wing relies crucially on the specifics of
   the Fujisaki-Okamoto transformation used in ML-KEM-768: the X-Wing
   combiner cannot be assumed to be secure, when used with different KEMs.
   In particular it is not known to be safe to leave out the post-quantum
   ciphertext from the combiner in the general case." (draft-11 §6,
   "Security Considerations"). This is a cryptographic-engineering argument
   specific to X-Wing+ML-KEM-768, not a general FIPS rule — but it does mean
   X-Wing's specific combiner should not be treated as a template for
   combining *other* KEM pairs.
2. **X-Wing is informational, not an IETF consensus document**, and has
   "no formal standing in the IETF standards process" (datatracker boilerplate,
   same URL). A FIPS 140-3 validation lab would need to assess the combiner
   on its cryptographic merits against SP 800-56C's text, independent of
   X-Wing's IETF status (**UNVERIFIED**: whether any CMVP-validated module to
   date has actually claimed X-Wing's combiner as an SP 800-56C KDM in a
   security policy; no such validation certificate was located in this
   research pass).

### 4.4 What changed between draft -06 (Apple CryptoKit) and draft -11

Apple's CryptoKit documentation for `XWingMLKEM768X25519` states explicitly,
in its own page metadata: "The X-Wing (ML-KEM768 with X25519) Key
Encapsulation Mechanism, defined in
https://datatracker.ietf.org/doc/html/draft-connolly-cfrg-xwing-kem-06"
(fetched from
<https://developer.apple.com/documentation/cryptokit/xwingmlkem768x25519>,
page `<meta name="description">` / `og:description` tags, 2026-10-05). So
Apple's CryptoKit implementation tracks **draft -06** specifically.

The datatracker's Appendix G change log (fetched from the rendered -11 text)
lists everything changed since -06:

- **Since -07** (→ -08/-09/-10/-11, i.e. everything after -06 up to date):
  "Elaborate on relation between randomized and derandomized functions" and
  "Update implementations section" (purely editorial/documentation).
- **Since -06** (the -07 delta, i.e. the first change after the draft Apple
  cites): "Add asn.1 module", "To match FIPS 202, we request number of bits
  from SHAKE-256 instead of number of bytes. #27", "Update implementations
  section", "Correct PEM header. #25".

None of these entries touch the `Combiner()` function, the `XWingLabel`
value, or the input ordering — the combiner formula in -06 and -11 is
byte-for-byte identical (confirmed by reading draft -11's Python reference
code in Appendix B, which matches the formula quoted in §4.1 above, and by
the fact that the change log for every revision from -07 through -11 lists
only ASN.1/HPKE/documentation changes, never a combiner change). The last
*substantive* combiner-adjacent change pre-dates -06: "Move label at the
end... Use SHAKE-256 to stretch seed" is logged under **"Since
draft-connolly-cfrg-xwing-kem-03"** (draft -04's change log, i.e. two
revisions before -06), and "Mandate ML-KEM encapsulation key check" is under
**"Since -03"** as well (draft -04 change log entries, applying to the
`Encapsulate()` key-check behavior, not the combiner hash itself).

**Conclusion for Q3, second half**: Apple CryptoKit's X-Wing implementation
(tracking draft -06) and the current draft -11 combiner are cryptographically
identical. The only risk surface for an implementer pinned to -06 is the
editorial/encoding deltas (ASN.1 OIDs, SHAKE256 bit-vs-byte argument
convention, PEM header), not the FIPS-relevant combiner math.

## 5. CNSA 2.0's position on hybrid key establishment

Source: NSA "CNSA Suite 2.0 and Quantum Computing FAQ", U/OO/194427-22,
PP-22-1338, September 2022, Ver. 1.0. Direct fetch of
`media.defense.gov/2022/Sep/07/2003071836/-1/-1/0/CSI_CNSA_2.0_FAQ_.PDF`
returned HTTP 403 from this research environment; the identical PDF (15
pages, same U/OO/194427-22 control number) was retrieved via the Internet
Archive Wayback Machine snapshot
(`web.archive.org/web/20231205203113/https://media.defense.gov/2022/Sep/07/2003071836/-1/-1/0/CSI_CNSA_2.0_FAQ_.PDF`)
and converted with `pdftotext`. **Flagged as UNVERIFIED-by-direct-fetch**:
this research could not confirm from the live `media.defense.gov` host
itself that no newer FAQ revision exists; the version in hand is explicitly
"Ver. 1.0".

Direct quotes:

> "Q: What is NSA's position on the use of hybrid solutions? A: NSA has
> confidence in CNSA 2.0 algorithms and **will not require** NSS developers
> to use hybrid certified products for security purposes. Product
> availability and interoperability requirements may lead to adopting hybrid
> solutions. NSA recognizes that some standards may require using
> hybrid-like constructions to accommodate the larger sizes of CRQC
> algorithms and will work with industry on the best options for
> implementation." (CNSA 2.0 FAQ, "Hybrids" section, p.13)

> "Q: Should one use a hybrid or other non-standardized QR solution while
> waiting for a final NIST post-quantum standard? A: **Do not use a hybrid or
> other non-standardized QR solution on NSS mission systems.** NSA encourages
> limited purchase and use for research and planning, but only to prepare
> for transitioning to CNSA 2.0. Because NSA is confident that CNSA 2.0
> algorithms will sufficiently protect NSS, it does not require a hybrid
> solution for security purposes. ... Using a hybrid solution that involves a
> symmetric key in accordance with established standards (e.g., RFC 8446,
> RFC 8784) may be appropriate, but key management complexity generally
> restricts this to specialized applications." (CNSA 2.0 FAQ, p.14)

> "NSA does not approve using pre-standardized or non-FIPS-validated CNSA 2.0
> algorithms (even in hybrid modes) for NSS missions." (p.6, footnote context
> around software/firmware signing guidance)

**Timeline** (CNSA 2.0 FAQ, "Timing" section, p.6):

| Category | Support & prefer CNSA 2.0 by | Exclusively CNSA 2.0 by |
|---|---:|---:|
| Software/firmware signing | 2025 | 2030 |
| Web browsers/servers, cloud services | 2025 | 2033 |
| Traditional networking equipment (VPN, routers) | 2026 | 2030 |
| Operating systems | 2027 | 2033 |
| Niche equipment (constrained devices, large PKI) | 2030 | 2033 |
| Custom applications / legacy equipment | — | update or replace by 2033 |

**Answer to Q4**: Hybrid classical+PQC is *permitted* for NSS where product
availability/interop demands it, but it is explicitly **not required** by
NSA, and ad hoc (non-NSA-reviewed) hybrids are **discouraged — "do not use"
— on NSS mission systems specifically**; NSA reserves the right to bless
specific standardized hybrid constructions (RFC 8446 / RFC 8784 are the named
precedents) later. A commercial `pqcble-r1` deployment is not an NSS and is
not directly bound by this FAQ, but it is the clearest authoritative signal
available on how a national-security risk owner views hybrid designs like
X-Wing.

## 6. Approved KDFs for a key-schedule combiner (HKDF vs KMAC256, SP 800-108/SP 800-56C/SP 800-140C)

SP 800-108 Rev. 1 (with 2024 update,
<https://csrc.nist.gov/pubs/sp/800/108/r1/upd1/final>, fetched as
`NIST.SP.800-108r1-upd1.pdf`) specifies four approved iteration modes for
deriving additional keying material from an existing key-derivation key,
using HMAC, CMAC, or KMAC as the underlying PRF (§1, Table of Contents):

- KDF in Counter Mode (§4.1)
- KDF in Feedback Mode (§4.2)
- KDF in Double-Pipeline Mode (§4.3)
- KDF Using KMAC (§4.4) — "KMAC can output keying material that has the
  required length without iteration" (§4, intro text)

These four are the `Expand` half of SP 800-56C Rev. 2's two-step
extraction-then-expansion KDM (SP 800-56C Rev. 2 §2: "those functions
[SP 800-108] are employed in the second (key-expansion) step of these
two-step procedures"). HKDF (RFC 5869) is the specific case where `Extract`
is HMAC-based randomness extraction and `Expand` is SP 800-108's HMAC
counter-mode KDF.

Per the live CMVP page for SP 800-140D (`csrc.nist.gov/projects/
cryptographic-module-validation-program/sp-800-140-series-supplemental-information/sp800-140d`,
fetched 2026-10-05), the approved "Key Agreement Key Derivation" building
blocks are, verbatim:

> "**6.2.7 Key Agreement Key Derivation** — Barker EB, Chen L, Davis R (2020)
> *Recommendation for Key-Derivation Methods in Key-Establishment Schemes*
> (SP) 800-56C, Rev. 2. — HMAC-based Extract-and-Expand Key Derivation
> Function (HKDF). RFC 5869, May 2010."

So **both** HKDF-SHA-256/384 (via RFC 5869, cited directly by CMVP) **and**
KMAC256-based one-step or two-step SP 800-56C KDMs are CMVP-approved
building blocks — there is no CMVP preference for one over the other; the
choice is an engineering tradeoff (HKDF is widely implemented and reviewed;
KMAC256 avoids a separate hash-based extraction step and is already present
if SHA-3/SHAKE is in the module for ML-KEM). Both qualify under FIPS 140-3
Annex D (SSP generation/establishment) via SP 800-140D §6.2.7.

**Answer to Q5**: For a key schedule `CK ← KDF(CK, ss, H(ek)||H(ct), ctx,
epoch)`, HKDF-SHA-256/384 and KMAC256 are both FIPS-approved choices under
SP 800-56C Rev. 2 / SP 800-108 Rev. 1, and both are listed by name (HKDF via
RFC 5869, KMAC via SP 800-185/SP 800-56C) in CMVP's SP 800-140D approved-list.
SHA-3/KMAC256 has a practical edge only if the module already implements
Keccak for ML-KEM/SHA3-256 (as X-Wing does) and wants to avoid a second
primitive family; this is an implementation-efficiency argument, not a FIPS
approval difference.

## 7. AEAD tag lengths and MAC truncation

### 7.1 SP 800-38D (GCM) tag-length rules

SP 800-38D (Nov 2007; the live CSRC page carries a "Planning Note
(03/06/2024): NIST has decided to revise this publication" —
**UNVERIFIED current/updated** whether a revised SP 800-38D has since been
published; none was found in this pass, and the document fetched is still
the 2007 text) specifies:

> "In general, t may be any one of the following five values: 128, 120, 112,
> 104, or 96. For certain applications, t may be 64 or 32; guidance for the
> use of these two tag lengths, including requirements on the length of the
> input data and the lifetime of the key in these cases, is given in
> Appendix C. An implementation shall not support values for t that are
> different from the seven choices in the preceding paragraph." (SP 800-38D,
> main body, "the tag", p.8)

Appendix C ("Requirements and Guidelines for Using Short Tags") imposes, for
any implementation supporting 32- or 64-bit tags, a mandatory table lookup
binding "maximum combined length of ciphertext+AAD per packet" to "maximum
number of authenticated-decryption invocations per key" (Tables 1–2):

| Tag | Max combined ciphertext+AAD per packet | Max decryption invocations per key |
|---|---:|---:|
| 32-bit | 32 B (2⁵) | 2²² |
| 32-bit | 1024 B (2¹⁰) | 2¹¹ |
| 64-bit | 32 KiB (2¹⁵) | 2³² |
| 64-bit | 32 MiB (2²⁵) | 2¹⁷ |

(full tables in SP 800-38D Appendix C; only the end rows of each are shown
here). Appendix C also mandates: silently discard failed packets (no
ACK/NACK oracle), limit AAD to header-only, rotate the key frequently, and
ensure no single packet's forgery compromises the overall message meaning
(Appendix C, items 1–4).

**Answer to Q6 (AEAD half)**: An 8-byte (64-bit) tag is within the approved
set and usable under Appendix C's bookkeeping; a 16-byte (128-bit) tag is
simply the default/standard approved length with no special bookkeeping
required. Neither requires a waiver — both are in the "seven choices" set —
but 8-byte tags carry mandatory rekey/length constraints that 16-byte tags do
not.

### 7.2 SP 800-107 Rev. 1 (hash/HMAC truncation)

SP 800-107 Rev. 1 (Aug 2012; CSRC page carries a "Planning Note (12/20/2022):
NIST has decided to withdraw SP 800-107 Rev. 1" pending a replacement
Implementation Guidance document — **flagged UNVERIFIED-current**: the
replacement IG was not located/confirmed published in this pass; SP 800-107
Rev. 1 is cited here as the still-live text as of the fetch date) states, on
HMAC output truncation (§5.3.3):

> "When an application truncates the HMAC output to generate a MacTag to a
> desired length, λ, the λ left-most bits of the HMAC output shall be used
> as the MacTag. However, the output length, λ, **shall be no less than 32
> bits**." (SP 800-107 Rev. 1 §5.3.3)

And on acceptable practice (§5.3.5):

> "A commonly acceptable length for the MacTag is 64 bits; MacTags with
> lengths shorter than 64 bits are discouraged." (SP 800-107 Rev. 1 §5.3.5)

The same section gives a quantitative risk table (Table 2) of forgery
probability vs. MacTag length `λ` and number of allowed failed verifications
`2^t`, e.g. `λ=40, 2^t=2^20 → P(forge)=2^-20`; `λ=64, 2^t=2^30 → 2^-34`;
`λ=96, 2^t=2^35 → 2^-61`.

**Answer to Q6 (hash-MAC half)**: 32 bits is the documented absolute floor,
64 bits is the documented "commonly acceptable" line, and the document frames
shorter-than-64-bit tags as "discouraged" but not forbidden, contingent on
bounding the number of allowed failed-verification attempts per key (exactly
analogous in spirit to SP 800-38D Appendix C's packet-count bookkeeping for
short GCM tags).

## 8. Must FIPS-conformant designs replace ChaCha20-Poly1305 with AES-256-GCM?

Yes. The live CMVP "SP 800-140C: Approved Security Functions" page
(`csrc.nist.gov/projects/cryptographic-module-validation-program/sp-800-140-series-supplemental-information/sp800-140c`,
referencing SP 800-140C Rev. 2, July 2023, fetched 2026-10-05) enumerates
every CMVP-approved block cipher and MAC. Under **6.2.2 Block Cipher** the
only entries are AES (FIPS 197, with SP 800-38A/B/C/D/E/F/G modes),
Triple-DES (legacy, decrypt/unwrap/verify only as of Jan 2024), and SKIPJACK
(decrypt-only, FIPS 185 withdrawn). Under **6.2.6 Message Authentication**
the only entries are Triple-DES CMAC, AES CMAC/CCM/GCM, HMAC (FIPS 198-1 +
SP 800-107 Rev. 1), KMAC (SP 800-185), and Ascon-AEAD128 (SP 800-232, 2025).
No ChaCha stream cipher and no Poly1305 MAC appear anywhere on this page, nor
in SP 800-140C Rev. 2's own PDF text (grep of the converted PDF text for
"chacha"/"poly1305" returned zero matches). This directly confirms the
premise in Q7: **ChaCha20-Poly1305 is not a NIST-approved algorithm under
FIPS 140-3**, and a FIPS 140-3 validated module cannot claim it as an
approved AEAD. AES-256-GCM (with the tag-length rules in §7.1 above) or the
newer Ascon-AEAD128 (SP 800-232, 2025, lightweight-crypto track) are the
approved alternatives; Ascon-AEAD128 is new enough that broad CMVP
module-validation track record is **UNVERIFIED** at this time.

## 9. Is X25519 FIPS-approved for ECDH?

SP 800-186 ("Recommendations for Discrete Logarithm-based Cryptography:
Elliptic Curve Domain Parameters", Feb 2023,
<https://csrc.nist.gov/pubs/sp/800/186/final> via
`NIST.SP.800-186.pdf`) Table 2 ("Allowed Usage of the Specified Curves", §3.1.2,
p.7) is the controlling table:

| Specified Curves | Allowed Usage |
|---|---|
| K-233/B-233, K-283/B-283, K-409/B-409, K-571/B-571 | Deprecated |
| P-224, P-256, P-384, P-521 | **ECDSA, EC key establishment (see SP 800-56A)** |
| Edwards25519, Edwards448 | **EdDSA** |
| Curve25519, W-25519, Curve448, E448, W-448 | "Alternative representations included for implementation flexibility. **Not to be used for ECDSA or EdDSA directly.**" |

Montgomery-form Curve25519/Curve448 (the curves X25519/X448 actually operate
on) are placed in the third row — explicitly scoped only as alternative
*representations* of the birationally-equivalent Weierstrass/Edwards curves,
and explicitly barred from direct signature use. Critically, **this table
does not place Curve25519/Curve448 in the "EC key establishment (see SP
800-56A)" row at all** — that row is reserved for the four NIST Weierstrass
curves. SP 800-186's introduction independently narrows the document's own
scope: "The key pairs specified here are used for digital signature
generation and verification or key agreement only and should not be used for
any other purposes" (SP 800-186, Introduction/Purpose and Scope, p.1), and it
is written "for use in conjunction with... NIST SP 800-56A... Rev. 3" — but SP
800-56A Rev. 3 itself (not independently re-fetched in this pass; referenced
via SP 800-186's own bibliography entry) is the document that actually
defines approved ECDH schemes, and it is a pre-Montgomery-curve document.

This is corroborated by the CMVP SP 800-140D web page (§6.2.6, "Key
Agreement"): the only references listed are SP 800-56A Rev. 3 and SP 800-56B
Rev. 2 — **no RFC 7748 (X25519/X448) citation appears anywhere on that
page**, whereas RFC 7748-based EdDSA's signature cousin (Ed25519/Ed448) is
separately approved via FIPS 186-5 (§6.2.3 Digital Signature:
"DSA, RSA, ECDSA, EdDSA, ML-DSA, SLH-DSA" explicitly lists EdDSA,
citing FIPS 186-5 and SP 800-186).

**Answer to Q8**: X25519 is **not** FIPS-approved for ECDH key establishment.
SP 800-186 added the underlying Montgomery/twisted-Edwards curve math
(Curve25519, Curve448, Edwards25519, Edwards448) to its domain-parameter
catalogue, and FIPS 186-5 approved **EdDSA signatures** on Edwards25519/
Edwards448 — but neither document, nor SP 800-56A Rev. 3, nor the CMVP
approved-methods list, approves Curve25519/X25519 for Diffie-Hellman key
*agreement*. This is precisely the EdDSA-vs-ECDH distinction the question
anticipated: FIPS 186-5 blessed the signature use of the Edwards form of this
curve family; no NIST publication found in this research blesses the
Montgomery/X25519 Diffie-Hellman use for FIPS purposes. This is exactly why
SP 800-56C Rev. 2's `Z' = Z || T` hybrid-secret clause (§3 above) is the
mechanism that makes X25519 usable at all in a FIPS-conformant hybrid: X25519
enters only as the non-approved auxiliary `T`, never as the approved `Z`.

## 10. Truncated PRF/MAC outputs used as pseudonyms or beacon identifiers (not authentication tags)

SP 800-107 Rev. 1's truncation guidance (§5.3.3, §5.3.5, quoted in full in
§7.2 above) is written in terms of a "MacTag" used for *message
authentication and integrity verification* — the 32-bit floor and 64-bit
"commonly acceptable" line, and the forgery-probability table (Table 2), are
all derived from an adversary's incentive to **forge** a tag and have it
accepted by a verifier. The document does not carve out a separate, more
permissive regime for non-authentication uses such as identification tags,
pseudonymous beacon IDs, or lookup keys — **UNVERIFIED**: no text was found
in SP 800-107 Rev. 1, SP 800-108 Rev. 1, or SP 800-56C Rev. 2 that explicitly
discusses "identification" or "pseudonym" as a distinct security objective
from "message authentication," and none of these documents define a
different (weaker) acceptable-length floor for that use case.

Practically, this means:

- If an 8–16 byte truncated-PRF beacon/pseudonym is modeled, for FIPS-citation
  purposes, as a "MacTag" (i.e., the underlying primitive is HMAC or KMAC and
  the output is truncated the same way an authentication tag would be), then
  SP 800-107 Rev. 1's 32-bit floor / 64-bit "commonly acceptable" guidance is
  the only applicable NIST floor found, and it applies regardless of whether
  the *use* is authentication or identification — the document's own
  forgery-probability argument is agnostic to downstream use (an attacker who
  can guess/forge the tag can impersonate or correlate a pseudonym just as
  well as they can forge a message).
- There is **no FIPS-approved weaker floor for "mere identification" tags**
  found in this research. A design that wants an 8-byte identification tag
  should treat it as sitting exactly at SP 800-107 Rev. 1's "commonly
  acceptable" line, with the same key-rotation/attempt-limiting logic SP
  800-38D Appendix C requires for short GCM tags (§7.1) applied by analogy:
  bound the number of guesses an adversary gets against any one key before
  rotating it.
- A 4-byte (32-bit) pseudonym sits at the documented absolute floor, not
  above it, and SP 800-107 Rev. 1's own Table 2 example (`λ=32` is not even
  tabulated at the low end of Table 2, which starts at `λ=40`) suggests NIST
  itself treats 32-bit outputs as a worst-case/last-resort choice requiring
  very tight bounds on adversary guesses, not a design target.

## 11. Recommended suite table

This table is a candidate input for a future ADR, not a decision. Every row
cites the primary source established above.

| Component | Candidate | FIPS 140-3 approved? | CNSA 2.0 compliant? | Vendor-implemented? | Justification |
|---|---|---|---|---|---|
| KEM combiner construction | SP 800-56C Rev. 2 one-step KDM, Option 1 (`H = SHA3-256` or SHA-256), applied to `Z' = ss_MLKEM \|\| ss_X25519` with domain separator | **Yes**, if implemented as an explicit SP 800-56C one-step KDM call (X-Wing's own combiner is this construction; SP 800-227 §4.6.3 names this shape as its approved example) | Not itself a CNSA 2.0 primitive; CNSA 2.0 does not mandate or endorse a specific hybrid combiner (CNSA 2.0 FAQ, "Hybrids") | X-Wing: Apple CryptoKit (draft -06), BoringSSL, Cloudflare CIRCL, RustCrypto | SP 800-227 §4.6.2–4.6.3 + SP 800-56C Rev. 2 §4.1 Table 1 (SHA3-256 approved Option-1 hash) |
| KEM (post-quantum component) | ML-KEM-768 | **Yes** — FIPS 203, listed directly by CMVP SP 800-140D §6.2.10 alongside SP 800-227 | **Yes** — CNSA 2.0's QR algorithm suite includes ML-KEM (per CNSA 2.0 FAQ transition timeline, §5 above; **UNVERIFIED** exact parameter-set mandate text — not independently re-confirmed from the FAQ's algorithm-selection table in this pass) | ubiquitous (liboqs, BoringSSL, AWS-LC, CIRCL, CryptoKit) | FIPS 203; CMVP SP 800-140D §6.2.10 |
| Classical component | X25519 | **No** — SP 800-186 Table 2 excludes Curve25519 from the "EC key establishment" row; CMVP SP 800-140D §6.2.6 cites only SP 800-56A/B, no RFC 7748 | n/a — CNSA 2.0 is PQC-first and does not mandate a classical component, but tolerates one for interoperability (CNSA 2.0 FAQ, "Hybrids") | ubiquitous (libsodium, BoringSSL, CryptoKit, every major TLS stack) | SP 800-186 §3.1.2 Table 2; only usable in a FIPS context as the non-approved auxiliary `T` in SP 800-56C Rev. 2's `Z'=Z‖T` |
| KDF (key-schedule ratchet) | HKDF-SHA-384 **or** KMAC256 | **Yes**, both — CMVP SP 800-140D §6.2.7 lists RFC 5869 (HKDF) and SP 800-56C Rev. 2 (which covers KMAC256-based one-step/two-step KDMs) side by side | Not independently CNSA 2.0-mandated; SHA-384 is explicitly named CNSA-2.0-safe against large quantum computers (CNSA 2.0 FAQ, "Preparation" section: "AES-256, SHA-384, SHA-512... are considered safe") | ubiquitous | SP 800-56C Rev. 2 §4–5; SP 800-108 Rev. 1 §4; CMVP SP 800-140D §6.2.7 |
| AEAD | AES-256-GCM, 16-byte tag (96-bit nonce) | **Yes** — SP 800-38D main body; listed CMVP SP 800-140C §6.2.2/§6.2.6 | **Yes** — AES-256 is the CNSA 2.0 symmetric algorithm (CNSA 2.0 FAQ, "Preparation": "AES-256... considered safe against attack by a large quantum computer") | ubiquitous, hardware-accelerated on every modern phone/desktop CPU | SP 800-38D; CMVP SP 800-140C §6.2.2.1 |
| AEAD (short-tag variant, e.g. for constrained framing) | AES-256-GCM, 8-byte (64-bit) tag, under SP 800-38D Appendix C bookkeeping | **Yes**, conditionally — only if the Appendix C per-key invocation-count/packet-length table is enforced | Same AES-256 basis as above | same libraries, tag-length configurable | SP 800-38D Appendix C Table 2 |
| AEAD (non-FIPS stream cipher) | ChaCha20-Poly1305 | **No** — absent from CMVP SP 800-140C §6.2.2/§6.2.6 entirely (verified by full-text search of the live approved-algorithm page and the SP 800-140C Rev. 2 PDF) | **No** | ubiquitous in non-FIPS contexts (TLS 1.3, WireGuard, Signal) | Confirmed absence, §8 above |
| MAC / truncated PRF for pseudonyms | HMAC-SHA-256 or KMAC256, truncated to ≥ 8 bytes (64 bits "commonly acceptable"), with an explicit per-key failed-attempt bound | **Approvable as a MAC primitive**; the *truncation length* is a judgment call under SP 800-107 Rev. 1 guidance, not a separate FIPS-approved category for "identification" use | n/a | ubiquitous | SP 800-107 Rev. 1 §5.3.3/§5.3.5; no NIST text found distinguishing "identification" from "authentication" truncation floors (§10 above) |
| Curve for signatures (if needed) | Ed25519 (EdDSA) or P-256/P-384 ECDSA | **Yes**, both — FIPS 186-5 approves EdDSA on Edwards25519/Edwards448; ECDSA on P-224/256/384/521 remains approved | ECDSA P-384 is the CNSA 1.0/2.0-listed classical signature; Ed25519 is **not** a named CNSA 2.0 algorithm (**UNVERIFIED** — not independently confirmed against a CNSA 2.0 algorithm table in this pass; inferred from the FAQ's emphasis on ML-DSA/LMS/XMSS for CNSA 2.0 and ECDSA P-384 for CNSA 1.0) | ubiquitous | FIPS 186-5 §7 (EdDSA); SP 800-186 Table 2 (Edwards25519 row: "EdDSA") |

## 12. Open items and explicit UNVERIFIED flags

1. **UNVERIFIED**: Whether any FIPS 140-3 CMVP certificate has actually
   claimed an X-Wing-shaped combiner as an SP 800-56C approved KDM in a
   published security policy. Not located in this pass; would require a
   CMVP certificate-database search, which was out of scope for this
   primary-source literature pass.
2. **UNVERIFIED**: The exact text of a CNSA 2.0 FAQ revision newer than Ver.
   1.0 (Sept 2022) could not be independently confirmed live from
   `media.defense.gov` (blocked with HTTP 403 from this environment on every
   attempt, including with browser user-agent strings); the Wayback Machine
   copy used here is dated and self-identifies as Ver. 1.0. If NSA has since
   issued an updated CNSA 2.0 FAQ or algorithm table with more specific
   hybrid guidance, it is not reflected here.
3. **UNVERIFIED**: SP 800-38D's "Planning Note (03/06/2024): NIST has decided
   to revise this publication" — whether a revised SP 800-38D (e.g. with
   updated GCM/short-tag guidance) has since been published was not
   confirmed; the 2007 text is what was fetched and cited.
4. **UNVERIFIED**: SP 800-107 Rev. 1's withdrawal (Planning Note 12/20/2022)
   is pending a replacement FIPS 140-3 Implementation Guidance (IG) document
   from CMVP that would supersede its truncation-length guidance; whether
   that IG has since been published, and whether it changes the 32-bit
   floor / 64-bit "commonly acceptable" guidance, was not confirmed.
5. **UNVERIFIED**: SP 800-56C Rev. 2's "Planning Note (01/06/2026): NIST has
   decided to revise this publication" — a revision announcement exists as of
   this writing, but no Rev. 3 draft text was found to fetch; all citations
   above are to the still-current Rev. 2 (Aug 2020) text.
6. **UNVERIFIED**: The precise CNSA 2.0 algorithm-and-parameter-set table
   (e.g., which ML-KEM parameter set, which ML-DSA/LMS/XMSS parameter sets)
   was referenced only indirectly via the "Preparation" and "Timing" FAQ
   sections quoted above; a dedicated pass through the FAQ's full algorithm
   table (not fully reproduced in this report) would be needed to make
   parameter-set-level CNSA 2.0 compliance claims.
7. **UNVERIFIED**: Ascon-AEAD128's actual CMVP validation track record (how
   many modules have been certified using it as of this writing) was not
   checked; it is listed in SP 800-140C solely on the strength of SP 800-232
   being a 2025 NIST-finalized standard appearing on the current CMVP
   approved-algorithm page.

## References

- NIST SP 800-227 (final, Sept 2025), *Recommendations for
  Key-Encapsulation Mechanisms*:
  <https://csrc.nist.gov/pubs/sp/800/227/final> (PDF:
  `https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-227.pdf`)
- NIST SP 800-56C Rev. 2 (final, Aug 2020; revision announced Jan 2026),
  *Recommendation for Key-Derivation Methods in Key-Establishment Schemes*:
  <https://csrc.nist.gov/pubs/sp/800/56/c/r2/final> (PDF:
  `https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-56Cr2.pdf`)
- NIST SP 800-133 Rev. 2 (final), *Recommendation for Cryptographic Key
  Generation*:
  `https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-133r2.pdf`
- NIST SP 800-108 Rev. 1 (incl. upd1, Feb 2024), *Recommendation for Key
  Derivation Using Pseudorandom Functions*:
  `https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-108r1-upd1.pdf`
- NIST SP 800-186 (Feb 2023), *Recommendations for Discrete Logarithm-based
  Cryptography: Elliptic Curve Domain Parameters*:
  `https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-186.pdf`
- FIPS 186-5, *Digital Signature Standard (DSS)*:
  `https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.186-5.pdf`
- NIST SP 800-38D (Nov 2007; revision announced March 2024),
  *Recommendation for Block Cipher Modes of Operation: Galois/Counter Mode
  (GCM) and GMAC*: <https://csrc.nist.gov/pubs/sp/800/38/d/final> (PDF:
  `https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf`)
- NIST SP 800-107 Rev. 1 (Aug 2012; withdrawal announced Dec 2022),
  *Recommendation for Applications Using Approved Hash Algorithms*:
  <https://csrc.nist.gov/pubs/sp/800/107/r1/final> (PDF via DOI redirect:
  `https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-107r1.pdf`)
- NIST SP 800-140C Rev. 2 (July 2023) + live CMVP approved-algorithm page:
  <https://csrc.nist.gov/pubs/sp/800/140/c/r2/final>;
  <https://csrc.nist.gov/projects/cryptographic-module-validation-program/sp-800-140-series-supplemental-information/sp800-140c>
  (PDF: `https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-140Cr2.pdf`)
- NIST SP 800-140D Rev. 2 + live CMVP approved SSP generation/establishment
  page:
  <https://csrc.nist.gov/projects/cryptographic-module-validation-program/sp-800-140-series-supplemental-information/sp800-140d>
- IETF, `draft-connolly-cfrg-xwing-kem-11` (2026-09-23), *X-Wing:
  general-purpose hybrid post-quantum KEM*:
  <https://datatracker.ietf.org/doc/draft-connolly-cfrg-xwing-kem/>; history/
  revision list: <https://datatracker.ietf.org/doc/draft-connolly-cfrg-xwing-kem/history/>
- Apple Developer Documentation, `XWingMLKEM768X25519` (CryptoKit):
  <https://developer.apple.com/documentation/cryptokit/xwingmlkem768x25519>
  (page metadata cites `draft-connolly-cfrg-xwing-kem-06`)
- NSA, *CNSA Suite 2.0 and Quantum Computing FAQ*, U/OO/194427-22,
  PP-22-1338, Sept 2022, Ver. 1.0 (original URL blocked with HTTP 403 from
  this research environment; retrieved via Wayback Machine):
  `https://web.archive.org/web/20231205203113/https://media.defense.gov/2022/Sep/07/2003071836/-1/-1/0/CSI_CNSA_2.0_FAQ_.PDF`
  (original: `https://media.defense.gov/2022/Sep/07/2003071836/-1/-1/0/CSI_CNSA_2.0_FAQ_.PDF`)
- FIPS 203, *Module-Lattice-Based Key-Encapsulation Mechanism Standard*
  (cited via CMVP SP 800-140D listing; not independently re-fetched in this
  pass — already verified in the companion `2026-10-05-pqc-over-ble-findings.md`
  research note)
