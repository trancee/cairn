# Android↔iOS background BLE discovery and transport feasibility

Builds on `docs/research/2026-10-05-pqc-over-ble-findings.md` §9.1, §9.2, and §9.7, and
answers `.scratch/pqcble-r1/issues/04-android-ios-background-ble.md`. Scope: `pqcble-r1`
targets Android 8 (API 26)+ ↔ iOS 13+, Android↔Android and Android↔iOS only (iOS↔iOS
is explicitly out of scope).

Sourcing convention used throughout: **Verified** = traced to a current or archived
first-party doc (Apple Developer docs, AOSP source, Google's `developer.android.com`/
`source.android.com`), with the citing URL/path given. **Community-reported** = blog
posts, Stack Overflow, issue trackers, or general architectural inference not tied to a
fetched first-party artifact in this research session; flagged explicitly wherever used.

## 1. iOS background advertising + Android scanning the "overflow area"

### 1.1 What Apple's docs say is dropped/moved

**Verified** — *Core Bluetooth Background Processing for iOS Apps* (Apple Developer
Library archive,
`developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html`):

> "The `CBAdvertisementDataLocalNameKey` advertisement key is ignored, and the local
> name of peripheral is not advertised." … "All service UUIDs contained in the value of
> the `CBAdvertisementDataServiceUUIDsKey` advertisement key are placed in a special
> 'overflow' area; they can be discovered only by an iOS device that is explicitly
> scanning for them."

Confirmed, with more detail, in the current `CBPeripheralManager.startAdvertising(_:)`
reference:

> "While in the foreground, your app can use up to 28 bytes of space in the initial
> advertisement data… there's an additional 10 bytes of space in the scan response,
> usable only for the local name… Any service UUIDs… that don't fit in the allotted
> space go to a special 'overflow' area. These services are discoverable **only by an
> iOS device explicitly scanning for them**. While your app is in the background, the
> local name isn't advertised and **all** service UUIDs are in the overflow area."

And `CBAdvertisementDataOverflowServiceUUIDsKey`:

> "Because data stored in this area results from not fitting in the main advertisement,
> UUIDs listed here are 'best effort' and may not always be accurate."

Also verified: `CBPeripheralManager.startAdvertising(_:)` supports exactly two keys,
`CBAdvertisementDataLocalNameKey` and `CBAdvertisementDataServiceUUIDsKey` — apps on
iOS **cannot** set manufacturer data or service data at all, foreground or background.

Apple's repeated phrase — "discoverable only by an iOS device explicitly scanning for
them" — is a strong signal the overflow area is not a standard GAP advertising-data (AD)
structure in the legacy 31-byte PDU, but an Apple-proprietary channel only iOS's own
CoreBluetooth stack knows how to surface. This is consistent with how iOS's Continuity
protocols are known to use Apple manufacturer-specific-data (company ID `0x004C`) rather
than standard service-UUID AD types.

**Community-reported / not independently re-verified in this session**: academic
reverse-engineering of Apple's Continuity/BLE protocols describes iOS encoding short
state hints inside Apple manufacturer-specific-data structures with proprietary type
bytes:
- J. Martin et al., "Handoff All Your Privacy: A Review of Apple's Bluetooth Low Energy
  Continuity Protocol," PoPETs 2019.
- G. Celosia, M. Cunche, "Discontinued Privacy: Personal Data Leaks in Apple Bluetooth-
  Low-Energy Continuity Protocol," PoPETs 2020.

These document Apple's proprietary AD structures for Continuity features generally but
do **not** specifically document the overflow-service-UUID mechanism's over-the-air wire
format — that remains a gap (see "Must confirm on real devices").

### 1.2 Can Android's `BluetoothLeScanner`/`ScanFilter` detect it?

