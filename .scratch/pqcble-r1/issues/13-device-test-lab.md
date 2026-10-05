# Device test lab

Type: task
Status: resolved
Blocked by:

## Question

Provision the physical devices needed to validate decisions and the prototype: at least two Android phones (API ≥ 31, ideally different vendors, one with BLE 5 2M PHY + LE CoC), at least one iPhone, a Mac with Xcode, and optionally a BLE sniffer (e.g. nRF52840 dongle + Wireshark). HITL: the human confirms which devices are available; record models/OS versions here.

## Comments

- 2026-10-05: Required measurements from [ADR 0003](../../../docs/adr/0003-ble-transport.md):
  - which discovery path wins with a backgrounded iPhone (iOS-as-central vs Android scanning the overflow UUID vs direct-connect fallback);
  - Android↔iOS L2CAP CoC interop (this gates the CoC flag);
  - connect → beacon read → Resume → first frame inside iOS's ~10 s wake budget;
  - effective MTU and PHY.

  At least one Android device must be API 29+ for CoC, and one should be API 26–28 to test the MTU-23 / no-CoC path.

### Android fleet (user, 2026-10-05)

23 Android devices, from Android 8 (SDK 26) to Android 16 (SDK 36). No BLE sniffer is available, so measurements rely on app counters, `onMtuChanged`/`onPhyUpdate` callbacks and HCI snoop logs (`adb bugreport`).

Proposed core matrix: covers the OS floor/ceiling, BT 4.2 vs 5.x, Qualcomm/MediaTek/Exynos/Kirin, low RAM, and known quirks.

| Role | Device | Android | BT | Why |
|---|---|---|---|---|
| OS floor | Huawei P10 Lite (Kirin 658) | 8 / 26 | 4.2 | `minSdk` floor; no 2M PHY; Kirin stack |
| Low end | Samsung Galaxy XCover 4 (Exynos 7570, 2 GB) | 9 / 28 | 4.2 | Slowest ML-KEM; Exynos; "hello stays unknown on GATT" |
| CoC floor | Xiaomi Pocophone F1 (SD845) | 10 / 29 | 5.0 | First API with L2CAP CoC |
| Samsung stack | Galaxy S10e (SD855) | 12 / 31 | 5.0 | Samsung BT stack; Android 12 permission model |
| Doze | Nokia X20 (SD480) | 14 / 34 | 5.0 | Doze-sensitive discovery; API 34 foreground-service rules |
| Low-end new | Xiaomi Redmi A3 (Helio G36, 3 GB) | 16 / 36 | 5.4 | Low-end MediaTek on the newest OS |
| Baseline | Nothing Phone (2) (SD8+ Gen 1) | 16 / 36 | 5.3 | "Stable baseline"; Android 14+ MTU-517 behaviour |
| Samsung new | Galaxy Z Flip4 (SD8+ Gen 1) | 16 / 36 | 5.2 | Samsung on the newest OS; route-ready quirk |

The rest of the fleet is an extended matrix for regression and soak runs.

### iOS fleet (user, 2026-10-05)

| Role | Device | iOS | Why |
|---|---|---|---|
| OS floor | iPhone SE (1st gen) | ≤ 15.8 (exact version to confirm) | iOS 15 deployment floor; oldest BLE controller |
| Old OS | iPhone 15 | 17.6.1 | Pre-26: no CryptoKit ML-KEM; mid-range iOS |
| Newest OS | iPhone 12 mini | 26.6.1 | iOS 26 BLE behaviour; CryptoKit ML-KEM available for cross-checks |
| Spare | iPhone SE 2 | to confirm | Second iPhone for iOS↔iOS and two-central tests |

The Mac with Xcode is assumed available (the XcodeBuildMCP tooling is present). No sniffer.

## Answer

The lab is provisioned (user, 2026-10-05):
- 23 Android devices covering SDK 26–36;
- 4 iPhones covering iOS 15 to 26;
- no sniffer.

The core matrix is the 8 Android devices above plus the SE (1st gen), the iPhone 15 and the iPhone 12 mini. The ADR 0003/0005 measurements run during implementation against this matrix. Without a sniffer, on-air claims rest on HCI snoop logs and app counters.
