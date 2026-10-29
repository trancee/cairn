---
status: proposed
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

1. **Redial after a supervision timeout.** A central whose link is lost to a
   supervision timeout may dial that address again after a random 1–5 s.
   The retry delays are the ones §10.4 already uses for a dial that fails
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
2. **The peripheral leaves the redial to the central.** When an address's
   connection to an Android GATT server ends, with or without a link,
   Android doesn't dial that address for 15 s plus the 0–3 s first-dial
   spread. The central redials within that time, after 1–5 s or 5–15 s.
   This extends [ADR 0039](0039-android-waits-for-ios-to-dial.md) from the
   first sight of a peer to every reconnection. It covers every reason,
   because Android 9's server callback reports a supervision timeout as
   status 0.
3. **Forgive the first drop mid-pairing.** If a link drops with a pairing in
   flight, and the address has no earlier failure on record, the drop
   doesn't back the address off. Any later transport failure backs off as
   OI-30 says, starting at 2 min. The forgiven drop is cleared like any
   other failure: 1 h later, or when a pairing with that address completes.
   A missed §4.4 deadline is still a transport failure from the first.

No byte of any frame changes.

## Consequences

- After a timeout during pairing, the iPhone dials again within 1–5 s and
  pairing restarts at once, instead of 2 min or more later.
- A link that keeps timing out is dialled at most three times per
  2 min 20 s or so. Pairing over it is backed off after the second drop,
  doubling as before. The 30 pairing attempts per hour still bound X-Wing
  work.
- Without rule 2, both phones dialled at once after a timeout. In run RD3,
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

- Rule 1 works: the iPhone dials again within 5 s.
- Rule 2 works: in RY1, Android didn't dial while the iPhone was
  redialling.
- The links still don't hold. In RY1 the iPhone's redials reached
  Android's server and dropped within about 2 s, before subscribing. Both
  full links dropped 1.5–2.1 s after link-up. Recovery took 33–49 s
  instead of 2 min or more.
- In the H1 snoop, both drops came 2.7–3.7 s after the link moved to 2M.
  The one link Android dialled (h=00e) took a 15 ms interval and a 2 s
  timeout, which the iPhone accepted, and didn't drop. Android-central
  links to iPhones haven't dropped in any run. Issue 58 records the option
  of letting Android dial an iPhone whose link timed out, against
  ADR 0039.
