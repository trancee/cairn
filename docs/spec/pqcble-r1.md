# `pqcble-r1` protocol specification

Status: **draft 0.2** (ticket *Spec consolidation*, 2026-10-05). It is not frozen: the formal models (*Formal model: Resume*, *Formal model: PQ ratchet mixing*, *Formal model: SAS pairing*) may change §5–§7, and test vectors are pending (§12).

This document consolidates, and is normative over:
- [ADR 0001](../adr/0001-crypto-suite.md) to [ADR 0009](../adr/0009-pairing-ux.md);
- the [wire-format draft](../research/2026-10-05-wire-format-draft.md);
- the [threat model](threat-model.md).

Consolidation found 15 inconsistencies and gaps between the sources. They were resolved on 2026-10-05 and are recorded in §13; the affected ADRs are amended. **[OI-n]** marks text that follows resolution *n*. Items marked *provisional* remain subject to the formal models.

The key words MUST, MUST NOT, SHOULD, SHOULD NOT and MAY are to be interpreted as described in RFC 2119 and RFC 8174 when, and only when, they appear in capitals.

Vocabulary follows [`GLOSSARY.md`](../../GLOSSARY.md).

## 1. Overview

Two **peers** run **pairing** once (§5) and become **contacts**. Every BLE connection between contacts starts with a **Resume** (§6), which derives the **session** keys. Data frames (§7) then carry real-time messages, **queued messages** (§8), receipts and the chunks of the post-quantum ratchet (§9). Contacts find each other through **beacons** (§10) and may ring each other with a **doorbell** (§10.3). The BLE transport is specified in §4.

```
Pairing (once)                Resume (each connection)         Data
X-Wing + QR/SAS/TOFU ──RK──►  CK_n + X25519, 57 B / 49 B ──SK──► AES-256-GCM, 17 B
                                        ▲ mix completed PQ epoch      │ ML-KEM-768 chunks in padding
                                        └─────────────────────────────┘
```

## 2. Notation and primitives

### 2.1 Primitives (ADR 0001)

| Name | Definition |
|---|---|
| `XWing.KeyGen / Encaps / Decaps` | X-Wing KEM (ML-KEM-768 + X25519, SHA3-256 combiner); `ek` 1216 B, `ct` 1120 B, `ss` 32 B |
| `MLKEM.KeyGen / Encaps / Decaps` | ML-KEM-768 (FIPS 203); `ek` 1184 B, `ct` 1088 B, `ss` 32 B |
| `X25519(sk, pk)` | RFC 7748; all-zero output MUST be rejected (abort) |
| `H(x)` | SHA-384 |
| `HMAC(k, x)` | HMAC-SHA-384 |
| `HKDF-Extract`, `HKDF-Expand` | RFC 5869 with SHA-384 |
| `Seal(k, n, aad, p)`, `Open(…)` | AES-256-GCM, 96-bit nonce, 16 B tag |
| `rand(n)` | `n` bytes from the backend CSPRNG |

No other algorithms are used. There is no suite negotiation.

### 2.2 Conventions

- `‖` concatenates. `x[..n]` is the first `n` bytes of `x`. `TruncN(x) = x[..N]`.
- Integers are big-endian unless noted. `u8`, `u16` and `u64` are fixed-width.
- `LEB128` is unsigned LEB128. Encoders MUST use the minimal encoding, and decoders MUST reject non-minimal encodings and values above 2^32 − 1.
- `lp(x) = u16(len(x)) ‖ x`.
- String literals are ASCII without a terminator.
- **Labelled KDF.** Every derived key uses
  ```
  KDF(ikm, salt, label, info, L) = HKDF-Expand(HKDF-Extract(salt, ikm), lp("pqcble-r1 " ‖ label) ‖ info, L)
  ```
  An empty salt is 48 zero bytes.
- **Labelled MAC.** `MAC(k, label, x) = Trunc16(HMAC(k, lp("pqcble-r1 " ‖ label) ‖ x))`.
- `Digits(x, d) = (u64(x[..8]) mod 10^d)`, rendered with leading zeros. The modulo bias is below 2^-44 and is ignored.
- All comparisons of MACs, tags, pseudonyms against secret-derived tables, beacons and SAS inputs MUST be constant-time (§11).

