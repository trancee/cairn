# Wire-format draft: `pqcble-r1` (rough, for reaction)

Status: **accepted draft** (ticket *Wire-format byte layouts*; decisions in [ADR 0005](../adr/0005-wire-format.md)). Exact bit-level encoding is finalised in `pqcble-wire`. Byte counts come from
[`prototypes/wire-layouts/wire_layouts_prototype.py`](prototypes/wire-layouts/wire_layouts_prototype.py),
which reuses [`ble_airtime.py`](ble_airtime.py). Items marked **[Qn]** were grilled on 2026-10-05; all recommendations were accepted.

Builds on [ADR 0001](../adr/0001-crypto-suite.md) (suite), [ADR 0002](../adr/0002-store-and-forward.md)
(message layer), [ADR 0003](../adr/0003-ble-transport.md) (framing), and §4 of the
[findings](2026-10-05-pqc-over-ble-findings.md).

## 1. Conventions

- Integers are big-endian unless noted. Variable-length integers use **LEB128**: 1 B up to 127, 2 B up to 16 383, 3 B up to 2 097 151.
- `H` = SHA-384. Truncations follow ADR 0001.
- `ctx = "pqcble-r1" ‖ pairID ‖ epoch` goes into every KDF and MAC.
- **Version [Q1]:**
  - The protocol version is carried by the GATT service UUID and the `ctx` label.
  - An explicit version byte appears only in the QR payload and in P1.
  - Each contact record stores the version the pair agreed on. Resume and data frames carry no version byte.
  - No negotiation: when versions differ, pairing fails.

## 2. Frame header (1 B, every frame and every fragment)

```
bit 7     MORE     1 = more fragments follow (GATT only; always 0 on L2CAP CoC)
bits 6–4  type     0 PAIR  1 S1  2 S2  3 DATA  4–7 reserved
bits 3–0  sub      PAIR: step 1–4;  S1/S2: bit 0 = KCI;  DATA: 0
```

- **Fragmentation.**
  - Each fragment repeats the header byte. MORE is set on every fragment except the last.
  - Reassembly concatenates the fragment bodies under one header with MORE cleared.
  - Cost: +1 B per extra fragment, and 0 B when the frame fits one ATT value.
- **AAD.** In DATA frames the reassembled header byte is the AES-GCM AAD.
- **Unknown values.** A reserved type or a non-zero reserved bit closes the link. Nothing is sent back, so there is no error oracle.

## 3. Pairing (once per contact; pre-auth limit 2560 B)

Pairing role A initiates and B responds. KEM: X-Wing.

| Msg | Layout | Bytes |
|---|---|---:|
| QR (out of band, shown by A) | `ver(1) ‖ H(ek_A)[..32] ‖ token(16)` | 49 |
| P1 A→B | `hdr ‖ ver(1) ‖ mode(1: QR/SAS/TOFU) ‖ commit=H(nA)[..32] ‖ ek_A(1216)` | 1251 |
| P2 B→A | `hdr ‖ ct(1120) ‖ nB(16)` | 1137 |
| P3 A→B | `hdr ‖ nA(16) ‖ AEAD(confirm_A(16) ‖ card)` | 113 (card 64 B) |
| P4 B→A | `hdr ‖ AEAD(confirm_B(16) ‖ card)` | 97 |

- **`ss`** comes from X-Wing.
- **Transcript.** `th = H(P1 ‖ P2 ‖ nA)`, and `RK = HKDF(ss, th, ctx)`.
- **SAS.** `SAS = Trunc_6digits(H("sas" ‖ th ‖ nB))`.
  - A commits to `nA` before seeing `nB`, and B sends `nB` before seeing `nA`. Neither side can grind the code.
- **QR mode.**
  - B checks `H(ek_A)` against the QR, which authenticates A.
  - B proves it scanned the QR with `confirm_B = MAC(K, "qr" ‖ token ‖ th)`, which authenticates B.
  - Both phones also show a **4-digit confirmation code**, `Trunc_4digits(H("qrc" ‖ th ‖ nB))`, and A taps confirm. This defeats an attacker who photographed the QR ([threat model](../spec/threat-model.md)). It needs no extra bytes on the wire.
- **TOFU.** Same exchange with no comparison. The contact stays marked *unverified*. Keeping `th` lets the pair show the SAS later for an in-person upgrade.
- **Contact card** (AEAD-protected): display name (≤ 48 B UTF-8), capability bits (L2CAP CoC, KCI), and the optional static ML-KEM-768 `ek` (+1184 B) when the KCI profile is on.

## 4. Resume (every connection; pre-auth)

| Msg | Layout | Bytes |
|---|---|---:|
| S1 I→R | `hdr ‖ pseudonym(8) ‖ eI(32) ‖ mac(16)` | **57** |
| S2 R→I | `hdr ‖ eR(32) ‖ confirm(16)` | **49** |
| S1 KCI | `… ‖ ct_to_R_static(1088) ‖ mac` | 1145 |
| S2 KCI | `… ‖ ct_to_I_static(1088) ‖ confirm` | 1137 |

