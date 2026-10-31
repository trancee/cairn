---
status: accepted
date: 2026-10-29
version: cairn-r1
---

# 0037: iOS BLE adapter for slice S3

## Context

Slice S3 ([issue 33](../../.scratch/cairn-r1/issues/33-slice-s3.md)) carries
the S2 flow (admission, pairing, Resume and CHAT) between Android and iOS
over BLE. [ADR 0023](0023-android-ble-adapter.md) put the link driver, its
send queue, timers and errors in shared `:sdk` code, so an iOS adapter only
implements `Radio`, `Timers` and `ClockSource` and reports to a
`RadioListener`.

Four constraints shape the iOS side:

- The CodeQL inventory rejects tracked iOS-only Kotlin
  ([ADR 0015](0015-build-backed-kotlin-codeql.md)), so the radio is Swift in the host
  app, like the row sealer ([ADR 0035](0035-sealed-row-storage.md)).
- CoreBluetooth objects (`CBPeripheral`, `CBCentral`, `CBATTRequest`) can't
  be constructed in tests.
- iOS can't advertise service data, so it can't advertise a beacon as
  Android does (spec §10.1). Android dials a peer that advertises only the
  service UUID (§10.4, ADR 0025).
- A `CBPeripheralManager` has no call that disconnects a central.

## Decision

The rules below mirror ADR 0023 §3. Where they differ, the reason is
CoreBluetooth.

### 1. Structure

- **`IosRadio`** (Swift, `iosApp/`) implements `Radio` and holds every
  decision: dial policy, link stages, flow control, MTU and the beacon
  answer. It talks to CoreBluetooth only through a `BlePort` protocol of
  commands keyed by the peer's `UUID` (`connect`, `discover`, `subscribe`,
  `readBeacon`, `write`, `notify`, …), and CoreBluetooth reports back
  through plain methods (`discovered`, `connected`, `subscribed`,
  `beaconRead`, `wrote`, `writeRequests`, …).
- **`CoreBluetoothPort`** implements `BlePort` over `CBCentralManager` and
  `CBPeripheralManager`. It maps UUIDs to CoreBluetooth objects and forwards
  delegate callbacks; it holds no decisions.
- **Threading.** Both managers, the timers, the driver and the UI run on the
  main queue, as Android's session runs on the main looper. CoreBluetooth
  delivers callbacks there, so nothing is posted twice. `send` and
  `disconnect` are deferred with `DispatchQueue.main.async`, because the
  driver calls them while it dispatches, possibly before `linkUp` returned
  the id (ADR 0023 §3).
- **Timers and clock.** `SchedulerTimers` schedules `MainScheduler`'s `DispatchWorkItem`s on the
  main queue. `IosClock` reads `mono_ms` from `CLOCK_MONOTONIC`, which
  includes sleep on Darwin (ADR 0022 §2), and `unix_s` from the wall clock.

### 2. Discovery

- Foreground only. The radio runs while the scene is active and stops when
  it leaves it. Background advertising and scanning stay in S6
  ([issue 04](../../.scratch/cairn-r1/issues/04-android-ios-background-ble.md)).
- The peripheral advertises the fixed service UUID only. The foreground
  beacon UUID of §10.1 [OI-9] is deferred to S6, as S2 deferred Android's
  beacon. Android therefore dials iOS whatever its own beacon, after giving
  iOS 10 s to dial first ([ADR 0039](0039-android-waits-for-ios-to-dial.md)).
- The central scans for the service UUID with duplicates allowed, so
  repeated results gate dials the way Android's scan results do.

### 3. Central

- Dials follow spec §10.4: a random 0–3 s delay after an identifier is first
  seen, retries after a random 1–5 s and 5–15 s when a dial fails before
  `linkUp`, otherwise one dial per identifier every 2 minutes. A dial not up
  within 10 s fails and is cancelled.
- The radio doesn't dial a peer that is already linked to its GATT server
  under the same identifier. CoreBluetooth gives a remote device the same
  identifier in both roles.
- iOS publishes no GATT slot limit, so the radio keeps no slot budget. It
  runs at most 2 dials at once.
- Connect, then discover the service and `beacon`, `rx` and `tx`, then enable
  `tx` notifications. Only then does it report `linkUp` and read `beacon`.
  A write to `rx` waits for that read, as on Android.
- **MTU.** iOS negotiates the ATT MTU itself and reports no change. The link
  MTU is `maximumWriteValueLength(for: .withoutResponse) + 3`. The
  with-response length is not used: it is 512 whatever the MTU, because iOS
  would split longer values into prepared writes, which the Android server
  refuses. Before each write the radio checks the length again and reports
  `mtuChanged` if it moved.
