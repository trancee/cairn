---
status: accepted
date: 2026-10-28
version: cairn-r1
---

# 0038: Move Android's extended advert to the LE 2M secondary PHY when iOS is near

## Context

[ADR 0028](0028-android-extended-advertising.md) moved Android to an
extended connectable advert where the controller supports it. Its auxiliary
packet (`AUX_ADV_IND`) uses the LE 1M PHY. ADR 0028 rejected 2M because "a
scanner without 2M support would miss the advert".

No iPhone reported that advert, so iOS could dial only Android phones that
advertise legacy ([ADR 0037](0037-ios-ble-adapter.md),
[issue 33](../../.scratch/cairn-r1/issues/33-slice-s3.md)). Yet
`CBCentralManager.supports(.extendedScanAndConnect)` is true on these
iPhones. Apple documents it only as "The hardware supports extended scans
and enhanced connection creation". The Accessory Design Guidelines (R32,
§57.3) list only legacy PDUs for general accessories. They require extended
advertising only for spatial accessories, and those must also support LE 2M
(§19.4.5.4). No document states which extended adverts iOS reports.

Controlled A/B, 2026-10-28:
- A probe app scanned with no service filter and allowed duplicates. It never
  connected or advertised, and logged every advert with a non-zero
  `kCBAdvDataRxSecondaryPHY` and every Cairn advert, for 25 s per variant.
- An Android phone ran one advert variant at a time, all with the same
  payload, at a 100 ms interval.

| Android advert (primary 1M) | iPhone 12 mini, iOS 27 |
|---|---|
| Extended, connectable, secondary 1M (ADR 0028) | 0, 0, 0 |
| Extended, non-connectable, secondary 1M | 0 |
| Extended, scannable, data in the scan response, secondary 1M | 0 |
| Extended, secondary 1M, more than 31 B of data | 0 |
| Extended, secondary 1M, non-discoverable, bare UUID, or with Tx power | 0 each |
| **Extended, connectable, secondary 2M** | **60, 62, 58** |
| Legacy (`ADV_IND`), control | 203 |

The table counts reports. The repeated runs gave the same result on:
- a Pocophone F1 (Snapdragon 845, Android 10): 1M 0, 2M 80, legacy 184;
- an iPhone 15 (iOS 17.6.1): 1M 0, 2M 67;
- an iPhone SE 2020 (iOS 18.7.8): 1M 0, 2M 85.

Every 2M report carried `kCBAdvDataRxSecondaryPHY` = 2. During the 1M runs
the advert was on air: the Pocophone found the Nothing's 1M set and dialled
it.

Root cause: iOS reports an extended advert to apps only when its auxiliary
packet is on LE 2M. Auxiliary packets on LE 1M never reach Core Bluetooth on
iOS 17, 18 or 27, whatever the advert's other properties. The
`extendedScanAndConnect` flag doesn't say this, and Apple documents neither
the rule nor whether it changes.

With a 2M auxiliary packet, the iPhone also connects to the set as central.
On an iPhone 12 mini with its own advertising disabled, so that only iOS
could dial, it sent `AUX_CONNECT_REQ`. The link came up `CENTRAL mtu 293`
(515 over legacy), then pairing (`0x00`–`0x04`) and Resume
(`0x10`/`0x20`/`0x30`) completed on both sides. Two Android phones that both
advertised 2M paired and resumed as before (MTU 517).

Fleet capabilities from `BluetoothAdapter` (debug probe, 2026-10-28): every
one of the 15 phones measured with `isLeExtendedAdvertisingSupported` also
had `isLe2MPhySupported`, on API 29 to 37. The phones without extended
advertising (P30 lite, Huawei WAS-LX1A, Mi Note 3) can't receive either form.

## Decision

- **Secondary PHY on demand.** The Android radio's extended set (§10.1,
  ADR 0028) keeps its auxiliary packet on LE 1M until it sees an iOS peer.
  An iOS peer is a Cairn advert without service data: Core Bluetooth can't
  advertise service data, and every Android radio does. When the controller
  has `isLe2MPhySupported`, such a sighting restarts the set at once with a
  2M auxiliary packet. The set goes back to 1M at the first window rotation
  (§10.1) that comes 300 s or more after the last sighting. The primary PHY
  stays 1M, and the payload, interval, connectability and fallback stay as
  in ADR 0028.
- **iOS dial rule.** iOS dials an Android peer that advertises extended as
  it dials any other peer. The rule that an extended Android phone dials a
  legacy peer whatever the beacons stays, because iOS still advertises
  legacy.
- **Spec.** §10.1 and §10.4 follow [OI-40]. No byte of any frame changes.

## Consequences

- iPhones on iOS 17 and later in the foreground see and dial every nearby
  Android phone with extended advertising and 2M. Android↔iOS links come up
  from either side, as ADR 0037 assumed.
- Without an iPhone in range, Android behaves exactly as under ADR 0028.
  The Android↔Android cost measured below is paid only while an iPhone is
  near.
- Restarting the set for a first sighting takes a new advertising address,
  as a window rotation does.