### 2.3 Roles

- **Pairing role A** shows the QR code and sends P1. **Pairing role B** sends P2. The role is fixed per contact and stored.
- **I** (initiator) and **R** (responder) are Resume roles: I is the GATT central of the connection.

## 3. Versioning

- The protocol version is `0x01` for `pqcble-r1`.
- It appears explicitly only in the QR payload and P1. Elsewhere it is implied by the GATT service UUID (§4.1) and by the `"pqcble-r1 "` prefix of every KDF and MAC label.
- A peer MUST abort pairing when P1's or the QR's version differs from its own. There is no negotiation and no downgrade.
- Each contact stores the version it paired under. Any change to a layout, label or primitive requires a new version, a new service UUID and re-pairing (ADR 0005).

## 4. Transport (ADR 0003)

### 4.1 GATT service

The peripheral is the GATT server. UUIDs are vendor 128-bit values, fixed for r1, and are listed in §12.

| Characteristic | Properties | Content |
|---|---|---|
| `beacon` | read | The current 8 B beacon (§10.1) |
| `rx` | write without response | Central → peripheral fragments |
| `tx` | notify | Peripheral → central fragments |
| `psm` | read | `u16` L2CAP PSM. The server MUST return an ATT error unless a Resume has completed on this connection |

### 4.2 Frame header

Every frame and every fragment begins with one header byte:

```
bit 7     MORE   1 = more fragments of this frame follow (GATT only; 0 on L2CAP CoC)
bits 6–4  type   0 PAIR   1 S1   2 S2   3 DATA   4–7 reserved
bits 3–0  sub    PAIR: step 1–4;  S1/S2: bit 0 = KCI; S1 bit 1 = MIX (*provisional*, §9) [OI-4]; other bits 0;  DATA: 0
```

A receiver MUST close the link without sending anything when it sees:
- a reserved type;
- a sub value not allowed for the type;
- a frame type not allowed in the current state.

### 4.3 Fragmentation

- One ATT value carries one fragment: the header byte plus up to `ATT_MTU − 4` body bytes.
- The fragments of a frame are sent back to back. Every fragment repeats the header, with MORE set on all but the last.
- Fragments from different frames in the same direction MUST NOT interleave.
- Reassembly concatenates the bodies. The reassembled frame is the header with MORE cleared, followed by the bodies.
- A fragment whose header differs from the first fragment's header in anything but MORE MUST close the link.

On L2CAP CoC, one SDU is exactly one frame with MORE = 0.

### 4.4 Limits

| State | Max reassembled frame | Other |
|---|---|---|
| Before authentication (pairing, Resume) | 2560 B | One frame in flight per direction; it must be reassembled within 5 s |
| After Resume | 4096 B | — |

- Exceeding a limit closes the link.
- A connection that has not completed Resume or pairing within 5 s of connecting MUST be closed.
- Implementations MUST cap the number of concurrent unauthenticated links.

### 4.5 Flow control, loss and CoC upgrade

- Only platform backpressure is used, with a bounded send queue. There are no transport acks.
- A disconnect discards any partial frame. Recovery is a new Resume plus the store-and-forward resend (§8).
- **CoC upgrade.** After a Resume, if both sides set CAPS bit `coc` (§7.3) and the feature flag is on, the central reads `psm` and opens an LE CoC channel. Later frames of the session use CoC. If the upgrade fails, the session continues on GATT.

### 4.6 Duplicate links

If two contacts hold two links, the link where pairing role A is the central survives. The other is closed before Resume.

## 5. Pairing

Pairing MUST only be accepted while the local user has the pairing screen open (threat model §5). It is the one place where an asymmetric operation may run before authentication.

### 5.1 Messages

| Msg | Dir | Body after `hdr` | Size |
|---|---|---|---:|
| QR | A shows | `ver(1) ‖ qh(32) ‖ token(16)` | 49 |
| P1 | A→B | `ver(1) ‖ mode(1) ‖ commit(32) ‖ ek_A(1216)` | 1251 |
| P2 | B→A | `ct(1120) ‖ nB(16)` | 1137 |
| P3 | A→B | `nA(16) ‖ Seal(K_card_A, 0^12, hdr ‖ th, confirm_A(16) ‖ card_A)` | ≤ 135 |
| P4 | B→A | `Seal(K_card_B, 0^12, hdr ‖ th, confirm_B(16) ‖ card_B)` | ≤ 119 |