**Verified** — AOSP `framework/java/android/bluetooth/le/ScanRecord.java`
(`android.googlesource.com/platform/packages/modules/Bluetooth`, current `main`):
Android's scan-record parser only recognizes standard Bluetooth SIG GAP AD types
(`0x02`–`0x09` service-UUID/local-name variants, service data, manufacturer-specific
data, etc.). There is no "overflow" concept anywhere in Android's BLE stack — Android
only ever sees what is physically transmitted in the legacy 31-byte advertising PDU
(plus scan response). `ScanFilter`/`ScanRecord` has no API surface for anything
Apple-internal.

**Conclusion (first-party evidence on both sides):** Apple's own doc language
("discoverable only by an iOS device explicitly scanning for them") plus Android's
AOSP parser only understanding standard GAP AD types together give strong evidence that
**Android cannot reliably discover or parse an iOS app's background-advertised service
UUID via the overflow mechanism.** If a UUID happens to also fit in a standard AD
structure within the 31-byte legacy PDU, any central (Android included) can see it — but
per Apple's doc, in the background case *all* service UUIDs go to overflow, i.e. none
remain in the over-the-air-visible area.

This must still be confirmed empirically: Apple doesn't give the exact byte-level
overflow encoding, so it's possible (though undocumented) that some bytes leak into a
standard AD type by coincidence, and behavior could differ by iOS version/chipset.

## 2. Android background advertising/scanning, API 26–35

### 2.1 Location-permission era (API 26–30)

**Verified** — AOSP `BluetoothLeScanner.java` Javadoc on `startScan(ScanCallback)`:

> "An app must have `ACCESS_COARSE_LOCATION` permission in order to get results. An App
> targeting Android Q or later must have `ACCESS_FINE_LOCATION` permission in order to
> get results."

