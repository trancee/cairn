# Extended-advert A/B on iOS 15/16 and Android 8/9 hardware

Type: task
Status: needs-triage
Blocked by: none

## Question

Does [ADR 0038](../../../docs/adr/0038-android-extended-advert-2m-secondary.md)
hold at the project minimums, iOS 15 and Android 8 (API 26)? Its A/B ran on
iOS 17, 18 and 27 and Android API 29–37.

## Tests

Re-run the ADR 0038 probe: an iOS probe app scans with no filter and allows
duplicates, logging every advert with a non-zero `kCBAdvDataRxSecondaryPHY`
and every Cairn advert, 25 s per variant. An Android phone runs one advert
variant at a time (extended 1M, extended 2M, legacy), same payload, 100 ms.

1. **iOS 15 and iOS 16**, one iPhone each, ideally with
   `supports(.extendedScanAndConnect)` logged. Expected: 0 reports for 1M,
   non-zero for 2M, as on iOS 17+.
2. **iPhone 8 or X** on iOS 15/16 (BT 5 radio, but see "Hardware floor"),
   with a 2M extended advert, so the 1M rule can't explain a miss. Expected
   per Apple: `extendedScanAndConnect` false, no extended reports, only
   legacy adverts seen. Unproven; this test decides it.
3. **iOS 18.6.x** against a 2M connectable extended advert. An Apple forum
   post says a device is discovered but cannot be connected on 18.6.2 and
   works on 26.5.2 (it doesn't say which PHY). ADR 0038 connected on 18.7.8
   only.
4. **Android 8 and 9** (API 26–28), one phone each. Log
   `isLeExtendedAdvertisingSupported`, `isLe2MPhySupported`,
   `isLeCodedPhySupported`, `getLeMaximumAdvertisingDataLength`,
   `AdvertisingSet` start result, and whether `setLegacy(false)` scans see
   a peer's 2M set. Note: no fleet phone below API 29 was measured.
5. **Mixed links**: an API 26–28 BT 5 phone with an iPhone, in both dial
   directions; MTU and PHY after connect.
6. **Range** (open in ADR 0038): dial and advert-hear rates at 1M and 2M
   at 5, 10 and 15 m with a wall, one Android pair and one Android–iPhone pair.

Record per device: model, SoC, OS build, the capability flags above, report
counts per variant, link up/down and `mtu`, and dial timeouts.

## Hardware floor (from research)

Apple states extended scanning is supported "on iPhone XS and the new iPad
Pro" (WWDC19 session 901, 2019). iOS 15's floor (iPhone 6s) is older than
that, so some supported iPhones may **never** see extended adverts, and an
Android phone that advertises only extended would be invisible to them.

Evidence for iPhone 8/X/XR is weak. A Nordic DevZone thread (60667) has one
user who couldn't see an nRF52 extended advert on an iPhone 8, one on an
iPhone XR (iOS 13.3), and a Nordic engineer who guessed iPhone 8 should
work. The thread never states the advert's PHY, so the 2M-only rule
(WWDC19) could explain the misses. Test 2 settles it. If it confirms, ADR
0038's dial rule needs a legacy path for those peers, or a documented
minimum-iPhone statement.

## Research notes (2026-10-29)

Live sources, via Tavily search and extract.

| Fact | Source | Confidence |
|---|---|---|
| iOS scans extended adverts only when transmitted on LE 2M; payload up to 124 B; legacy and extended scanned together, same API and filters | Apple WWDC19 session 901, https://developer.apple.com/videos/play/wwdc2019/901 | High, official. Makes ADR 0038's "undocumented" rule documented (for iOS 13). |
| Extended scan/connect is queryable via `CBCentralManager.Feature.extendedScanAndConnect`; supported since iOS 13 API, hardware-dependent | https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/feature/extendedscanandconnect | High |
| Extended connections use an explicit `AUX_CONNECT_RSP`, can start on 2M, and avoid host wake-ups for lost connection requests | WWDC19 session 901 | High, official. Matches ADR 0028's reasoning. |
| iPhone 8 and XR (iOS 13.3) users saw no nRF52 extended adverts; the advert's PHY isn't stated | https://devzone.nordicsemi.com/f/nordic-q-a/60667/apple-device-support-for-ble-extended-advertising (read in full) | Low, anecdotal and confounded by the 2M-only rule; test 2 |
| An nRF Connect iOS user on iOS 18 couldn't discover a Coded-PHY extended advert that Android saw | https://devzone.nordicsemi.com/f/nordic-q-a/119506/ios-support-for-ble-5-0-extended-advertisement (read in full) | Low, one report; consistent with ADR 0038 rejecting Coded |
| iOS 18.6.2: extended device discovered but not connectable; works on 26.5.2; PHY not stated | https://developer.apple.com/forums/tags/core-bluetooth (post text read) | Low, one report; test 3 |
| iOS background advertising drops the local name, and service UUIDs go to the overflow area, found only by scanners filtering for them | https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html | High, official |
| Android 8.0 adds the Bluetooth 5 APIs (`isLe2MPhySupported`, `isLeExtendedAdvertisingSupported`, `AdvertisingSet`), available only with a compatible controller | https://source.android.com/docs/core/connect/bluetooth/ble_advertising | High, official |
| `ScanSettings.setLegacy` defaults to true; `false` is required to see extended adverts | https://stackoverflow.com/questions/74806907/how-to-filter-ble-devices-that-are-advertising-extended-advertising-message, https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder | High |
| Pixel 2 was the first phone with usable BT 5; most late-2017 Android phones lacked it | https://blog.nordicsemi.com/getconnected/bluetooth-5-in-smartphones | Medium |
| Scan starts are limited to 5 per 30 s (introduced in Android 7 previews); unfiltered scans pause on screen-off since 8.1 | https://github.com/nordicsemi/Android-Scanner-Compat-Library/issues/18, https://medium.com/@martijn.van.welie/making-android-ble-work-part-1-a736dcd53b02 | Medium |
| Android supports about 7 simultaneous GATT connections by default; the hardware can do more and some OEMs raise it (15 on one Samsung tablet). The Zebra page, which also says 7, could not be fetched | https://stackoverflow.com/questions/41365009/what-is-the-max-concurrent-ble-connections-android-m-can-have (read in full) | Low, 2016 answer; measure per device |
| iOS has no published connection limit; an accessory developer reported above 20 as central, and one recent answer says about 7+ | https://stackoverflow.com/questions/13469502/maximum-number-of-peripherals-on-corebluetooth, https://e2e.ti.com/support/wireless-connectivity/bluetooth-group/bluetooth/f/bluetooth-forum/246231/how-many-ble-devices-can-connect-to-ios-simultaneously (both read in full) | Low, central role only; the peripheral role is unmeasured |
| Payload-only airtime for 100 B: 0.4 ms (2M), 0.8 ms (1M), 1.6 ms (Coded S=2), 6.4 ms (Coded S=8); a faster PHY can be slower in practice when the signal is too weak | https://www.everythingrf.com/community/bluetooth-le-1m-vs-2m-vs-coded-phy-range-speed-and-receiver-sensitivity (read in full) | Medium |
| Connectable extended advertising data is capped by the controller (for example 191 B on one vendor stack) | https://docs.silabs.com/bluetooth/2.13/bluetooth-code-examples-stack-features-adv-and-scanning/extended-adv-example | Medium; Cairn's payload is flags plus service data, well below the iOS 124 B cap |
| Bluetooth Mesh has an advertising bearer (non-connectable adverts) and a GATT bearer for devices that can't use it. In a managed-flooding example, 60 relays each sending a PDU 3 times give up to 180 extra transmissions per message. Silicon Labs' note covers extended advertising (up to 1,650 B) in Mesh | https://safeguard.sh/resources/blog/bluetooth-mesh-explained-managed-flooding-provisioning-network-and-application-keys-friend-nodes-and-mesh-1-1, https://www.silabs.com/documents/public/application-notes/an1405-bt-mesh-advertising-extensions.pdf (both read in full) | Medium; the 180 figure is one blog's worked example |

## What this means by dimension

| | Legacy 1M | Extended 2M secondary (ADR 0038) | Extended 1M secondary (ADR 0028) | Coded |
|---|---|---|---|---|
| **Performance** | Works everywhere. 31 B. Lost `CONNECT_IND` shows as status 133 (ADR 0028). | Same link throughput as any set; the link negotiates PHY itself. iOS and Android both see it. Connection answered by `AUX_CONNECT_RSP`. | Android only; invisible to iOS. | Slowest; iOS unreliable. |
| **Battery** | Cheapest per event. | About half the aux airtime of 1M, plus one `ADV_EXT_IND`. Apple says lost requests no longer wake the host. | More aux airtime than 2M. | Highest airtime. |
| **Stability** | Mature; congested primary channels. | Fleet A/B: on demand matched 1M; always-2M had more dial timeouts (ADR 0038). Iffy on iOS 18.6.2 (test 3). | Fewest failed dials of the Android options (ADR 0028). | Not supported by fleet or iOS. |
| **Peers / scale** | One legacy set per phone; slot limits per controller. | One set; `ADV_EXT_IND` on 3 primary channels, aux on 37 secondary channels, so less primary-channel crowding. Scanner must follow the pointer. | Same. | n/a |
| **Reach** | Every phone, including 4.2 controllers. | Needs BT 5 on both sides; iPhone XS or newer. About 3 dB less sensitivity than 1M. | BT 5 Android only. | n/a |

## Mesh implications

- **Discovery graph is asymmetric**: iOS advertises legacy only, Android
  extended (2M with an iPhone near). Relaying across an iOS hop therefore
  relies on Android dialling iOS's legacy advert (ADR 0038 keeps that rule).
  An iPhone older than XS may never dial an extended-only Android phone
  (unproven, tests 1–2), so the mesh could partition around it unless that
  Android phone also dials it.
- **GATT-connection relaying** (Cairn's model) is bounded by about 7
  Android links and an unpublished iOS limit, not by advert airtime. Flooding
  by advertising scales with relay count instead (Bluetooth Mesh note
  above), which is why Cairn's slot budget (ADR 0025) matters more than
  PHY choice for peer count.
- **Capability negotiation** stays in the connection, not the advert,
  as ADR 0028 decided. Test 5 checks that no phone gets stranded.
- **Other P2P apps** (pages read in full):
  - **Berty/Wesh** built BLE drivers for libp2p on Android and iOS, and
    reports Android's BLE API was far harder than iOS's: concurrency of
    operations and MAC addresses that rotate. Its first Android driver
    was unstable (connections failing in loops or lasting hours) because of
    low-level race conditions the platform leaves to the developer. It
    found BLE "extremely slow", fine for small text and unsuitable for
    photos, and chose Android Nearby and Multipeer Connectivity (BLE for
    discovery, then Wi-Fi) as the fast path, keeping BLE only for
    inter-OS links. It notes the BLE standard defines no connection limit,
    so chip and OS decide. Source: https://berty.tech/blog/bluetooth-low-energy,
    https://berty.tech/docs/protocol. Medium (2018–2020 experience, a vendor's
    own account). It doesn't mention advertising extensions.
  - **Briar** says it syncs over Bluetooth, Wi-Fi or Tor
    (https://briarproject.org/how-it-works). No BLE design detail found.
  - **Bridgefy**: only marketing and Wikipedia pages found. Unverified.
  - Lesson for Cairn: the operation queue and the cross-OS link, not the
    advert PHY, were their stability problems. Wi-Fi handover for bulk
    data is their answer to BLE speed; Cairn's ADR set doesn't have one.

## Legacy advertise/scan, then upgrade after connect (researched 2026-10-29)

This is already the shape of ADR 0003 (GATT, optional L2CAP CoC after
Resume) plus ADR 0003's Android 2M/MTU 517 request. Findings from pages
extracted in full:

| Claim | Source | Confidence |
|---|---|---|
| Android `getPsm()` (and `listenUsingL2capChannel`) were added in API 29; iOS `CBL2CAPChannel` is iOS 11+. So Android 8/9 (API 26–28) can never take the CoC upgrade; GATT stays mandatory there. | developer.android.com `BluetoothServerSocket`; developer.apple.com `CBL2CAPChannel`; Ditto talk (octet-stream.net) says "iOS 11 and Android 10" | High |
| Plain GATT reaches about 700 kbps on 1M between two nRF devices; Nordic sees no significantly higher bandwidth from raw L2CAP. WWDC17 712 quotes L2CAP+EDL+15 ms at 394 kbps on iOS. | Nordic DevZone 61028 (staff answer, 2020) | Medium (vendor, old) |
| Ditto (a commercial BLE mesh) moved iOS from GATT to L2CAP: update latency 230 ms to 100 ms, throughput 5.56x to over 22 KB/s, stays Android-compatible, picks the fastest mode per link, keeps GATT for old phones. | ditto.com blog 2021 | Medium (vendor claim; confirms mixed-OS CoC and the fallback design) |
| Insecure L2CAP is "fairly robust"; secure (bonded) L2CAP is "cursed" on Android and iOS; Android connect is finicky, and the PSM needs GATT first. | Kable discussion 588 (one contributor) | Low–medium |
| 2M PHY draws more power while on air but costs less energy per byte, because the radio sleeps sooner. | PMC6749335 (measured, BLE 4.2 vs 5) | High |
| Berty: BLE was too slow for bulk, so it hands off to Wi-Fi. | berty.tech | Medium |

Not extracted (fetch failed), so unverified: Nordic 127664 (L2CAP socket
fails with bonding), the Stack Overflow throughput thread, Renesas, and
Apple forum 723218 (page gone).

Impact by dimension:
- **Performance:** the upgrade barely matters for Cairn's payloads (pairing
  and ratchet at most about 2.4 KB, ADR 0003). The gain is lower per-message
  latency and flow control, not peak rate. GATT write-without-response +
  notify at MTU 247–517 and 2M is close. The PSM read adds a GATT round trip,
  so tiny messages may not win.
- **Battery:** the saving comes from shorter radio-on time (2M, bigger MTU,
  fewer ATT headers), not from the protocol. Always-2M adverts lost in ADR
  0038, so PHY upgrades after connect are the cheap place to spend 2M.
- **Stability/support:** legacy discovery keeps the ADR 0028 cost: lost
  `CONNECT_IND` on crowded primary channels gives status 133. Upgrade after
  connect doesn't fix that; it only helps the link after it is up. CoC is
  API 29+ only, and Android-to-iOS CoC interop is unproven in Cairn; the
  flag stays off until tested.
- **Peers:** an L2CAP channel still occupies one connection slot, so the
  limit (about 7 on Android by default, ADR 0032 slots) is unchanged.

Recommendation: keep legacy-compatible discovery and GATT as baseline, do
PHY/MTU/data-length over GATT first (works on every API level), and treat
CoC as an optional measured upgrade for API 29+/iOS pairs. Add a device test
for Android 10+↔iOS CoC (insecure channel, app-layer security as ADR 0003
already does) before enabling the flag.

## Corrections to ADR 0038

- Done (2026-10-29): the 2M-only rule is documented by WWDC19 session 901
  (124 B cap, iPhone XS+); ADR 0038 Context, root cause and Consequences
  now say so.
- Still to add after the tests: the iOS 15/16, API 26–28, iPhone 8/X and
  range results, in Validation.

## Resolution

(open)