- `mode` is `0x01` QR, `0x02` SAS or `0x03` TOFU. Any other value aborts.
- The sizes are maxima for a card with a 48 B name and no KCI key (86 B plaintext, §5.4) [OI-1]. A KCI card adds 1184 B.

### 5.2 Computation

```
A:  (ek_A, dk_A) ← XWing.KeyGen();  nA ← rand(16);  token ← rand(16)   (QR mode only)
    qh     = Trunc32(H(ek_A))
    commit = Trunc32(H(lp("pqcble-r1 commit") ‖ nA))
B:  (ct, ss) ← XWing.Encaps(ek_A);  nB ← rand(16)
A:  ss ← XWing.Decaps(dk_A, ct)
    th = H(P1 ‖ P2 ‖ nA)                     # P1, P2 = complete reassembled frames
B:  on P3: check Trunc32(H(lp("pqcble-r1 commit") ‖ nA)) == commit, else abort
RK                        = KDF(ss, th, "rk", "", 32)
K_conf_A, K_conf_B        = KDF(RK, "", "conf A", "", 32), KDF(RK, "", "conf B", "", 32)
K_card_A, K_card_B        = KDF(RK, "", "card A", "", 32), KDF(RK, "", "card B", "", 32)
confirm_A = MAC(K_conf_A, "P3", th)
confirm_B = MAC(K_conf_B, "P4", th ‖ token)   # token = empty unless mode = QR
```

- Each side MUST verify the peer's AEAD and confirmation MAC and abort on failure.
- In QR mode, B MUST check `qh` against the scanned QR before sending P2.
- **Abort** means: erase all pairing state, persist nothing, and close the link.
- The pairing session times out 120 s after the QR is shown or the search starts, if P4 hasn't been verified (ADR 0009).

### 5.3 Verification codes

```
SAS  = Digits(H(lp("pqcble-r1 sas") ‖ th ‖ nB), 6)     # shown as "ddd ddd"
QRC  = Digits(H(lp("pqcble-r1 qrc") ‖ th ‖ nB), 4)
```

| Mode | Before the contact is stored |
|---|---|
| QR | Both phones show `QRC`; A's user confirms it (10^-4) |
| SAS | Both phones show `SAS`; both users confirm (2^-20) |
| TOFU | No comparison; the contact is stored as **Unverified** |

- A mismatch aborts pairing (ADR 0009).
- A later **Verify** of an Unverified contact recomputes `SAS` from the stored `th` and `nB` on both sides. A mismatch then marks the contact **Compromised**: sending to it is blocked until the contact is removed (ADR 0009).

### 5.4 Contact card

The card is AEAD-protected inside P3/P4. Its plaintext is:

```
caps(1) ‖ bk_day(u32) ‖ BK_day(32) ‖ name_len(1) ‖ name(≤48, UTF-8) ‖ [static_ek(1184) if caps.kci]     [OI-1, OI-12]
caps bits: 0 coc, 1 kci, 2–7 reserved (MUST be 0)
```

- `BK_day` is the sender's current device beacon key for day `bk_day` (§10.2).
- The KCI profile is chosen at pairing only. It is active iff both cards set `kci` and carry `static_ek`. Enabling it later requires re-pairing [OI-12].

### 5.5 Pairing output (persisted per contact)

```
pairID      = KDF(RK, "", "pairid", "", 16)
CK_0        = KDF(RK, "", "ck0", "", 32)
K_door_A→B  = KDF(RK, "", "door A", "", 32);  K_door_B→A = KDF(RK, "", "door B", "", 32)   [OI-10]
```

- The stored contact record also holds: pairing role, mode, verification state (Verified / Unverified / Compromised), `th` and `nB` (for a later Verify), the peer card, version, Resume index `n = 0`, and the peer's beacon key.
- `RK`, `ss`, `dk_A`, `nA`, `nB`-derived keys and `token` MUST be erased once the contact is persisted. `th` and `nB` are kept; neither is secret on its own.

