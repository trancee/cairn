# Crossed dials lose a link that came up

Type: bug
Status: needs-triage
Blocked by: none

## Question

When two phones dial each other at the same time, why does a link that
came up go down again? [Issue 50](50-simultaneous-dial-backoff.md) made
crossed dials link within seconds. This is a different failure: the link
comes up, then the losing dial tears it down.

## Observation (2026-10-29)

From [issue 57](57-legacy-os-device-matrix.md) test 2. An iPhone X (iOS
16.7.16) and a legacy-advertising Redmi `2201117TY` (Android 13) were
started together three times.

1. **Run C.**
   - The X linked as central at 13:58:15 (MTU 517), and pairing ran.
   - The Redmi's outbound dial reported `connected after 39 ms` twice and
     never became a link.
   - The Redmi logged `dial 1B:10 timed out` at 13:58:25.164. Its inbound
     link went down 0.6 s later (`link 1 down at 10416 ms`), and the X logged
     `link 1 down`.
   - Hypothesis: the dial's GATT client shares the ACL with the inbound
     link. Closing it on timeout drops the ACL.
2. **Run C2.**
   - The Redmi's dials failed with HCI `0x3e` three times.
   - Meanwhile the X linked as central twice. Each time, about 0.5 s after the
     X received the last pairing frame (`in 0x03 87 B`), the X's SDK asked for
     the disconnect.
   - `bluetoothd` logged `App disconnecting` and reason 722 (local).
   - The core's close reasons are listed in `core/cairn-proto/src/core.rs`
     (`close`, `fail`). The logs don't say which one fired.
3. **Run C3.** The link held.

4. **Android 8/9 phones** ([issue 57](57-legacy-os-device-matrix.md)
   tests 4 and 5), 2026-10-29:
   - Mi Note 3 (API 28) with a 12 mini: two iOS-central links dropped
     shortly after the Mi's own dial "connected after 11 ms" and then
     failed with `0x08` (connection timeout). Same pattern as run C.
   - Xcover 4s (API 28) with a 12 mini: one link negotiated **MTU 23**
     (20 B fragments) and hit the 5 s pre-auth expiry; a second, Android
     central at MTU 517, closed after 98 ms, likely the duplicate-link
     tie-break.
   - Xcover 4s with an iPhone X: iOS sent P4 (`0x04`, 71 B) and Android
     never logged receiving it. Android hit the pre-auth expiry while iOS
     stored the contact: an **asymmetric pairing**.

The X showed 4 contacts after 6 pairing attempts in that session (A, B, C,
C2 ×2, C3), consistent with C2's two attempts failing.

The logs (iPhone syslog, Android `CairnRadio`) are not committed. To
reproduce, rerun the three trials.

## Tried: park a dial that joins the peer's connection (2026-10-29, rejected)

Hypothesis: when our dial connects while the same peer is already connected
to our GATT server, the dial rides that ACL. Closing it on timeout or
failure drops the peer's link. The patch kept such a dial open, did no GATT
work on it, and closed it only when the server connection ended. It passed
Robolectric tests and Kover, then ran on devices with the Mi Note 3 against
the 12 mini (F1–F4) and the Redmi `2201117TY` against the iPhone X (R1–R3),
45 s each:

- The path fired in F2, F4 and R2 (`dial … joined the peer's connection`).
- F1 still lost its link: the dial connected *before* the server's connect
  callback, then failed `0x08` 5.6 s later, and the inbound link dropped in
  the same millisecond. The ordering of server and client callbacks can't
  be relied on.
- F3 lost its link 1.7 s after link-up with no dial in flight, so dial
  teardown is not the only cause.
- R2 regressed: the parked dial held for 32 s while the iPhone's server
  connection never became a link, and the real link came only 36 s in.
- The iPhone's address changed during F1 (`24:6E`, then `BB:22`), so
  address keys also miss.

Not merged. Next: capture an HCI snoop log on the Android side
(`bluetooth_hci.log`) during a reproduction, and log the core's close
reason first (`Action::Disconnect` carries no reason; about 20 call sites
in `core/cairn-proto/src/core.rs`).

