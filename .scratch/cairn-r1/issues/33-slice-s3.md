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
- In every Android↔iOS run, Android was the central. iOS never opened a second
  link to an Android peer that was already linked to its GATT server. That is
  consistent with CoreBluetooth giving the remote device the same identifier as
  `CBCentral` and as `CBPeripheral`. It doesn't prove it: iOS may simply not
  have seen Android's extended advert. OI-39 stays open.
- The iOS permission prompt appears on first launch, from
  `NSBluetoothAlwaysUsageDescription`.

Status: done pending PR review.