**Verified** — `developer.android.com/source/docs/core/connect/bluetooth/ble` ("BLE
scanning" → "Location scanning"):

> "In Android 11 and lower, individual apps require location permissions to use BLE
> scanning, even if they're scanning only to find devices to connect to. If the user
> disables location scanning, or doesn't grant an app location permissions, then the
> app won't receive any BLE scanning results."

**Verified** — `developer.android.com/develop/connectivity/bluetooth/bt-permissions`
("Target Android 11 or lower"): `BLUETOOTH` for comms, plus runtime
`ACCESS_FINE_LOCATION` "because, on Android 11 and lower, a Bluetooth scan could
potentially be used to gather information about the location of the user"; a
background (service-based) scanner on API 29–30 additionally needs
`ACCESS_BACKGROUND_LOCATION`.

**For `pqcble-r1` (min API 26):** scanning on API 26–28 needs `ACCESS_COARSE_LOCATION`
(plus `BLUETOOTH`/`BLUETOOTH_ADMIN`); targeting API 29+ needs `ACCESS_FINE_LOCATION`; a
background scanner on API 29–30 additionally needs `ACCESS_BACKGROUND_LOCATION`. This is
a hard, user-facing permission prompt the app must show even though beacons carry no
real location data — a direct UX cost on older OS versions.

### 2.2 Android 12 (API 31) Bluetooth runtime permissions

**Verified** — `developer.android.com/develop/connectivity/bluetooth/bt-permissions`
("Target Android 12 or higher"): `BLUETOOTH_SCAN` for scanning, `BLUETOOTH_ADVERTISE`
for advertising, `BLUETOOTH_CONNECT` for communicating with paired devices. If scan
results aren't used to derive physical location, declare
`android:usesPermissionFlags="neverForLocation"` on the `BLUETOOTH_SCAN` permission to
drop the location-permission requirement and the associated "Nearby devices" UX.
Confirmed again on `source.android.com/docs/core/connect/bluetooth/ble`.

**For `pqcble-r1`:** because beacons are rotating PRF outputs (not geolocation data),
`neverForLocation` is correct on API 31+, removing the location prompt on newer OSes
while it's still required pre-31 (§2.1).

### 2.3 Android 14 (API 34) foreground-service type

**Verified** — `developer.android.com/develop/connectivity/bluetooth/ble/background`
("Communicate in the background"): names the `connectedDevice` foreground-service type
(or the companion-device presence API) as the sanctioned mechanism to keep a BLE
connection/notification stream alive while not foregrounded.

**Gap flagged by the research agent:** the specific API-34 enforcement page
(`/about/versions/14/changes/foreground-service-types`) could not be fetched cleanly in
this session (404'd; likely moved under `/develop/background-work/services/fgs/service-types`).
The requirement that BLE background scanning/advertising needs the `connectedDevice` FGS
type on API 34+ is consistent with Android's general FGS-type tightening but should be
re-confirmed directly against the current page (see "Must confirm on real devices").

### 2.4 Scan throttling for background apps

**Verified** — AOSP `BluetoothLeScanner.java` Javadoc on the no-filter
`startScan(ScanCallback)` overload:

> "For unfiltered scans, scanning is stopped on screen off to save power. Scanning is
> resumed when screen is turned on again. To avoid this, do filtered scanning by using
> proper `ScanFilter`."

This confirms unfiltered scans are suppressed screen-off, and `ScanFilter` is the
documented way to keep scanning while backgrounded/screen-off.

**Community-reported, unverified in this session:** the widely cited "5 scans per 30
seconds for apps not in the foreground" throttle (introduced around API 24) could not be
re-confirmed from current AOSP — the expected `AppScanStats.java` path 404'd against
current `main`, suggesting the throttling logic moved in the modularized Bluetooth
stack. Treat this quota as historical/unverified and measure directly per target
OEM/API level.

### 2.5 PendingIntent-based scanning

**Verified** — AOSP `BluetoothLeScanner.java` Javadoc for
`startScan(List<ScanFilter>, ScanSettings, PendingIntent)`:

> "Start Bluetooth LE scan using a `PendingIntent`. The scan results will be delivered
> via the `PendingIntent`. **Use this method of scanning if your process is not always
> running and it should be started when scan results are available.**"

This is the official, Google-documented mechanism for scanning that survives process
death — distinct from (and complementary to) a `connectedDevice` foreground service,
which keeps the process alive for an active connection. Same Bluetooth/location
permission requirements apply.

**Recommendation implication:** Android discovery should combine (a) a
`connectedDevice` foreground service for the duration of an active session/connection
with (b) `PendingIntent`-based filtered scanning (beacon/app service UUID in a
`ScanFilter`) as the wake-from-stopped-process mechanism.

## 3. iOS background scanning restrictions

**Verified** — `CBCentralManager.scanForPeripherals(withServices:options:)` current
reference:

> "If the `serviceUUIDs` parameter is `nil`, this method returns all discovered
> peripherals… The recommended practice is to populate the `serviceUUIDs` parameter
> rather than leaving it nil… Your app can scan for Bluetooth devices in the background
> by specifying the `bluetooth-central` background mode. **To do this, your app must
> explicitly scan for one or more services by specifying them in the `serviceUUIDs`
> parameter.** The scan option has no effect while scanning in the background."

**Verified** — *Core Bluetooth Background Processing for iOS Apps*:

> "The `CBCentralManagerScanOptionAllowDuplicatesKey` scan option key is ignored, and
> multiple discoveries of an advertising peripheral are coalesced into a single
> discovery event. If all apps that are scanning for peripherals are in the background,
> the interval at which your central device scans for advertising packets increases."

**Confirmed facts:**
- Background scanning with `serviceUUIDs == nil` yields zero results — this is
  mandatory, not merely recommended, while backgrounded.
- `allowDuplicates` is ignored in background; discoveries are coalesced and scan
  cadence slows when all scanning apps are backgrounded. No exact numeric interval is
  published by Apple anywhere fetched in this session — treat "slower cadence" as
  qualitative only.

**Implication:** the iOS app must always scan with a concrete, fixed (not rotating)
service-UUID filter when backgrounded. CoreBluetooth does accept an array of UUIDs, so
in principle it could filter on several known peers' rotating UUIDs at once, but this
only helps if the rotating UUID *is* the discovery token reaching the air (see §4).

## 4. Carrying rotating beacon bytes when iOS can't set manufacturer data

### 4(a) GATT characteristic read immediately after connect

Requires a **fixed, known service UUID** advertised (foreground or background) so any
peer can recognize "this is a `pqcble-r1` peer" and initiate a direct connect — this is
necessary because overflow-area UUIDs are "best effort" per Apple's own doc, and
`CBPeripheralManager` exposes only one app-chosen service-UUID-list channel; there's no
separate "fixed connect UUID" distinct from the general service-UUID key.

Cost: one extra GATT round trip (connect → MTU negotiation/service discovery → read
characteristic) before the peer can be matched against the local beacon table and
resumption can begin. Android's own guide
(`.../ble/connect-gatt-server`, `.../ble/transfer-ble-data`) shows the canonical
sequence: `connectGatt()` → `onConnectionStateChange(STATE_CONNECTED)` →
`discoverServices()` → `onServicesDiscovered()` → read characteristic. **No first-party
numeric latency figure for this sequence was found** in either platform's docs — this
round trip, especially cold iOS state-restoration launch, needs on-device measurement.

This approach means a connection must be established (and possibly torn down
immediately if the beacon doesn't match an expected peer) just to learn the beacon — a
privacy/battery cost versus pure advertisement-based discovery, but it's the only way
to carry 8–16 B of beacon payload to/from a backgrounded iOS peripheral once overflow
is unreliable.

### 4(b) Local name

**Verified**, same sources as §1.1: the local name is **not advertised at all while
backgrounded** ("the local name isn't advertised"). In the foreground it's usable (up to
the ~28 B combined budget, or 10 B in the scan response), but foreground-only encoding
is useless for the backgrounded/store-and-forward requirement central to `pqcble-r1`.

### 4(c) Rotating 128-bit service UUID

**Verified**: iOS can include service UUIDs in background advertisements — they're just
relegated to the unreliable overflow area (§1.1).

**Verified** on the Android side — AOSP `ScanRecord.java`
(`DATA_TYPE_SERVICE_UUIDS_128_BIT_PARTIAL/COMPLETE`, `0x06`/`0x07`): Android parses raw
128-bit UUID bytes directly from the standard AD structure and exposes them as
`ParcelUuid` on `ScanRecord`/`ScanResult`. So **if** the bytes reach Android in a
standard AD structure (iOS foreground, or Android↔Android), Android can read all 16
bytes of an arbitrary/rotating UUID with no special handling.

**The catch (per §1):** this only works when iOS is in the **foreground** (service UUID
in the real 28 B block or 10 B scan response — genuine over-the-air AD structures any
scanner sees) or when iOS is the **central**. When iOS is backgrounded as a peripheral,
the rotating UUID goes to the unreliable, Apple-only overflow area and is not confirmed
reachable by Android.

### Recommendation given §1 and §3

Use a two-tier UUID scheme:

1. A single **fixed, static "`pqcble-r1` app" service UUID** is what iOS actually
   advertises while backgrounded (the one UUID Apple's stack places in overflow).
   Android scans foreground and background with a `ScanFilter` on this fixed UUID — but
   this only helps Android find iOS if overflow-area delivery to non-iOS centrals works
   in practice, which remains the single most important unresolved item (see "Must
   confirm"). As a fallback that doesn't depend on overflow delivery at all, Android
   should also periodically attempt a direct GATT connect to any previously-seen
   `pqcble-r1`-advertising iOS peripheral address (address rotation permitting) and read
   the beacon characteristic.
2. The **rotating beacon bytes** are carried as: (i) a *foreground-only* rotating
   128-bit service UUID (per existing findings doc §9.1/§9.2), readable by both
   platforms off the standard AD structure, and (ii) a GATT characteristic read
   immediately after connect (§4(a)) as the background-compatible path, gated behind the
   fixed app UUID from (1).

This avoids depending on the unverified overflow-to-Android delivery path for the actual
secret beacon value, while still using it (if it works at all) purely as a low-stakes
"is a `pqcble-r1` app nearby" hint.

## 5. Connection-oriented transport: L2CAP CoC vs GATT notify/write-without-response

### 5.1 L2CAP CoC platform support

**Android** — `BluetoothDevice.createL2capChannel(int)` /
`createInsecureL2capChannel(int)` and `BluetoothServerSocket.listenUsingL2capChannel()` /
`listenUsingInsecureL2capChannel()`: confirmed present in the current
`developer.android.com/reference/android/bluetooth/BluetoothDevice` reference as the
LE-mode counterpart to classic `createRfcommSocketToServiceRecord(UUID)`. Widely
documented as introduced in **API 29 (Android 10)**; the exact "Added in API level 29"
badge did not render as plain text in this session's fetch and should be re-confirmed
directly against the reference page.

**iOS** — `CBPeripheralManager.publishL2CAPChannel(withEncryption:)` and
`CBCentralManager`'s L2CAP-open APIs, plus `CBL2CAPChannel` itself: confirmed via Apple's
structured availability metadata, **available since iOS 11.0**. Discussion text:

> "The system determines an unused Protocol and Service Multiplexer (PSM) at the time of
> publishing, and provides it to your app with
> `peripheralManager(_:didPublishL2CAPChannel:error:)`. **L2CAP channels aren't
> discoverable by themselves, so it's the app's responsibility to handle PSM discovery
> on the client.**"

This directly confirms the "PSM must be advertised via a GATT characteristic" caveat —
Apple states there is no advertising-level PSM discovery; the app must publish the PSM
value itself, e.g. via a GATT characteristic read.

**Wire compatibility:** both Android's LE L2CAP CoC and iOS's `CBL2CAPChannel` are
user-space bindings over the Bluetooth Core Specification's "LE Credit Based Flow
Control Mode" (Core Spec Vol 3, Part A, L2CAP §10 in 5.x numbering). **This exact spec
text could not be independently re-fetched in this session** (SIG spec behind an access
gate, consistent with the existing findings doc's §9.8 note). Treat the Vol 3 Part A
citation as plausible but unverified against primary spec text; both platforms'
public docs independently describe PSM-based setup and credit-based flow control
consistent with that section, but **no first-party cross-platform interop statement
exists from either vendor** — Apple's CoreBluetooth docs never mention Android and vice
versa. This pairing is untested by any source found and must be validated on real
devices.

**Interop caveats (derived from the docs above, not a confirmed interop report):**
- PSM assignment is dynamic and platform-chosen on both sides — Android: whatever the
  server socket negotiates; iOS: "the system determines an unused PSM." Neither side can
  hardcode a PSM; it must be exchanged out-of-band (e.g., via GATT), adding a round trip
  before L2CAP can even start, undercutting some of its latency advantage for small
  payloads.

### 5.2 GATT: MTU, PHY, DLE

- **ATT MTU max 517 B** per Bluetooth Core Spec (widely cited figure; not re-verified
  against primary spec text in this session, same SIG-access-gate reason as existing
  findings doc §9.8 — carried over, not newly confirmed).
- Android: `BluetoothGatt.requestMtu(int)` requests up to 517 B; negotiated value is the
  minimum of both sides' requests.
- iOS: Apple doesn't expose raw ATT MTU negotiation to apps; `CBPeripheral
  .maximumWriteValueLength(for:)` is the documented way apps learn usable write-payload
  size. Its exact current numeric guarantee wasn't retrieved in this session (fetch
  404'd/didn't render) — the commonly cited **160–185 B practical payload** figure for
  modern iPhones is **community-reported, not confirmed against a current Apple doc page
  in this session**.
- **2M PHY**: introduced in Core Spec 5.0. Android exposes
  `BluetoothGatt.setPreferredPhy()`/`readPhy()` since API 26, consistent with Android 8's
  "Bluetooth 5" feature support (not independently re-fetched this session). Apple
  exposes **no public PHY-selection API** to apps — CoreBluetooth negotiates PHY
  automatically/opaquely with no documented app-level control confirmed here.
- **DLE** (Data Length Extension, up to 251 B link-layer PDU): specified in Core Spec
  4.2. Neither platform's app-facing API (CoreBluetooth or `BluetoothGatt`) gives apps
  direct DLE control; it's typically negotiated transparently by the controller once a
  sufficiently large ATT MTU is requested. No first-party doc confirming exact DLE
  exposure was retrieved.
- **Realistic Android↔iOS GATT notification throughput:** **no first-party (Apple or
  Google) numeric throughput figure for cross-platform GATT streaming was found** in
  this session. The existing findings doc §9.6 already flags Nordic/community numbers
  and a 2026 arXiv nRF52840 energy paper, neither of which covers iOS-side throughput.
  Any number (e.g., community figures of a few KB/s to tens of KB/s depending on
  MTU/PHY/interval) must be labeled community-reported pending real measurement (see
  existing findings doc's P1/P2 validation plan).

### 5.3 Byte-budget estimate for the two payload sizes

Given the absence of a first-party cross-platform throughput number, transfer time is
better expressed as a function of negotiated MTU and connection interval than as a
single fabricated figure:

- **Introduction (~2.4 KB):** at a conservatively small practical payload (~150–200 B
  per write/notification, consistent with commonly-reported iOS negotiated MTU minus
  ATT/L2CAP headers — community-reported, unverified) this is roughly 12–16 PDUs; at one
  connection event per interval (commonly 15–50 ms, platform/OS-governed and not fully
  app-controllable on iOS) this lands on the order of a few hundred milliseconds to low
  seconds. Not precise without a confirmed MTU figure — flag for on-device measurement.
- **Ratchet epoch (~2.3 KB):** same order of magnitude; no materially different
  conclusion.
- Both sizes are small enough, relative to any plausible real MTU/PHY combination on
  either platform, that **transport choice (L2CAP vs GATT) is unlikely to dominate
  cost** — connection setup, service discovery, PSM exchange, and iOS's background
  connection-event throttling (§6) are far more likely to dominate wall-clock time than
  raw link throughput. This qualitative conclusion holds even without a precise
  throughput number.

**Recommendation:** given (a) L2CAP's extra PSM-discovery-via-GATT round trip, (b) no
confirmed first-party Android↔iOS LE-CoC interop statement, and (c) payload sizes small
enough that GATT's per-PDU overhead is immaterial, **GATT notify/write-without-response
is the lower-risk primary transport** for both payload sizes, with L2CAP CoC as an
optional higher-throughput fallback only after real-device interop is confirmed (useful
if `pqcble-r1` later adds materially larger payloads, e.g. file/media transfer).

## 6. iOS background connection lifetime and connection-event limits

**Verified** — *Core Bluetooth Background Processing for iOS Apps*:

> "Even if your app supports one or both of the Core Bluetooth background execution
> modes, it can't run forever. At some point, the system may need to terminate your app
> to free up memory for the current foreground app—causing any active or pending
> connections to be lost."
>
> "While your app is in the background you can still discover and connect to
> peripherals, and explore and interact with peripheral data. In addition, the system
> wakes up your app when any of the `CBCentralManagerDelegate` or `CBPeripheralDelegate`
> delegate methods are invoked."
>
> "Upon being woken up, an app has around **10 seconds** to complete a task. Ideally, it
> should complete the task as fast as possible and allow itself to be suspended again.
> Apps that spend too much time executing in the background can be throttled back by the
> system or killed."

This confirms: (a) an already-connected peripheral connection is maintained and its
delegate callbacks continue to fire in the background, as long as the app declared the
relevant background mode and hasn't been terminated for memory pressure; (b) there is a
documented **~10-second** per-wake execution budget before the system may suspend/
throttle again — the one hard numeric limit Apple publishes in this area; (c) no
persistent/indefinite guarantee — the system "may need to terminate your app."

**State restoration** — **verified** via the `CBCentralManagerOptionRestoreIdentifierKey`
reference:

> "Providing this key causes Core Bluetooth to call `centralManager(_:willRestoreState:)`
> with the preserved state when restoration is available." For scene-based apps,
> "`launchOptions` is always `nil` on launch… Persist the UID yourself… and pass it to
> `init(delegate:queue:options:)` on every launch."

The background-processing guide enumerates what the system preserves/restores for a
`CBCentralManager` (services scanned for with options, peripherals being/already
connected, subscribed characteristics) and for `CBPeripheralManager` (advertised data,
published services/characteristics, subscribed centrals). This is the mechanism that
lets the system **relaunch a fully-terminated app** in response to a matching Bluetooth
event — supporting the existing findings doc's §9.1 claim that "resume can run without
user action once connected."

**No documented numeric limit on connection-event length/interval while backgrounded**
was found in any first-party page fetched. Apple's statements are qualitative only
("the interval at which your central device scans for advertising packets increases" /
"the frequency at which your peripheral device sends advertising packets may decrease").
No equivalent first-party statement about *already-connected* GATT connection-interval
throttling (as opposed to scan/advertising cadence) was found — this is a genuine gap,
not an omission in this report.

## Must confirm on real devices

1. **Whether Android's `BluetoothLeScanner` surfaces an iOS background peripheral's
   overflow-area service UUID in scan results at all**, and if so through which raw AD
   type/byte layout. §1 gives first-party evidence suggesting "no" or "unreliable," but
   it was not empirically tested with real hardware capture (Wireshark/`btsnoop` on both
   platforms). **Single most important open item.**
2. **Exact byte-level format of Apple's overflow-area encoding** — present over the air
   in the legacy advertising PDU at all, or purely internal to the iOS Bluetooth daemon?
   The Continuity-protocol papers cited in §1.1 should be read in full and corroborated
   with a live packet capture against a current iOS version.
3. **Real connection latency for "connect → discover services → read beacon
   characteristic,"** especially cold-start: iOS backgrounded/suspended-with-state-
   restoration and terminated-with-state-restoration, where the app must be relaunched
   before any GATT operation can proceed. Apple's ~10-second background execution budget
   (§6) is the only published constraint; whether a cold state-restoration relaunch
   reliably completes connect+discover+read within that window needs device testing.
4. **Exact current negotiated ATT MTU and practical payload-per-write/notify figures for
   Android↔iOS GATT streaming** — no first-party numeric figure was retrievable; only
   community/vendor benchmark numbers exist and must be measured directly.
5. **Whether Android LE L2CAP CoC actually interoperates with iOS `CBL2CAPChannel` over
   the air** — no first-party cross-vendor interop statement exists from either Apple or
   Google; pure both-ends-present test needed.
6. **Exact Android API level `createL2capChannel`/`listenUsingL2capChannel` were
   introduced at** — strongly believed to be API 29 but the "Added in API level 29"
   badge didn't render as retrievable plain text in this session's fetch; re-confirm
   directly.
7. **Current numeric Android background-scan throttling policy** — the widely-cited
   "5 scans per 30 s" figure's expected AOSP location (`AppScanStats.java`) 404'd against
   current `main` (modularized Bluetooth stack likely moved it); re-derive from current
   AOSP or measure empirically per target OEM/API level (OEM battery-management skins on
   e.g. Samsung/Xiaomi are well known, though not confirmed here, to impose additional
   undocumented restrictions beyond stock AOSP).
8. **Whether iOS throttles/extends the connection interval of an already-connected GATT
   link while backgrounded** (distinct from scan/advertising cadence, which Apple
   documents qualitatively) — no first-party statement found either way; materially
   affects notify-based data-frame latency during background delivery.
9. **Exact Android 14 (API 34) enforcement details for the `connectedDevice`
   foreground-service type** — the direct doc URL 404'd in this session; re-fetch from
   its current location and read in full.
10. **iOS↔iOS background discovery status** — explicitly out of scope for `pqcble-r1`,
    but worth re-confirming empirically that it fails reliably, since any future scope
    change would depend on this.

## Recommended discovery and transport strategy

1. **Discovery/advertising:**
   - **Android↔Android:** standard rotating 128-bit service-UUID advertising (via
     `AdvertisingSet`/legacy `BluetoothLeAdvertiser` as capability allows) plus
     `ScanFilter`-based scanning, foreground and background, backed by a
     `connectedDevice` foreground service while actively connected and
     `BluetoothLeScanner.startScan(filters, settings, PendingIntent)` for wake-on-beacon
     when the process isn't resident. Most capable, lowest-risk path; both advertising
     and `ScanFilter`/`ParcelUuid` APIs are confirmed first-party and process-death
     resilient.
   - **Android↔iOS, iOS backgrounded as peripheral:** do **not** rely on the rotating
     beacon UUID reaching Android via iOS's overflow mechanism (§1's first-party docs
     lean negative, and items 1/2 above remain open). Instead:
     - iOS advertises a single **fixed, static, non-rotating app-identifying service
       UUID** in the background (the one UUID Apple's stack places in overflow —
       accepting the "app identity is somewhat exposed to any iOS device explicitly
       scanning for it" trade-off already noted in the existing findings doc §9.1).
     - Android scans (foreground or background, via `ScanFilter` + `PendingIntent`) for
       that fixed UUID **and/or** performs periodic direct-connect attempts to
       previously-seen candidate addresses, consistent with Android's own "there is no
       limitation on connecting to a device while the app is in the background"
       guidance.
     - Once connected, Android reads a GATT "beacon" characteristic to learn the current
       rotating beacon value and resume the session — i.e. **GATT read-after-connect,
       not UUID-embedding, is the backgrounded-iOS-compatible carrier for the rotating
       beacon**, matching the existing findings doc §9.1 item 2, now backed by
       first-party confirmation that (a) iOS cannot carry service/manufacturer data
       other than a service-UUID list even in the foreground, and (b) the background
       overflow path for that UUID is unreliable for non-iOS scanners.
     - When iOS is in the **foreground**, additionally use the rotating 128-bit
       service-UUID-as-beacon approach (embedding the 8–16 B PRF output directly as a
       generated `CBUUID`), since foreground advertisements place service UUIDs in the
       real, standard AD structure Android's `ScanRecord` parses natively — a
       zero-round-trip discovery path whenever both apps are foregrounded
       simultaneously, layered on top of the connect-and-read fallback.
   - **iOS↔iOS:** explicitly out of scope; no design effort beyond acknowledging it
     won't work reliably backgrounded.

2. **Transport:** use **GATT notifications/write-without-response** as the primary
   data-frame transport for both pairings, sized to work within conservative MTU
   assumptions (don't assume more than low-to-mid hundreds of bytes per PDU on iOS until
   measured). This avoids the L2CAP CoC PSM-discovery-via-GATT bootstrap cost and the
   unverified Android↔iOS LE-CoC interop risk (§5), while the ~2.3–2.4 KB payload sizes
   are small enough that GATT's framing overhead is immaterial to user-perceived
   latency. Keep **L2CAP CoC as an explicitly optional, feature-flagged fallback/future
   transport** for materially larger payloads (e.g. file/media transfer) — only after a
   dedicated real-device interop test confirms Android `createL2capChannel`/
   `listenUsingL2capChannel` and iOS `CBL2CAPChannel`/`publishL2CAPChannel(withEncryption:)`
   actually talk to each other, since no first-party source from either vendor currently
   claims cross-platform interop.

3. **Background connection keep-alive:** design the resume/ratchet protocol (existing
   findings doc §4.2) to tolerate the **~10-second** per-wake execution budget Apple
   documents for backgrounded delegate callbacks (§6) — the entire resume handshake plus
   one data frame should complete well within that window from a cold,
   state-restoration-triggered relaunch, since there's no guarantee of a second wake if
   the first is missed. On Android, pair the `connectedDevice` foreground service (for
   the duration of an active session) with `PendingIntent` scanning (for wake-from-
   stopped) as the two complementary primitives Google's current background-BLE guide
   names for exactly this need.