## Close-reason trace (2026-10-29)

Both adapters now log why a link ended, just before `down` (ADR 0023,
"Link trace"): `close requested` when the core asked for it, `lost status
0x..` (Android) or `lost error N` (iOS `CBError` code) when the connection
ended otherwise.

Five 40 s runs, Mi Note 3 (API 28) with the 12 mini (T1–T5):
- T2: the iPhone linked as central, and 2.6 s later, during pairing, it
  logged `lost error 6`: `CBError.connectionTimeout`, a supervision
  timeout. Android's server saw status `0x00`. No Android dial was in
  flight: the previous one had failed 8 s earlier, and the next started
  0.2 s after the drop.
- T5: one `close requested` on a second iPhone-central link, the core's
  usual duplicate-link close.
- The other links held until the run ended. The Mi Note 3's dials to the
  iPhone failed with `0x85` (GATT error 133) 16 times out of 16.

So at least some of these losses are radio-level supervision timeouts, not
the core closing the link and not a dial tearing down a shared ACL. The
earlier run C (dial timeout, then link down 0.6 s later) still needs a
trace to tell whether it was the same.

## HCI snoop (2026-10-29)

Mi Note 3 with the 12 mini, runs H1–H3 with the trace build. The snoop
log came from the `BTSNOOP_LOG_SUMMARY` section of `adb shell dumpsys
bluetooth_manager`. That section is base64 of a zlib stream (version 2: per
record a length, packet length, µs delta and type). The full
`btsnoop_hci.log` is unreadable without root, and the bugreport doesn't
include it. Turn on "Bluetooth HCI snoop log" in Developer options, then
restart Bluetooth.

- Every `0x85` (133) dial is an `LE Create Connection` whose `LE Connection
  Complete` arrives within about 30 ms. A `Disconnection Complete` with
  reason **0x3E** follows about 300 ms later: the iPhone never answers on
  the data channel.
- **H2**: Android's dial linked (handle 0x00e). Then the iPhone dialled
  (0x00c) and its core closed that duplicate. Android reported its
  *central* link lost with `0x13`, but handle 0x00e stayed up for another
  32 s. Bluedroid routes GATT client events by address, so two ACLs to one
  address get mixed up.
- **H3**: the Android dial joined the iPhone's connection ("connected after
  15 ms"). It sent `LE Connection Update` (interval 6, then 9–12), which the
  iPhone refused with 0x3B. 1 s after the core closed the duplicate client
  link, the Android host sent `Disconnect` (0x13) on the shared handle.
- **H1**: the iPhone-central link (interval 30 ms, supervision timeout
  **720 ms**, LE 2M) ended with reason **0x08** on both sides. No Android
  dial was in flight. The iPhone kept advertising, and Android kept
  active-scanning it.

## Android waits for iOS (2026-10-29, ADR 0039)

[ADR 0039](../../../docs/adr/0039-android-waits-for-ios-to-dial.md),
spec 0.20 [OI-41]:
- Android dials a beacon-less (iOS) peer only 10 s, plus the spread, after
  first seeing it.
- It doesn't dial an address that connected to its server less than 10 s
  ago.

Results are in the ADR's Validation:
- Mi Note 3: crossed-dial losses fell from 2 of 3 runs to 1 of 10, and
  5 of 10 runs had no Android dial at all.
- Redmi: no crossed-dial loss in 10 runs.
- iPhone X with the extended Pocophone: still linked in 3 of 3, through
  Android's dial after the wait.

## Supervision timeouts (open)

These remain on both Android phones: Mi Note 3 3 of 10, Redmi 2 of 10
(R2 and R9, on links already paired and idle).

Ruled out:
- **Android scan load.** A build that stopped scanning once the iPhone
  connected (N1–N10) still had 5 of 10 runs with one.
- **LE 2M, untested.** Android can't test 1M on the iPhone's link: the
  iPhone, as central, ignored Android's `LE Set PHY` for 1M and stayed on 2M.

