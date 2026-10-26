# Slice S1: Walking skeleton (loopback)

Type: task
Status: resolved
Blocked by: 26, 30

## Question

Build automatic admission (P0, the tie-break and the admission limits from spec §5.6), TOFU pairing (P1–P4), a basic Resume (spec §6, non-KCI, no rate limits or concurrent Resume) and CHAT DATA frames between two `CairnCore` instances over an in-memory loopback, driven through UniFFI from a KMP test. Rust tests use seeded randomness through a test-only `CryptoBackend`; the KMP loopback uses the real RNG and asserts outcomes. Later slices reuse the harness. Switch on the gates for `cairn-wire` fuzzing and the constant-time taint check on `cairn-proto`.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments

2026-10-23: re-scoped by the owner. Pairing starts automatically for every
stranger ([ADR 0021](../../../docs/adr/0021-automatic-neighbour-admission.md)), and a basic Resume moves here from S7 because DATA keys
come only from Resume. A `CairnCore` contract ADR comes first.

2026-10-23: the contract is [ADR 0022](../../../docs/adr/0022-cairn-core-contract.md).
The owner chose minimal beacons in S1 (the §10.1 value, day ratchet and
constant-time match on the `beacon` read; advertising stays in S6),
`ChatRejected(NoSession)` instead of queuing, and four stacked PRs.

2026-10-23: PR (b) adds the spec §4.2 header to `cairn-wire` and, in
`cairn-proto`, fragmentation and reassembly, the admission ledger and P0
tie-break, P1–P4 pairing and the version-1 persistence blob behind the
`Core` event loop. Persistence moved from PR (c) to PR (b) because the
contact record is what pairing produces. Two cores pair over a seeded
in-memory loopback in `core/cairn-proto/tests/admission.rs`.

2026-10-23: PR (c) adds beacons, Resume and DATA/CHAT to `Core`. The owner
chose an empty DATA frame from I as key confirmation. Concurrent Resume
(OI-17) and Resume rate limits stay deferred; meanwhile a new link for a
contact that already has a Resume or session link is closed. See
[ADR 0022](../../../docs/adr/0022-cairn-core-contract.md) §10 and
`core/cairn-proto/tests/session.rs`.

2026-10-23: PR (d) is split in two. PR (d1) exports `CairnCore` through
UniFFI, adds Rust and KMP loopbacks with the real backend and migrates the
reference app. It also makes `BeaconRead` carry bytes (a wrong length closes
the link and backs off the address), and a panic poisons the core so later
calls fail with `CoreException.Poisoned`. PR (d2) adds the fuzz targets and
the constant-time taint check behind a hidden `probes` feature. See
[ADR 0022](../../../docs/adr/0022-cairn-core-contract.md) §3 and §9.

2026-10-23: PR (d2), #41, landed the gates. `core/ct` taints every
`cairn-proto` secret comparison through `probes`. The `framing`, `records`
and `session` fuzz targets run per PR. The `session` fuzzer found peer
X-Wing faults (an ML-KEM modulus failure, or a low-order X25519 share)
surfacing as `CoreError::Crypto`. They now fail pairing as malformed. See
[ADR 0022](../../../docs/adr/0022-cairn-core-contract.md) §8.

2026-10-26: Android device demonstration. `main` at `adb9439`, debug APK
(`arm64-v8a`, `armeabi-v7a`; SHA-256 prefix `3fc07106486a0c51`), run with
`am instrument -w ch.trancee.cairn.android/.CoreStatusInstrumentation`.
This drives `coreStatus()`: two `CairnCore`s pair, chat and close over the
in-memory loopback, through `:app` → `:sdk` → Rust.

| Role | Device | API | Result |
|---|---|---:|---|
| Oldest | Huawei P10 lite (WAS-LX1A, Kirin 658) | 26 | `PASS: paired=1+1 chat=hello rejected=NotRestored closed=true` |
| Newest | Nothing Phone (2) (A065, SM8475) | 36 | `PASS: paired=1+1 chat=hello rejected=NotRestored closed=true` |

The Android instrumentation now compares against the shared
`EXPECTED_CORE_STATUS`, and both phones pass again.

iPhone demonstration: `:app` gains iOS targets and a `CairnApp` framework,
and `iosApp/` is a minimal SwiftUI shell that runs the same `coreStatus()`
at launch (see `iosApp/README.md`). Built with Xcode 27.1 at `minos 15.0`:

| Device | iOS | Result |
|---|---|---|
| iPhone SE (2020) | 18.7.8 | `PASS: paired=1+1 chat=hello rejected=NotRestored closed=true`, exit 0 (`devicectl --console … -selfTest`) |
| iPhone 12 mini (newest) | 27.0.1 | `PASS: paired=1+1 chat=hello rejected=NotRestored closed=true`, exit 0 (`devicectl --console … -selfTest`) |
| iPhone 15 | 17.6.1 | `PASS` on screen; installed with `ios-deploy`, because CoreDevice did not list it; the log capture was lost |

Not run: the matrix's oldest phone, the iPhone SE (1st gen) on iOS 15.8.8. Xcode
27 does not offer it as a destination, so automatic signing cannot add
it to the profile.

2026-10-26: resolved by the owner. S1 has passed on the oldest and newest
Android phones and on three iPhones, including the newest (iOS 27.0.1).
The iOS 15 floor phone moves to [issue 48](48-apple-lane-ios-targets.md).