- Writes to `rx` are with response; `didWriteValueFor` reports `sent`, and a
  write error closes the link.

### 4. Peripheral

- The GATT service is the one in spec §12: `beacon` (read), `rx` (write),
  `tx` (notify) and `psm` (read). A `beacon` read is answered from
  `RadioListener.beacon`, honouring the request offset. A `psm` read is
  answered with `requestNotSupported`, since S3 opens no L2CAP CoC.
- A central's subscription to `tx` reports `linkUp`, with MTU
  `maximumUpdateValueLength + 3`. Unsubscribing, which iOS also reports when
  the central disconnects, reports `linkDown`.
- Writes to `rx` from a central without a link, at a non-zero offset, or to
  another characteristic are refused with one error response for the whole
  batch; otherwise each value is received in order and the batch is answered
  with success.
- **Flow control.** `updateValue` returning false holds the fragment. The
  radio retries every held fragment on `peripheralManagerIsReady`. Each
  accepted notification reports `sent`.
- **Disconnect.** iOS can't drop a central. `disconnect` reports `linkDown`
  at once and marks the central closed: its writes are refused, which makes
  an Android central close the connection, and a new subscription opens a
  new link [OI-39].

### 5. Adapter state

The radio starts both managers on `start`. While either is not
`poweredOn`, it closes every link, reporting `linkDown` for each, and shows
the Bluetooth-off gate. When both are `poweredOn` again it adds the service,
advertises and scans. An unauthorized state shows the permission gate.
`NSBluetoothAlwaysUsageDescription` gives the reason, worded like Android's.

### 6. Reference app

A SwiftUI screen mirrors ADR 0023 §5 and Android's strings: the permission
and Bluetooth-off gates, the contact list, one conversation with message
statuses, the fault banner and the link panel. `ChatModel` ports Android's
plain-Kotlin model to Swift. The `-selfTest` launch argument keeps its
meaning; without it the app opens the sealed rows and runs the radio.

### 7. Coverage

As for the row sealer (ADR 0035), XCTest covers `IosRadio`, `MainScheduler`,
`SchedulerTimers`, `IosClock` and `ChatModel` on a simulator through a fake `BlePort` and a fake
`RadioListener`, with Xcode's coverage on. They are outside CI and the
coverage gates. `CoreBluetoothPort`, the `Session` wiring and the SwiftUI views
hold no decisions; the device demonstration covers them.

## Consequences

- Android↔iOS links come up from either side, but iOS can dial only an
  Android peer that advertises legacy. On an iPhone 12 mini (iOS 27), whose
  `CBCentralManager.supports(.extendedScanAndConnect)` is true, Core
  Bluetooth reported no extended advert at all, with or without a service
  filter, while it reported the same Android phone's legacy advert at once
  and dialled it. An Android phone that advertises extended sees iOS's
  legacy advert and dials it whatever the beacons (ADR 0028), so every
  Android–iOS pair still links. iOS does report, and connect to, an extended
  advert whose auxiliary packet is on LE 2M, and Android uses one while
  it sees iOS: [ADR 0038](0038-android-extended-advert-2m-secondary.md).
- Two links between the same pair are possible when both dial at once; the
  core keeps at most one Resume per contact in flight (OI-17). On Android 9
  such a second link can tear down the first, so Android waits for iOS to
  dial ([ADR 0039](0039-android-waits-for-ios-to-dial.md)).
- An idle Android central linked to a closed iOS peripheral stays connected
  until it next writes or its own eviction closes it.
- iOS↔iOS dialling has no tie-break until the beacon UUID arrives in S6;
  both sides may dial.

## Rejected alternatives

- **Kotlin `iosMain` radio over the CoreBluetooth cinterop.** The CodeQL
  inventory rejects it (ADR 0015), and it would still need a seam for tests.
- **Only one role on iOS.** Android↔Android pairing relies on either side
  dialling; a peripheral-only iPhone would depend on Android's slot budget,
  and a central-only one couldn't be found.
- **Writes without response.** They would remove the per-fragment
  acknowledgement that `sent` relies on, and need
  `canSendWriteWithoutResponse` flow control that Android's central path
  doesn't share.

## Amendments

2026-10-30, from [ADR 0041](0041-close-reasons.md): `disconnect(link:reason:)`
logs `close requested (<reason>)`, the same line as the Android link trace.

2026-10-31, from [ADR 0042](0042-fragment-check.md) (OI-43): the GATT server
answers a write batch with ATT error `0x9E` when any write in it fails its
check, drops the batch, and logs `write rejected (check)`. A central whose
write fails with `CBATTError` code `0x9E` writes the same value again, up to
3 times, and logs `resend <n> (check)`.