The common factor is the iPhone-central link's 720 ms supervision timeout.
Apple's Accessory Design Guidelines allow 2–6 s. The lab has about 38 phones
on 2.4 GHz.

Controls (2026-10-29, 120 s runs, no timeout in any):
- **Android–Android** (Redmi and Pocophone): 3 of 3 runs, about 6
  link-minutes.
- **iPhone X central, Mi Note 3 peripheral**: 10 runs, about 20
  link-minutes. Half used a temporary iOS build that stopped scanning while
  a link was up (XS1–XS5), half the normal build (XB1–XB5). The only
  losses were duplicate links from RPA rotation, closed by the core.
- **Pocophone central, iPhone X peripheral** (X1–X3, above): 3 of 3.

So far only the 12 mini, as central, has had a timeout, with two different
Android phones. The iPhone's own `AllowDuplicates` foreground scan is still
a suspect there: the no-scan build couldn't run on the 12 mini, which was
locked.

### 12 mini runs (2026-10-29 evening)

- **iPhone scan, ruled out.** The normal and the no-scan iOS builds,
  alternated run by run against the Mi Note 3 (Mbase1–5, Mns1–5, 120 s
  each): `CBError` 6 (connection timeout) in 3 of 5 runs with each.
- **When.** Of 12 timeouts across all runs, 7 came 1.8–3.9 s after link-up,
  one at 9.7 s and four at 18–63 s: mostly during pairing.
- **Snoop, H1.** Both 0x08 links (handles 0x00a and 0x00d) were healthy
  through PHY 2M and Data Length (251 B). Then the iPhone's acknowledgements
  (Number of Completed Packets) slowed to one per 0.1–0.7 s on a 30 ms
  interval, with nothing received for 1.4 s before the drop. Handle 0x00d
  had just sent three 515 B notifications; handle 0x00a sent only small
  GATT responses. So packet size doesn't explain it: the link is lossy for
  over 720 ms at a time.
- **Android can't ask for conforming parameters.** A GATT client on the
  iPhone's link logged `onConnectionUpdated`: the iPhone uses interval 24
  (30 ms), timeout 72 (720 ms).
  - `requestConnectionPriority(BALANCED)` was refused with 0x3B (59). The
    Android presets ask for a 20 s supervision timeout, and Apple allows
    at most 6 s.
  - `BluetoothGatt.requestLeConnectionUpdate` doesn't exist on Android 9
    and is blocked as hidden API on Android 13 (`NoSuchMethodException`
    on both).
- **Recovery is slow.** After a drop, neither side redials for up to
  2 min: §10.4 allows one attempt per address per 2 min, and a dial that
  linked counts. A drop mid-pairing also backs pairing off for 2 min,
  doubling (OI-30). In Mns2, the iPhone dialled again 48 s after the drop.

### Faster recovery (ADR 0040, proposed)

ADR 0040 proposes three rules. Each was written test-first (Rust admission,
Android `DialPolicyTest` and `DialRuleTest`, iOS `IosRadioTests`).
- A central redials a link lost to a supervision timeout after 1–5 s,
  then 5–15 s, then 2 min.
- Android doesn't dial an address for 15 s after its server connection
  ends.
- The first drop mid-pairing is forgiven.

Device runs (12 mini and Mi Note 3, RD1–6 and RY1; ADR 0040 §Validation):
- The iPhone redials within 5 s.
- Android stays out of the way.
- Recovery took 33–49 s instead of 2 min or more, because the redialled
  links also dropped within about 2 s.
- RY2 onwards were invalid: the iPhone's screen locked and iOS suspended
  the app.

**Hand-over (ADR 0040 rule 2, 2026-10-29 late).** The H1 snoop showed
iPhone-central drops 2.7–3.7 s after the move to 2M. The one Android-central
link (h=00e: 15 ms interval, 2 s timeout) held. So after a timeout the
iPhone now waits 45 s and Android dials it after 15–18 s. Two fixes came
from the device runs:
- HO1: Android's schedule was at 2 min from failed first-contact dials, so
  it didn't take over. A server connection that ends now restarts it.
