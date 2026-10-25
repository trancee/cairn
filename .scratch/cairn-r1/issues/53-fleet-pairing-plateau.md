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

## Fleet4

Same build as fleet3 (`feat/s2-busy-frame`), same 12 USB phones with
cleared app data, 180 s, `log.tag.CairnRadio=D` on every phone. Pairs below
are phone pairs whose matched central link reached a session frame (frame
type 3). This is stricter than the 22 quoted for fleet3 above.

| | fleet3 | fleet4 |
|---|---|---|
| Phone pairs with a session | 16 | 29 |
| … within 60 s / 120 s | 13 / 16 | 24 / 27 |
| Last new pair | 77 s | 143 s |
| Central P0s with no peripheral match | 3 | 0 |
| Failed dials (`CONNECTING`) | 233 (214) | 209 (198) |
| First S2/DATA median / p90 / max | 1.11 / 2.76 / 3.64 s | 1.02 / 1.92 / 3.01 s |

- With the GX6 visible, no central P0 is unmatched. That supports the
  hidden GX6 trace as the cause of fleet3's three.
- The GX6 paired with 5 phones. The P10 lite paired with 2, after 4 links
  and 30 failed dials.
- **7XHEIBPB dropped out.** 7 s after launch its controller reported
  `Hardware Error Event 0x00` and the system restarted the Bluetooth
  process; Bluetooth was back on within 2 s. `AndroidRadio` didn't follow
  adapter state, so its server, advertising and scanning stayed dead and it
  logged nothing more. 29 pairs is therefore out of 55 possible, not 66.
  The fault happened once, 4 s after the app's first two dials; fleet1–3
  didn't show it, so its cause is unknown. The radio now follows adapter
  state; see ADR 0023 §3.

## Back-off refusals (2026-10-25)

Classifying every central link by what it sent corrects the fleet3 finding
that admission is not a main limiter. A link that closed within 2 s of
link-up, sent nothing, and had no pairing of its own in flight was refused
by admission:

| Run | P0 sent | closed, own pairing in flight | refused | Resume |
|---|---|---|---|---|
| fleet3 | 36 | 16 | 10 | 2 |
| fleet4 | 43 | 10 | 14 | 2 |

The budgets were far from used up (at most 43 attempts across 12 phones),
so the refusals were the per-address back-off. In fleet4, 20 pairing
attempts failed and none failed a protocol check: 11 reached the 5 s
deadline without a reply, 7 lost the link after 0.1–4.4 s, and 2 timed out
after step 3. Each backed off its address for 1 h, and each refused dial
re-armed the hour.

Fixed by spec OI-30 (user's choice, option A): transport failures back off
2 min, doubling up to 1 h; protocol failures keep 1 h; a refused dial
doesn't re-arm a back-off. A new fleet run should confirm that the plateau
lifts.

## Fleet5 and A/B with OI-30 (2026-10-25)

All 22 reachable phones were tried. Six took part in none of the runs:
- Pixel 6, Nothing Phone 2, Nokia X20, Redmi Note 11 (`884d596`) and
  OnePlus 6 are on a secure lock screen; the activity never resumes.
- Galaxy Xcover 4 (`armeabi-v7a`, API 28) crashes at start:
  `libcairn_ffi.so` is packaged only for `arm64-v8a`, although ADR 0004
  lists `armeabi-v7a`.

Two more Redmi phones can't be prepared: MIUI refuses `pm grant` and input
injection until "USB debugging (security settings)" is enabled. Note that
`pm clear` also revokes runtime permissions, so each run grants them again.

Interleaved A/B on the same 14 phones, 300 s each, `main` (`b6f3779`, 1 h
back-off) against PR #58 (OI-30). 12–13 phones logged links; the Huawei
P30 lite never linked, the OnePlus Nord 2T only once.

| | main | PR #58 |
|---|---|---|
| Phone pairs with a session | 26 | 24 |
| … by 60 / 120 / 180 s | 20 / 22 / 25 | 15 / 20 / 23 |
| Possible pairs never reached by a matched P0 | 34 of 66 | 36 of 66 |
| Pairs with a failed attempt / paired later | 2 / 0 | 5 / 3 |
| Central links refused (no pairing in flight) | 19 | 13 |
| Failed dials (hung ≥ 29 s) | 468 (80) | 466 (93) |

- The pair count is within run-to-run variance (fleet3 and fleet4, one
  build, gave 16 and 29). OI-30 is not what limits it.
- The plateau is reaching the peer at all: about half of all phone pairs
  never exchange a P0, against about 470 failed dials per run, mostly
  `CONNECTING` status `0x85`. The back-off only affects the 2–7 pairs per
  run whose attempt failed after P0; with OI-30, 3 of 5 paired later.
- The address back-off is weaker than assumed even on `main`: in fleet4,
  6 of 10 pairs with a failed attempt paired later, some within 5 s. The
  other phone can dial in the opposite role, and Android rotates the
  advertising address.
- On the Huawei P10 lite (Android 8) `com.android.bluetooth` crashed once
  with SIGSEGV in `bta_gattc_char_dscpt_disc_cmplt` during service
  discovery: a platform stack fault, not the app.

## Open

1. **Plateau.** It is the failed dials (`0x85`, 30 s hung connects), not
   admission. Next: per phone pair, which dials fail (the dial line carries
   an address prefix), and whether fewer concurrent dials per phone help.
2. **Unanswered frames.** Was the notification lost over the air, or did the
   central stall? Needs an HCI snoop on one affected pair. The `out` trace
   is logged when the fragment is queued, so `onNotificationSent` timing
   would also help.
3. **Unmatched P0s.** Resolved: fleet4 has none with the GX6 visible.
4. **P10 lite.** Find out why it never links as central: 11 hung connects
   and 24 status 0x85 failures.
5. **`armeabi-v7a`.** Package the 32-bit library as ADR 0004 says, or
   amend the ADR.