- An iPhone in the background advertises its service UUID only in the
  overflow area, which Android doesn't match, so nearby Android phones stay
  on 1M. A backgrounded iPhone can't report the 2M set to the app either.
- A scanner with extended scanning but no 2M PHY misses a 2M set. None in
  the fleet; the Bluetooth core spec doesn't require 2M with extended
  advertising. Such a phone is still dialled by the 2M phone if it
  advertises legacy, or reaches it through its own set.
- 2M has about 3 dB less sensitivity than 1M, so a scanner may hear
  `ADV_EXT_IND` at a range where it misses `AUX_ADV_IND`. Not measured: the
  fleet sits in one room.
- iOS's rule is undocumented and could change. The legacy-dial rule keeps
  Android dialling iOS whatever iOS reports.

## Validation

Fleet A/B, 2026-10-29, [issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md)
protocol: 22 Android phones (14 with extended advertising and 2M, the rest
legacy), arms of 300 s interleaved over 2 h, `pm clear` before each. "Pairs"
counts phone pairs that completed pairing; a dial times out after 10 s.

| Arm | Secondary PHY | Pairs | Dial timeouts | Dials connected |
|---|---|---|---|---|
| a1–a4 | 1M (ADR 0028) | 43, 48, 50, 47 | 151, 112, 130, 146 | 36–39 % |
| b1, b3, b4 | 2M always | 44, 33, 44 | 134, 215, 143 | 26–34 % |
| c1, c2 | 2M always, initiating PHYs 1M and 2M | 43, 47 | 198, 251 | 32–38 % |
| d1 | on demand, no iPhone | 45 | 195 | 32 % |
| m1 | on demand, no iPhone (its app crashed) | 32 | 230 | — |
| m2 | on demand, iPhone 12 mini in range | 32 | 126 | — |

A fourth always-2M arm (b2) is excluded: a `pm grant` race left three
phones without Bluetooth permissions, so they never advertised.

Always-2M arms averaged 42 pairs against 47 on 1M, and their timeouts ran
higher. The spread is wide: d1 behaved exactly like 1M (no phone switched)
and still timed out 195 dials. The per-phone timeout rate rose on most
extended diallers under always-2M, not on one controller. Setting both
initiating PHYs didn't help, and the Core spec doesn't require it: a
controller connecting on a PHY without parameters uses another PHY's
parameters. So always-2M fails this ADR's acceptance rule, that pairs and
timeouts don't regress beyond the run-to-run spread. On demand doesn't
change Android↔Android behaviour without an iPhone, and d1 shows no false
iOS sightings.

The m arms ran later the same morning, and both scored fewer pairs than
any earlier arm, with or without an iPhone. So the absolute numbers drifted
and don't compare with a–d. In m2, 13 of the 14 extended phones logged
`advertising extended 2M` within a second of starting, and the iPhone
connected as central 17 times. After correcting the phone clocks, 16 of
those links match a peripheral link on an Android phone within 0.35 s.
Seven of them, to five different phones, were on extended phones, which
advertise nothing but the extended set. So iOS found those phones through
their 2M adverts, which it never did on 1M.

## Considered options

- **2M always.** The simplest change, and the one first proposed. Measured
  above: fewer pairs and more dial timeouts among Android phones, with no
  iPhone to gain. Rejected for on demand.
- **Parallel sets: 2M, 1M and legacy at once.** Android can run several
  advertising sets if the controller has the slots. Each set adds its own
  `ADV_EXT_IND` or `ADV_IND` on all three primary channels at every
  interval, so advertising airtime, and with it the radio's advertising
  energy, grows about linearly with the number of sets. A 2M auxiliary
  packet takes about half the airtime of a 1M one, so 2M alone costs less
  than the ADR 0028 set. Each set also takes a controller slot that other
  apps compete for (the P30 lite already fails one legacy advert with
  `ADVERTISE_FAILED_TOO_MANY_ADVERTISERS`), and gets its own rotating
  address, so peers see one phone as two or three devices and dial it
  twice. A 1M set would reach only scanners that have extended scanning
  but no 2M PHY, and the fleet has none. A legacy set brings back the
  primary-channel `CONNECT_IND` losses ADR 0028 removed. Rejected: one set,
  its secondary PHY chosen by whether an iPhone is near.
- **Dual sets: extended plus a slower legacy set.** iOS would see the legacy
  set. ADR 0028 rejected it: traffic on the crowded primary channels, and a
  second address to rotate and budget.
- **Legacy advertising when an iOS peer is near.** Android can tell iOS
  from the missing service data, but a legacy set brings back the
  primary-channel `CONNECT_IND` losses ADR 0028 removed. A 2M auxiliary
  packet keeps the connection request on a secondary channel.
- **Leave as is.** Every pair links, because Android dials iOS, but iOS can
  never reach an Android phone whose slots are full or that is out of its
  scan window. ADR 0037's "from either side" doesn't hold.
- **Coded secondary PHY.** Untested on iOS, and coded adverts cost several
  times the airtime in a crowd.
