# Energy and airtime measurement methodology for pqcble

**Status:** draft — primary-source literature review complete; several items marked
`UNVERIFIED` require hands-on confirmation in the device lab before the protocol below
can be trusted as a cross-vendor baseline. No lab measurements have been taken yet.

Builds on `docs/research/2026-10-05-android-ios-background-ble.md` (background
discovery/advertising constraints) and reuses the airtime model in
`docs/research/ble_airtime.py`. Answers the ticket "Energy and airtime measurement
methodology."

Sourcing convention (same as the companion background-BLE doc): **Verified** = traced to
a current official vendor doc or AOSP/Apple source, with the citing URL given.
**UNVERIFIED** = could not be confirmed against a primary source in this research pass,
or is architecturally plausible but unconfirmed; must be checked by hand in the lab
before being relied on.

## 0. Summary

No tool in this lab directly measures discharge-side BLE radio energy in SI units
(joules) on a stock, non-rooted, non-Pixel Android phone or a retail iPhone. Every
Android energy-reporting path (`dumpsys batterystats`, `BluetoothActivityEnergyInfo`,
Perfetto's `android.power`) is either a **timing-based model** fed by OEM-supplied
constants (`power_profile.xml`), or depends on hardware (ODPM/PowerStats HAL energy
rails) that Google's own docs say is "not yet available on most production phones" and
has historically been Pixel-only — and this lab has **no Pixels**. iOS has even less:
MetricKit's full metric list contains no Bluetooth-specific metric at all, and
Instruments'/PacketLogger's historical Bluetooth tooling is either undocumented in
current public Apple pages or gated behind Apple Developer Program tooling not
confirmed to work on retail, non-jailbroken devices.

What **is** solid, well-documented, and workable without any extra hardware:

1. **Airtime** can be measured precisely and model-independently via **Android's
   HCI snoop log** (`btsnoop`, host-side capture of Bluetooth controller traffic,
   no physical sniffer needed) — Android only, but the project is BLE-GATT, so the
   iOS side of a connection can usually be characterized from the Android peer's
   capture since the link-layer PDU exchange is symmetric per Core Spec timing rules.
2. **Energy** must be inferred as a *time-and-current* measurement using
   **`dumpsys batterystats`'s timing data combined with an external current draw
   proxy**, because no in-lab tool reports true joules. The practical fallback, given
   "no lab power monitor," is a **coulomb-counting / battery-percentage-regression**
   method using the stock `IHealth` HAL battery counters (`BatteryManager`,
   available on all compliant devices) over long, repeated, controlled runs, with
   statistical averaging to beat the counters' coarse resolution — explicitly a
   **relative, not absolute**, energy measurement, and this limitation must be stated
   in any report derived from it.
3. The nRF PPK2 is **not usable** for phone-side measurement (it is a development-board
   current/voltage source-measure unit for Nordic DKs, not a battery-bypass rig for
   phones) — confirmed by its own product documentation. A phone-battery-eliminator
   rig (Monsoon-style) is the correct class of tool but is explicitly **not in this
   lab's inventory** and is out of scope for this protocol; it is only flagged as the
   "right tool we don't have."
4. A USB inline power meter mostly measures **charging** current, not discharge-side
   peripheral draw, unless charge current is independently suppressed — Google's own
   Perfetto docs confirm this caveat and that the only documented workarounds are a
   USB data-only hub or an **undocumented, Pixel-specific, rooted sysfs write** (not
   usable here). `adb shell dumpsys battery unplug` only changes the *logical*
   plugged-state used by Doze/standby; it does not stop physical USB charge current.

Given these constraints, the protocol below is a **relative energy + absolute airtime**
methodology: airtime numbers (bytes, PDU counts, radio-on microseconds) are trustworthy
and portable across all 27 lab devices; energy numbers are necessarily comparative
(baseline-subtracted battery-drain deltas across many repeated runs), not calibrated
joule measurements, and every energy figure in a future report must carry that caveat.

## 1. Android software sources

### 1.1 `dumpsys batterystats` / Battery Historian

**Verified** — `BatteryStats` is a timing/state tracker, not a current/energy meter:

> "The service doesn't track battery current draw directly, but instead collects timing
> information that can be used to approximate battery consumption by different
> components." … "Battery use statistics are handled entirely by the framework and do
> not require OEM modifications."
— `source.android.com/docs/core/power` (https://source.android.com/docs/core/power)

Per-component "power used" numbers reported by `batterystats`/Battery Historian are
derived by multiplying measured **timing** (e.g. seconds of BLE scan, seconds of GATT
connection) against **manually curated OEM current-draw constants** in
`power_profile.xml` (`frameworks/base/core/res/res/xml/power_profile.xml`, referenced
from the same `source.android.com/docs/core/power` page) — i.e. attribution is a
**model-based estimate using OEM-declared constants**, not a measurement of actual
current. If an OEM's `power_profile.xml` entries for Bluetooth are wrong, stale, or
copy-pasted from a reference device (common on budget/rebadged chipset Android
builds, per general industry knowledge, not independently re-verified here), the
reported numbers will be wrong in the same proportion, silently.

The `BatteryStats` class fields live in
`frameworks/base/core/java/android/os/BatteryStats.java`
(https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/os/BatteryStats.java).

Official collection workflow:

```
adb shell dumpsys batterystats --enable full-wake-history
adb bugreport
```

— then load the bugreport into the Battery Historian web UI.
(https://developer.android.com/topic/performance/power/setup-battery-historian,
https://developer.android.com/topic/performance/power/battery-historian)

**Verified** — `google/battery-historian` is still distributed as a Docker image
(`gcr.io/android-battery-historian/stable:3.1`) and Android's current developer docs
still link to it as the sanctioned viewer
(https://github.com/google/battery-historian). **UNVERIFIED**: whether it receives
active engineering investment beyond the Docker image refresh; no changelog/commit
cadence was checked. Treat as "still the officially linked tool, maintenance level
unknown," not as "actively maintained."

**UNVERIFIED**: whether `dumpsys batterystats --checkin` emits a distinct per-UID
**Bluetooth energy** field analogous to the `mobileradio`/`wifi` checkin keys. The
checkin text format is not enumerated on a public doc page; confirming this requires
reading `BatteryStatsImpl.dumpCheckinLocked` in
`frameworks/base/core/java/com/android/internal/os/BatteryStatsImpl.java` and/or Battery
Historian's Go `parseutils` package, which was not done in this pass. **Action before
relying on checkin parsing**: run `adb shell dumpsys batterystats --checkin` on one lab
phone per chipset family and grep the output for `ble`/`bt`/`blem` tags before building
tooling around it.

### 1.2 `BluetoothActivityEnergyInfo` / `dumpsys bluetooth_manager`

**Verified** — the AOSP data structure is real and current:

```
mTimestamp, mBluetoothStackState, mControllerTxTimeMs, mControllerRxTimeMs,
mControllerIdleTimeMs, mControllerEnergyUsed, mUidTraffic
```
`packages/modules/Bluetooth/framework/java/android/bluetooth/BluetoothActivityEnergyInfo.java`
(https://android.googlesource.com/platform/packages/modules/Bluetooth/+/refs/heads/main/framework/java/android/bluetooth/BluetoothActivityEnergyInfo.java)

This is a **hidden `@SystemApi(client = PRIVILEGED_APPS)` API** — not directly callable
by a normal third-party test app without system/privileged signing or a rooted
device/shell-level `dumpsys` invocation.

`dumpsys bluetooth_manager` is the AOSP-documented debugging entry point, and HCI snoop
extraction from a bugreport uses the bundled `btsnooz.py` script
(`packages/modules/Bluetooth/system/tools/scripts/btsnooz.py`):
> "To check the Bluetooth service status using dumpsys, use the following command:
> `adb shell dumpsys bluetooth_manager`" … "To extract snoop logs from the bug report,
> use the btsnooz script."
— https://source.android.com/docs/core/connect/bluetooth/verifying_debugging

`AdapterService.java` (the system-server-side Bluetooth service) wires in
`BluetoothActivityEnergyInfo`/`IBluetoothActivityEnergyInfoListener`, confirming the
data path is live in the current Bluetooth module
(https://android.googlesource.com/platform/packages/modules/Bluetooth/+/refs/heads/main/android/app/src/com/android/bluetooth/btservice/AdapterService.java).

**UNVERIFIED** (architecturally plausible, not confirmed from a primary doc): whether
the controller Tx/Rx/idle-time numbers are actually populated by the **vendor HCI
firmware/HAL** on non-reference/non-Pixel chipsets, or silently return all-zero/garbage
if the vendor stack doesn't implement the underlying "Read Tx/Rx/Idle time" vendor HCI
extension. No AOSP doc page states a hard Pixel-only requirement for this specific API
(distinct from the ODPM/PowerStats HAL case in §1.3, which **is** explicitly
Pixin-documented), but given 23 phones across OnePlus/OPPO/Xiaomi/Nothing/Samsung/
Motorola/Nokia/Realme/Gigaset/Huawei on Qualcomm/MediaTek/Exynos/Kirin with **no
Pixels**, this must be **empirically spot-checked per chipset family** before any
report relies on it — do not assume it works, do not assume it's zero; check with
`adb shell dumpsys bluetooth_manager` while a GATT connection is active, per device.

### 1.3 PowerStats HAL / On-Device Power Monitor (ODPM)

**Verified** — the current AIDL interface (`getPowerEntityInfo`, `getStateResidency`,
`getEnergyConsumerInfo`/`getEnergyConsumed`, `getEnergyMeterInfo`) requires a
per-device vendor implementation to expose energy "channels"/"consumers" at all — it is
not automatically populated on any device merely by running a compatible Android
version:
`hardware/interfaces/power/stats/aidl/android/hardware/power/stats/IPowerStats.aidl`
(https://android.googlesource.com/platform/hardware/interfaces/+/refs/heads/main/power/stats/aidl/android/hardware/power/stats/IPowerStats.aidl)

**Verified, directly dispositive for this lab** — Perfetto's own docs state:

> "This data source has been introduced in Android 10 (Q) and requires the dedicated
> hardware on the device. **This hardware is not yet available on most production
> phones.**"
— https://perfetto.dev/docs/data-sources/battery-counters (ODPM section)

...and the same page's rail-selection instructions are given specifically "on Pixel
devices," reinforcing the historical Pixel-centricity of this feature.

**Conclusion for this lab: assume ODPM/PowerStats HAL energy rails are unavailable
project-wide** (23 Android phones, zero Pixels) **unless proven otherwise per device**
— this is a hard limitation to state in any report, not something to keep re-checking.
If any lab phone happens to expose it (verify with
`adb shell dumpsys android.hardware.power.stats.IPowerStats/default` or via Perfetto's
rail-listing trace config), treat it as a bonus data point for that device only, not a
baseline the whole protocol can depend on.

### 1.4 Perfetto power data sources

**Verified** (https://perfetto.dev/docs/data-sources/battery-counters) — `android.power`
exposes three distinct things:

1. **Battery counters** (`BATTERY_COUNTER_CAPACITY_PERCENT`, `_CHARGE`, `_CURRENT`,
   `_VOLTAGE`) — polls the Android `IHealth` HAL
   (https://cs.android.com/android/platform/superproject/main/+/main:hardware/interfaces/health/2.0/IHealth.hal),
   which **is** broadly implemented (compliant devices must implement the Health HAL
   for `BatteryManager`), but "resolution depends on the device manufacturer." This is
   the one generically-available, non-Pixel-only data source in this list.
2. **ODPM / power rails** (`collect_power_rails: true`) — requires the PowerStats HAL
   hardware described in §1.3, "not yet available on most production phones."
3. `linux.sysfs_power` — ChromeOS/Linux fallback, **not applicable to Android phones**.

**Verified** — Perfetto does **not** document any Bluetooth-specific energy counter;
`android.power` only surfaces whole-battery or whole-rail-group energy, never a
per-radio (BLE) breakdown. There is no Perfetto equivalent of "BLE joules used in this
trace window."

**Verified, directly relevant to the "USB power meter" question (§3)** — Perfetto's own
docs state the USB-charging caveat in so many words:

> "Battery counters measure the charge flowing in and out of the battery. If the device
> is plugged to a USB cable, you will likely observe a positive instantaneous current …
> This can make measurements in lab settings problematic."
— https://perfetto.dev/docs/data-sources/battery-counters ("Measuring charge while
plugged on USB")

The only documented workarounds are a USB **data-only** hub (electrically disconnects
charge pins) or, on a rooted Pixel 2 specifically, an "undocumented and not exposed
through any HAL" SoC-specific sysfs write to suspend charging — neither is usable
generically across this lab's 23 non-Pixel phones.

### 1.5 HCI snoop logs (btsnoop) — the one reliable, hardware-free source

**Verified** (https://source.android.com/docs/core/connect/bluetooth/verifying_debugging)
— HCI snoop logging is explicitly a **host-side** capture of traffic between the Android
application processor and the Bluetooth controller chip — distinct from an
over-the-air RF capture:

> "In Android 4.4 and later, you can manually collect BTSnoop logs, which resemble the
> snoop format in RFC 1761. These logs capture the Host Controller Interface (HCI)
> packets."

File format: RFC 1761 "snoop" format, cited directly by the AOSP doc
(https://www.rfc-editor.org/rfc/rfc1761). Workflow:

1. Settings → Developer Options → "Enable Bluetooth HCI snoop log" → toggle on,
   restart Bluetooth (or reboot).
2. Exercise the pqcble flow (discovery/Resume/pairing/ratchet) for the window to be
   measured.
3. `adb bugreport` (or on-device log at `/data/misc/bluetooth/logs`, root/debug build
   required for direct file pull).
4. Extract with AOSP's bundled script,
   `packages/modules/Bluetooth/system/tools/scripts/btsnooz.py`, to reconstitute a
   standard `.btsnoop` / `.pklg`-compatible log, then open in Wireshark (which has a
   native "Bluetooth HCI" dissector) for packet-level inspection.

This **works without a physical sniffer** — it is purely host-side software logging —
which matches the lab's "no BLE sniffer" constraint, with the caveat that it captures
HCI framing/timing at the host↔controller boundary, not literal over-the-air RF timing;
for this project's purpose (counting PDUs, bytes, connection events, and GATT
operations per logical message) this is the right level of capture, since what we want
to bill is "airtime our protocol causes the radio to use," not raw RF waveform analysis.

**Connection-event / airtime timing model — primary source status:**

**Verified (existence/scope only)** — Bluetooth Core Specification (current major
version 6.0/6.1, Vol 6 "Low Energy Controller," Part B covers link-layer connection
event timing): https://www.bluetooth.com/specifications/specs/core-specification-6-0/
— **UNVERIFIED in detail**: the exact Part B timing tables (inter-frame space, PDU
overhead bytes per PHY, inter-connection-event gap rules) were not re-fetched/re-derived
in this research pass; the repo's own `docs/research/ble_airtime.py` already encodes a
reasonable working model (DLE 251 B payload, 150 µs T_IFS, empty-ACK-per-data-PDU, 1M/2M
PHY byte-time arithmetic) and should be treated as the project's airtime model of
record, cross-checked against Core Spec Part B before being called authoritative.

**UNVERIFIED / likely does not exist**: no Nordic Semiconductor page was found that
ties BLE connection-event/airtime estimation specifically to **HCI snoop log**
analysis. Nordic's public tooling in this space (the "Online Power Profiler," linked
from the PPK2 product page) estimates **current consumption** for BLE/LTE-M/NB-IoT from
lab-characterized nRF-silicon models — it is a current estimator for Nordic chips, not
an HCI-log airtime calculator, and not applicable to phone-side analysis. Any
PDU-count × PHY-rate airtime model for this project must be derived independently from
Core Spec timing parameters (as `ble_airtime.py` already does), not cited to a vendor
tool.

## 2. iOS

### 2.1 Instruments Energy Log

**Verified** — Apple's current developer docs funnel energy/performance analysis
through two sanctioned paths, neither of which is Bluetooth-specific:

- `developer.apple.com/documentation/xcode/improving-your-app-s-performance`: confirms
  Xcode Organizer (fed by MetricKit) is Apple's primary tool for shipped-app energy/
  launch/memory data; MetricKit "goes beyond the metrics in the Metrics organizer to
  include average pixel luminance, cellular network conditions, and durations
  associated with custom OSSignpost events" — **no mention of Bluetooth energy**.
- `developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-shipping-app`:
  Organizer reports "launch times, memory usage, UI responsiveness, and impact on the
  battery" for **shipped, App-Store-distributed** apps using anonymized aggregated
  telemetry, with "Insufficient usage data available" below some user-volume threshold
  — impractical for an internal 27-device lab test, not production users.

**UNVERIFIED**: the classic standalone Instruments "Energy Log" template's current exact
metric list could not be confirmed — Apple's Instruments Help page
(`help.apple.com/instruments/mac/current/`) is JavaScript-rendered and was not
scrapable as plain text in this pass. Apple's current public docs steer users toward
Xcode Organizer + MetricKit rather than the old standalone template, suggesting but not
confirming it may be deprecated/superseded.

**UNVERIFIED**: minimum iOS/Xcode-version compatibility boundaries for live Instruments
profiling of the **1st-generation iPhone SE** were not found in a primary doc.
Instruments/Xcode device support is gated by the connected device's max supported iOS
version and the host Xcode version; the SE (1st gen) tops out well below iOS 17/26.
**Must be verified directly in the lab** (plug the SE 1 into the available Xcode
version and see what Instruments templates/targets are offered), not assumed from docs.

### 2.2 MetricKit

**Verified** (https://developer.apple.com/documentation/metrickit,
https://developer.apple.com/documentation/metrickit/mxmetricpayload) — the full
`MXMetricPayload` property list is: `cellularConditionMetrics`
(`MXCellularConditionMetric`), `cpuMetrics`, `displayMetrics`, `gpuMetrics`,
`locationActivityMetrics`, `networkTransferMetrics`, `applicationExitMetrics`,
`applicationTimeMetrics`, `memoryMetrics`, `applicationLaunchMetrics`,
`animationMetrics`, `applicationResponsivenessMetrics`, `diskIOMetrics`,
`signpostMetrics`, `diskSpaceUsageMetrics`.

**Verified, hard negative result**: **there is no Bluetooth-specific metric class
anywhere in MetricKit.** `networkTransferMetrics` (`MXNetworkTransferMetric`) covers
only cellular/Wi-Fi upload/download byte counts. `MXCellularConditionMetric` is
confirmed cellular-signal-strength-only ("the cellular condition measurements for the
reporting period") and is **confirmed irrelevant to BLE**, as suspected in the ticket.
MetricKit cannot be used for any part of this protocol.

### 2.3 PacketLogger / "Additional Tools for Xcode" / sysdiagnose

**Verified**: Apple's general Bluetooth developer landing page
(`developer.apple.com/bluetooth/`) contains only a Core Bluetooth framework marketing
blurb — no PacketLogger/Bluetooth Explorer documentation is published there.

**Verified**: attempting to fetch the "Additional Tools for Xcode" download listing
(`developer.apple.com/download/all/?q=Additional%20Tools`) redirects to
`idmsa.apple.com` sign-in — direct evidence that the disk image containing PacketLogger
and Bluetooth Explorer is gated behind an authenticated Apple Developer account and has
no freely published doc page of its own.

**UNVERIFIED, flag strongly**: historically, using PacketLogger's live HCI capture mode
against a **connected iOS device** (as opposed to just the Mac's own Bluetooth
controller) is widely reported (community knowledge, not a primary Apple doc found in
this pass) to require installing a special Bluetooth diagnostic/developer profile on
the iOS device, provisioned through Apple's Bluetooth Special Interest Group developer
resources — no current, indexed Apple doc page describing this provisioning step was
located; it may only exist inside the PacketLogger app's bundled help or an
unpublished/expired WWDC session. **Treat PacketLogger-against-iPhone as unconfirmed
until hands-on tested** against the lab's iPhone 15 / 12 mini; budget a short spike to
find out whether it works with a plain retail (non-jailbroken) device before depending
on it in the protocol.

**Verified (existence only)**: `sysdiagnose` is Apple's sanctioned no-special-hardware
diagnostic path; Apple's "Profiles and Logs" page exists for submitting diagnostic
captures including Bluetooth-related sysdiagnose data
(https://developer.apple.com/feedback-assistant/profiles-and-logs/?name=bluetooth,
redirected from `/bug-reporting/profiles-and-logs/`), but the fetched content was only
high-level marketing/process copy. **UNVERIFIED in technical detail**: whether a
sysdiagnose Bluetooth log actually contains HCI-level timing data suitable for airtime
analysis, versus only high-level connection/state events. Must be tested by taking a
sysdiagnose on one iPhone during an active pqcble connection and inspecting the
resulting Bluetooth log bundle contents directly.

### 2.4 iOS summary

There is **no confirmed, freely available, primary-sourced way to get Bluetooth energy
or HCI-level airtime data off a retail, non-jailbroken iPhone in this lab** from
official Apple tooling alone. The two live leads worth a short hands-on spike are (a)
PacketLogger against a connected device (status unknown, may require developer
profile/approval) and (b) sysdiagnose Bluetooth log contents (status unknown, may be
too high-level). Absent either panning out, the realistic position for iOS in this
protocol is: **airtime is derived from the Android side of each cross-platform
connection** (link-layer PDU exchange is symmetric, so Android's HCI snoop capture of
an Android↔iOS connection describes both ends' airtime equally), and **iOS-side energy
is only estimated indirectly** via the coulomb-counting method in §4, using iOS's own
battery-percentage/`UIDevice.batteryLevel` API as the (coarse, OS-reported) discharge
proxy — note `UIDevice.batteryLevel` resolution is ~1% steps, which is why long,
repeated runs are required (see §4.3).

## 3. Cheap hardware

### 3.1 nRF PPK2

**Verified** (Internet Archive capture of the official Nordic product page; the live
site blocks automated fetches via a Cloudflare challenge — archived primary source:
https://web.archive.org/web/20240521163026/https://www.nordicsemi.com/products/development-hardware/power-profiler-kit-2):

> "The PPK2 is a flexible, low-cost, standalone unit, which can measure and optionally
> supply currents all the way from sub-µA and as high as 1A **on all Nordic DKs**, in
> addition to external hardware."

Specs confirmed: USB-powered; Source Measure Unit (SMU) mode supplies 0.8–5V to the
device under test at up to 1A; Ampere-meter (AMP) mode requires an *external* 0.8–5V
supply to the DUT; resolution 100 nA–1 mA depending on range. Explicitly scoped to
Nordic silicon: "support for both short range applications on our nRF51, nRF52 and
nRF53 Series, in addition to our nRF91 Series cellular SiP."

**Verified, dispositive**: no inline "insert between phone and battery" mode is
documented or implied anywhere in the product description. The DUT connection model
(jumper cables + 10-pin logic-port header cable) matches bare dev-board pin headers,
not a phone's internal 2-wire battery connector, and the voltage range (0.8–5V at ≤1A)
does not match typical phone battery discharge profiles (single-cell Li-ion, higher
peak currents, no standard 2-pin interrupt harness). **PPK2 cannot be used to measure
phone battery energy in this lab**, confirmed from its own product documentation, not
merely inferred.

`docs.nordicsemi.com`'s detailed PPK2 User Guide pages are also Cloudflare-protected and
were not fetchable in this pass (Wayback Machine returned only an index listing, not
page content) — the product-page archive above was sufficient to confirm scope/specs,
but **UNVERIFIED**: any fine print in the User Guide that might describe an
unsupported/off-label bypass mode was not checked.

### 3.2 Phone-scale battery-bypass rigs (contrast, not available in this lab)

The correct class of tool for true phone-side joule measurement is a **battery
eliminator/bypass rig** — e.g. Monsoon Solutions' HVPM/LVPM Power Monitor units with a
phone-model-specific eliminator board that physically replaces the battery pack with a
regulated bench supply wired through the monitor, or academic projects like PowerTutor
that reverse-engineer OEM current models. This is a fundamentally different hardware
approach from the PPK2 (bench power supply + current meter in place of the battery,
not a dev-board probe), and **this lab has none of this class of equipment** (no
Monsoon, no Otii, no Joulescope, per the ticket's stated constraints). This is flagged
here only as "the right tool we don't have," not pursued further — no new primary
source was fetched for Monsoon in this pass since it is out of scope for this lab's
actual protocol.

### 3.3 USB inline power meters

A phone exercising BLE in this test protocol runs on **battery**, not USB, for any
measurement to reflect true discharge-side peripheral draw. An inline USB-C power
meter/logger (Power-Z, ChargerLAB, FNIRSI, etc. — general product knowledge, not
separately cited) connected while the phone charges mostly reflects **charging circuit
behavior** (CC/CV charge curve, thermal throttling, etc.), not BLE radio draw, because
the charge current dominates and partially masks the radio's incremental draw.

This is independently confirmed by Perfetto's own docs (§1.4): a USB-plugged device
shows a **positive instantaneous current** (charging) in `BatteryManager`/`IHealth`
counters, and the only documented ways to get a true discharge reading while connected
are a USB **data-only** hub (no VBUS/charge pins wired) or a rooted, Pixel-specific,
undocumented sysfs suspend-charging write — neither generalizes to this lab's 23
non-Pixel, non-rooted-by-default phones.

**Verified, and explicitly a different problem**: `adb shell dumpsys battery unplug`
(with companion `adb shell dumpsys battery reset`) is an official, documented ADB
command (https://developer.android.com/training/monitoring-device-state/doze-standby)
that forces the **software-reported** plugged state for Doze/App Standby testing
purposes. It does **not** stop physical USB charge current and does **not** make an
inline USB meter read true discharge current — it only affects what the OS *believes*
about plugged state for power-management policy testing. Do not conflate this with a
physical charge-current cutoff.

**Protocol implication**: for any energy measurement in this project, phones under test
must be run **on battery, unplugged, screen off**, not tethered to a USB power meter —
inline USB meters are not usable for this project's energy questions at all, beyond
possibly confirming charge-cycle counts for unrelated battery-health bookkeeping.

## 4. Protocol

Given §0–§3, the protocol below separates **airtime** (precise, hardware-free, portable
across both platforms) from **energy** (necessarily relative, battery-percentage/
coulomb-counting based, requiring heavy statistical averaging because no calibrated
joule-level instrument is available).

### 4.1 Airtime protocol (Android-anchored, applies to both platforms' link)

1. On an Android device acting as one end of the connection, enable "Enable Bluetooth
   HCI snoop log" in Developer Options and restart Bluetooth (§1.5).
2. Run the scenario to be measured in isolation — one of: (a) idle background
   advertise+scan for a fixed wall-clock window (e.g. 1 hour), (b) a single Resume
   handshake (57 B + 49 B) followed immediately by a clean disconnect, (c) a single
   application message of known plaintext size, (d) one full pairing (~2.4 KB KEM
   traffic), (e) one PQ ratchet epoch (~2.3 KB). Run each scenario **in its own
   isolated capture window**, not interleaved, so PDUs can be unambiguously attributed.
3. Pull the capture via `adb bugreport` and extract with
   `packages/modules/Bluetooth/system/tools/scripts/btsnooz.py` (or pull
   `/data/misc/bluetooth/logs` directly on a debug/rooted lab device), producing a
   standard btsnoop file openable in Wireshark's "Bluetooth HCI" dissector.
4. From the capture, extract: PDU count by type (ADV_IND/SCAN_REQ/SCAN_RSP for
   discovery; LL_DATA/empty-ACK for GATT traffic; connection parameter update PDUs),
   connection interval actually negotiated, PHY actually used (1M/2M), and total
   elapsed connection-event time for the scenario window.
5. Cross-check the observed PDU-count/byte-count/airtime-µs numbers against the
   project's model in `docs/research/ble_airtime.py` (DLE 251 B payload, T_IFS 150 µs,
   empty-ACK-per-data-PDU model) — treat large discrepancies as a signal to revisit the
   model's Core Spec Part B assumptions (§1.5) rather than silently trusting either
   source.
6. Repeat each scenario **at least 10 times** per device under test to capture
   controller-level jitter (retransmissions, connection-parameter renegotiation,
   OEM-specific scheduling quirks) — report median and IQR, not a single run.
7. Because this captures **host-side HCI framing**, not raw RF, note explicitly in any
   report that "airtime" here means "radio-on time implied by the HCI exchange,"
   not a literal RF-capture timestamp; this is the correct level of abstraction for
   billing the protocol's own overhead, not for RF-layer interference debugging.
8. For the iOS side of an Android↔iOS connection, rely on the Android peer's capture
   (link-layer PDU exchange, connection interval, and PHY are symmetric/negotiated
   jointly per Core Spec) rather than attempting a separate iOS-side HCI capture,
   unless the §2.3 PacketLogger/sysdiagnose spike pans out.

### 4.2 Per-scenario breakdown to report

- **Idle background cost per hour** (advertise + scan, no connection): capture a full
  hour with no application traffic, count ADV_IND/SCAN_REQ/SCAN_RSP PDUs and derive
  airtime fraction of the hour; separately run the §4.3 energy protocol for the same
  one-hour window (screen off, airplane mode except BT) to get a relative energy
  baseline.
- **Cost per Resume**: isolate exactly the 57 B + 49 B handshake plus its surrounding
  connection-establishment PDUs (CONNECT_IND, first connection-event exchange) in the
  capture; report PDU count, airtime µs, and bytes-over-the-air (including L2CAP/ATT/LL
  framing overhead, not just the 106 B payload).
- **Cost per message**: isolate one GATT write/notify cycle for one known plaintext
  size at a time, across a representative size range (smallest/typical/largest
  expected frame) — report airtime and PDU count as a function of payload size, and fit
  against the `ble_airtime.py` model's PDU-count formula.
- **Pairing cost**: isolate the full ~2.4 KB KEM exchange; report total PDU count,
  total airtime, and wall-clock duration (wall-clock duration also matters for UX, not
  just radio cost, and may be dominated by processing time on slow/old devices like the
  SE 1st gen, not radio time — call this out separately).
- **PQ ratchet epoch cost**: same breakdown as pairing, for the ~2.3 KB-per-epoch
  exchange; additionally report this as "cost per epoch" and "cost per epoch normalized
  per day" for whatever epoch-rotation policy the ratchet design settles on, since the
  ticket's energy budget question is really "epochs/day × cost/epoch."

### 4.3 Energy protocol (relative, coulomb-counting / battery-percentage regression)

No tool in this lab reports calibrated joules (§0). The practical substitute:

1. **Controls, applied identically across all runs and all 27 devices:**
   - Airplane mode **on**, Bluetooth **manually re-enabled** afterward (kills
     Wi-Fi/cellular radio contributions, isolates BLE as the only active radio besides
     baseline CPU/display).
   - Screen **off** for the duration of the measurement window (eliminates display
     power, the single largest and most variable component on most phones); use `adb
     shell input keyevent KEYCODE_POWER` or a lab fixture to turn the screen off after
     starting the test harness, and verify via `adb shell dumpsys power` that the
     device is actually asleep, not just dimmed.
   - Battery at a fixed, consistent state-of-charge window at the start of each run
     (e.g. always start at 70–80%, discard runs that cross a charge-curve inflection
     point near 0% or 100% where current/voltage behavior is nonlinear).
   - Ambient temperature roughly constant (BLE/CPU current draw is temperature
     dependent; avoid measuring a phone that just came off a charger, or back-to-back
     with no cooldown, since thermal state biases results).
   - Background apps/sync disabled or frozen as far as practical (this cannot be made
     perfect on heavily customized OEM Android builds, which is itself a source of
     cross-device variance to report, not eliminate).
2. **Baseline-subtraction design**: for each device, first measure a **BLE-off
   baseline** — same controls, Bluetooth disabled entirely, same wall-clock duration —
   to capture the device's idle CPU/display-off/misc-radio power floor. Then measure
   the **scenario-under-test** (idle advertise+scan, or N repetitions of
   Resume/message/pairing/ratchet back-to-back inside the same wall-clock window) with
   Bluetooth on. The **energy attributable to BLE** is the batterystats-reported or
   coulomb-derived drain in the scenario run **minus** the BLE-off baseline run, both
   normalized to the same wall-clock duration.
3. **Measurement source for the drain itself**, in order of preference per device,
   checked empirically rather than assumed:
   a. `BluetoothActivityEnergyInfo` controller Tx/Rx/idle-time + `mControllerEnergyUsed`
      via `adb shell dumpsys bluetooth_manager`, **if** it returns non-zero, plausible
      values on that specific device (§1.2 — verify per chipset family before trusting;
      expect this to fail on a meaningful fraction of the 23 phones).
   b. Battery percentage via `adb shell dumpsys battery` (or on iOS,
      `UIDevice.batteryLevel` in a small harness app) sampled at the start and end of a
      long repeated-scenario run — because OS-reported battery percentage is coarse
      (~1% steps on both platforms), **each run must last long enough, or repeat the
      scenario enough times back-to-back, to move the percentage by several points**
      (e.g. run 200–500 Resume handshakes back-to-back, or a multi-hour idle-advertise
      window) rather than relying on sub-percent interpolation.
   c. `dumpsys batterystats`'s modeled per-component "power used" number (§1.1), used
      only as a **secondary, model-based cross-check**, not a primary source, given its
      dependency on OEM-supplied `power_profile.xml` constants of unknown accuracy on
      this lab's non-reference devices.
4. **Repetitions**: run each (device × scenario) combination **at least 5 independent
   baseline-subtracted trials**, each trial being a full "BLE-off baseline, then
   BLE-on scenario" pair measured back-to-back on the same charge-state window, and
   report mean ± standard deviation (or median ± IQR if the distribution is skewed,
   which is likely given OEM scheduling jitter). Given 27 devices × 5 scenarios × 5
   trials × (baseline + scenario) = a large matrix, prioritize covering **one device
   per chipset family first** (Qualcomm/MediaTek/Exynos/Kirin, plus one iOS device),
   then expand to the full 23+4 device set only for the scenarios that show
   surprising/outlier results on the first pass — treat the full-matrix run as a
   confirmation pass, not the first thing to attempt.
5. **Explicit caveat to carry into any report**: every energy number produced by this
   protocol is a **relative, baseline-subtracted, battery-percentage or
   vendor-HAL-timing-derived estimate**, not a calibrated joule measurement. Treat
   cross-device comparisons (e.g. "device A uses 2× the energy of device B for the same
   scenario") as more trustworthy than absolute numbers (e.g. "pairing costs 14 mJ"),
   since relative comparisons partially cancel out `power_profile.xml`/battery-gauge
   calibration errors that are likely consistent within one device across repeated
   trials, but not comparable in absolute terms across different OEM calibrations.

### 4.4 What would upgrade this protocol, if available later

- A Monsoon-style phone battery-eliminator rig (or Otii/Joulescope with a
  phone-specific interposer) would replace all of §4.3 with true joule measurements —
  explicitly out of scope for this lab today (§3.2), but worth flagging as the single
  highest-value equipment purchase if energy numbers from this protocol prove too noisy
  to act on.
- A real BLE sniffer (Ellisys/Frontline/nRF Sniffer) would let RF-layer airtime be
  cross-checked against the HCI-log-derived model in §4.1, and would be the only way to
  independently verify the `ble_airtime.py` model's Core Spec Part B assumptions
  (§1.5) rather than relying on Android's host-side view alone.
- Resolving the §2.3 PacketLogger/sysdiagnose UNVERIFIED items would let iOS airtime be
  measured independently rather than inferred symmetrically from the Android peer.

## 5. Open items requiring lab verification (not resolvable from docs alone)

1. Does `BluetoothActivityEnergyInfo`/`dumpsys bluetooth_manager` return non-zero,
   plausible controller Tx/Rx/idle times on each of the 23 Android phones (one check
   per chipset family at minimum)? (§1.2)
2. Does `dumpsys batterystats --checkin` emit a distinct per-UID Bluetooth energy
   field? Not found in public docs; check the raw checkin output directly. (§1.1)
3. Does any lab phone unexpectedly expose PowerStats HAL/ODPM energy rails despite
   having no Pixels? Spot-check via Perfetto rail-listing or
   `dumpsys android.hardware.power.stats.IPowerStats/default`. (§1.3)
4. What iOS/Xcode-version ceiling does the iPhone SE (1st gen) actually hit for live
   Instruments profiling? (§2.1)
5. Does PacketLogger's live HCI capture mode work against the lab's iPhone 15 / 12 mini
   without a special Bluetooth developer profile/approval? (§2.3)
6. Does a sysdiagnose Bluetooth log bundle actually contain HCI-level timing data, or
   only high-level connection/state events? (§2.3)
7. Do the project's `ble_airtime.py` model assumptions (DLE 251 B, 150 µs T_IFS,
   empty-ACK-per-data-PDU) match Core Spec Vol 6 Part B's actual connection-event
   timing tables closely enough to trust as "ground truth" absent a real sniffer?
   (§1.5)
