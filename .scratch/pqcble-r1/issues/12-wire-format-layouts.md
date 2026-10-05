# Wire-format byte layouts

Type: prototype
Status: resolved
Blocked by: 05, 09, 10, 14

## Question

What are the exact byte layouts of every `pqcble-r1` message — pairing messages per mode, Resume S1/S2, data frame header, ratchet chunk carriage, beacon payload, doorbell — including type codes, version negotiation, padding classes and length fields? Produce a rough spec draft plus a byte-count table (via `docs/research/ble_airtime.py`) to react to.

## Comments

- Prototype (throwaway): `docs/research/prototypes/wire-layouts/wire_layouts_prototype.py`. Run it with `python3`; it reuses `ble_airtime.py`. It is to be kept on a throwaway branch once the repository has git history (moving it there needs approval).
- Spec draft: `docs/research/2026-10-05-wire-format-draft.md`.

## Answer

Recorded in [ADR 0005: Wire format](../../../docs/adr/0005-wire-format.md). The user accepted all recommendations on 2026-10-05:
- The version byte appears only in the QR and P1.
- A per-device beacon key is shared with contacts and rotated when a contact is removed.
- Plaintext is padded to buckets, and ratchet chunks fill the slack.
- No 0-RTT.
- The doorbell is an 8 B HMAC tag in the beacon slot (this amends ADR 0001).
- The 21 B real-time overhead is accepted.

Key numbers: Resume is 57 + 49 B; P1 1251 B and P2 1137 B; a 30 B chat is 81 B padded; legacy advertising is 29 / 31 B.