## 6. Resume

`n` is the **Resume index** of the chain key `CK_n` (distinct from the PQ **epoch**; see [OI-13]).

```
ctx(n)    = pairID ‖ u64(n)
K_id      = KDF(CK_n, "", "id",     ctx(n), 32)
K_auth_I  = KDF(CK_n, "", "auth I", ctx(n), 32)
K_auth_R  = KDF(CK_n, "", "auth R", ctx(n), 32)
pseudonym = Trunc8(HMAC(K_id, lp("pqcble-r1 pseudonym") ‖ u8(attempt)))    attempt = min(tries, 3)  [OI-8]

S1  I→R : hdr ‖ pseudonym(8) ‖ eI(32) ‖ mac(16)              57 B
          mac = MAC(K_auth_I, "S1", hdr ‖ pseudonym ‖ eI)
S2  R→I : hdr ‖ eR(32) ‖ confirm(16)                         49 B
          th_s    = H(S1 ‖ eR)
          confirm = MAC(K_auth_R, "S2", hdr ‖ th_s)
dh        = X25519(e, E_peer)
prk       = HKDF-Extract(CK_n, dh ‖ pq)                      # pq per §9 if S1.MIX = 1, else empty [OI-4]
SK_I→R    = HKDF-Expand(prk, lp("pqcble-r1 sk I") ‖ ctx(n) ‖ th_s, 32)
SK_R→I    = HKDF-Expand(prk, lp("pqcble-r1 sk R") ‖ ctx(n) ‖ th_s, 32)
CK_{n+1}  = HKDF-Expand(prk, lp("pqcble-r1 ratchet") ‖ ctx(n) ‖ th_s, 32)
MS_{n+1}  = HKDF-Expand(prk, lp("pqcble-r1 msg seed") ‖ ctx(n) ‖ th_s, 32)    (§8)
```

**R's processing order:**
1. Look up the pseudonym in a table of `{CK_n, CK_{n+1}} × attempt 0–3` for every contact. On a miss, close the link.
2. Verify `mac` before any asymmetric operation; on failure, close the link.
3. Apply rate limits per pseudonym, per remote address and globally (threat model §5).
4. Only then generate `eR`, compute `dh`, and send S2.

**Key commitment and desync:**
- I commits `CK_{n+1}` (erasing `CK_n`) after a valid S2.
- R keeps both `CK_n` and `CK_{n+1}` until the first DATA frame from I that opens correctly under `SK_I→R`. That frame is I's key confirmation. R then erases `CK_n`.
- Ephemeral secrets are erased after `dh`.
- No data is sent before S2. There is no 0-RTT.

**KCI profile** (sub bit 0 = 1; both contacts MUST have exchanged static ML-KEM-768 keys) [OI-12]:
- S1 appends `ct_R = MLKEM.Encaps(static_ek_R)` before `mac`, and S2 appends `ct_I = MLKEM.Encaps(static_ek_I)` before `confirm`.
- `pq` gains `ss_R ‖ ss_I`, and `confirm` is keyed with `KDF(K_auth_R, ss_R, "auth R kci", "", 32)`.
- I's first DATA frame proves it knows `ss_I`.
- Sizes: S1 1145 B, S2 1137 B.

## 7. DATA frames

### 7.1 Frame

```
DATA = hdr ‖ Seal(SK_dir, nonce, hdr, plaintext) ‖ tag(16)
nonce = u8(dir << 7) ‖ 0x00 0x00 0x00 ‖ u64(ctr)      dir: 0 = I→R, 1 = R→I; ctr starts at 0 per SK
```

- `ctr` MUST strictly increase. A sender MUST close the session before `ctr` reaches 2^32.
- A receiver MUST close the link on the first failed `Open` (fail closed).
- Session keys are never persisted, and `ctr` is never restored.

### 7.2 Plaintext and padding

- The plaintext is a sequence of records `type(1) ‖ LEB128(len) ‖ body`. A `0x00` type byte ends the records, and every remaining byte MUST be zero; a receiver checks this in constant time over the padding length.
- The plaintext length MUST be the smallest bucket in {32, 64, 128, 256, 512, 1024, 2048, 4079} that fits. 4079 = 4096 − 17.
- Pending ratchet chunks (§9) MUST fill the slack before padding is added.

