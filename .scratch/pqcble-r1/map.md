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
- [Android↔iOS background discovery and transport feasibility](issues/04-android-ios-background-ble.md): fixed service UUID plus GATT-read beacon; GATT-first transport; L2CAP optional.
- [Formal verification gate](issues/07-formal-verification-gate.md): symbolic model gates Resume, PQ ratchet mixing and SAS pairing only.
- [Reference app scope](issues/08-reference-app-scope.md): minimal 1:1 chat with pairing flows plus a bytes/airtime debug panel.

## Not yet specified

- **Implementation slicing**: how the build is cut into vertical slices (core crates → FFI → BLE adapters → app), and in which order. This becomes specifiable once the threat model and key storage are settled.
- **Spec consolidation**: merging ADRs 0001–0005 and the wire draft into one `docs/spec/pqcble-r1.md`, plus test vectors. This depends on the formal-model results.

## Out of scope

- iOS↔iOS operation (especially backgrounded discovery) — not in the prototype platform pairs.
- Desktop (macOS/Windows/Linux) shells — deferred past this destination.
- Group messaging, multi-hop relay, BLE Mesh.
- Submitting our own module for CMVP/FIPS 140-3 certification.
