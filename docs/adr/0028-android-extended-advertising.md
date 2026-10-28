---
status: accepted
date: 2026-10-25
version: cairn-r1
---

# 0028: Advertise with extended connectable PDUs on Android

## Context

The Android radio advertises legacy connectable PDUs (spec §10.1). A
central connects to them with `CONNECT_IND`, which it sends once, on the
same crowded primary channel as the advert. The peripheral does not answer
it. If the peripheral misses it, the central's controller still reports the
connection, then drops it with reason `0x3E` (Connection Failed to be
Established) after 6 connection events.

An HCI snoop of three phones in a 15-phone fleet run
([issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md))
showed that every fast status-133 dial failure, 102 of 238 failures in the
run, is this sequence. In the one case snooped at both ends, the central
connected to the peer's current advertising address while it advertised,
and the peer logged no connection.
[ADR 0026](0026-android-congestion-levels.md) found the same pressure from
the other side: `LOW_POWER` advertising, with fewer adverts on the primary
channels, halved the failed dials but slowed discovery.

Bluetooth 5 extended advertising moves the connection request off the
primary channels. The advert (`ADV_EXT_IND`) points to an auxiliary packet
on one of the 37 secondary channels, and the central sends
`AUX_CONNECT_REQ` there. The peripheral answers with `AUX_CONNECT_RSP`, and
the central's controller creates the connection only after that answer. A
lost request is retried by the controller on a later advert instead of
becoming a failed connection.

Bluetooth 4.2 controllers cannot receive extended adverts. The fleet has
three of them (Galaxy Xcover 4, P10 lite, P30 lite).

## Decision

The Android radio advertises extended where the controller supports it
(spec §10.1, §10.4):

- **Advertising.** If `BluetoothAdapter.isLeExtendedAdvertisingSupported`,
  the radio advertises with `startAdvertisingSet`: not legacy, connectable,
  not scannable, primary and secondary PHY 1M, and the same payload as the
  legacy advert (flags and service data, service UUID ‖ beacon). The
  interval follows the energy band ([ADR 0027](0027-android-energy-bands.md)):
  `INTERVAL_LOW`, `INTERVAL_MEDIUM` and `INTERVAL_HIGH` for `FULL`, `SAVE`
  and `LOW`, the intervals of the legacy modes.
- **Fallback.** Without that support, or when the set fails to start, the
  radio advertises legacy as before, until it is next opened. The fallback
  is logged.
- **Scanning.** With that support, the radio scans with `setLegacy(false)`
  on all supported PHYs, so it receives both advert kinds.
- **Dial rule.** A radio that advertises extended dials a peer it sees
  through a legacy advert whatever their beacons, because that peer may not
  see it. Between two radios that both advertise extended, or both legacy,
  the lower beacon dials (ADR 0025).
- Advertising still stops while the slots are full (ADR 0025), and the set
  still restarts at every beacon window (§10.1).

## Consequences

- A connection request to an extended advertiser is answered before the
  connection exists. A lost request costs a later advert, not a 6-event
  link and a status-133 callback.
- Two Bluetooth 5 phones keep the beacon rule. A Bluetooth 5 phone and a
  4.2 phone pair through the Bluetooth 5 phone dialling. Two 4.2 phones pair
  as before.
- A phone whose extended set fails advertises legacy. Bluetooth 5 peers then
  dial it whatever the beacons, and it may dial them too if its beacon is
  lower. Both dials may race, as OI-28 allows.
- The advert payload and every frame stay the same. Only the PDU type on
  air changes.
- Measured in a fleet A/B against `main` (13 phones, two 300 s runs each,
  [issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md)):
  failed dials under 1.5 s fell from 159 and 150 to 27 and 21, all failed
  dials by 31 %, and pairs rose from 36 and 40 to 38 and 45, within the
  run-to-run spread. Dial timeouts rose from 52 and 11 to 108 and 91: a
  pending connection to an extended target that stopped advertising or
  changed address is now cancelled at 10 s instead of failing fast.

## Considered options

- **Dual sets: extended plus a slower legacy set.** Keeps the beacon rule
  for every pair, but the legacy set keeps traffic on the crowded primary
  channels and adds a second address to rotate and budget.
- **Secondary PHY 2M.** Halves the auxiliary packet's airtime, but a
  scanner without 2M support would miss the advert.
- **Coded PHY.** More range, but more airtime per advert in a crowd.
- **A capability bit in the advert.** Says which peers can scan extended,
  but changes the §10.1 payload, where the PDU type already says it.

## Open

- iOS (S6): Core Bluetooth chooses its own PDUs, and it doesn't report
  extended adverts whose auxiliary packet is on LE 1M
  ([ADR 0037](0037-ios-ble-adapter.md)). An extended Android phone dials iOS's
  legacy advert; iOS can't dial it. [ADR 0038](0038-android-extended-advert-2m-secondary.md)
  (proposed) moves the auxiliary packet to LE 2M, which iOS does report.
