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

## Done when

- The close reason in C2 is identified from a log that names it. (The
  trace now names it; C2 itself has not been rerun on an iPhone X build
  with the trace.)
- Pairing can't end with only one side storing the contact (the lost-P4
  case), or the issue records why it is acceptable.
- A dial timeout or a failed crossed dial no longer drops an established
  link. A Robolectric test is written first for the Android dial-timeout
  path.
- Ten crossed-dial trials between an iPhone and a legacy Android phone keep
  every link that came up.