### 7.3 Records

| Type | Name | Body |
|---|---|---|
| `01` | CHAT | `LEB128(msgno) ‖ UTF-8 text` |
| `02` | QUEUED | `gen(1) ‖ LEB128(idx) ‖ Seal(mk_idx, 0^12, gen ‖ idx, LEB128(msgno) ‖ text) ‖ tag` [OI-6] |
| `03` | ACK | `LEB128(msgno)`: highest contiguous message number received |
| `04` | READ | `LEB128(msgno)`: read up to and including this number |
| `05` | EXPIRED | `LEB128(from) ‖ LEB128(to)`: inclusive range the sender expired |
| `06` | KEM_EK | `epoch(1) ‖ LEB128(offset) ‖ chunk` |
| `07` | KEM_CT | `epoch(1) ‖ LEB128(offset) ‖ chunk` |
| `08` | CAPS | `caps(1)`: as §5.4 |
| `09` | CLOSE | `reason(1)`: 0 normal, 1 protocol error, 2 limit, 3 user [OI-14] |
| `0A` | BEACON_KEY | `day(u32) ‖ BK_day(32)` (§10.2) [OI-3] |
| `0B` | BEACON_ACK | `day(u32)` [OI-3] |
| `0C` | EPOCH_DONE | `epoch(1)` (§9, *provisional*) [OI-4] |

- Unknown record types MUST close the link.
- A record whose length runs past the plaintext end MUST close the link.
- Record parsing runs only on authenticated plaintext.

## 8. Store-and-forward (ADR 0002)

- **Message numbers.** One `msgno` space per direction, starting at 1 and shared by CHAT and QUEUED. Number 0 is reserved (an ACK of 0 means nothing received).
- **Message-key chains.** At each Resume, both directions' chains are reseeded from `MS_{n+1}`:
  ```
  gen       = (n + 1) mod 256                                    [OI-5]
  MC_dir,0  = KDF(MS_{n+1}, "", "chain " ‖ dir, "", 32)          dir ∈ {"I","R"} of that Resume
  mk_i      = KDF(MC_dir,i, "", "mk", "", 32);   MC_dir,i+1 = KDF(MC_dir,i, "", "next", "", 32)
  ```
  QUEUED carries the chain index `idx = i`; the `msgno` travels inside the ciphertext [OI-6].
- **Generation collision.** The receiver keeps a chain (and its skipped keys) only for generations with outstanding messages. If a new Resume would reuse a `gen` that still has outstanding messages, both sides treat that generation's undelivered messages as expired: the sender reports them with EXPIRED, and the receiver deletes the old chain [OI-5].
- **Sending.** Sealing advances the chain and erases `mk_i` and `MC_i`. The sealed message and the advanced chain MUST be persisted in one transaction before the UI shows "sent" (ADR 0006).
- **Delivery.**
  - A real-time CHAT that is unacked when the link drops is re-sealed as QUEUED under the same `msgno`.
  - After each Resume the sender resends every unacked QUEUED message, and the receiver drops duplicates.
- **Bounds.**
  - At most 500 queued messages per contact, each kept at most 7 days. A full queue blocks sending.
  - An expired message is announced with EXPIRED.
  - Skipped keys: at most 500, each kept at most 7 days. They are deleted on EXPIRED.
- **Receipts.** Delivery is reported by ACK. READ is sent only if the global, reciprocal read-receipt setting is on (the default).

## 9. Post-quantum ratchet

Status: **provisional; gated by the model in *Formal model: PQ ratchet mixing*** [OI-4].

- An epoch `e` (`u8`, wrapping) transfers one ML-KEM-768 `ek` from its generator to the encapsulator in KEM_EK chunks, and one `ct` back in KEM_CT chunks. Offsets allow a transfer to continue in a later session.
- The generator of epoch `e` is pairing role A when `e` is even and role B when `e` is odd [OI-4].
- **Completion.**
  - The encapsulator holds `ss_e` once it has encapsulated.
  - The generator holds `ss_e` once it has received the whole `ct` and decapsulated it. It then sends EPOCH_DONE(`e`).
