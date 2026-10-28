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

## HCI snoop of failed dials (2026-10-25)

HCI snoop logs were captured on 3 Qualcomm phones (S10e `R38`, Nothing
`1f1dad34`, moto `ZY22`) during two 300 s fleet runs of `main`. The
MediaTek realme writes only a 16-byte file, and the POCO's run after its
reboot logged no cairn lines. Each dial failure in logcat was matched to
the HCI events of the same dial:

| App failure | Share of fleet failures | HCI sequence |
|---|---:|---|
| Fast 133 (< 1.5 s) | 102 of 238 | `LE Extended Create Connection` → connection complete `0x00` → disconnect `0x3E` after 6 connection events (0.21–0.32 s at 45 ms) |
| 10 s timeout | 106 of 238 | Create connection pending for 10 s with no connectable advert from the target → cancel → connection complete `0x02` |
| 5 s (S10e only) | 30 of 238 | As the timeout; Samsung's stack cancels after 5 s |

- **Fast 133s reach the air.** In the one fast 133 where both ends were
  snooped, the moto connected to the Nothing's current advertising address
  while it advertised, and the Nothing logged no connection: the
  `CONNECT_IND` was lost on the advertising channels. This fits plan B,
  where `LOW_POWER` advertising halved the failed dials.
- **Timeouts dial phones that stopped advertising.** Every advertising gap
  over 1 s on the 3 phones was cairn's own slots-full stop (ADR 0025). The
  moto advertised for 16 % of its run, the S10e 59 % and the Nothing 68 %.
  Of the 2 timeouts where both ends were snooped, the target stopped
  advertising for a full slot set in one and rotated its address in the other.
- **Android rebuilds the advertising set, with a new address, after each
  connection attempt.** The phones used 23 to 41 addresses in 300 s.
- Only 3 phones and a handful of matched pairs back these causes.
  Kirin phones, which have many timeouts, cannot be snooped without root.
  The MediaTek realme can: `*#800#` → Communication & network → Bluetooth
  → Bluetooth connections starts the OPLUS log kit, which writes standard
  btsnoop files under `/sdcard/Android/data/com.oplus.logkit/files/Log/`.
  A 90 s run there shows the same `0x3E` drops after
  `LE Extended Create Connection`.

## Extended advertising A/B (ADR 0028, 2026-10-25)

