# Android↔iOS background discovery and transport feasibility

Type: research
Status: resolved
Blocked by:

## Question

For an Android device and an iOS device running the app (foreground, background, and iOS-suspended with state restoration), which discovery and connection combinations actually work: iOS advertising in background (service UUID moved to the overflow area) and whether Android can scan/match it; Android advertising/scanning in background with a `connectedDevice` foreground service; iOS background scanning restrictions (service-UUID filter required, no duplicates); rotating private beacon payloads vs iOS's inability to set manufacturer data. Also: L2CAP CoC (`CBL2CAPChannel` / `BluetoothSocket` LE CoC) interop and throughput between Android and iOS vs GATT notifications/writes-without-response with 2M PHY + DLE + large MTU. Report verified sources and what must be confirmed on real devices.

## Comments

- 2026-10-05 (charting): background operation on **both** Android and iOS is required. Minimum targets **Android 8 (API 26) / iOS 13**: cover location-permission scanning on Android 8–11, foreground-service rules per API level, and LE CoC unavailability below API 29.
- 2026-10-05 (research): findings in [../../../docs/research/2026-10-05-android-ios-background-ble.md](../../../docs/research/2026-10-05-android-ios-background-ble.md). Gist: iOS's background "overflow area" for service UUIDs is Apple-only and very likely invisible to Android scanners (first-party docs, not yet device-tested), so the rotating beacon must NOT depend on it. Recommended fix: iOS advertises one fixed static service UUID while backgrounded; Android scans/connects on that UUID and reads the rotating beacon via a GATT characteristic after connect, falling back to direct-connect-by-address when needed. Use GATT notify/write-without-response as the primary transport for both the ~2.4 KB pairing and ~2.3 KB ratchet epoch (L2CAP CoC has no confirmed Android↔iOS interop and adds a PSM-exchange round trip); design the resume handshake to fit iOS's documented ~10-second background wake budget.

## Answer

Android probably **cannot** see iOS's background-advertised UUIDs, which sit in Apple's overflow area (strong first-party evidence; needs a sniffer check). Background-safe discovery: a **fixed static service UUID**, with the rotating beacon fetched by **GATT read after connect**; beacon bytes in advertising are a foreground-only optimization. iOS background scans need a UUID filter, and duplicates are coalesced. Each iOS wake gets about 10 s of execution, and state restoration relaunches the app on BLE events. Transport: **GATT notify/write-without-response first**; L2CAP CoC (Android 29+, PSM via GATT) is optional later, with no vendor interop statement. A 10-item real-device checklist is in the [findings](../../../docs/research/2026-10-05-android-ios-background-ble.md).
