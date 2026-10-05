# Map: pqcble-r1 — PQC peer-to-peer over BLE

Label: `wayfinder:map`

## Destination

A working `pqcble` SDK (Rust core + Kotlin Multiplatform/Compose Multiplatform shell) and a minimal reference chat app that establish post-quantum, FIPS-conformant, constant-time peer-to-peer sessions over plain BLE (no Bluetooth bonding) and exchange real-time and store-and-forward messages, end-to-end on Android↔Android and Android↔iOS — preceded by a written `pqcble-r1` spec + ADRs.

## Notes

- **Execution is in scope** (override of wayfinder's plan-only default): the destination is a working prototype, so later tickets may build. Gate: spec + ADRs for every protocol/crypto/wire decision exist **before** implementation of that part (`CONSTITUTION.md` O3, S6).
- Baseline research: [`PQC over BLE findings`](../../docs/research/2026-10-05-pqc-over-ble-findings.md) (protocol sketch §4, open questions §8, round-2 research §9) and [`ble_airtime.py`](../../docs/research/ble_airtime.py).
- Settled at charting (user answers, 2026-10-05):
  - Product: SDK + reference app; messages: real-time **and** store-and-forward.
  - Topology: pairwise P2P only; "introduction" = app-layer, no BLE pairing/bonding.
  - Security level: ML-KEM-768 (NIST L3).
  - Prototype platforms: Android↔Android, Android↔iOS.
  - Protocol scope: Introduction (QR, SAS, TOFU), Resume, Data frames, PQ ratchet, Beacons, Doorbell (connectionless), KCI profile — all in.
  - Shell: KMP + Compose Multiplatform over a Rust core.
  - FIPS: approved algorithms now; hybrid with X25519 allowed via an SP 800-56C/227-conformant combiner (ML-KEM is the approved component); CMVP-validated module is the later target behind a crypto backend seam. AEAD therefore AES-256-GCM.
  - Background operation required on both Android and iOS.
  - Store-and-forward: encrypt at send time with a Signal-style skipped-message-key window (details in *Store-and-forward sync semantics*).
- Skills every session should consult: `grilling`, `domain-modeling`; by topic: `ble-protocol-stack`, `ble-throughput`, `android-ble`, `android-ble-gatt-server`, `android-bluetooth-sockets`, `corebluetooth`, `kotlin-multiplatform`, `compose-multiplatform`, `tdd`, `security-audit`, `wycheproof`, `nist-cavp`.
- Standing rules: established primitives only (no novel crypto); no commits/pushes without explicit approval; research findings go to `docs/research/` and are linked from the ticket (no throwaway branches — commits need approval).
- Refer to tickets by name.

## Decisions so far

<!-- one line per resolved ticket: [title](issues/NN-slug.md): gist -->

- [Minimum OS versions](issues/06-minimum-os-versions.md): Android 8 (API 26) / iOS 15; a GATT-only path is mandatory and ML-KEM ships in the Rust core.
- [FIPS-validated modules providing ML-KEM](issues/01-fips-validated-mlkem-modules.md): no module is validated on both mobile platforms yet; claim "approved algorithms" for now and keep the backend seam.
- [FIPS-conformant hybrid KEM combiner](issues/02-fips-hybrid-kem-combiner.md): X-Wing is acceptable under SP 800-227; AES-256-GCM is required; truncated tags/PRFs ≥ 64 bit.
- [Kotlin Multiplatform + Rust core + BLE toolchain viability](issues/03-kmp-rust-ble-toolchain.md): Gobley bindings; platform-specific BLE code; iOS floor is ≥ 15.
- [Android↔iOS background discovery and transport feasibility](issues/04-android-ios-background-ble.md): fixed service UUID plus GATT-read beacon; GATT-first transport; L2CAP optional.
- [Formal verification gate](issues/07-formal-verification-gate.md): symbolic model gates Resume, PQ ratchet mixing and SAS introduction only.
- [Reference app scope](issues/08-reference-app-scope.md): minimal 1:1 chat with introduction flows plus a bytes/airtime debug panel.

## Not yet specified

- **Threat model & security goals document** — exact adversary model (active MITM at introduction, device seizure, tracking adversary), which properties each mode claims (FS, PCS, KCI, unlinkability); likely graduates once the crypto suite is fixed.
- **Key storage & state persistence** — Android Keystore / iOS Keychain + Secure Enclave usage, backup exclusion, monotonic-counter proof, behavior on app reinstall/restore.
- **Constant-time & conformance CI** — dudect / valgrind taint / Binsec, ACVP/CAVP vectors, Wycheproof, fuzzing of parsers; depends on chosen backend.
- **Formal model scope details** — which tool, which lemmas; depends on the formal-verification gate decision.
- **Beacon & discovery tuning** — window length, truncation size, rotation vs iOS/Android advertising limits; depends on background-discovery research.
- **SAS / QR introduction UX** — exact screens, emoji list, error/abort flows; depends on reference-app scope.
- **Packaging & distribution** — XCFramework/AAR/Maven, App Store export compliance (`ITSAppUsesNonExemptEncryption`, BIS), privacy manifest.
- **Energy & airtime validation methodology** — how to measure on real devices against the model.
- **External cryptographic review** — whether/when, by whom.

## Out of scope

- iOS↔iOS operation (especially backgrounded discovery) — not in the prototype platform pairs.
- Desktop (macOS/Windows/Linux) shells — deferred past this destination.
- Group messaging, multi-hop relay, BLE Mesh.
- Submitting our own module for CMVP/FIPS 140-3 certification.