- **Mixing.**
  - I sets S1.MIX = 1 when it holds `ss_e` and, if I is the encapsulator, has received EPOCH_DONE(`e`).
  - With MIX = 1, `pq = ss_e ‖ H(ek_e) ‖ H(ct_e)` enters the Resume KDF (§6). If R does not hold `ss_e`, R closes the link and I retries with MIX = 0.
  - After a Resume that mixed epoch `e`, both sides erase `dk_e`, `ss_e` and the transfer buffers, and epoch `e + 1` may start.
- **Cadence:** a new epoch starts when none is in flight and ≥ 10 Resumes or ≥ 24 h have passed since the last completed epoch [OI-11]. Idle contacts Resume when ≥ 6 h have passed or an epoch is due (ADR 0008).

## 10. Beacons and doorbell

### 10.1 Beacon

```
w      = floor(unix_time / 300)
beacon = Trunc8(HMAC(BK_d, lp("pqcble-r1 beacon") ‖ u64(w)))      # no role [OI-2]
BK_d+1 = KDF(BK_d, "", "beacon day", "", 32)                       d = floor(unix_time / 86400)
```

- **Receivers** keep, for every contact, the beacons of windows `{w−1, w, w+1}` in a constant-time lookup structure.
- **Advertisers** stop and restart the advertising set at every window boundary plus 0–30 s of random jitter.
- **Android** advertises legacy PDUs: flags + service data (128-bit service UUID ‖ beacon), 29 of 31 B.
- **iOS** advertises in the foreground the fixed UUID plus a beacon UUID `Trunc16(HMAC(BK_d, lp("pqcble-r1 beacon uuid") ‖ u64(w)))` [OI-9]. In the background it advertises the fixed UUID only.

### 10.2 Device beacon key

- One device beacon key is created at install. It is shared with every contact in the pairing card [OI-1] and rotated to a fresh random key, with **no overlap**, when a contact is removed.
- The remaining contacts receive the new key in a BEACON_KEY record in every session until they answer with a matching BEACON_ACK [OI-3].

### 10.3 Doorbell (Android advertisers only)

```
door = Trunc8(HMAC(K_door_me→peer, lp("pqcble-r1 door") ‖ u64(w)))
```

- The doorbell replaces the beacon in the same service-data slot. It carries no payload.
- An advertiser with pending queued messages rotates once per second, round-robin over its beacon and up to 8 doorbells.
- On a match, the receiver connects and Resumes. A replay within the window costs at most one wasted connection.

### 10.4 Connect policy (ADR 0008)

- Connect to an unknown or beaconless peer only if there is something to send, or a contact has not been seen for 10 min.
- At most one attempt per address per 2 min. After 3 non-matching `beacon` reads, back off that address for 1 h.

## 11. Implementation requirements

- **Constant time.** All operations on secrets MUST be constant-time, including:
  - KEM operations, MAC/AEAD verification, and SAS/QRC derivation;
  - pseudonym, beacon and doorbell table lookups;
  - padding checks.

  CI enforces this per ADR 0007.
- **Hygiene.** Secrets MUST be held in zeroize-on-drop types and MUST NOT cross the FFI, apart from the sealed persistence blob (ADR 0004).
- **Storage.** Persisted state MUST be excluded from backups. Restoring old state is out of scope, but a device that detects a non-monotonic `n` MUST require re-pairing (ADR 0006).
- **Errors.** Any protocol error closes the link without a response, so there is no error oracle. CLOSE is sent only for orderly shutdown.

## 12. Constants and test vectors

- GATT service and characteristic UUIDs: **TBD** in *Slice S0: Bootstrap* (random v4, recorded here).
- Test vectors (pairing, Resume, DATA, QUEUED, beacon, doorbell, SAS/QRC): **pending**. They are generated from the reference adapter and cross-checked with the `aws-lc-rs` adapter during the implementation slices. Pinning them belongs to the spec freeze.

## 13. Consolidation issues (resolved 2026-10-05)

