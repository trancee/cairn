# Android↔iOS background discovery and transport feasibility

Type: research
Status: open
Blocked by:

## Question

For an Android device and an iOS device running the app (foreground, background, and iOS-suspended with state restoration), which discovery and connection combinations actually work: iOS advertising in background (service UUID moved to the overflow area) and whether Android can scan/match it; Android advertising/scanning in background with a `connectedDevice` foreground service; iOS background scanning restrictions (service-UUID filter required, no duplicates); rotating private beacon payloads vs iOS's inability to set manufacturer data. Also: L2CAP CoC (`CBL2CAPChannel` / `BluetoothSocket` LE CoC) interop and throughput between Android and iOS vs GATT notifications/writes-without-response with 2M PHY + DLE + large MTU. Report verified sources and what must be confirmed on real devices.

## Comments

- 2026-10-05 (charting): background operation on **both** Android and iOS is required. Minimum targets **Android 8 (API 26) / iOS 13**: cover location-permission scanning on Android 8–11, foreground-service rules per API level, and LE CoC unavailability below API 29.
