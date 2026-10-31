---
status: accepted
date: 2026-10-29
version: cairn-r1
---

# 0040: Redial soon after a supervision timeout

## Context

[Issue 58](../../.scratch/cairn-r1/issues/58-crossed-dial-link-loss.md)
found that links where an iPhone 12 mini is the central and an Android phone
is the peripheral sometimes drop with a supervision timeout. iOS reports it
as `CBError` 6 and Android as HCI reason 0x08. It happened with the Mi Note 3
(Android 9) and the Redmi (Android 13).
Seven of twelve came 1.8–3.9 s after link-up, which is during pairing.

The apps can't prevent these drops:

- The iPhone sets the parameters: a 30 ms interval and a 720 ms supervision
  timeout. An HCI snoop shows the link losing every packet for more than
  720 ms. It does this whether the iPhone scans or not, and whether packets
  are large or small.
- iOS gives an app no control over connection parameters.
- Android can only ask through `requestConnectionPriority`. Its presets ask
  for a 20 s supervision timeout, and the iPhone refuses them with 0x3B.
  Apple allows 2–6 s.
- `requestLeConnectionUpdate` doesn't exist on Android 9 and is blocked as a
  hidden API on Android 13.

What makes a drop costly is the recovery:

- Spec §10.4 allows one dial per address per 2 min, and a dial that linked
  counts. So neither side dials again for up to 2 min. In run Mns2 the
  iPhone dialled again 48 s after the drop.
- A drop with a pairing in flight is a transport failure (spec §5.6,
  OI-30). It backs the address off for 2 min, doubling up to 1 h.

## Decision

Recover quickly from a drop instead of trying to prevent it.

1. **Redial after a supervision timeout.** An Android central whose link is
   lost to a supervision timeout may dial that address again after a random
   1–5 s. The retry delays are the ones §10.4 already uses for a dial that fails
   before link-up:

   | Timeout | Next dial after |
   |---|---|
   | First | random 1–5 s |
   | Second | random 5–15 s |
   | Third | 2 min |

   A timeout counts towards the next step only if its link was up for less
   than 2 min. A timeout after a longer link starts again at the first
   step. Losses for any other reason, and links that either core closes,
   still wait 2 min. Those include a peer that disconnects (0x13).
2. **iOS hands the redial over to the peer.** An iOS central whose
   connection to an address ends with `CBError.connectionTimeout`, at any
   stage, doesn't dial that address for 45 s plus the 0–3 s first-dial
   spread. Links that iOS dials get a 30 ms interval and a 720 ms
   supervision timeout, which no app can change. Links that Android dials
   got a 15 ms interval and a 2 s timeout, which the iPhone accepted, and
   none has dropped. Android dials the iPhone 15–18 s after the drop by
   rule 3, and two failed dials and their retries fit in the 45 s.
   While a central that linked to iOS after the hand-over is still linked,
   iOS doesn't dial the handed-over address, and when that link goes down
   the 45 s start again. Android dials from another address than it
   advertises, so iOS can't tell whether that central is the same peer.
   Dialling it would cross the link (ADR 0039, failure 2). The hand-over
   ends when iOS links to the address as central.
3. **Android leaves the redial to the central first.** When an address's
   connection to an Android GATT server ends, with or without a link,
   Android doesn't dial that address for 15 s plus the 0–3 s first-dial
   spread. A central that lost the link for another reason redials within
   that time, after 1–5 s or 5–15 s. After that, Android may dial the
   address whatever its earlier dials did: the peer was just in range, and
   an iPhone that handed over waits for it. This extends
   [ADR 0039](0039-android-waits-for-ios-to-dial.md) from the first sight
   of a peer to every reconnection. It covers every reason, because
   Android 9's server callback reports a supervision timeout as status 0,
   so only iOS knows that the link timed out.
4. **Forgive the first drop mid-pairing.** If a link drops with a pairing in
   flight, and the address has no earlier failure on record, the drop
   doesn't back the address off. Any later transport failure backs off as
   OI-30 says, starting at 2 min. The forgiven drop is cleared like any
   other failure: 1 h later, or when a pairing with that address completes.
   A missed §4.4 deadline is still a transport failure from the first.

No byte of any frame changes.

## Consequences

- After a timeout during pairing with an iPhone, Android dials the iPhone
  15–18 s later and pairing restarts, instead of 2 min or more later.
  Between Android phones, the central dials again within 1–5 s.
- An iPhone before XS sees Android's legacy advert, and Android dials it
  the same way. If Android can't link within 45 s, the iPhone dials again.
