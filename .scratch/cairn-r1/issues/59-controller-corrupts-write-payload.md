# The radio corrupts a write payload below the host

Type: bug
Status: needs-triage
Blocked by: none

## Question

Why does pairing or resume between an iPhone and the Redmi `2201117TY`
sometimes fail with an `authentication` close, and what should cairn do
about it?

## Observation (2026-10-30)

The close reasons from ADR 0041 showed the failure. The runs used the
Redmi (Android 13, Snapdragon 680 `bengal`, legacy advertising) as
peripheral and an iPhone 12 mini (iOS 27.0.1) or SE 2020 (iOS 18.7.8) as
central.

| Run | Central | Failure |
| --- | --- | --- |
| CR1 | 12 mini | The iPhone closed `authentication` after P3. |
| SE5 | SE 2020 | The Redmi closed `authentication` on S1. |
| J9 | 12 mini | The iPhone closed `authentication` after P3. |
| K7 | 12 mini | The iPhone closed `authentication` after P3. |
| L13 | 12 mini | The iPhone closed `authentication` after P3. |

There were 5 failures in about 60 runs. Every other fragment and every
other run matched byte for byte.

## Evidence

Temporary builds logged an FNV-1a digest (J), then the full hex (K, L), of
every fragment on both sides.

- **J9.** The iPhone wrote the second P2 fragment (`0x82`, 512 B) as
  `5398da53`. The Redmi received 512 B as `3f30b2cd`.
- **K7.** The first P2 fragment arrived with value bytes 193–243 replaced
  by random-looking data (50 of 51 bytes differ, 3.8 bits flipped per
  byte). The data matches no other logged fragment.
- **L13.** The first P2 fragment arrived with value bytes 29–243 replaced.
  - The iPhone's HCI log (`pymobiledevice3 btlogger`) shows the host gave
    the controller the correct bytes: ACL 251 + 251 + 17.
  - The Redmi's HCI snoop (from a bugreport) shows the controller gave its
    host the corrupted bytes, in the same 251 + 251 + 17 split. They are
    identical to what the app received.
  - The link used 1M PHY, a 30 ms interval and a 251-byte data length both
    ways. No PHY update was made.

In K7 and L13 the corruption ends at value byte 243. That is the last
byte of the first 251-byte link-layer PDU (4 L2CAP + 3 ATT + 244 value).

## Conclusion

Neither host is at fault. The bytes change between the iPhone's controller
and the Redmi's host: in the iPhone's transmit, on air, or in the Redmi's
Qualcomm receive path. Each corrupted PDU still passed the 24-bit
link-layer CRC, which random noise does not explain at this rate.

The protocol behaved correctly. The P3 card MAC and the S1 MAC detected
the change and closed the link. No corrupted data was accepted.

The cost is availability. Each failure loses a pairing. The redial then
often fails with `0x3e` for 15–20 s ([issue 58](58-crossed-dial-link-loss.md)).

## Open

- Does it happen with an Android central, or with other Android
  controllers? The Mi Note 3 is also Qualcomm.
- Does a single-PDU write fail too? SE5's S1 was 57 B and had no hex dump.
- Options:
  - recover at the fragment level, for example a per-fragment check that
    rejects the GATT write so the central retries it (costs bytes on every
    fragment; needs an ADR);
  - redial faster after an `authentication` close during pairing;
  - accept it and document the device.

Evidence is archived in the session `files/i59-corruption/` (logs, the
iPhone `pklg` and the Redmi `btsnoop`).
