# Implementation slicing

Type: grilling
Status: resolved
Blocked by: none

## Question

How is the build cut into vertical slices across the Rust core crates, the UniFFI FFI, the Android and iOS BLE adapters, the KMP SDK and the reference app, and in which order? Each slice should be demoable end to end. Cover:
- which slices may start before the formal models land (the formal-verification gate covers only Resume, PQ ratchet mixing and SAS);
- the first walking skeleton;
- when the CI gates from ADR 0007 switch on;
- the repo and Gradle/Cargo layout of the first commit;
- the definition of done per slice.

## Comments

## Answer

Grilled in one round on 2026-10-05; all recommendations accepted. No ADR: this is a reversible plan, not an architectural trade-off.

- **Order.** Twelve vertical slices, S0–S11, tracked as task tickets on this map with blocking edges:
  - Slice S0: Bootstrap
  - Slice S1: Walking skeleton (loopback)
  - Slice S2: Android↔Android over BLE
  - Slice S3: Android↔iOS
  - Slice S4: QR pairing and pairing hub
  - Slice S5: Sealed storage and store-and-forward
  - Slice S6: Beacons, discovery and background
  - Slice S7: Resume
  - Slice S8: SAS pairing and in-chat Verify
  - Slice S9: PQ ratchet
  - Slice S10: Doorbell and KCI profile
  - Slice S11: Debug panel and measurement
- **Walking skeleton.** An in-memory loopback through UniFFI from a KMP test, before any BLE.
- **Formal-model gate.** Strict: Resume, SAS and the ratchet don't start until their model tickets resolve.
- **Spec gate.** S0 starts now; S1 and later wait for Spec consolidation.
- **CI gates.** Each ADR 0007 gate switches on, blocking, in the slice that adds the code it covers.
- **Definition of done.** Gates green, TDD, spec sections referenced, and a demo on the oldest and newest core-matrix devices of each platform pair.
- **Build.** One root Gradle build (`:sdk`, `:app`, version catalog). Ubique's unified plugin builds the `core/` Cargo workspace, which also builds standalone.
- **Git.** `git init` with `main`, a feature branch per slice, and commits only with the user's approval.
