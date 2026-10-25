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
- Galaxy Xcover 4 (`armeabi-v7a`, API 28) crashes at start with
  `UnsatisfiedLinkError`. The fleet APK is a debug build, and the uniffi
  plugin packages only the host ABI (`arm64-v8a`) in debug builds. Release
  builds include `armeabi-v7a` as ADR 0004 says. Building with
  `./gradlew :androidApp:assembleDebug -PandroidAbis=arm64-v8a,armeabi-v7a`
  packages both, and the app starts and resumes on the Xcover 4.

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

## GATT slot exhaustion (ev1, 2026-10-25)

A 300 s run on 15 phones (`main` with OI-30, both ABIs) captured the system
log and `dumpsys bluetooth_manager`.

- Android allocates a GATT link record (TCB) for every connection, in or
  out, when the connect starts. The table holds `GATT_MAX_PHY_CHANNEL`
  entries: 7 in AOSP up to Android 14, at least 8 from Android 15
  (`gatt_get_max_phy_channel()`). `dumpsys` shows 8 on the Realme (API 35),
  10 on the OnePlus `1f1dad34` and 16 on the Galaxy Z Flip4. A full table
  makes `connectGatt` fail with `133` within milliseconds, and the stack
  drops incoming links "due to out of resources".
- 274 of 443 fast `133` dial failures fall within 100 ms of a
  `Max TCB for gatt_if … reached` line. That is every fast `133` on the five
  phones whose stack logs the tag (API 26–34). 30 incoming links were
  dropped for lack of resources on the phones with 8–10 slots.
- The slots are not held by sessions. `e9097611` hit the limit 78 times
  with about 1 link up and 2 failing dials in flight. The rest are pending
  dials and incoming connections from the other 13 phones that are not yet
  links.
- 14 phones each wanting 13 links need far more than 7–8 slots. At most
  about 7 × 14 / 2 = 49 of 91 pairs can be connected at once, which is
  consistent with about half of all pairs never connecting.
- It does not follow API level: the phones that hit the limit run API 26,
  28, 29, 31 and 34.
- Phones report no usable battery wear. Health is "good" everywhere, and
  `charge_full` equals the design value where it can be read at all.

## Slot budget A/B (2026-10-25)

[ADR 0025](../../../docs/adr/0025-android-gatt-slot-budget.md), merged in
PR #60. 15 phones, 300 s each, `main` (`df80e25`) then the PR (`86081df`):

| Metric | `main` | slot budget |
|---|---:|---:|
| Pairs | 36 | 49 |
| Pairs by 60 / 120 / 180 / 240 s | 22 / 27 / 31 / 33 | 28 / 31 / 38 / 42 |
| Dial failures | 718 | 288 |
| Fast status-133 failures (< 2 s) | 422 | 97 |
| … within 100 ms of "Max TCB reached" | 259 | 0 |
| Incoming links dropped "out of resources" | 32 | 0 |
| Evictions / dial timeouts / advertising stops | – | 54 / 125 / 286 |

- Slot exhaustion is gone. The remaining fast 133s have another cause.
- New pairs still form at 300 s in both runs, so a longer run must show
  whether the plateau is gone.
- The P10 lite paired with 1 phone.

## Congestion levels rejected (plan B, 2026-10-25)

Two congestion controllers on top of the slot budget (PR #62) were each run
in a back-to-back A/B against `main`, 15 phones × 300 s:

| Variant | Pairs at 60 s | Pairs at 300 s | Failed dials | Timeouts |
|---|---:|---:|---:|---:|
| `main` | 33 | 45 | 233 | 79 |
| One level, `LOW_POWER` when `CROWDED` | 17 | 38 | 126 | 81 |
| `main` | 32 | 47 | 238 | 88 |
| Crowd and channel levels | 26 | 41 | 240 | 116 |

- `LOW_POWER` advertising and scanning halved the failed dials, but slowed
  discovery more.
- Slowing to `BALANCED` only when dials failed did not reduce failures. The
  5 s timeout added timeouts, and the dial gap slowed dialling.
- The remaining failures do not track the phone's own advert, scan or dial
  rate. ADR 0026 records the rejection.
- `main` paired 45, 47 and 49 times in three runs of the same code: the
  spread between runs is a few pairs.

## Energy bands (plan D, 2026-10-25)

ADR 0027 (PR #63) was run on 15 phones × 300 s per band. Each band was forced
on every phone with `dumpsys battery unplug` and `dumpsys battery set level`
(90, 40 and 10 %):

| Band | Pairs at 240 s | Pairs at 300 s | Failed dials | Timeouts | Links up |
|---|---:|---:|---:|---:|---:|
| `FULL` | 42 | 47 | 229 | 64 | 215 |
| `SAVE` | 41 | 47 | 195 | 61 | 167 |
| `LOW` | 23 | 27 | 59 | 34 | 91 |

Bluetooth controller use (`dumpsys batterystats`, median of the 4 phones that
report it: `1f1dad34`, `R5CT83AC`, `ZY22GCD9`, `e9097611`):

| Band | Rx time | Tx time | Bluetooth drain |
|---|---:|---:|---:|
| `FULL` | 305 s | 71 s | 1.96 mAh |
| `SAVE` | 103 s | 54 s | 0.88 mAh |
| `LOW` | 64 s | 40 s | 0.55 mAh |

- `FULL` matches `main` (45, 47 and 49 pairs).
- `SAVE` paired as fast as `FULL` and used 55 % less Bluetooth energy.
- `LOW` paired 40 % fewer phones and used 72 % less. It trades reach for
  battery, as ADR 0027 intends.
- The L2N phone (Huawei) showed its low-battery warning at 10 %, and its
  logcat main buffer kept only the last 6 s of the `LOW` run. Its 0 pairs
  there are a logging gap; the `LOW` row counts 14 phones.
- `42c2cf` reported 83 mAh in `FULL`, which is a `batterystats` artefact,
  and the other phones report no controller energy.
- Every phone was in the same band at once. A real crowd mixes bands.

## Open

1. **Plateau.** Slot exhaustion resolved by ADR 0025 (36 to 49 pairs). Still
   open: the 97 fast 133s without a full table, and whether pairing
   completes in a longer run. A congestion controller did not help
   (ADR 0026); an HCI snoop of R38 or e9097611 should show whether their
   connect requests reach the air.
2. **Unanswered frames.** Was the notification lost over the air, or did the
   central stall? Needs an HCI snoop on one affected pair. The `out` trace
   is logged when the fragment is queued, so `onNotificationSent` timing
   would also help.
3. **Unmatched P0s.** Resolved: fleet4 has none with the GX6 visible.
4. **P10 lite.** Find out why it never links as central: 11 hung connects
   and 24 status 0x85 failures.
5. **`armeabi-v7a`.** Resolved: build fleet APKs with
   `-PandroidAbis=arm64-v8a,armeabi-v7a`. ADR 0004 holds for release builds.