- Key schedule as in findings §4.2. The epoch and the retry counter are not sent: R pre-indexes the pseudonyms for `{CK_n, CK_{n+1}} × attempts 0–3`.
- The first DATA frame from I is R's key confirmation.
- There is no 0-RTT, so data starts after S2 **[Q4]**.

## 5. DATA frame

```
hdr(1) ‖ AES-256-GCM( records ‖ zero padding ) ‖ tag(16)
nonce = direction(1 bit) ‖ 0…0 ‖ frame counter (64 bit)    # implicit, per session key
```

**Records** (`type(1) ‖ len(LEB128) ‖ body`). A `0x00` type byte ends the stream, and the remaining bytes are padding.

| Type | Body |
|---|---|
| `01` CHAT | `msgno(LEB128) ‖ UTF-8 text` |
| `02` QUEUED | message-layer seal: `gen(1) ‖ msgno(LEB128) ‖ AES-GCM ct ‖ tag(16)` |
| `03` ACK | highest contiguous `msgno` (cumulative, ADR 0002) |
| `04` READ | `msgno` up to which messages were read |
| `05` EXPIRED | `from(LEB128) ‖ to(LEB128)` |
| `06` KEM_EK | `epoch(1) ‖ offset(LEB128) ‖ chunk of ML-KEM-768 ek` |
| `07` KEM_CT | `epoch(1) ‖ offset(LEB128) ‖ chunk of ML-KEM-768 ct` |
| `08` CAPS | capability bits (e.g. CoC upgrade allowed) |
| `09` CLOSE | reason(1) |

- **Padding [Q3].** Recommended: pad the plaintext up to buckets `32/64/128/256/512/1024/2048/max`. Either way, KEM_EK/KEM_CT chunks fill the padding slack first, so padding pays for the ratchet.
- **Ratchet.**
  - When a KEM epoch completes, its `ss` and `H(ek) ‖ H(ct)` are mixed into `CK` **at the next Resume**. Data frames therefore need no key-phase bit.
  - Offsets let a transfer continue after a disconnect.
  - Idle connections may flush the remaining chunks in dedicated frames.

## 6. Beacon and doorbell (advertising)

- **Beacon [Q2].** One **device beacon key**, given to every contact at pairing and rotated to the remaining contacts when one is removed. 8 B, `Trunc8(HMAC(BK_d, role ‖ window))`, with a 5-minute window and a daily one-way `BK_d` chain.
- **Android legacy advertisement.** `flags(3) ‖ svcdata(2+16 UUID+8)` = **29 / 31 B**.
- **iOS in the foreground** encodes the beacon in a rotating 128-bit UUID. **iOS in the background** sends none.
- **Doorbell [Q5].**
  - The previous `beacon ‖ ctr ‖ AEAD(flags) ‖ tag` design needs 42 B and **does not fit** legacy advertising.
  - Proposal: the doorbell is an 8 B per-contact PRF tag `Trunc8(HMAC(K_door_pair, "door" ‖ window))` that **replaces** the beacon in the same slot. The advertiser alternates between the beacon and pending doorbells.
  - It costs 0 extra bytes and carries no payload. A replay within the window causes at most one wasted connection.
  - This changes ADR 0001's "doorbell 8 B AEAD tag" into "8 B HMAC tag".
  - Not available on iOS: iOS cannot ring and can only be rung.

## 7. Byte table (selected, 2M PHY, airtime at ATT MTU 247)

| Message | Bytes | Frags @23 / 185 / 247 / 517 | ms |
|---|---:|---|---:|
| P1 (X-Wing ek) | 1251 | 66 / 7 / 6 / 3 | 7.62 |
| P2 (X-Wing ct) | 1137 | 60 / 7 / 5 / 3 | 6.72 |
| S1 + S2 | 57 + 49 | 3+3 / 1+1 / 1+1 / 1+1 | 1.29 |
| chat "hi", no padding | 23 | 2 / 1 / 1 / 1 | 0.52 |
| chat 30 B, no padding / pad16 / buckets | 51 / 65 / 81 | 1 frag @ ≥185 | 0.64 / 0.69 / 0.76 |
| chat 200 B, buckets | 273 | 15 / 2 / 2 / 1 | 1.96 |
| queued 30 B, delivered (buckets) | 81 | 5 / 1 / 1 / 1 | 0.76 |
| ack only | 21 | 2 / 1 / 1 / 1 | 0.52 |
| KEM epoch ek + ct | 1207 + 1111 | 7+7 @185 | 13.6 |

A real-time chat costs **21 B of overhead** without padding: header 1, record header 2, msgno 2 and tag 16. A 2 B "hi" doesn't fit one 20 B ATT value at the minimum MTU **[Q6]**.
