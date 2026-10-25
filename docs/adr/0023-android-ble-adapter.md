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

- **Seam.** The radio reports to a `RadioListener` (`linkUp`, `mtuChanged`,
  `received`, `sent`, `linkDown` and `beacon`), which the driver implements.
  The app may wrap it to observe radio events, for example to refresh the
  debug panel.
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

- **Module.** The Android library module `:androidBle` implements `Radio` as
  `AndroidRadio`. Its tests are Robolectric host tests that never load the
  Rust library, which avoids the ADR 0020 gap.
- **Threading.** Every call runs on one `Handler` thread, and every platform
  callback is posted there. `send` and `disconnect` are posted too, because
  the driver calls them while it dispatches, possibly before `linkUp`
  returned the id.
- **Start and stop.** `start` needs Bluetooth on and both the scanner and
  the advertiser; otherwise it starts nothing and returns false. It is
  idempotent. `stop` stops discovery, closes every connection and reports
  `linkDown` for each link at once.
- **Adapter state.** From `start` until `stop`, the radio follows
  `BluetoothAdapter.ACTION_STATE_CHANGED`, received on its `Handler`. On
  `STATE_TURNING_OFF` or `STATE_OFF` it closes every connection and the GATT
  server, reports `linkDown` for each link, and reports `availability(false)`.
  It doesn't stop scanning or advertising itself: the stack drops both, and
  the calls throw `IllegalStateException` once the adapter has left
  `STATE_ON`. On `STATE_ON` it opens everything again and reports
  `availability(true)`; if that fails, it reports nothing. This also covers
  a `start` while Bluetooth was off. The trigger was a controller fault in
  fleet4 (issue 53): the system restarted Bluetooth within 2 s, and the old
  radio stayed silent for the rest of the run. `availability` is a callback
  on `AndroidRadio`, not on `RadioListener`, because adapter state is a
  platform concern the core never sees.
- **Discovery.** S2 advertises only the fixed service UUID (legacy,
  connectable) and scans with a filter on it, while the app is in the
  foreground. Beacons in advertising data, duty cycles and background
  operation stay in S6. The central reads `beacon` on every link, as for a
  peer whose advertised beacon matched nothing (ADR 0003).
- **Central.** `connectGatt` over LE without auto-connect, then MTU 517,
  service discovery and the `tx` CCCD write. Only then does it report
  `linkUp` and read `beacon`. A write to `rx` waits for that read, since
  Android runs one GATT operation per connection. Dials follow spec §10.4:
  a random 0–3 s delay after an address is first seen, two retries after a
  random 1–5 s and 5–15 s when a dial fails before `linkUp`, otherwise one
  dial per address every 2 minutes. The address is only this back-off key.
  The radio gates dials on scan results rather than timers, so a peer that
  stops advertising is not dialled. Each failed dial logs its stage, status,
  elapsed time and next delay under the tag `CairnRadio`, with only the last
  two address bytes.
- **Peripheral.** The GATT server reports `linkUp` when the central enables
  `tx` notifications, at the MTU the central negotiated (23 by default), and
  `MtuChanged` when the MTU changes later. Writes to `rx` before that are
  refused. A `beacon` read is answered from `CairnCore.beacon`. A `psm` read
  returns an ATT error, since S2 does not open L2CAP CoC.
- **API 33.** On API 33+ the radio uses the value-taking write and notify
  calls and the value-bearing read and notification callbacks; below, the
  deprecated ones.
- **Link trace.** At debug level under `CairnRadio`, the radio logs each
  link's `up` (role and MTU), every fragment `in` and `out` (header byte,
  size and milliseconds since `up`), and `down`. It logs no addresses and no
  payload bytes. An `out` is logged when the fragment is queued, not when it
  goes over the air.
- **Connection priority and PHY.** On connecting, the central requests
  `CONNECTION_PRIORITY_HIGH` and prefers the LE 2M PHY both ways, so
  pre-auth fragments arrive in time under load (issue 52). Ten seconds later
  it requests `CONNECTION_PRIORITY_BALANCED` again, if the link is still
  open: the length of two spec §4.4 deadlines, for pairing and then Resume.
  The revert is timed, not tied to session start, since the core reports no
  such event. The controller may decline either request, so a refusal
  doesn't close the link. The PHY result is logged as `dial … phy`. The
  peripheral requests neither; the central owns the connection parameters.
