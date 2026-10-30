---
status: accepted
date: 2026-10-29
version: cairn-r1
---

# 0039: Android waits for iOS to dial

## Context

Spec §10.4 has iOS dial every Android peer it sees, and Android dial every iOS
peer, because iOS can't advertise a beacon and the beacon rule of
[ADR 0025](0025-android-gatt-slot-budget.md) can't pick one side. Both phones
therefore dial each other within the 0–3 s first-dial spread.
[Issue 58](../../.scratch/cairn-r1/issues/58-crossed-dial-link-loss.md)
found that this crossed dial loses links on Android 8 and 9.

An HCI snoop of a Mi Note 3 (Android 9, Snapdragon 660) paired with an
iPhone 12 mini (iOS 27) shows three failure modes on 2026-10-29. Each came
from the `dumpsys bluetooth_manager` snoop summary of runs H1–H3:

1. **Status 133 is 0x3E.** Every failed Android dial is an
   `LE Create Connection` whose `LE Connection Complete` arrives in about
   30 ms, then a `Disconnection Complete` with reason 0x3E (*Connection
   Failed to be Established*) about 300 ms later. The iPhone never answers
   on the data channel. Two of three runs began with 1–3 such dials. Each
   one occupies the only dial slot of API ≤ 28 (ADR 0025).
2. **Bluedroid can't tell two ACLs to one address apart.** In H2 the
   Android dial linked (handle 0x00e, Android central). Then the iPhone
   dialled too (handle 0x00c). When the iPhone's core closed that duplicate
   link, Android reported its *central* link lost with status 0x13, though
   handle 0x00e stayed up for another 32 s. Bluedroid routes GATT client
   events by peer address.
3. **Closing a GATT client tears down a shared ACL.** In H3 the Android
   dial joined the iPhone's existing connection (handle 0x00f, Android
   peripheral) and reported "connected after 15 ms". About 1 s after the core
   closed that duplicate client link, the Android host sent
   `Disconnect` (0x13) on handle 0x00f, so the link the iPhone had dialled
   went down too.

A fourth mode, a supervision timeout (reason 0x08, 720 ms on the iPhone's
connection) during GATT discovery, happened with no Android dial in flight.
This ADR does not address it; issue 58 tracks it.

iOS reports a legacy advert from every Android phone, and an extended one
when its secondary PHY is 2M, which Android uses while iOS is near
([ADR 0038](0038-android-extended-advert-2m-secondary.md)). So iOS can
dial every Android phone, except that iPhones before XS see no extended
advert at all.

## Decision

An Android radio waits for an iOS peer to dial it:

- It waits 10 s, plus the 0–3 s first-dial spread, after first seeing an
  advert without service data before dialling that address. Only iOS sends
  such adverts (spec §10.1).
- It doesn't dial an address that connected to its GATT server less than
  10 s ago and hasn't subscribed yet. Such a peer is in its pre-auth window
  (spec §4.4, twice for pairing then Resume).

The retries after a failed dial and the beacon rule are unchanged. No byte
of any frame changes.

## Consequences

- An iPhone that sees the Android advert dials within its own 0–3 s spread.
  Android dials it only if it hasn't linked 10 s later.
- An iPhone before XS can't see an extended advert, so it links only when
  Android dials. That takes up to 13 s instead of 3 s.
- A peer that dials Android first is never dialled back during its
  pre-auth window, so the crossed-dial failures 2 and 3 above can't start
  from an Android dial in that window.
- Android↔Android dialling is unchanged: Android peers advertise a beacon.

## Validation

Device runs on 2026-10-29, 45 s each, both apps started fresh. A link lost
about 30 s after link-up, with reason 0x13, is the end of a run, not a loss.

| Runs | Pair | With dials | 133 / 0x3E dials | Lost to a crossed dial | Supervision timeouts |
|---|---|---|---|---|---|
| H1–H3, before | Mi Note 3, 12 mini | 3 of 3 | 4 | 2 (H2, H3) | 1 (H1) |
| W1–W10, after | Mi Note 3, 12 mini | 5 of 10 | 8 | 1 (W8) | 3 (W5, W6, W10) |
| R1–R10, after | Redmi `2201117TY` (Android 13), 12 mini | 4 of 10 | 7 | 0 | 2 (R2, R9) |
| X1–X3, after | Pocophone F1 (extended), iPhone X | 3 of 3 | 2 | 0 | 0 |

- W1–W4 and W9 linked once, with no Android dial, and held. After the
  change, every Android dial followed an iPhone link that had ended, an
  iPhone dial that had failed, or a new iPhone address. W8 is the one
  remaining crossed-dial loss: the iPhone's first link dropped, so 10 s
  later both phones dialled again at once.
- The iPhone X sees no extended advert. The Pocophone dialled it 11–17 s
  after it first saw an iOS advert, and every run linked.
- The supervision timeouts are not caused by this decision. They also hit
  links that had paired and gone idle (R2 at 36 s, R9 at 18 s). Two
  experiments ruled out causes on the Android side:
  - stopping the Mi Note 3's scan once the iPhone connected (N1–N10) left
    5 of 10 runs with one;
  - Android's preference for LE 1M on the iPhone's link was ignored, and the
    link stayed on 2M.

  Issue 58 tracks them.

## Considered options

- **Android never dials iOS.** This is simplest, but pre-XS iPhones would
  never link to an extended-advertising Android phone. Rejected.
- **iOS never dials Android.** iOS can't see Android's extended advert unless
  it is on 2M, and pre-XS iPhones never see it. Android's dials to iOS also
  fail with 0x3E at the start of most runs. Rejected.
- **Park a dial that joins the peer's connection** (issue 58, "Tried").
  On devices it either never fired or held a link for 32 s. Rejected.
- **A shorter wait.** The iPhone's first dial comes within its 0–3 s spread.
  Its retries take another 1–5 s, and pairing plus Resume take up to 10 s.
  A 10 s wait covers a first dial that fails once. A longer one only delays
  pre-XS iPhones.

## Amendments

2026-10-29, proposed in [ADR 0040](0040-redial-after-supervision-timeout.md) (spec OI-42):
- After an address's connection to the GATT server ends, with or without a
  link, Android doesn't dial it for 15 s plus the 0–3 s spread. The wait
  applied only after first sight, so after a supervision timeout both
  phones dialled each other again at once.
