---
status: proposed
date: 2026-10-28
version: cairn-r1
---

# 0038: Send Android's extended advert on the LE 2M secondary PHY

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

## Decision (proposed)

- **Secondary PHY.** The Android radio's extended set (§10.1, ADR 0028)
  uses LE 2M as its secondary PHY when `isLe2MPhySupported`, else LE 1M. The
  primary PHY stays 1M, and the payload, interval, connectability and
  fallback stay as in ADR 0028.
- **iOS dial rule.** iOS dials an Android peer that advertises extended as
  it dials any other peer. The rule that an extended Android phone dials a
  legacy peer whatever the beacons stays, because iOS still advertises
  legacy.
- **Spec.** §10.1 changes "on 1M PHYs" to "primary 1M, secondary 2M where
  supported", and §10.4 drops "iOS dials only Android peers that advertise
  legacy". No byte of any frame changes.

## Consequences

- iPhones on iOS 17 and later see and dial every Android phone with
  extended advertising. Android↔iOS links come up from either side, as ADR
  0037 assumed.
- The auxiliary packet's airtime halves, which reduces secondary-channel
  load in a crowd.
- A scanner with extended scanning but no 2M PHY misses a 2M set. None in
  the fleet; the Bluetooth core spec doesn't require 2M with extended
  advertising, so such a phone may exist elsewhere. It would still be
  dialled by the 2M phone if it advertises legacy, or seen through its own
  set otherwise. Two such phones pair through each other's 1M sets.
- 2M has about 3 dB less sensitivity than 1M. The primary advert stays 1M,
  so a scanner may hear `ADV_EXT_IND` at a range where it misses
  `AUX_ADV_IND`. This narrows extended-to-extended discovery range slightly.
- iOS's rule is undocumented and could change. The legacy-dial rule and the
  iOS→Android direction through Android dialling stay as fallbacks.

## Validation required before acceptance

- A fleet A/B against `main` with the [issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md)
  protocol (13+ phones, two 300 s runs each). Pairs, failed dials under
  1.5 s and dial timeouts must not regress beyond the run-to-run spread.
- An RSSI-at-discovery comparison, 1M against 2M, for the range cost.
- iOS 15 and 16 (SE 2016 and older iPhones without extended scanning) only
  see legacy adverts and are unaffected. Confirm with
  `supports(.extendedScanAndConnect)` = false on the SE 2016.

## Considered options

- **Dual sets: extended plus a slower legacy set.** iOS would see the legacy
  set. ADR 0028 rejected it: traffic on the crowded primary channels, and a
  second address to rotate and budget.
- **Legacy advertising when an iOS peer is expected.** Android can't know,
  and it would undo ADR 0028's gains.
- **Leave as is.** Every pair links, because Android dials iOS, but iOS can
  never reach an Android phone whose slots are full or that is out of its
  scan window. ADR 0037's "from either side" doesn't hold.
- **Coded secondary PHY.** Untested on iOS, and coded adverts cost several
  times the airtime in a crowd.