- Between two iPhones, both hand over and dial again after 45–48 s. If
  the first to dial links before the other's window ends, the other holds
  off by the guard; otherwise they cross, as before this ADR.
- The guard can't tell peers apart. In a mesh, any central that links to
  the iPhone during a hand-over holds the iPhone's dial to the handed-over
  address back until that central's link goes down.
- After a server connection ends, Android may dial that address 15–18 s
  later even if its own dials failed three times. That relaxes the 2 min
  attempt limit for a peer that was just in range.
- A link that keeps timing out between Android phones is dialled at most
  three times per 2 min 20 s or so. Pairing over it is backed off after
  the second drop, doubling as before. The 30 pairing attempts per hour still bound X-Wing
  work.
- Without rule 3, both phones dialled at once after a timeout. In run RD3,
  Android dialled the iPhone 0.1 s after its peripheral link went down.
  The iPhone's redials reached Android's server at +4.9 s and +12 s, but
  the crossed dials failed with 133 and 0x08, as in ADR 0039.
- After a peer that dialled Android closes the link on purpose, Android
  waits 15–18 s before dialling it back.
- Android detects a timeout by `onConnectionStateChange` status 0x08. iOS
  detects it by `CBError.connectionTimeout`.

## Considered options

- **Ask for longer supervision timeouts.** The iPhone refuses Android's
  presets, Android has no public API for exact parameters, and iOS has
  none at all. Not possible.
- **iOS redials quickly too.** Runs RD3 and RY1 tried this: the iPhone
  redialled within 5 s, but its redials dropped within about 2 s like the
  first link, and recovery took 33–49 s. Rejected for rule 2.
- **Android detects the timeout and dials at once.** Android 9's server
  callback reports a timeout as status 0, the same as a clean close, so
  Android can't tell. Rejected.
- **Redial quickly after any loss.** A peer that disconnects on purpose
  would be dialled again within seconds. Rejected.
- **One quick redial, then 2 min.** A second drop is common: in the 12 mini
  runs, two timeouts sometimes came within a minute of each other. The
  second step costs at most two more dials. Rejected.
- **Forgive every drop mid-pairing.** A link that keeps dropping would then
  restart pairing, and its X-Wing work, without back-off. Rejected.

## Validation

Device runs on 2026-10-29, iPhone 12 mini central and Mi Note 3, 120 s
each. Runs with no iOS radio log were left out: in those, the iPhone's
screen had locked and iOS suspended the app.

| Runs | Build | Timeouts | First redial after a timeout | Next full link |
|---|---|---|---|---|
| Mns2, before | `main` | 1 | 48 s | 48 s |
| RD3 | rule 1 only | 1 | iPhone +4.9 s, crossed by an Android dial at +0.1 s | none in the run (60 s) |
| RY1 | rules 1–3 | 2 | iPhone +4.8 s and +13 s; Android waited 17 s | +33 s, then +49 s |

In RD3 and RY1 the iPhone redialled within 5 s itself, and Android
waited, but every link the iPhone dialled dropped again within about 4 s.
Recovery took 33–49 s. In the H1 snoop, those drops came 2.7–3.7 s after
the link moved to 2M. The one link Android dialled (h=00e) took a 15 ms
interval and a 2 s timeout, which the iPhone accepted, and didn't drop.
That led to rule 2, the hand-over.

Runs on the same evening with rules 2 and 3 (150 s each):

| Run | Build | What happened |
|---|---|---|
| HV3, HV4 | hand-over, no guard | The iPhone timed out. Android linked 28 s and 51 s later, and pairing completed. That link held 20–22 s until the iPhone's 45 s ran out and it dialled the same Android under another identifier. The crossed dial tore the link down. This led to the guard in rule 2. |
| HW4 | rules 1–4 | The iPhone's link timed out 2.5 s after link-up. Android linked 21 s later. Pairing completed within 1.2 s, and the link held 52 s, to the end of the run. The iPhone didn't dial while it was up. |
| HW1, HW2, HW3 | rules 1–4 | The iPhone's links timed out at once, and all 23 of Android's dials to the iPhone failed with 133 (0x3E). No link held. |

- The hand-over works when Android's dial gets through, and its link then
  holds where the iPhone's didn't.
- Android's dials to the iPhone fail with 0x3E most of the time on this
  pair. That now limits recovery, as ADR 0039 failure 1 found. Its cause
  is unknown, like the cause of the timeouts. Both may be the same lossy
  radio path.
- Runs RY2–RY8 and HO were left out: in RY the iPhone's screen locked,
  and HO ran an Android build without the schedule restart of rule 3.
