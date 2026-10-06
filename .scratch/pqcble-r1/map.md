# Map: pqcble-r1 — PQC peer-to-peer over BLE

Label: `wayfinder:map`

## Destination

A working `pqcble` SDK (Rust core + Kotlin Multiplatform/Compose Multiplatform shell) and a minimal reference chat app that establish post-quantum, FIPS-conformant, constant-time peer-to-peer sessions over plain BLE (no Bluetooth bonding) and exchange real-time and store-and-forward messages, end-to-end on Android↔Android and Android↔iOS — preceded by a written `pqcble-r1` spec + ADRs.

## Notes

- **Execution is in scope** (override of wayfinder's plan-only default): the destination is a working prototype, so later tickets may build. Gate: spec + ADRs for every protocol/crypto/wire decision exist **before** implementation of that part (`CONSTITUTION.md` O3, S6).
- Baseline research: [`PQC over BLE findings`](../../docs/research/2026-10-05-pqc-over-ble-findings.md) (protocol sketch §4, open questions §8, round-2 research §9) and [`ble_airtime.py`](../../docs/research/ble_airtime.py).
- Settled at charting (user answers, 2026-10-05):
  - Product: SDK + reference app; messages: real-time **and** store-and-forward.
  - Topology: pairwise P2P only; "pairing" = `pqcble` app-layer pairing, never Bluetooth pairing/bonding (see `GLOSSARY.md`).
  - Security level: ML-KEM-768 (NIST L3).
  - Prototype platforms: Android↔Android, Android↔iOS.
  - Protocol scope: Pairing (QR, SAS, TOFU), Resume, Data frames, PQ ratchet, Beacons, Doorbell (connectionless), KCI profile — all in.
  - Shell: KMP + Compose Multiplatform over a Rust core.
  - FIPS: approved algorithms now; hybrid with X25519 allowed via an SP 800-56C/227-conformant combiner (ML-KEM is the approved component); CMVP-validated module is the later target behind a crypto backend seam. AEAD therefore AES-256-GCM.
- Vocabulary: [`GLOSSARY.md`](../../GLOSSARY.md); decisions: [`docs/adr/`](../../docs/adr/).
  - Background operation required on both Android and iOS.
  - Store-and-forward: see ADR 0002.
- Skills every session should consult: `grilling`, `domain-modeling`; by topic: `ble-protocol-stack`, `ble-throughput`, `android-ble`, `android-ble-gatt-server`, `android-bluetooth-sockets`, `corebluetooth`, `kotlin-multiplatform`, `compose-multiplatform`, `tdd`, `security-audit`, `wycheproof`, `nist-cavp`.
- Standing rules: established primitives only (no novel crypto); no commits/pushes without explicit approval; research findings go to `docs/research/` and are linked from the ticket (no throwaway branches — commits need approval).
- Refer to tickets by name.
- Current ratchet contract: spec draft 0.6 includes CK-bound recovery,
  conditional honest-epoch healing, durable KEM_PROGRESS and strict
  contiguous reassembly (OI-21-26). The composed model loads cleanly, but
  its cryptographic/helper, execution/recovery and mutation proofs remain
  incomplete. *Formal model: PQ ratchet mixing* stays claimed; its
  implementation gate is closed.

## Decisions so far

<!-- one line per resolved ticket: [title](issues/NN-slug.md): gist -->

- [Minimum OS versions](issues/06-minimum-os-versions.md): Android 8 (API 26) / iOS 15; a GATT-only path is mandatory and ML-KEM ships in the Rust core.
- [FIPS-validated modules providing ML-KEM](issues/01-fips-validated-mlkem-modules.md): no module is validated on both mobile platforms yet; claim "approved algorithms" for now and keep the backend seam.
- [FIPS-conformant hybrid KEM combiner](issues/02-fips-hybrid-kem-combiner.md): X-Wing is acceptable under SP 800-227; AES-256-GCM is required; truncated tags/PRFs ≥ 64 bit.
- [Kotlin Multiplatform + Rust core + BLE toolchain viability](issues/03-kmp-rust-ble-toolchain.md): Gobley bindings; platform-specific BLE code; iOS floor is ≥ 15.
- [Kompact suitability for pqcble payload encoding](issues/14-kompact-payload-encoding.md): not adopted; no savings on crypto-dominated frames; chat envelope uses a Rust presence-bitmap layout.
- [Crypto suite and parameter set under FIPS](issues/05-crypto-suite-under-fips.md): X-Wing / ML-KEM-768 / X25519-as-T / SHA-384 / AES-256-GCM, no signatures, no negotiation; see ADR 0001.
- [Store-and-forward sync semantics](issues/09-store-and-forward-semantics.md): seal at send with per-session-reseeded message chains, two layers for queued only, acks/resend/dedup, 500 msgs/7 days; see ADR 0002.
- [Data transport and fragmentation](issues/10-data-transport-and-framing.md): symmetric discovery, GATT beacon/rx/tx/psm, MORE-bit fragmentation, 4096/2560 B limits, flagged L2CAP CoC upgrade; see ADR 0003.
- [Rust core architecture and crypto backend seam](issues/11-rust-core-architecture.md): sans-IO `handle(event)->actions` core, compile-time CryptoBackend with 2 adapters, keystore-sealed Persist/Restore, core/sdk/app monorepo; see ADR 0004.
- [Wire-format byte layouts](issues/12-wire-format-layouts.md): 1 B header (MORE|type|sub), version only in QR/P1, 4-message pairing, S1 57 B / S2 49 B, record-based DATA with bucket padding, shared device beacon, doorbell = 8 B HMAC tag in beacon slot; see ADR 0005.
- [Device test lab](issues/13-device-test-lab.md): 23 Android (SDK 26–36) + 4 iPhones (iOS 15–26), no sniffer; core matrix of 8 Android + 3 iPhones.
- [Threat model and security goals](issues/15-threat-model.md): A1–A7 in scope, compromised OS/physical/jamming/proximity out; FS + PCS claims; TOFU passive-only; QR gains 4-digit confirm; see `docs/spec/threat-model.md`.
- [Constant-time and conformance tooling for the Rust core](issues/17-ct-conformance-tooling.md): CT tools are Linux-only (no on-device proof); ACVP + Wycheproof per PR, dudect advisory nightly, X-Wing cross-checked vs BoringSSL/CIRCL.
- [Packaging, distribution and export compliance](issues/22-packaging-export-compliance.md): AAR/Maven + XCFramework/SPM; non-exempt encryption → EAR 5D002 via ENC/§742.15(b) open-source notice + ANSSI for France; UniFFI/Gobley MPL-2.0.
- [Energy and airtime measurement methodology](issues/23-energy-methodology.md): HCI-snoop airtime (precise) + baseline-subtracted relative battery drain; no absolute joules possible with this lab.
- [Formal model tooling and lemmas](issues/19-formal-model-tooling.md): Tamarin primary (+ProVerif for SAS bound, CryptoVerif optional); explicit KEM binding; lemma lists for Resume/ratchet/SAS.
- [Key storage and state persistence](issues/16-key-storage.md): after-first-unlock keys, Keystore/Keychain AES master key, SQLite with one transaction per Persist batch, core-held per-contact storage keys (crypto-shred), no backups; see ADR 0006.
- [Constant-time and conformance CI gates](issues/18-ct-conformance-gates.md): per-PR blocking KATs/Wycheproof/X-Wing cross-vectors/differential/valgrind taint; dudect+long fuzz nightly advisory; on-device timing pre-release; see ADR 0007.
- [Beacon and discovery tuning](issues/20-beacon-discovery-tuning.md): per-state duty cycle, 5-min window + adv restart w/ jitter, rate-limited purposeful connects, idle Resume ≥6 h, no-overlap key rotation, ≤2 %/24 h idle target; see ADR 0008.
- [External cryptographic review](issues/24-external-review.md): required before any non-prototype release (not the prototype); stage 1 spec+models (academics + public ePrint), stage 2 Rust-core audit (firm); Critical/High must be fixed.
- [SAS and QR pairing UX](issues/21-pairing-ux.md): hub screen (my QR + scanner, SAS/TOFU as fallback links), in-chat Verify upgrade, 6-digit SAS only, upgrade mismatch → Compromised contact (sending blocked), 120 s timeout, prefilled editable name, dev-only debug panel; see ADR 0009.
- [Implementation slicing](issues/25-implementation-slicing.md): 12 vertical slices from S0 (bootstrap) through S11 (measurement), tracked as tickets; in-memory loopback skeleton first; strict formal-model gate; S1+ wait for Spec consolidation; CI gates switch on with their code; DoD = gates + TDD + oldest/newest device demo.
- [Spec consolidation](issues/26-spec-consolidation.md): `docs/spec/pqcble-r1.md` draft 0.2 (normative); 15 consolidation issues resolved, including the beacon key in the card, new BEACON_KEY/BEACON_ACK/EPOCH_DONE records, encrypted msgno in QUEUED, epoch cadence ≥10 Resumes/24 h, and KCI at pairing only; ADRs 0001/0002/0005/0008 amended.
- [Formal model: SAS pairing](issues/29-formal-model-sas.md): Tamarin model of QR/SAS/TOFU/Verify verified (16 lemmas); found mode downgrade → B checks `P1.mode` (OI-19); SAS/TOFU roles: picker is B (OI-20); `weaksecret` replaced by counting argument; spec draft 0.4.
- [Formal model: Resume](issues/27-formal-model-resume.md): all four profiles re-verified with public `pairID` (16/17/19/20 lemmas); OI-16/17/18 regressions retained. Resume gate restored; composed ratchet gate remains pending.
- [Android↔iOS background discovery and transport feasibility](issues/04-android-ios-background-ble.md): fixed service UUID plus GATT-read beacon; GATT-first transport; L2CAP optional.
- [Formal verification gate](issues/07-formal-verification-gate.md): symbolic model gates Resume, PQ ratchet mixing and SAS pairing only.
- [Reference app scope](issues/08-reference-app-scope.md): minimal 1:1 chat with pairing flows plus a bytes/airtime debug panel.

## Not yet specified

- **Test vectors and spec freeze**: once the reference implementation exists, generate vectors, pin them in the spec, and freeze `pqcble-r1` (this precedes stage 1 of the external review).

## Out of scope

- iOS↔iOS operation (especially backgrounded discovery) — not in the prototype platform pairs.
- Desktop (macOS/Windows/Linux) shells — deferred past this destination.
- Group messaging, multi-hop relay, BLE Mesh.
- Submitting our own module for CMVP/FIPS 140-3 certification.
- Commissioning the external review itself (selecting vendors, setting a budget): it happens after the prototype, before a non-prototype release; see [External cryptographic review](issues/24-external-review.md).
