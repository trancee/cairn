# Fleet pairings plateau and some pre-auth frames go unanswered

Type: task
Status: needs-triage
Blocked by: none

## Question

Why did only 22 of the 66 phone pairs pair in fleet3, and why are some
queued pre-auth frames never answered?

Context: fleet3 in [issue 52](52-preauth-fleet-timing.md), the first fleet
run where every phone started with cleared app data.

## Observations

- Pairings: 17 in the first 60 s, 5 more by 140 s, none afterwards.
  P10 lite and `GX6CTR500184` had only 3 links between them and no pairing.
- 233 dials failed, 214 of them at `CONNECTING`, mostly with status 0x85.
- Five peripheral links queued a frame and then received nothing until the
  5 s deadline:
  - A BUSY to 7XHEIBPB: the central received nothing.
  - A P1 to 42c2cf: the central received all of P1, but its P2 never
    arrived.
  - Three P1s matched no central P0 in any of the 12 logs.

## Open

1. **Plateau.** Separate the causes:
   - failed dials;
   - the 2 min attempt interval per address;
   - the 1 h back-off after a timed-out pairing.

   Logging back-off decisions from the core would show which applies.
2. **Unanswered frames.** Was the notification lost over the air, or did the
   central stall? Needs an HCI snoop on one affected pair. The `out` trace
   is logged when the fragment is queued, so `onNotificationSent` timing
   would also help.
3. **Unmatched P0s.** Why do some peripheral links match no central P0?
   Check clock offsets and whether the 4 wireless phones run the app.
