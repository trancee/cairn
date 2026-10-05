# Formal model tooling and lemmas for `pqcble-r1`

Status: **draft research** (ticket *Formal model tooling and lemmas*). Scope matches the
formal-verification gate: **Resume** ([ADR 0005](../adr/0005-wire-format.md) §4,
[findings](2026-10-05-pqc-over-ble-findings.md) §4.2), **ratchet mixing** (the amortized
ML-KEM-768 epoch, findings §4.4/§9.3), and **SAS pairing** (commit-then-reveal, findings §4.1/§9.4).
The message-key chains (ADR 0002) and BLE transport are explicitly out of scope here.

Primary sources were fetched directly (IACR ePrint abstract pages, USENIX page metadata, GitHub
API `/license` and `/repos` endpoints, opam package metadata, the Signal spec site, and the
WireGuard formal-verification page). Items that could not be directly fetched (most PDF bodies are
behind a Cloudflare-style gate on `eprint.iacr.org`) are marked **UNVERIFIED** and rely on abstract
or secondary-page metadata only.

## 1. Summary

- Use **Tamarin** as the primary tool for Resume, ratchet mixing and SAS: it is the tool used by
  the two closest prior analyses (PQXDH, Apple PQ3), it handles unbounded sessions/loops (needed
  for the ratchet's repeated epochs), and its `restriction`/`lemma` machinery can express ordered
  commit-then-reveal and bounded-guess properties. Symbolic (Dolev-Yao), not computational.
- Treat **CryptoVerif** as a secondary, optional tool only if a quantitative bound on the SAS
  2⁻²⁰ guessing probability or a reduction-style proof of the X-Wing hybrid combiner is wanted;
  it is the only one of the three with a documented post-quantum/hybrid-KEM soundness extension
  (Blanchet–Jacomme, CSF'24). **ProVerif** is a viable Tamarin alternative with push-button
  automation and a native `weaksecret` query construct for guessing-type properties, but neither
  ProVerif nor CryptoVerif has a published KEM-binding library; Tamarin does (Cremers–Dax–Medinger).
- The standard symbolic treatment of public-key encryption as a perfect, collision-free black box
  does **not** capture KEM re-encapsulation/binding attacks. Three independent sources confirm
  this and give a path to model it correctly: Cremers–Dax–Medinger (ePrint 2023/1933, Tamarin
  binding-property library), Bhargavan–Jacomme–Kiefer–Schmidt (USENIX Sec'24, Tamarin PQXDH model,
  public repo), and Fiedler–Günther (ePrint 2024/702, computational/game-based, complementary).
  `pqcble-r1`'s explicit `H(ek)‖H(ct)` binding in the ratchet (findings §4.4) is precisely the
  mitigation these papers say is required.
- No tool-based (Tamarin/ProVerif) model of Vaudenay's SAS-MCA or MANA was found; those remain
  pen-and-paper. The closest reusable templates are two Bluetooth pairing Tamarin/ProVerif models
  (Numeric Comparison / Secure Simple Pairing) that already encode a commit-then-reveal-shaped
  association flow.
- Apple PQ3 (Linker–Sasse–Basin, ePrint 2024/1395) is the single closest prior model to
  `pqcble-r1` as a whole: Tamarin, double-ratchet-style construction extended with PQ KEM epochs,
  explicitly handles "both key ratchets, including unbounded loops." No public repo was located
  for it, so it is a template to imitate, not a model to fork.
- WireGuard offers three reusable artifacts across both paradigms (Tamarin, pen-and-paper
  computational, and CryptoVerif-mechanized ACCE) and is the direct precedent for the
  separate-confirmation-key fix already applied in Resume (findings §4.2).

## 2. Tool comparison

| | **Tamarin** | **ProVerif** | **CryptoVerif** |
|---|---|---|---|
| Paradigm | Symbolic, Dolev-Yao. Multiset rewriting + first-order (guarded) logic. | Symbolic, Dolev-Yao. Horn-clause resolution over the applied pi-calculus. | **Computational/reductionist.** Sequence-of-games proofs reducing to standard assumptions (IND-CPA, UF-CMA, PRF, …). |
| Sessions | Unbounded, including unbounded loops (confirmed usable for ratchets by PQ3, ePrint 2024/1395). | Unbounded. | Unbounded, with explicit concrete/exact security bounds. |
| Automation | Interactive + heuristic automated proof search; can require manual oracles for hard lemmas. | Fully automated (push-button); can produce false attacks (sound for proofs, not for attack-finding). | Mostly automated game transformations; some manual guidance for non-standard assumptions. |
| Native guessing/weak-secret support | `restriction` + custom lemmas; no single built-in "weak secret" query, but used successfully for KEM-binding and Bluetooth NC/PE guessing properties (see §3). | Built-in `weaksecret` query construct, directly aimed at bounded-guess/low-entropy-secret properties. | Expresses a guessing bound as an explicit probability term in the final security bound — most natural fit for a quantitative 2⁻²⁰ claim. |
| Closest prior art to `pqcble-r1` | PQXDH (USENIX Sec'24), Apple PQ3 (ePrint 2024/1395), WireGuard (`wireguard-tamarin`), TLS 1.3 resumption (`tls13tamarin`), Bluetooth NC/PE pairing (OSUSecLab, NDSS'23). | Bluetooth SSP/Numeric Comparison (`purseclab/btmodel_proverif`), Rosenpass, Noise Explorer (auto-generates `.pv`). | WireGuard ACCE proof (Lipp–Blanchet–Bhargavan, EuroS&P'19); Blanchet–Jacomme CSF'24 post-quantum/hybrid soundness extension. |
| License | GPL-3.0 (GitHub API `license` field on `tamarin-prover/tamarin-prover`). | GPL-2.0-or-later (opam-repository official metadata, `dev-repo` = Inria GitLab `bblanche/proverif`). | CeCILL-B (opam-repository official metadata). |
| Repo / manual | `https://github.com/tamarin-prover/tamarin-prover`; manual at `https://tamarin-prover.github.io/manual/index.html` | `https://bblanche.gitlabpages.inria.fr/proverif/`; canonical source `https://gitlab.inria.fr/bblanche/proverif` | `https://cryptoverif.inria.fr/` (redirects to `https://bblanche.gitlabpages.inria.fr/cryptoverif/`) |

**Recommendation:** Tamarin as the primary tool for all three gate items, because (a) it is the
tool both closest prior-art papers (PQXDH, PQ3) actually used, meaning there is a concrete style
of KEM/ratchet encoding to imitate rather than invent; (b) it explicitly supports the unbounded
repeated-epoch loops the ratchet needs; and (c) a reusable Tamarin KEM-binding equational-theory
library already exists in the literature (Cremers–Dax–Medinger), even though its code was not
publicly locatable (see §3, gap noted). Use ProVerif only as a cross-check tool for the SAS
guessing-bound lemma, where its native `weaksecret` query is a more direct fit than a Tamarin
restriction. Reserve CryptoVerif for a later, optional quantitative pass over the SAS 2⁻²⁰ bound
and/or the X-Wing hybrid combiner, citing Blanchet–Jacomme CSF'24 as the methodological precedent
for post-quantum/hybrid soundness in CryptoVerif.

Citation for the ProVerif survey/background: Bruno Blanchet, "Modeling and Verifying Security
Protocols with the Applied Pi Calculus and ProVerif," *Foundations and Trends in Privacy and
Security* 1(1-2):1-135, Oct 2016, DOI 10.1561/3300000004.

## 3. Modelling KEMs for re-encapsulation/binding

The standard symbolic (Dolev-Yao) treatment of public-key encryption as a perfect, collision-free
black box does not model KEM re-encapsulation or binding failures — a KEM's shared secret may, in
a real implementation, fail to uniquely determine the public key, ciphertext, or both, enabling
confusion/re-encapsulation attacks across sessions. Three sources, read together, define how to
model this correctly:

- **Cremers, Dax, Medinger — "Keeping Up with the KEMs: Stronger Security Notions for KEMs and
  Automated Analysis of KEM-based protocols,"** ePrint 2023/1933,
  `https://eprint.iacr.org/2023/1933` (abstract fetched directly). Establishes a hierarchy of
  computational KEM security/binding notions formalizing "in which sense outputs of the KEM
  uniquely determine, i.e., bind, other values," and a corresponding family of symbolic models
  **encoded as a library in the Tamarin prover**. Tamarin automatically re-derives that the key
  exchange protocol in the original Kyber paper needs stronger binding properties than were
  proven. **No public repository for this Tamarin library was found** (searched GitHub API for
  the paper's authors and keyword combinations) — **UNVERIFIED/not publicly located**; the exact
  names of the binding notions (candidate labels such as BIND-K-CT/BIND-K-PK/MAL-BIND referenced
  in the research brief) could not be confirmed because the PDF body is Cloudflare-gated —
  **UNVERIFIED**, only the abstract was read.
- **Bhargavan, Jacomme, Kiefer, Schmidt — "Formal verification of the PQXDH Post-Quantum key
  agreement protocol for end-to-end secure messaging,"** USENIX Security 2024, pp. 469–486, PDF
  at `https://www.usenix.org/system/files/usenixsecurity24-bhargavan.pdf` (title/authors/venue
  confirmed via USENIX page metadata). **Symbolic, Tamarin-based.** Public model repo:
  `https://github.com/Inria-Prosecco/pqxdh-analysis`, with iterative directories
  (`revision1`, `revision1-WithKyberCR`, `revision2`, `revision3`) tracking PQXDH spec revisions,
  including a Kyber-ciphertext-rejection variant directly addressing re-encapsulation. Per
  Fiedler–Günther's abstract, this paper "pointed out a potential re-encapsulation attack if the
  KEM shared secret does not bind the public key" — exactly the attack class `pqcble-r1`'s ratchet
  mixing (findings §4.4) mitigates via `H(ek)‖H(ct)` binding. **License: none found** — GitHub API
  `/license` endpoint on `Inria-Prosecco/pqxdh-analysis` returns `license: None` (confirmed by
  direct query 2026-10-05); treat as all-rights-reserved absent an explicit grant, and contact the
  authors before reusing code verbatim.
- **Fiedler, Günther — "Security Analysis of Signal's PQXDH Handshake,"** ePrint 2024/702,
  `https://eprint.iacr.org/2024/702` (PKC 2025 proceedings version; title/authors confirmed via
  IACR metadata). **Computational/game-based, not a Tamarin/ProVerif/CryptoVerif artifact** — a
  "maximum-exposure" security-model proof with concrete bounds, introducing a novel KEM binding
  notion and proving ML-KEM satisfies it. Explicitly concurrent with and complementary to the
  Bhargavan et al. tool-based analysis: one symbolic/mechanized, one computational/pen-and-paper,
  converging on the same binding requirement. No EasyCrypt/CryptoVerif artifact was found in the
  abstract; **whether a code artifact exists is UNVERIFIED** (PDF body not accessible).

**Modelling guidance for `pqcble-r1`:** model ML-KEM-768 (ratchet) and X-Wing (pairing) not as an
opaque asymmetric-encryption primitive but as explicit `encaps(ek) -> (ct, ss)` /
`decaps(dk, ct) -> ss` function symbols with an equational theory restricted to decaps-correctness
(no equation that lets the adversary derive `ss` from `ct` alone), and add the binding assumption
as an explicit Tamarin `restriction` or axiom stating that `(ek, ct)` determines `ss` — mirroring
the Cremers–Dax–Medinger notion and the `H(ek)‖H(ct)` binding already in the design. Reuse the
`WithKyberCR` revision of the Inria-Prosecco repo as a worked example of how to encode ciphertext
rejection/re-encapsulation checks in Tamarin syntax (style reference only, given the unresolved
license).

## 4. Modelling the commit-then-reveal SAS with a 2⁻²⁰ guessing bound

No tool-based (Tamarin/ProVerif/CryptoVerif) model of Vaudenay's SAS-MCA framework or the MANA
protocol family was found; repeated GitHub searches for combinations of "Vaudenay," "SAS,"
"MANA," "proverif," and "tamarin" returned no relevant repositories. Vaudenay, "Secure
Communications over Insecure Channels Based on Short Authenticated Strings," CRYPTO 2005, and
Gehrmann–Mitchell–Nyberg's MANA I/II (2004) should be treated as **un-mechanized, pen-and-paper
baseline references only** — mark this gap explicitly in the model's assumptions section.

Two genuine tool-based models of structurally similar Bluetooth pairing protocols exist and are
the best available templates for the commit-then-reveal ordering and bounded-guess lemma:

- **`OSUSecLab/bluetooth-pairing-formal-verification`**,
  `https://github.com/OSUSecLab/bluetooth-pairing-formal-verification` — Tamarin models of
  Bluetooth Passkey Entry (PE) and **Numeric Comparison (NC)** pairing, from "Extrapolating Formal
  Analysis to Uncover Attacks in Bluetooth Passkey Entry Pairing," NDSS 2023. **License: MIT**
  (confirmed via GitHub API `/license`). The README documents `vulnerable/`/`patched/` model pairs
  driven by a `gen_proof.py` script, and acknowledges direct input from the Tamarin core team
  (Cremers, Dreier, Sasse) on modelling commit-reveal ordering and guessing restrictions — the
  most directly reusable Tamarin style for `pqcble-r1`'s SAS.
- **`purseclab/btmodel_proverif`**, `https://github.com/purseclab/btmodel_proverif` — ProVerif
  model of Bluetooth Secure Simple Pairing (including its Numeric-Comparison association model)
  and Bluetooth Mesh provisioning (an OOB/commit-style flow), from "Formal Model-Driven Discovery
  of Bluetooth Protocol Design Vulnerabilities," IEEE S&P 2022. **License: none found** (GitHub
  API `/license` returns `null`) — **UNVERIFIED/no explicit license**, confirm before reuse. Its
  `model/ssp.pv` and modular composition-by-shell-script pattern is a good structural reference for
  splitting Resume/ratchet/SAS into separate composable `.pv` files.

**Modelling approach for the 2⁻²⁰ bound:**

- In **Tamarin**, there is no single built-in weak-secret query; express the property as a
  restriction forcing the commit (`H(nA)`) to be sent and fixed before the adversary can see or
  choose `nB`, then state a lemma of the shape "if the adversary did not control both `nA` and
  `nB`, a session where `SAS_attacker = SAS_honest` requires either (a) the adversary already knew
  the pre-image of the commitment — ruled out by the `restriction` — or (b) it guessed the
  6-digit value outright." Tamarin cannot natively quantify "probability ≤ 2⁻²⁰"; it can only
  show *that* a guess is unavoidable, i.e., that there is no attack strategy better than guessing
  a value from the stated 2²⁰ space. The quantitative bound itself is a counting argument outside
  Tamarin's logic (state it in the model's accompanying prose, as the OSUSecLab NDSS'23 paper does
  for Passkey Entry's guessing bound).
- In **ProVerif**, the native `weaksecret` query is built for exactly this: declare the SAS digit
  string as a weak secret and let ProVerif check that no derivation reveals it faster than
  brute-force guessing, which is the cleanest match to a probability-style guessing claim, though
  ProVerif likewise reports a binary yes/no on guessing-resistance rather than deriving the
  concrete 2⁻²⁰ figure itself.
- For an actual quantitative 2⁻²⁰-per-attempt bound with a quantified adversary advantage,
  **CryptoVerif**'s computational game-hopping proof style is the only one of the three tools that
  natively carries numeric probability terms through to the final theorem statement; this is the
  tool to reach for only if a literal numeric bound (not just qualitative guessing-resistance) is
  required by the gate.
- Encode the protocol-level commit-then-reveal ordering constraint itself (A commits to `nA`
  before learning `nB`; B sends `nB` before learning `nA`) as a hard precondition/restriction in
  whichever tool is used — this is the mechanism that prevents either party from grinding the code
  (findings §4.1, ADR 0005 §3), and it is exactly the property the OSUSecLab repo's commit-reveal
  modelling notes address.

## 5. Modelling PSK + DH Resume with ratchet erasure (FS, PCS, desync)

| Prior art | Paradigm / tool | What `pqcble-r1` reuses |
|---|---|---|
| Dowling, Paterson — "A Cryptographic Analysis of the WireGuard Protocol," ePrint 2018/080 / EuroS&P 2018 | Computational, pen-and-paper eCK-style model. **No public mechanized artifact** for this specific paper (confirmed: not linked from the WireGuard formal-verification page as a tool model). | The 1.5-RTT structure analysis and the **separate confirmation-key fix** — already applied in `pqcble-r1`'s `K_auth_R` (findings §4.2). |
| Donenfeld, Milner — WireGuard formal-verification paper (draft), `https://www.wireguard.com/papers/wireguard-formal-verification.pdf` | Symbolic, **Tamarin**. Model: `git://git.zx2c4.com/wireguard-tamarin/`. **License: GPLv2** (confirmed by fetching `COPYING` directly from the repo). | Proves correctness, strong key agreement/authenticity, KCI resistance, UKS resistance, key secrecy, forward secrecy, session uniqueness, identity hiding — the exact property list Resume needs. |
| Lipp, Blanchet, Bhargavan — "A Mechanized Cryptographic Proof of the WireGuard Virtual Private Network Protocol," EuroS&P 2019 (HAL `https://inria.hal.science/hal-02100345`) | Computational, **mechanized in CryptoVerif** (ACCE model). Model download linked from the WireGuard site: `https://benjaminlipp.de/master-thesis/master-thesis-cryptoverif.tar.gz` (license of the tarball itself: **UNVERIFIED**, not stated on the page). | Full transport-inclusive ACCE proof covering message secrecy, forward secrecy, mutual auth, KCI/UKS resistance, and **replay resistance of the first protocol message** — directly analogous to the S1 pseudonym+MAC replay requirement. *(Note: the design brief's attribution to "Lipp/Blanchet/Hülsing" is corrected here to Lipp/Blanchet/Bhargavan per the HAL author list.)* |
| `tls13tamarin/TLS13Tamarin`, `https://github.com/tls13tamarin/TLS13Tamarin` | Symbolic, Tamarin, versioned by TLS 1.3 draft revision (`src/rev21`). **License: none found** (GitHub API `/license` → null) — **UNVERIFIED**. | Closest published analogue for single-use/puncturable PSK-resumption modelling, since TLS 1.3 resumption PSKs are likewise single-use-then-erased in the standard's own security model. |
| Rosenpass, `https://github.com/rosenpass/rosenpass` | Symbolic, **ProVerif**-family (`.mpv` files under `analysis/`, e.g. `01_secrecy.entry.mpv`, `02_availability.entry.mpv`). **License: Apache-2.0** (confirmed via GitHub API `/license` → `LICENSE-APACHE`; repo may be dual-licensed, check for a `LICENSE-MIT` file if that matters). | The "biscuit" stateless-responder option (findings §9.3) as an alternative to storing `{CK_n, CK_{n+1}}`. Whether the ProVerif model specifically covers the biscuit mechanism (vs. only describing it in the whitepaper) is **UNVERIFIED** — the whitepaper body was not read. |
| Noise Explorer, `https://noiseexplorer.com/`, repo `https://github.com/symbolicsoft/noiseexplorer` | Auto-generates ProVerif `.pv` models from a Noise handshake-pattern description. **License: GPL-3.0** (confirmed via GitHub API and by fetching `LICENSE.md` directly, which begins "GNU GENERAL PUBLIC LICENSE / Version 3"). | Pattern-level forward-secrecy/KCI-resistance queries auto-generated per Noise pattern; useful as a generator template, though `pqcble-r1`'s Resume is not a stock Noise pattern (PSK chain key + fresh DH + separate confirmation key is closer to TLS 1.3 `psk_dhe_ke` per findings §9.3). |
| Linker, Sasse, Basin — "A Formal Analysis of Apple's iMessage PQ3 Protocol," ePrint 2024/1395, `https://eprint.iacr.org/2024/1395` | Symbolic, **Tamarin**. Abstract confirmed directly by fetch: "machine-checked security proofs using the TAMARIN prover," covering PQ3's PQ initialization phase and a double-ratchet-style construction extended for PQ post-compromise security, and explicitly stating the analysis covers **"both key ratchets, including unbounded loops"**, countering the belief that this is out of scope for Tamarin. **No public repository located** — searched GitHub for the authors and "PQ3 tamarin"; **UNVERIFIED/not found**. | The single closest prior-art model to `pqcble-r1` as a whole (PQ KEM epochs + ratchet + PCS). Use as the structural template for the Resume+ratchet-mixing lemma set even without a forkable repo. |

Signal's own current spec site (`https://signal.org/docs/`, fetched directly) documents PQXDH,
Double Ratchet, Sesame, and **ML-KEM Braid** — the live name for the amortized PQ-ratchet
construction `pqcble-r1`'s findings §4.4 calls "SPQR-like" (Signal's site does not currently use
"SPQR" or "Triple Ratchet" in its navigation). The ML-KEM Braid spec
(`https://signal.org/docs/specifications/mlkembraid/`, fetched directly) formalizes it as a
**Sparse Continuous Key Agreement (SCKA)** protocol with `Send(state) -> (msg, sending_epoch,
output_key)` / `Receive(state, msg) -> (receiving_epoch, output_key)` functions and named
correctness properties including **session key consistency**, per-participant epoch uniqueness,
and sender/receiver epoch agreement. No separate academic formal-verification paper of ML-KEM
Braid/SPQR itself (as opposed to PQXDH) was found — **UNVERIFIED/not found**; the PQXDH papers in
§3 are the closest available independent analysis of a structurally related Signal KEM ratchet.
Use the SCKA correctness-property names directly as the vocabulary for the ratchet-mixing lemma
list below.

## 6. Modelling effort estimate

Rough, unverified estimate based on the scope of the closest comparable published models (PQXDH:
multiple spec revisions each requiring new Tamarin files per the `revision1`…`revision3`
structure in `Inria-Prosecco/pqxdh-analysis`; PQ3: described by its authors as covering "both key
ratchets, including unbounded loops," implying a non-trivial multi-week modelling effort even for
an expert team). No effort figures are published in either paper's abstract, so the following is
inference, not a cited number — **mark as UNVERIFIED/estimate only**:

| Gate item | Relative effort | Why |
|---|---|---|
| SAS pairing | Low–Medium | Structurally close to the two existing Bluetooth NC/SSP Tamarin/ProVerif models (§4); mainly adapting commit-then-reveal ordering and the X-Wing KEM in place of ECDH. |
| Resume (PSK + DH, single-use CK_n) | Medium | Structurally close to WireGuard's Tamarin model and TLS 1.3 `psk_dhe_ke`/resumption Tamarin models (§5); the single-use/puncturable-PSK erasure needs explicit `restriction`s not present in a vanilla WireGuard model, since WireGuard's identity keys are long-term, not single-use chain keys. |
| Ratchet mixing (amortized ML-KEM epochs into CK) | High | No public reusable Tamarin library for the KEM-binding equational theory exists (Cremers–Dax–Medinger's library was not publicly locatable; PQ3's Tamarin model was not publicly locatable), so this item requires building the `encaps`/`decaps` equational theory and the `H(ek)‖H(ct)` binding axiom from scratch, following the style of `Inria-Prosecco/pqxdh-analysis`'s `WithKyberCR` revision, plus modelling the unbounded ratchet-epoch loop (PQ3 proved this is tractable, but did not publish code to reuse). |

Overall, expect the ratchet-mixing model to dominate total effort, given that it combines the two
hardest unsolved items (unbounded loops + KEM binding) with no directly forkable public artifact.

## 7. Recommendation

- **Primary tool: Tamarin**, for all three gate items, modelling KEMs as explicit
  `encaps`/`decaps` function symbols with an added binding restriction (§3), not as opaque
  asymmetric encryption.
- **Secondary/cross-check tool: ProVerif**, specifically for the SAS guessing-bound lemma via its
  native `weaksecret` query (§4), and optionally for a second, independent cross-check of the
  Resume authentication/secrecy lemmas.
- **Optional tertiary tool: CryptoVerif**, only if a literal numeric probability bound (the SAS
  2⁻²⁰, or a reduction-style bound on the X-Wing hybrid combiner) is required by the gate, citing
  Blanchet–Jacomme CSF'24 as the precedent for post-quantum/hybrid soundness in CryptoVerif.
- Build the ratchet-mixing model around the **SCKA `Send`/`Receive` correctness vocabulary** from
  Signal's ML-KEM Braid spec (§5) and the **KEM-binding axiom** from Cremers–Dax–Medinger /
  Bhargavan et al. (§3), since no forkable public code exists for either the PQ3 or the
  Cremers–Dax–Medinger Tamarin libraries — both are templates to imitate, not repositories to
  fork.
- Before reusing any code from `Inria-Prosecco/pqxdh-analysis` or `purseclab/btmodel_proverif`,
  resolve the license gap (both report `license: None` via the GitHub API) — contact the authors
  or treat as reference-only / reimplement independently.

## 8. Lemma lists per gate

### 8.1 Resume (PSK chain key + fresh X25519, single-use `CK_n`)

1. **Mutual authentication / agreement.** If I completes Resume with R (and vice versa), both
   agree on `CK_n`, `eI`, `eR`, and the transcript `th` — standard Tamarin injective-agreement
   style, as in the WireGuard Tamarin model's "strong key agreement" lemma.
2. **Session-key secrecy.** `SK_I→R` and `SK_R→I` are secret from an adversary that has not
   compromised `CK_n` for that epoch, modelled with the usual Tamarin `Secret`/`reveal` facts.
3. **Single-use / puncturable PSK.** `CK_n` is used to derive `CK_{n+1}` and the session keys at
   most once; a Tamarin restriction forbidding a second `Resume` action consuming the same `CK_n`
   fact, mirroring Aviram–Gellert–Jager's requirement (cited in findings §9.3) that forward
   security of resumption needs single-use/puncturable credentials.
4. **Forward secrecy.** Compromise of the long-term pairing state after session epoch `n`
   completes does not reveal `SK` for any epoch `< n` — standard FS lemma, modelled with a
   `LongTermKeyReveal` restricted to occur only after the target session's `Commit`.
5. **Post-compromise security (via the DH contribution).** If the adversary compromises `CK_n`
   but not the fresh `eI`/`eR` ephemeral secrets, the resulting `CK_{n+1}` (and hence `SK` at
   epoch `n+1`) is secret — the classical healing property credited to mixing `dh` into
   `CK_{n+1}` (findings §4.2).
6. **Replay resistance of S1.** A replayed S1 (pseudonym + MAC) does not let the adversary derive
   any session key, because R always contributes a fresh `eR` and the adversary lacks `eI`'s
   secret — directly analogous to the WireGuard CryptoVerif ACCE proof's "replay resistance of
   the first message" property (Lipp–Blanchet–Bhargavan, §5).
7. **Reflection/Selfie resistance.** No execution exists where I's own S1 (or R's own S2) is
   reflected back and accepted, enforced by the role label embedded in every KDF/MAC context
   (findings §4.2, citing RFC 9258 App. A and Drucker–Gueron ePrint 2019/347).
8. **Distinct confirmation key.** `K_auth_R` used in the S2 `confirm` MAC is never equal to, or
   derivable from, any session key `SK_I→R`/`SK_R→I` — the Dowling–Paterson WireGuard fix
   (findings §4.2); modelled as a lemma that the adversary cannot derive `SK` from `K_auth_R`
   alone or vice versa.
9. **Desync recovery / no permanent lockout.** If R's stored `{CK_n, CK_{n+1}}` candidate set
   does not include the chain key I actually advanced to, there exists a recovery trace (a later
   successful Resume) — a reachability (not just secrecy) lemma capturing the "losing a single
   message is recoverable" claim in findings §4.2.
10. **DoS / unauthenticated-S1 cost bound.** An adversary without a valid MAC cannot force R to
    perform the asymmetric X25519 computation — expressible as a reachability lemma that the
    `dh` action is only ever reached after a MAC-verification action on the same session.

### 8.2 Ratchet mixing (amortized ML-KEM-768 epoch bound by `H(ek)‖H(ct)`)

1. **KEM output secrecy.** The ML-KEM shared secret `ss` for a given epoch is secret from an
   adversary that has not compromised the corresponding long-term/ephemeral ML-KEM secret key for
   that epoch.
2. **Binding (anti-re-encapsulation).** No two distinct `(ek, ct)` pairs the adversary can
   construct or observe produce the same mixed contribution to `CK` — i.e., `CK_{n+1}` is a
   function that only equates sessions sharing the identical `H(ek)‖H(ct)` binder, directly
   encoding the Cremers–Dax–Medinger / Bhargavan et al. binding requirement (§3) and ruling out
   the re-encapsulation attack class identified for PQXDH.
3. **Epoch agreement (SCKA `Send`/`Receive` correctness).** If both parties complete an epoch,
   they agree on the `sending_epoch`/`receiving_epoch` identifiers and the output key for that
   epoch — the named correctness property **"session key consistency"** from Signal's ML-KEM
   Braid spec (§5), restated as a Tamarin agreement lemma.
4. **Monotonic epoch ordering.** Epoch identifiers strictly increase with no gaps for a given
   party, i.e., the epoch counter (findings §9.3's "epoch counter is monotonic" requirement) is
   never reused or rolled back — a restriction preventing re-entry into a consumed epoch.
5. **Unbounded-loop termination-independence.** The above properties hold for an unbounded number
   of ratchet epochs, not just a bounded prefix — following PQ3's explicit claim (ePrint
   2024/1395) that Tamarin can handle "both key ratchets, including unbounded loops."
6. **Mixing-time confidentiality interaction.** Compromising `CK_n` at the moment a completed PQ
   epoch is about to be mixed in at the next Resume does not retroactively reveal the PQ shared
   secret `ss` for that epoch (no mixing-order leak) — a secrecy lemma over the composed
   Resume+ratchet-mixing trace, since the gate treats these two components together.
7. **Post-compromise security via the PQ ratchet.** After a full compromise of all symmetric
   state (`CK_n` and any in-flight PQ keypair), once a subsequent PQ epoch completes and is mixed
   in, `CK` is secret again from that point on — the PQ-specific post-compromise-security
   property that is the entire purpose of the amortized ratchet (findings §4.4).
8. **No key phase / epoch confusion from frame position.** Because a completed epoch is mixed in
   only at the next Resume (ADR 0005 §"DATA frame"/"Padding"), no lemma should find a trace where
   a partially-received `ek`/`ct` chunk set is accepted as a completed epoch — a reachability
   lemma that the mixing action requires all chunks reassembled under the stated offset/epoch
   bookkeeping.

### 8.3 SAS pairing (commit-then-reveal, 6-digit, 2⁻²⁰ guessing bound)

1. **Commitment binding.** The committing party (A) cannot later open its commitment `H(nA)` to
   any value other than the `nA` it actually used to compute the SAS — standard commitment
   binding lemma, a prerequisite for every other SAS property.
2. **Order enforcement (no grinding).** No execution exists where A learns `nB` before sending
   its commitment, or where B learns `nA` before sending `nB` — encoded as a Tamarin restriction
   on event ordering, the mechanism credited in ADR 0005 §3 and findings §4.1 for preventing
   either side from grinding the 6-digit code.
3. **SAS agreement.** If both A and B accept the same SAS value and complete pairing, they agree
   on the full transcript `th` (and hence on `ek_A`, `ct`, and the nonces) — an authentication
   lemma tying the human-verified 6 digits to the cryptographic transcript, closing the MitM gap
   that OOB/SAS exists to prevent.
4. **Guessing-resistance (qualitative).** No adversary strategy exists that computes a matching
   SAS value for two distinct transcripts with probability better than an outright guess from the
   stated 2²⁰ space — expressed via ProVerif's `weaksecret` query (§4) or a Tamarin lemma of the
   form "every successful SAS match corresponds to either transcript equality or an explicit
   guess action," with the quantitative 2⁻²⁰ figure argued separately as a counting bound over the
   6-digit space (Tamarin/ProVerif do not themselves output a numeric probability).
5. **TOFU-mode downgrade visibility.** In TOFU mode (no SAS comparison performed), the model
   should produce a reachability witness showing the active-MitM trace is realizable — not a
   bug, but a documented lemma confirming TOFU's stated "no active-MitM protection at first
   contact" property (findings §9.4) is accurately scoped, with the later SAS/QR upgrade path
   shown to recover authentication from that point forward.
6. **QR-mode MitM-proofness.** When `H(ek_A)` is delivered out-of-band (QR), no active-MitM trace
   exists regardless of in-band attacker control — a secrecy/authentication lemma over the OOB
   channel treated as adversary-free, contrasting with SAS/TOFU's weaker guarantees.

## 9. Gaps and uncertainties

- PDF bodies of ePrint 2023/1933, 2024/702, and 2024/1395 were not accessible (Cloudflare-style
  gate on `eprint.iacr.org/*.pdf`); all claims about them rely on abstract/metadata text only, not
  independently re-verified artifact-availability statements or exact binding-notion names.
- No public repository was located for the Cremers–Dax–Medinger (2023/1933) Tamarin KEM-binding
  library, nor for the Linker–Sasse–Basin PQ3 (2024/1395) Tamarin model, despite GitHub searches
  across the known author accounts. Both are usable as structural templates only.
- Vaudenay SAS-MCA and MANA I/II have no located machine-checked (Tamarin/ProVerif/CryptoVerif)
  artifact; treat as pen-and-paper baselines only.
- `purseclab/btmodel_proverif`, `Inria-Prosecco/pqxdh-analysis`, and `tls13tamarin/TLS13Tamarin`
  all report `license: None` via the GitHub API as of 2026-10-05 — confirm directly with the
  authors before reusing code, rather than assuming permissive reuse.
- The design brief's attribution of the WireGuard CryptoVerif ACCE proof to "Lipp/Blanchet/
  Hülsing" does not match the published author list; the HAL record (`hal-02100345`) lists
  Lipp, Blanchet, and **Bhargavan**. No Hülsing-authored WireGuard CryptoVerif paper was found.
  Treat the original brief's third-author name as an error.
- Whether Rosenpass's published ProVerif models (`analysis/*.mpv`) specifically formalize the
  "biscuit" stateless-responder mechanism, or only describe it in the whitepaper prose, is
  unverified — the whitepaper body was not read in this pass.
- "SPQR" / "Triple Ratchet" is not the name used on Signal's current spec site; the live
  construction is named **ML-KEM Braid**. No independent academic formal-verification paper of
  ML-KEM Braid specifically (as distinct from PQXDH) was found.
- The modelling-effort table in §6 is an inference from the scope of comparable published models,
  not a cited estimate from any source — treat it as a planning starting point, not a verified
  figure.
- Legacy-advertising arithmetic, device-lab checks, and other unrelated open items from the main
  findings doc (§9.8) are out of scope here and not re-verified.