The user accepted every proposal. OI-4 is accepted as *provisional*, pending *Formal model: PQ ratchet mixing*. The affected ADRs carry amendment notes.

| # | Issue | Resolution |
|---|---|---|
| OI-1 | ADR 0005 shares the device beacon key at pairing, but the draft's 64 B card has no room for it, so the P3/P4 sizes are wrong | Card carries `day(u32) ‖ BK_d(32)`: +36 B. With a 48 B name, P3 ≤ 135 B and P4 ≤ 119 B (the draft's 113/97 B assumed an illustrative 64 B card) |
| OI-2 | The beacon formula has `role ‖ window`, but a device-wide key has no pairing role | Drop `role`; use the label `"beacon"` |
| OI-3 | ADR 0008 sends the rotated beacon key "in a record at the next Resume", but there's no record type | New records `0A BEACON_KEY: day(u32) ‖ BK_d(32)` and `0B BEACON_ACK: day(u32)`. The sender includes BEACON_KEY in every session until the matching BEACON_ACK arrives |
| OI-4 | The ratchet doesn't say who generates `ek`, or how both sides agree that an epoch completed before mixing it at Resume (a lost last chunk or ack desyncs `CK`) | Alternate the generator by epoch parity. The generator sends `0C EPOCH_DONE(epoch)` after decapsulating. I sets S1 sub bit 1 = "mix pending epoch"; R mixes only if it has `ss_e`, else the Resume fails and I retries without the bit. Settle in the ratchet model |
| OI-5 | The 1 B chain generation wraps after 256 Resumes, which can happen within the 7-day queue lifetime | Receiver keeps chains only for generations with outstanding skipped keys. A collision expires the older generation's messages (EXPIRED); alternatively use LEB128 `gen` (+1 B after 127) |
| OI-6 | QUEUED carries the global `msgno`, but the receiver needs the chain index within its generation | Body becomes `gen(1) ‖ LEB128(idx) ‖ Seal(mk_idx, …, msgno ‖ text)`; `msgno` moves inside the ciphertext, which also hides it at the session layer. Same size |
| OI-7 | The draft's `ctx = "pqcble-r1" ‖ pairID ‖ epoch` is used for pairing too, but `pairID` comes from `RK`, which is circular | Pairing KDFs use only the label and `th` (as §5.2); `ctx(n)` applies from Resume on |
| OI-8 | Behaviour after attempt 3 without a valid S2 is undefined | Further attempts reuse attempt 3, so retries are linkable for one `CK_n`; accept, and back off per ADR 0008 |
| OI-9 | ADR 0003 calls the iOS beacon a "rotating 128-bit UUID" without a derivation | As §10.1. Receivers match on the first 8 B; iOS foreground only |
| OI-10 | `K_door_pair` is never derived | Two directional keys from `RK` (§5.5). They are static for the contact's lifetime, so they are not healed by the ratchet; acceptable for a hint without payload |
| OI-11 | The PQ epoch cadence ("every N sessions or T hours") was never decided | Start an epoch when none is in flight and ≥ 10 Resumes or ≥ 24 h have passed since the last completed epoch (user's choice) |
| OI-12 | The KCI profile is "opt-in per contact" but static keys travel only in the pairing card; enabling it later and the `confirm` keying are undefined | r1: choose KCI only at pairing (re-pair to enable); both cards MUST carry `static_ek`; keying as §6 |
| OI-13 | The draft's `ctx` calls the Resume counter "epoch", which clashes with the glossary (Epoch = PQ ratchet period) | Call it the **Resume index** `n` and add it to the glossary |
| OI-14 | CLOSE reason codes are undefined | As §7.3 |
| OI-15 | QR-mode authentication of B relies on `token`, but the draft's `confirm_B` places it differently (`"qr" ‖ token ‖ th`) | Equivalent; use §5.2 (`th ‖ token`) |

## 14. Change log

- 0.2 (2026-10-05): consolidation issues OI-1 to OI-15 resolved and applied.
- 0.1 (2026-10-05): first consolidation of ADRs 0001–0009, the wire-format draft and the threat model.
  - Clarifications that don't change any byte: the labelled KDF/MAC framing, domain-separated `commit`, and AAD = `hdr ‖ th` for P3/P4.
