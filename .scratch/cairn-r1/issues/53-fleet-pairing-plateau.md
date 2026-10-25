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
  The P10 lite had 3 links and no pairing. `GX6CTR500184` logged no links,
  but that is a logging artifact; see "GX6 trace hidden" below.
- 233 dials failed, 214 of them at `CONNECTING`, mostly with status 0x85.
- Five peripheral links queued a frame and then received nothing until the
  5 s deadline:
  - A BUSY to 7XHEIBPB: the central received nothing.
  - A P1 to 42c2cf: the central received all of P1, but its P2 never
    arrived.
  - Three P1s matched no central P0 in any of the 12 logs.

## Analysis of the fleet3 logs

- **Admission is not the main limiter.** Of the central links that closed
  without a reply, 18 had the phone's own pairing already in flight. At
  most 9 can be explained by admission back-off or limits.
- **Failed dials dominate.** `CONNECTING` status 0x85 is the most common
  dial outcome in every 30 s window. After 120 s only 6 links per role came
  up: 2 resumptions and 4 that closed without a reply. Together with the
  2 min attempt interval per address, this explains the plateau.
- **Hung connects.** 51 `CONNECTING` failures took 29 s or more, which is
  the Android stack's 30 s connect timeout. The P10 lite had 11 of them and
  no central link.
- **Hung connects mostly don't block other connects.** On most phones,
  central links came up while another dial was hung (for example 5 of 11
  on `1f1dad34`, 8 of 8 on 7XHEIBPB).

## GX6 trace hidden

`GX6CTR500184` sets the system property `log.tag=I`. That drops every
`Log.d` line, and the link trace and PHY log use `Log.d`, so fleet1–3
recorded only its `Log.i` dial failures.

A two-phone control run (GX6 and `1f1dad34`, 45 s) after
`adb shell setprop log.tag.CairnRadio D` showed the GX6 linking as both
central and peripheral, reaching 2M PHY, and pairing. Without the
property, the same run logged nothing on the GX6 even though `1f1dad34`
paired with it.

Consequences for fleet3:
- GX6 links and pairings are missing from the counts. The 22 of 66 is a
  lower bound.
- The three P1s that matched no central P0 probably had the GX6 as
  central. This can't be checked from the fleet3 logs.

Fleet runs must run `setprop log.tag.CairnRadio D` on every phone first.
The property doesn't survive a reboot. Only the GX6 overrides `log.tag`;
the other phones don't set it.

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
3. **Unmatched P0s.** Probably the hidden GX6 trace. Confirm in the next
   fleet run, with the tag property set.
4. **P10 lite.** Find out why it never links as central: 11 hung connects
   and 24 status 0x85 failures.
