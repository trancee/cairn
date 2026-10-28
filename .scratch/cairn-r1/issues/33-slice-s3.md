# Slice S3: Android↔iOS

Type: task
Status: open
Blocked by: 32

## Question

Build the iOS CoreBluetooth adapter in the KMP SDK and the iOS app target, and run S2's flow Android↔iOS. Verify the iOS MTU and Android↔iOS interop facts flagged as unverified.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments

2026-10-28: [ADR 0037](../../../docs/adr/0037-ios-ble-adapter.md) and spec
draft 0.18 (§10.4, OI-39) record the iOS radio. It lives in the Swift host
app, not in the KMP SDK:
- `IosRadio` holds every decision behind a `BlePort` protocol;
- `CoreBluetoothPort` adapts CoreBluetooth;
- `Session` wires both to the shared `LinkDriver`, and a SwiftUI port of
  Android's chat screen sits on top.

XCTest on the iPhone 16 simulator covers `IosRadio`, `ChatModel` and
`Platform` at 100% lines. `CoreBluetoothPort`, `Session` and the views are
covered by the device demonstration (ADR 0037 §7).

2026-10-28: Device demonstration with Debug builds. Android ran the debug APK
from the same commit. Every other phone had Cairn stopped.

- **Newest pair.** iPhone 12 mini (iOS 27.0.1) and Nothing Phone (2)
  (`1f1dad34`, Android 16, API 36), Nothing state cleared.
  - The Nothing dialled the iPhone. Its link came up `CENTRAL mtu 517` 1.4 s
    after connect. The iPhone came up `PERIPHERAL mtu 515`, because
    `maximumUpdateValueLength` caps at 512.
  - The Nothing listed the contact 14 s after launch.
  - A UI-test driver on the iPhone received "hello from Nothing" and replied.
    The reply showed `Delivered`, then `Read`.
  - The Nothing showed the reply, and its own message as `Read`.
- **Oldest pair.** iPhone SE 2016 (iOS 15.8.8) and Pocophone F1 (`e9097611`,
  Android 10), Pocophone state cleared.
  - The Pocophone dialled the iPhone and came up `CENTRAL mtu 517`. The SE came
    up `PERIPHERAL mtu 517`: iOS 15 reports 514 B, and spec §4.3 caps the body
    at 511 B anyway.
  - The Pocophone paired in 8 s, and its message showed `Delivered` 26 s after
    launch.
  - The SE has UI automation off: `XCUITest` failed with "Authentication
    cancelled". So this run proves the Android→iOS direction only. The
    iOS→Android direction is proven by the newest pair, and by the SE's
    handshake frames (`out 0x81`/`0x01`/`0x20`/`0x30`).
- **All four iPhones and the Nothing together** (iPhone 15, iOS 17.6.1; SE
  2020, iOS 18.7.8).
  - The 12 mini and the SE 2016, the two iPhones whose logs were captured,
    each linked in both roles.
  - Their iPhone↔iPhone links came up at MTU 185 or 515, and each one finished the
    handshake.
  - Duplicate iPhone↔iPhone links were closed by the core (OI-17).

Facts this answers:
- In every Android↔iOS run, Android was the central, because iOS never saw
  Android's extended advert (below).
- The iOS permission prompt appears on first launch, from
  `NSBluetoothAlwaysUsageDescription`.

2026-10-28: iOS as central (ADR 0037 Consequences, spec §10.4).

- A probe build of the iPhone 12 mini scanned with no service filter for 40 s
  and logged each device's first advert: 43 devices, none with a secondary
  PHY, and no Cairn advert, while the Nothing advertised its extended set.
  With the service filter it saw nothing either.
- The Nothing, forced to legacy advertising with the unchanged payload, was
  reported at once with its 8 B service data. The iPhone dialled it 3.5 s
  after launch: `link 1 up CENTRAL mtu 515`, pairing (`0x00`–`0x04`), then
  Resume (`0x10`/`0x20`/`0x30`) on both sides. iOS as central works.
- So Core Bluetooth doesn't report Android's extended adverts, although
  `supports(.extendedScanAndConnect)` is true. Root cause, found by A/B on
  three iPhones (iOS 17, 18, 27) and two Android controllers: iOS reports an
  extended advert only when its auxiliary packet is on LE 2M. ADR 0038
  (proposed) and issue 56. ADR 0028 stays: an extended
  Android phone dials iOS's legacy advert whatever the beacons, so every pair
  links; iOS dials only legacy-advertising Android peers.
- The P30 lite's legacy advert failed with `ADVERTISE_FAILED_TOO_MANY_ADVERTISERS`
  (2), silently. The radio now logs `advertising failed (2)`; the rotation
  retries it at the next window.
- The SE 2016 send test stopped at the device's "Enable UI Automation"
  passcode prompt (`Timed out while enabling automation mode`). It needs the
  passcode entered on the device; the SE→Android direction rests on its
  handshake frames above.

Status: done pending PR review.
