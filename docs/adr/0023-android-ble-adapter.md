---
status: accepted
date: 2026-10-24
version: cairn-r1
---

# 0023: Android BLE adapter for slice S2

## Context

Slice S2 ([issue 32](../../.scratch/cairn-r1/issues/32-slice-s2.md)) carries the
S1 flow (admission, pairing, Resume and CHAT) between two Android phones over
BLE. [ADR 0003](0003-ble-transport.md) fixes the transport: symmetric
discovery, a GATT service with `beacon`, `rx`, `tx` and `psm`, platform
backpressure and no transport acks. [ADR 0022](0022-cairn-core-contract.md)
fixes the `CairnCore` contract: the core fragments and reassembles, and the
platform only moves ATT values, runs timers and reports links.

Three constraints shape the Kotlin side:

- CONSTITUTION T3 requires 100% line and branch coverage in CI for
  maintained production code. Kotlin has no coverage engine yet.
- Android host tests in `:sdk` are off: Ubique's host library never reaches
  the AGP KMP host-test classpath ([ADR 0020](0020-root-gradle-wire-ffi.md)).
- BLE callbacks arrive on binder threads, while `CairnCore` expects one
  caller at a time and ordered events.

The spec left the GATT UUIDs open (§12).

## Decision

The owner chose the coverage route, in-memory persistence, Material 3 and
the timing-test split on 2026-10-24. The other rules follow from ADR 0003,
ADR 0022 and the spec.

### 1. GATT UUIDs

Random v4 values, recorded in spec §12 (draft 0.8). `tx` carries the
standard CCCD (`0x2902`).

### 2. Link driver and radio

The platform-neutral `LinkDriver` in `:sdk` `commonMain` sits between
`CairnCore` and a platform `Radio`. Every iOS and Android adapter reuses it.

- **Confinement.** The driver is not thread-safe. The platform calls it from
  one thread and posts BLE callbacks there.
- **Links.** `linkUp` allocates a `LinkId`, counting up from 1, never reused
  (ADR 0022 §4). The radio maps its connection objects to these ids.
- **Send queue.** Each link sends one fragment at a time, in order. The radio
  reports `sent(link)` when the platform accepts the next one (Android
  `onCharacteristicWrite` or `onNotificationSent`). The queue is bounded at
  32 KiB of unconfirmed fragment bytes per link; a 4096 B frame takes
  4320 B at ATT MTU 23. Overflow disconnects the link.
- **Disconnect.** `Disconnect` drops the link's queued fragments and closes
  it. The core learns that the link is gone from the radio's `linkDown`, like
  any other loss; a late event for a link the core closed is ignored
  (ADR 0022 §3).
- **Timers.** `SetTimer` and `CancelTimer` go to a platform `Timers`; expiry
  calls `timerFired`.
- **Clock.** A platform clock supplies `mono_ms` (monotonic since boot) and
  `unix_s` for every event.
- **Persistence.** S2 keeps the last `Persist` blob in memory only, so a
  process restart forgets contacts. Sealed storage arrives in S5 (ADR 0006).
- **Errors.** `CoreException.Crypto` drops the batch, as ADR 0022 §3
  describes, and is reported to the app. `Poisoned` disconnects every link,
  cancels every timer and replaces the core with a new one restored from the
  last blob; queries retry once on the replacement. Any other
  `CoreException` is a driver bug and propagates.
- **Notices.** Contacts, received, sent and rejected chats, faults and link
  statistics reach the app through one listener, on the driver's thread.
- **Debug panel, first fields.** Per link: GATT role, ATT MTU, fragments and
  bytes in each direction, and time since link-up. ADR 0009 adds pairing
  details later; nothing shown is secret.

### 3. Android radio

- **Module.** A separate Android library module implements `Radio`. Its
  tests are Robolectric host tests that never load the Rust library, which
  avoids the ADR 0020 gap.
- **Discovery.** S2 advertises only the fixed service UUID (legacy,
  connectable) and scans with a filter on it, while the app is in the
  foreground. Beacons in advertising data, duty cycles and background
  operation stay in S6. The central reads `beacon` on every link, as for a
  peer whose advertised beacon matched nothing (ADR 0003).
- **Central.** `connectGatt` over LE without auto-connect, then MTU 517,
  service discovery and the `tx` CCCD write. Only then does it report
  `linkUp` and read `beacon`.
- **Peripheral.** The GATT server reports `linkUp` at ATT MTU 23 when a
  central connects, and `MtuChanged` when the MTU changes. A `beacon` read is
  answered from `CairnCore.beacon`. A `psm` read returns an ATT error, since
  S2 does not open L2CAP CoC.
- **Permissions.** On API 31+, `BLUETOOTH_SCAN` with `neverForLocation`,
  `BLUETOOTH_CONNECT` and `BLUETOOTH_ADVERTISE`. On API 26–30, `BLUETOOTH`,
  `BLUETOOTH_ADMIN` and `ACCESS_FINE_LOCATION`, capped at `maxSdkVersion 30`.

### 4. Coverage

- Kover `0.9.11` with its default IntelliJ engine measures `:sdk`
  (`jvmTest`) and the Android modules (Robolectric host tests). The gate is
  100% lines and branches.
- The only exclusion is the UniFFI-generated package `ch.trancee.cairn.ffi`.
- Kover reports `0.9.x` as stable releases; the guidance's beta label is
  accepted as is.

### 5. Reference app

- A minimal Material 3 chat screen: contacts and one conversation.
- The debug-panel fields from §2.

### 6. Timing smoke test

The on-device timing smoke test of [ADR 0007](0007-ct-conformance-gates.md)
moves to its own issue. S2 covers the BLE adapter, the chat screen and the
debug panel.

## Consequences

- iOS (S3) implements only the `Radio`; link ids, queues, timers and errors
  are shared and tested once.
- Until S5, every app restart forces a new admission with every neighbour.
- Foreground-only discovery means two phones pair only while both apps are
  open.
- The two links that form when both phones connect at once are resolved by
  the admission tie-break (spec §5.6), and later by the one-link-per-contact
  rule (ADR 0022 §10).

## Alternatives considered

- **Platform code calls `CairnCore` directly.** Less code, but each platform
  reimplements queues, timers and errors, and the Android code needs
  Robolectric for logic that is not Android-specific.
- **Coroutines and a mutex instead of thread confinement.** Adds a
  dependency and suspension points into a synchronous core.
- **Emulator instrumentation with JaCoCo over netsim.** Proves real radio
  calls, but is heavy and unproven in the isolated lane.
- **Device demonstration as the only proof of the radio glue.** Deviates
  from T3.
- **Unsealed persistence before S5.** Contacts survive restarts, but the
  blob would be stored against ADR 0006 and spec §11.