Four 300 s runs in the order `main`, `ext`, `ext`, `main`, all phones forced
to band `FULL` (`dumpsys battery set ac 1`, `set level 100`). 23 phones
were attached. Three Xiaomi phones refuse adb installs (MIUI "Install via
USB"), and five wireless-adb phones logged no scan results after the first
run (the lock screen, most likely), so the 13 phones that linked in all
four runs are compared. Of those, 3 advertise legacy (Xcover 4, Mi Note 3,
P30 lite); none fell back from a failed set. For later runs, the Xiaomi
phones install over adb once "USB debugging (Security settings)" is
enabled, and every phone needs its lock screen off.

| 13 phones | `main` 1 | `ext` 1 | `ext` 2 | `main` 2 |
|---|---:|---:|---:|---:|
| Pairs at 300 s | 36 | 38 | 45 | 40 |
| Pairs at 120 s | 27 | 32 | 29 | 31 |
| Failed dials < 1.5 s (`0x3E`) | 159 | 27 | 21 | 150 |
| Failed dials 1.5–9 s | 19 | 28 | 14 | 32 |
| Dial timeouts (10 s) | 52 | 108 | 91 | 11 |
| All failed dials | 230 | 163 | 126 | 193 |

- Fast failures fell 85 %: the `CONNECT_IND` loss of the HCI snoop is gone.
- Timeouts rose: with an extended target, the controller keeps the create
  connection pending until a request is answered, and a target that stopped
  advertising (slots full) or changed address answers none. That is the
  failure class fix B (dial freshness) addresses.
- Pairs rose 9 % (41.5 against 38), inside the run-to-run spread.

## Dial freshness rejected (fix B, ADR 0029, 2026-10-25)

Fix B cancelled a dial once its target had gone unseen for 2 s at `FULL`
(PR #66). Four 300 s arms (`main`, fix B, fix B, `main`), all phones forced
to `FULL` and kept awake (`svc power stayon true`, `wm dismiss-keyguard`).
26 phones were attached; the 21 that linked in all four are compared. The
Xiaomi phones installed over adb; three wireless-adb phones dropped out in
some arms.

| 21 phones | `main` 1 | fix B 1 | fix B 2 | `main` 2 |
|---|---:|---:|---:|---:|
| Pairs at 60 s | 35 | 28 | 30 | 32 |
| Pairs at 300 s | 58 | 60 | 61 | 60 |
| Failed dials < 1.5 s | 64 | 141 | 181 | 99 |
| Failed dials 1.5–9 s (stale cancels) | 40 (0) | 339 (316) | 248 (223) | 51 (0) |
| Dial timeouts (10 s) | 107 | 11 | 34 | 199 |
| All failed dials | 211 | 491 | 464 | 353 |

- Timeouts fell 80–95 %, but pairs did not rise (60.5 against 59) and fell
  at 60 s. Dial places held by gone targets do not limit pairing.
- 214 of 321 cancelled dials in fix B 1 saw no sighting after the dial
  started; 22 cancelled addresses connected within 30 s.
- `com.android.bluetooth` died on 3 phones in fix B 2 (none in `main`); one
  MediaTek phone died 1 s after a stale cancel.
- Rejected: the code is not merged and ADR 0029 records the result.

## Eviction interval 15 s (ADR 0030, 2026-10-26)

The 60 s eviction interval of ADR 0025 held back idle links: in the `main`
runs of the fix B A/B, while a phone's open links filled its slots, 93–100 %
of the time a link idle for 30 s waited on the interval. ADR 0030 (PR #67)
shortens it to 15 s. A/B with 25 phones attached (Wireless debugging
re-enabled; the CPH2385 and a new 22071219CG, which refuses adb installs,
left out), 23 linked in all four runs:

| 23 phones | `main` 1 | 15 s 1 | 15 s 2 | `main` 2 |
|---|---:|---:|---:|---:|
| Pairs at 60 s | 31 | 33 | 39 | 32 |
| Pairs at 180 s | 43 | 52 | 60 | 45 |
| Pairs at 300 s | 60 | 63 | 71 | 51 |
| Evictions | 61 | 141 | 167 | 58 |
| Links up | 267 | 577 | 529 | 370 |
| Failed dials | 286 | 422 | 427 | 341 |
| Bluetooth restarts | 0 | 2 | 2 | 1 |

- Pairs rose 21 % at 300 s and 28 % at 180 s; both 15 s runs beat both
  `main` runs.
- Bluetooth restarted twice on `EQUGS85L` (CPH2359) in the 15 s runs and in
  none of the six other runs of either A/B, once after an HCI timeout on
  `LE_SET_EXTENDED_ADVERTISING_ENABLE`. `7XHEIBPB` restarts in `main` runs
  too.
- Analysis note: up to `e9b8b45` the radio logs "slots full; advertising
  stopped" at every stop but only the first start, so slot occupancy there
  must be derived from link up/down lines. Later builds log "slot free;
  advertising resumed" at each restart after a full stop.

## 15-minute run: the plateau is the admission limit (2026-10-26)

One 900 s run of PR #68's build (`main` with ADR 0030), logcat streamed;
4 wireless phones dropped out of adb but kept running Cairn, and `7XHEIBPB`
never linked, so 20 phones logged links:

| Pairs by | 60 s | 120 s | 180 s | 300 s | 450 s | 600 s | 900 s |
|---|---:|---:|---:|---:|---:|---:|---:|
| 20 phones | 22 | 43 | 51 | 58 | 66 | 67 | 68 |

- The last new pair formed at 730 s. 9 of the 20 phones admitted 10
  neighbours, the §5.6 limit per rolling hour, between 89 s and 729 s; 8 more
  stopped at 9, their 10th probably with an unlogged phone. No phone reached
  30 attempts (at most 27). A capped central skips P0 silently, so only 17
  BUSY replies were sent.
- So after about 300 s the fleet measures the admission limit, not the radio.
  The A/Bs above compared arms at 60–300 s, before most phones capped.
- For a mesh the pair count is the wrong target: the pair graph was one
  component by 90 s, and every phone was within 4 hops of every other from
  120 s.
- Links churn: of 1272 links the median lived 27 s, the 90th percentile 52 s
  and none 300 s. Links end 30–55 s after their last Resume frame, so idle
  eviction closes them; the core keeps authenticated links up. A mesh needs
  stable links to route over, so the owner chose to pin 75 % of the slots to
  the strongest links (ADR 0031).

## Stable slots (ADR 0031, 2026-10-26)

A version that kept only links up for at least 60 s was stopped after two
runs. The 30 s idle eviction closed links before they reached 60 s, so very
few were kept: 8 links lasted 60 s, against 38 on `main`.
Without that gate, a 600 s A/B (A = `main`, B = ADR 0031):

| | A₁ | B₁ | B₂ | A₂ |
|---|---:|---:|---:|---:|
| Link time in links up > 120 s | 8% | 90% | 89% | 11% |
| Evictions | 291 | 52 | 40 | 271 |
| Pairs by 600 s | 65 | 44 | 31 | 66 |
| Largest live component (mean) | 13.2 of 18 | 13.6 of 18 | 10.4 of 17 | 12.1 of 19 |

Links now stay up, and the live graph is about as connected as before.
Fewer pairs form because fewer slots rotate. Merged as ADR 0031.

## Advertising while full rejected (ADR 0032, 2026-10-26)

ADR 0032 tested whether a full radio should keep advertising at
`LOW_POWER`, evicting an idle link that isn't stable for a device that
connects. It was tested in two versions on 25–28 phones, with 900 s arms:

- **Always advertise while full.** It never evicted for a device that
  connected; it refused 205 devices. Full radios held 3–4 links, all of them
  stable, and their other slots held dials and connections that hadn't yet
  become links.
- **Advertise only while a link can be evicted.** Advertising happened in
  22 and 25 of about 450 full spells. The difference in pairs (50 and 63
  against 53 and 58) and in components is within the noise between arms.

Rejected; the spec is unchanged. Two logs were kept: evictions end in
`(scan)`, and the radio logs `slots full; disconnecting XX:XX`.

## Slot waste (PR #71, 2026-10-26)

PR #71 logs when a dial starts, how long it took to connect, and server
connections that ended without becoming a link. One 1200 s run of `main`
with these logs, on 28 phones:

| Slot time, whole run | slot-s | share |
|---|---:|---:|
| Central links | 49 836 | 52.1% |
| Peripheral links | 28 574 | 29.9% |
| Server connections that never became links | 9 810 | 10.3% |
| Dials that timed out (10 s) | 4 192 | 4.4% |
| Dial → link setup | 2 983 | 3.1% |
| Dials that failed fast | 259 | 0.3% |

- 93 of the 141 server connections that never became links overlap our
  own dial or link to the same address, so they take no extra slot. The 48
  from other phones held 2 526 slot-s (2.6%), with a median of 10.6 s.
- Of 731 dials, 140 connected and 419 timed out. Time to connect: median
  0.9 s, p99 6.6 s, max 7.0 s.
- Taken at the moment a radio goes full, its slots are 54% links and 46%
  connections still being set up. That moment overstates setup, because a
  new connection is usually what fills the radio.
- So about 7% of slot time is wasted. An 8 s dial timeout would save about
  1%, less than the noise between arms. No change.

## P10 and Nothing pre-auth stalls (2026-10-28)

During the S5 demonstration, the P10 lite (API 26) did not pair with the
Nothing Phone (2) (API 36) within 150 s. The receiver logged one 512 B
fragment, then the HCI assembler message `Controller sent a starting packet
without finishing previous packet. Drop previous one.`, and the link
closed. A build from before `d77abae` behaved the same. Pacing
notifications 40 ms after `onNotificationSent` and capping the MTU at 247
looked better at first, but later runs showed that those trials were
confounded by two problems:

- Five other fleet phones were still running cairn, so the Nothing dialled
  them instead of the P10.
- The P10's Bluetooth stack was degraded after many force-stops. It
  logged `enabling advertiser failed, status: 9`, and it recovered only
  after a reboot.

Before each run, the harness now force-stops cairn on every fleet phone
and turns Bluetooth off and on on both phones. With that harness, the
unmodified build paired 6 of 6 times in 18–43 s with no HCI drops. The P10
still queued three notifications within 9 ms, and the central received
all of them. So the dropped fragments came from the degraded stack, not
from notification pacing, and the protocol does not change.

Android 8 has no `svc bluetooth`, and the shell lacks `BLUETOOTH_ADMIN`.
Our harness uses the `REQUEST_DISABLE` and `REQUEST_ENABLE` system dialogs
there. The Pocophone's MIUI dialog was not found, so that phone was not
reset.

## Open

1. **Plateau.** Resolved. ADR 0025 ended slot exhaustion (36 to 49 pairs).
   The rest of the plateau is the §5.6 admission limit, and the mesh is one
   component by 90 s. These didn't help:
   - a congestion controller (ADR 0026);
   - cancelling dials sooner (ADR 0029);
   - advertising while full (ADR 0032).

   Fast 133s were connection requests lost on the advertising channels, and
   ADR 0028 fixed them. ADR 0031 keeps links up, and slot waste is about 7%.
2. **Unanswered frames.** Was the notification lost over the air, or did the
   central stall? On 2026-10-28, the P10 and Nothing losses went away after
   a Bluetooth reset (see above). The fleet3 cases are not yet explained. Needs an HCI snoop on one affected pair. The `out` trace
   is logged when the fragment is queued, so `onNotificationSent` timing
   would also help.
3. **Unmatched P0s.** Resolved: fleet4 has none with the GX6 visible.
4. **P10 lite.** Find out why it never links as central: 11 hung connects
   and 24 status 0x85 failures.
5. **`armeabi-v7a`.** Resolved: build fleet APKs with
   `-PandroidAbis=arm64-v8a,armeabi-v7a`. ADR 0004 holds for release builds.