- HV3, HV4: Android's link held, but when the iPhone's 45 s ran out it
  dialled the same Android, which dials from another address than it
  advertises. The crossed dial tore the link down. The iPhone now holds
  off while any central that linked after the hand-over is linked.

HW4: Android linked 21 s after the timeout, pairing completed, and the link
held 52 s to the end of the run. In HW1–HW3, all 23 Android dials to the
iPhone failed with 133 (0x3E), so no link held. Android's dial success to
an iPhone now limits recovery.

### 0x3E diagnosis (2026-10-30)

Runs HX1–HX5 used a Mi Note 3 HCI snoop, and HX4–HX5 also captured the
iPhone's `bluetoothd` log over USB (`pymobiledevice3 syslog live`). That
log needs no Bluetooth logging profile. HR1–HR2 paired the 12 mini with
the Redmi (Android 13). HW5–HW6 repeated the Mi Note 3 runs with its
Wi-Fi off.

- **Failed dials look the same at the HCI level.** The Android sends
  LE Create Connection (interval 30–50 ms, timeout 5 s, own address
  public, peer RPA). Connection Complete follows after 30–80 ms.
  Disconnect 0x3E follows 280–320 ms later, which is about 6 intervals of
  45 ms. The peer never answered the first connection events. Successful
  dials used the same parameters and the same RPA, and saw a PHY update
  about 1 s later.
- **The failure happens in both directions.** In HX5 the iPhone's own dial
  to the Mi Note 3 reported "Outgoing LE Connection complete … status 0",
  then "LE Link disconnected … reason 762" 365 ms later. Apple's status
  base 700 + 62 makes 762 equal to HCI 0x3E. The Mi Note 3's snoop has no
  peripheral Connection Complete for that attempt: it never received the
  CONNECT_IND. The iPhone logged no connection (no `Le topology` entry as
  peripheral) for any of the 12 Android dials in HX4–HX5.
- **Advertising-channel reception is fine.** The Mi Note 3 heard about 25
  iPhone adverts/s at a median RSSI of −68 to −73 dBm, with no difference
  between windows where dials failed and windows where they succeeded.
  Only data-channel exchanges fail: the first packets after CONNECT_IND,
  and links that do form drop with 0x08 within 2–5 s.
- **It's specific to the Mi Note 3 pair.** With the Redmi, in the same
  session and with the same builds, the iPhone's dials connected on the
  first or second attempt (one 0x3E in HR1), and both links held about
  113 s, to the end of the run, with no supervision timeout.
- **Ruled out:**
  - the iPhone's Wi-Fi: HX4 overlapped a 2.4 GHz "critical" window, but
    HX5 ran entirely on 5 GHz and failed the same way;
  - the Mi Note 3's Wi-Fi: in HW5–HW6, with Wi-Fi and Wi-Fi scanning off,
    11 of 13 dials still failed with 0x3E;
  - a bond or privacy filtering: there is no bond on either side;
  - other Cairn instances: none of the farm's phones was running Cairn.
- **A separate Android bug.** In HX1 the iPhone dialled while the Android's
  own link was up. When the crossed link closed, Android reported its
  central link lost with 0x13. The controller kept that ACL (h=009) for
  another 72 s, and the next three Android dials to the same RPA each hung
  for 10 s. This is ADR 0039 failure 2 again, seen from the dial side.

Conclusion: the 0x3E failures and the early 0x08 drops are a data-channel
radio problem between the 12 mini and the Mi Note 3 (an Android 9 phone
on the device farm), not a dial-policy fault. The Redmi pair is clean. The
remaining candidates are the Mi Note 3's controller or antenna, and its
placement among about 30 farm phones. Software can't distinguish these;
moving the phones can.

**iPhone HCI capture (HP2–HP3).** With Apple's Bluetooth logging profile
installed, `pymobiledevice3 btlogger` streams the 12 mini's HCI traffic over
USB in PacketLogger format, with no sysdiagnose needed. The Mi Note 3 snoop
ran at the same time; its clock is 5 h 2 min 13.4 s behind the iPhone
capture.
- HP3 control: the Mi Note 3's successful dial appears on the iPhone as
  LE Enhanced Connection Complete (peripheral, 45 ms, 5 s). A PHY update to
  2M follows, then ACL traffic, and the link held 105 s. So the capture
  includes connection events.