- **Permissions.** On API 31+, `BLUETOOTH_SCAN` with `neverForLocation`,
  `BLUETOOTH_CONNECT` and `BLUETOOTH_ADVERTISE`. On API 26–30, `BLUETOOTH`,
  `BLUETOOTH_ADMIN` and `ACCESS_FINE_LOCATION`, capped at `maxSdkVersion 30`.

### 4. Coverage

- Kover `0.9.11` with its default IntelliJ engine measures `:sdk`
  (`jvmTest`) and the Android modules (Robolectric host tests,
  `koverVerifyDebug`). The gate is 100% lines and branches.
- Robolectric `4.17` runs every Android host test on API 26 and API 37. It
  loads pinned `android-all` jars that Gradle resolves like any other input,
  never from the network (`gradle/robolectric.gradle.kts`). A generated
  `robolectric-deps.properties` points Robolectric at the jars in the
  Gradle cache. Copying them is not an option: the API 37 jar is about
  239 MB, above the isolated lanes' 128 MiB per-file ceiling
  ([ADR 0014](0014-hosted-apple-isolation-probes.md)). API 37 needs
  `--add-opens java.base/java.io` and `--add-exports
  java.base/jdk.internal.access` on JDK 17 and later.
- Compose ui-test pulls Espresso `3.5.0`, whose idling calls an
  `InputManager` method that API 37 removed; the catalog pins Espresso
  `3.7.0`.
- Exclusions:
  - the UniFFI-generated package `ch.trancee.cairn.ffi`;
  - in `:androidApp`, the on-device `CoreStatusInstrumentation`, which loads
    the Rust library a host test cannot;
  - in `:androidApp`, code annotated `@Composable`. The Compose compiler adds
    skip, restart and trace branches to every composable; no test can
    honestly reach some of them, for example the `isTraceInProgress` branch.
    The owner chose this exclusion on 2026-10-24. Composables therefore hold
    no decisions: state, statuses and gates live in plain code measured at
    100%, and Compose UI tests still assert every screen.
- Kover reports `0.9.x` as stable releases; the guidance's beta label is
  accepted as is.

### 5. Reference app

- `:androidApp` holds the screen, in Jetpack Compose with Material 3 (the
  Compose BOM pins the versions) and dynamic colour on API 31+. Whether S3
  shares UI with iOS through Compose Multiplatform is decided there; `:app`
  keeps only the `coreStatus()` loopback check.
- One activity shows, in order: a Nearby devices permission gate, a
  Bluetooth-off gate, the contact list and one conversation. Each message
  shows sent, failed or why it was not sent.
- A toggle shows the debug-panel fields from §2; faults show as a
  dismissable banner.
- The radio runs while the activity is started. It stops in `onStop`,
  except across a configuration change such as rotation. While it runs, the
  Bluetooth-off gate follows the radio's `availability`.

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

## Amendments

2026-10-25, from [ADR 0025](0025-android-gatt-slot-budget.md) (OI-31,
[issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md)):
- **Discovery.** The radio advertises service data (service UUID ‖ beacon,
  spec §10.1) instead of the bare service UUID. It restarts the advertising
  set at every beacon window boundary plus 0–30 s of jitter, and scans for
  either form. Duty cycles and background operation stay in S6.
- **Central.** The radio budgets its GATT slots: at most 5 (6 on API 35+)
  dials, central links and server connections; 1–2 dials in flight; a 10 s
  dial timeout. It dials a peer with an advertised beacon only if its own
  beacon is lower.
- **Peripheral.** It advertises only while it has a free slot, disconnects a
  device that connects to a full server, and, when full, evicts its
  longest-idle link for a waiting peer.

2026-10-25, from [ADR 0027](0027-android-energy-bands.md) (OI-33): the
advertising and scan modes follow the energy band (`FULL`, `SAVE`, `LOW`) in
place of a fixed `LOW_LATENCY`.

2026-10-25, from [ADR 0028](0028-android-extended-advertising.md) (OI-34): the
advert is an extended connectable set where the controller supports it, and
legacy otherwise; the scan receives both kinds.
