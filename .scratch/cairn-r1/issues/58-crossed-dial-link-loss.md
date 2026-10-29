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

## Done when

- The close reason in C2 is identified from a log that names it.
- Pairing can't end with only one side storing the contact (the lost-P4
  case), or the issue records why it is acceptable.
- A dial timeout or a failed crossed dial no longer drops an established
  link. A Robolectric test is written first for the Android dial-timeout
  path.
- Ten crossed-dial trials between an iPhone and a legacy Android phone keep
  every link that came up.