- All four failed dials (three in HP2, one in HP3) have no Connection
  Complete on the iPhone. The Mi Note 3 reports its own Connection Complete
  and then 0x3E. Either the iPhone's controller missed the CONNECT_IND, or
  it reports a peripheral connection only after the first connection event,
  which never succeeded. Either way, only the Mi Note 3 believed in the link.
- All four dials had the same RPA, parameters and Android build. The
  iPhone's HCI log in those windows has only advertising and vendor
  commands.

So the CONNECT_IND is lost between the two radios. Together with the
iPhone's own dials that the Mi Note 3 never receives, this points at the
Mi Note 3's radio: the adverts get through, but the timing-critical
packets sent 150 µs after an advert don't.

### Mi Note 3 workarounds (2026-10-30, none works)

The phones were 1 m apart for all of these runs. Each row is a temporary
Android build (source reverted) or a device change, run against the 12 mini.

| Run | Change | Android dials linked |
| --- | --- | --- |
| RB1–RB3 | Mi Note 3 rebooted after 6 days' uptime | 0 of 9 |
| Q1–Q3 | Stop advertising and scanning for 2 s around each dial | 0 of 9 |
| AC1–AC3 | `connectGatt(autoConnect = true)` | 0 of 9 (each times out after 10 s) |
| F1–F4 | Ladder of 8 retries at random 1–3 s | 1 of 45 |
| MX1–MX3 | iPhone X instead of the 12 mini (normal build) | 2 of 5 |
| RC1–RC2 | Redmi instead of the Mi Note 3 (control) | 1 of 1; both runs linked within seconds |

Earlier experiments ruled out the 1M PHY preference (the iPhone central
ignores it), connection-parameter requests (iOS refuses with 0x3B) and
Android scan load.

- Across HX, HW, HP and the runs above, about 1 in 5 Mi Note 3 dials to an
  iPhone links at best, and on some days almost none do. The iPhone's
  dials to the Mi Note 3 fail too.
- Each failure is decided between the two radios, below the host. No
  setting Android exposes changes the result.
- The Redmi links with the same 12 mini at the same spot. The iPhone X also
  links, though less reliably.
- So the fault is in the Mi Note 3's controller (2017 hardware, Android 9).
  Cairn can't fix it.

Decision:
- Treat the Mi Note 3 as a known-bad device.
- Use the Redmi (Android 13) as the legacy Android peer for iPhone
  acceptance runs.
- Keep the ladder as it is. More retries don't help this phone, and they
  would cost every other pair energy and add to crossed-dial collisions.

Open:
- In HW6, after the iPhone rotated its RPA (31:7B → D9:F0), Android dialled
  the new address three times while its link to the old address was still
  up. Each dial failed with 0x3E, and the link held. Android doesn't know
  that the two RPAs belong to the same peer until the handshake.

### Acceptance runs with the Redmi (2026-10-30, AR1–AR10)

Ten 90 s runs: Redmi (Android 13) and 12 mini, 1 m apart, both on the
branch build.
- **Every run ended linked and paired.** Every link that came up exchanged
  frames.
- **Crossed dials no longer drop links.** In AR2 and AR9 the Android dialled
  while the iPhone's link was up: twice to the same address and once to the
  iPhone's rotated RPA. Each duplicate was closed within 100 ms of link-up,
  and the established link held.
- **Supervision timeouts remain (OI-42).** Three iPhone-central links ended
  with iOS error 6 (`connectionTimeout`): AR3 after 23 s, AR8 after 60 s
  and AR9 after 3.5 s. Android reports these as status 0x00 on its server
  side. ADR 0040's recovery relinked each pair 5–20 s later.
- **One rejected pairing.** In AR6 the iPhone, as central, closed the link
  15 ms after P3 arrived instead of sending P4. The Android's P3 was 87 B,
  the usual size. The Android relinked as central 29 s later and paired in
  0.7 s.
  - The core closes there only when P3 fails the commitment or MAC check,
    or when the peer's beacon day is more than a day off.
  - A temporary soak test ran 27,500 pairings (AwsLc, Reference and mixed
    backends) with no failure, so a crypto edge case is unlikely.
  - Only AR6 shows this pattern across the 89 iPhone logs. Neither app
    logs why the core closed a link. Add that before chasing this further.

Logs, the snoop dumps and the decoders are kept outside the repository
(session `files/i58-snoop`, `files/i58-logs`, `files/i58-0x3e`).

## P3 closes and one-sided pairing (2026-10-31)

- **P3 closes.** In C2, AR6 and CR1, the iPhone closed the link about
  0.5 s after P3 arrived. Each time the peer was the Redmi. Issue 59 found
  the cause: the Redmi's controller corrupts some 512 B writes from an
  iPhone, and the frame's MAC then fails (`authentication`). ADR 0042 checks
  every fragment and resends a corrupted write. In runs N1–N22, 3 writes were
  corrupted; each was rejected and resent once, and no `authentication`
  close followed.
- **One-sided pairing.** ADR 0043 keeps a paired contact provisional until
  the pairing link carries a valid S2 (on B) or S1 (on A). Until then it is
  neither persisted nor reported, and it is forgotten if the link closes
  first.
  - A lost P4 or S1 now leaves both sides as strangers, so the next meeting
    pairs again.
  - A lost first DATA frame was already recovered by ADR 0022's key
    alternation.
  - A lost S2 still leaves A with an orphan contact. That is
    [issue 60](60-orphan-contact-after-lost-s2.md).
  - Core loopback tests cover each lost frame.

### Acceptance runs with ADR 0042 and 0043 (2026-10-31, P1–P10)

Ten 60 s runs: Redmi (Android 13) and 12 mini, 1 m apart, both built from
`fix/provisional-contact` and started together.
- **Every run paired.** The iPhone linked as central, and the link carried
  all 14 frames: pairing, Resume and the first DATA frame. No link closed
  as `authentication` or `unknown`.
- **ADR 0042 resent one corrupted write.** In P4 the Redmi rejected one
  write for its check, and the resend went through.
- **Duplicate closed, established link kept.** In P7 the iPhone opened a
  second link 46 s in. The core closed it as `duplicate` after 162 ms, and
  link 1 held until the run ended.
- **Supervision timeouts remain (OI-42).** P5 and P9 lost the link with
  iOS error 6, 45 s and 40 s after link-up, after pairing had completed.
- **No crossed dial came up.** The Redmi never dialled; ADR 0039 has it
  wait for the iPhone, so these runs don't exercise the Android
  dial-timeout path.

Logs are in `/tmp/pair/{a,i}_P*.log` (not committed).

## Done when

- [x] The close reason in C2 is identified from a log that names it.
  Issue 59's logs name it: `authentication`, after a corrupted write from
  the iPhone.
- [x] Pairing can't end with only one side storing the contact (the lost-P4
  case), or the issue records why it is acceptable. ADR 0043 closes the
  lost-P4 case. Issue 60 tracks the lost-S2 case.
- [x] A dial timeout or a failed crossed dial no longer drops an established
  link. A Robolectric test is written first for the Android dial-timeout
  path. Before the radio closes a dial whose address is connected to its GATT
  server, the server calls `connect(device, false)` to hold the shared link
  (ADR 0023 amendment, 2026-10-31). `DialPolicyTest` was red before the fix.
- [ ] Ten crossed-dial trials between an iPhone and a legacy Android phone keep
  every link that came up. Open: in H1–H10 (2026-10-31, Redmi `2201117TY`
  and iPhone 12 mini, 60 s each) no dial crossed. The iPhone dialled first
  every time, as ADR 0039 intends, and the hold path never ran. All 10 paired
  with 14 frames. H4, H6 and H7 later lost the link to the known iOS
  supervision timeout (error 6, ADR 0040); none followed a dial. Forcing a
  crossed dial needs a build that skips the 10 s wait.
