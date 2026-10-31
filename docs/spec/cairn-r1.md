# `cairn-r1` protocol specification

Status: **draft 0.24** (accepted OI-42 to OI-44; 2026-10-31). It is not frozen: the remaining formal model (*Formal model: PQ ratchet mixing*) may change §6, §7 and §9, and test vectors are pending (§12). §5, all four profiles of §6 and §8.1 are backed by verified [models](models/README.md), including Resume re-verification with public `pairID`. The composed ratchet implementation gate remains closed; [ADR 0016](../adr/0016-unexposed-epoch-transfer-core.md) waives it only for an unexposed Rust implementation of §9's epoch identifiers and object transfer.

This document consolidates, and is normative over:
- [ADR 0001](../adr/0001-crypto-suite.md) to [ADR 0009](../adr/0009-pairing-ux.md), as amended by [ADR 0021](../adr/0021-automatic-neighbour-admission.md), [ADR 0025](../adr/0025-android-gatt-slot-budget.md), [ADR 0027](../adr/0027-android-energy-bands.md), [ADR 0028](../adr/0028-android-extended-advertising.md), [ADR 0030](../adr/0030-android-eviction-interval.md), [ADR 0031](../adr/0031-android-stable-slots.md), [ADR 0033](../adr/0033-courier-relaying.md), [ADR 0034](../adr/0034-store-and-forward-core.md), [ADR 0035](../adr/0035-sealed-row-storage.md), [ADR 0037](../adr/0037-ios-ble-adapter.md), [ADR 0038](../adr/0038-android-extended-advert-2m-secondary.md), [ADR 0039](../adr/0039-android-waits-for-ios-to-dial.md), [ADR 0040](../adr/0040-redial-after-supervision-timeout.md), [ADR 0042](../adr/0042-fragment-check.md) and [ADR 0043](../adr/0043-provisional-contact.md);
- the [wire-format draft](../research/2026-10-05-wire-format-draft.md);
- the [threat model](threat-model.md).

Consolidation found 15 inconsistencies and gaps between the sources, and the formal models found more. They are resolved and recorded in §13; the affected ADRs are amended. **[OI-n]** marks text that follows resolution *n*. Items marked *provisional* remain subject to the formal models.

The key words MUST, MUST NOT, SHOULD, SHOULD NOT and MAY are to be interpreted as described in RFC 2119 and RFC 8174 when, and only when, they appear in capitals.

Vocabulary follows [`GLOSSARY.md`](../../GLOSSARY.md).

## 1. Overview

Two **peers** run **pairing** once (§5), automatically on first discovery, and become **contacts** (neighbours). Every BLE connection between contacts starts with a **Resume** (§6), which derives the **session** keys. Data frames (§7) then carry real-time messages, **queued messages** (§8), receipts and the chunks of the post-quantum ratchet (§9). Contacts find each other through **beacons** (§10) and may ring each other with a **doorbell** (§10.3). The BLE transport is specified in §4.

```
Pairing (once)                Resume (each connection)         Data
X-Wing + auto TOFU   ──RK──►  CK_n + X25519, 57 B / 49 B ──SK──► AES-256-GCM, 17 B
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
  KDF(ikm, salt, label, info, L) = HKDF-Expand(HKDF-Extract(salt, ikm), lp("cairn-r1 " ‖ label) ‖ info, L)
  ```
  An empty salt is 48 zero bytes.
- **Labelled MAC.** `MAC(k, label, x) = Trunc16(HMAC(k, lp("cairn-r1 " ‖ label) ‖ x))`.
- `Digits(x, d) = (u64(x[..8]) mod 10^d)`, rendered with leading zeros. The modulo bias is below 2^-44 and is ignored.
- All comparisons of MACs, tags, pseudonyms against secret-derived tables, beacons and SAS inputs MUST be constant-time (§11).

### 2.3 Roles

- **Pairing role A** sends P1. **Pairing role B** sends P0 and P2. The role is fixed per contact and stored.
- On an admission link the GATT central is B and the peripheral is A (§5.6). This supersedes the user-pick rule of OI-20 [OI-27].
- **I** (initiator) and **R** (responder) are Resume roles: I is the GATT central of the connection.

## 3. Versioning

- The protocol version is `0x01` for `cairn-r1`.
- It appears explicitly only in P1. Elsewhere it is implied by the GATT service UUID (§4.1) and by the `"cairn-r1 "` prefix of every KDF and MAC label.
- A peer MUST abort pairing when P1's version differs from its own. There is no negotiation and no downgrade.
- Each contact stores the version it paired under. Any change to a layout, label or primitive requires a new version, a new service UUID and re-pairing (ADR 0005).

## 4. Transport (ADR 0003)

### 4.1 GATT service

The peripheral is the GATT server. UUIDs are vendor 128-bit values, fixed for r1, and are listed in §12.

| Characteristic | Properties | Content |
|---|---|---|
| `beacon` | read | The current 8 B beacon (§10.1) |
| `rx` | write | Central → peripheral fragments, written with response (§4.3) [OI-43] |
| `tx` | notify | Peripheral → central fragments |
| `psm` | read | `u16` L2CAP PSM. The server MUST return an ATT error unless a Resume has completed on this connection |

### 4.2 Frame header

Every frame and every fragment begins with one header byte:

```
bit 7     MORE   1 = more fragments of this frame follow (GATT only; 0 on L2CAP CoC)
bits 6–4  type   0 PAIR   1 S1   2 S2   3 DATA   4–7 reserved
bits 3–0  sub    PAIR: step 0–4 [OI-27], 5 = BUSY [OI-29];  S1/S2: bit 0 = KCI; S1 bit 1 = MIX (*provisional*, §9) [OI-4]; other bits 0;  DATA: 0
```

A receiver MUST close the link without sending anything when it sees:
- a reserved type;
- a sub value not allowed for the type;
- a frame type not allowed in the current state.

### 4.3 Fragmentation

- One ATT value carries one fragment: `header ‖ body ‖ check`, with up to `min(ATT_MTU − 6, 509)` body bytes. The limit keeps every value within ATT's 512-byte attribute value limit (Core Vol 3 Part F §3.2.9); stacks drop longer notifications even when `ATT_MTU` is 517 [OI-43].
- `check` (2 B, big-endian) is CRC-16/CCITT-FALSE (polynomial `0x1021`, initial value `0xFFFF`, no reflection, no final XOR) over the header and the body; the check of the ASCII string `123456789` is `0x29B1`. It detects radio corruption and is not a MAC. A receiver MUST verify and remove it before reassembly; a value shorter than 3 B, or whose check fails, closes the link [OI-43].
- A GATT server that receives a write request to `rx` whose check fails MUST answer it with ATT error `0x9E` and drop it. A central whose write fails with `0x9E` MUST write the same value again, up to 3 times for one fragment; a fourth failure closes the link. A write without response, or a notification, whose check fails closes the link [OI-43].
- The fragments of a frame are sent back to back. Every fragment repeats the header, with MORE set on all but the last.
- Fragments from different frames in the same direction MUST NOT interleave.
- Reassembly concatenates the bodies. The reassembled frame is the header with MORE cleared, followed by the bodies.
- A fragment whose header differs from the first fragment's header in anything but MORE MUST close the link.

On L2CAP CoC, one SDU is exactly one frame with MORE = 0, and carries no check.

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

If two contacts hold two links, the link where pairing role A is the central survives. Neither side can tell that a link is a duplicate until it has matched a pseudonym, so the losing link is closed at S1 by the concurrent-Resume rule in §6 [OI-17].

## 5. Pairing

Pairing is automatic: a device admits every stranger it discovers as a **neighbour**, within the admission limits of §5.6 and without user action ([ADR 0021](../adr/0021-automatic-neighbour-admission.md)) [OI-27]. It is the one place where an asymmetric operation may run before authentication.

### 5.1 Messages

| Msg | Dir | Body after `hdr` | Size |
|---|---|---|---:|
| P0 | B→A | `r(16)` | 17 |
| P1 | A→B | `ver(1) ‖ mode(1) ‖ commit(32) ‖ ek_A(1216)` | 1251 |
| P2 | B→A | `ct(1120) ‖ nB(16)` | 1137 |
| P3 | A→B | `nA(16) ‖ Seal(K_card_A, 0^12, hdr ‖ th, confirm_A(16) ‖ card_A)` | ≤ 135 |
| P4 | B→A | `Seal(K_card_B, 0^12, hdr ‖ th, confirm_B(16) ‖ card_B)` | ≤ 119 |
| BUSY | A→B | — | 1 |

- P0 is B's admission request (§5.6); `r = rand(16)` is used only for the tie-break. P0 is not part of `th`.
- BUSY is A's refusal of a P0 (§5.6) [OI-29]. It is not part of `th`.
- `mode` MUST be `0x03` TOFU. B MUST abort on any other value [OI-19, OI-27]. The values `0x01` (QR) and `0x02` (SAS) are retired and abort.
- The sizes are maxima for a card with a 48 B name and no KCI key (86 B plaintext, §5.4) [OI-1]. With the default empty name, P3 ≤ 87 B and P4 ≤ 71 B. A KCI card adds 1184 B.

### 5.2 Computation

```
A:  (ek_A, dk_A) ← XWing.KeyGen();  nA ← rand(16)
    commit = Trunc32(H(lp("cairn-r1 commit") ‖ nA))
B:  (ct, ss) ← XWing.Encaps(ek_A);  nB ← rand(16)
A:  ss ← XWing.Decaps(dk_A, ct)
    th = H(P1 ‖ P2 ‖ nA)                     # P1, P2 = complete reassembled frames
B:  on P3: check Trunc32(H(lp("cairn-r1 commit") ‖ nA)) == commit, else abort
RK                        = KDF(ss, th, "rk", "", 32)
K_conf_A, K_conf_B        = KDF(RK, "", "conf A", "", 32), KDF(RK, "", "conf B", "", 32)
K_card_A, K_card_B        = KDF(RK, "", "card A", "", 32), KDF(RK, "", "card B", "", 32)
confirm_A = MAC(K_conf_A, "P3", th)
confirm_B = MAC(K_conf_B, "P4", th)           # the retired QR mode appended token here [OI-27]
```

- Each side MUST verify the peer's AEAD and confirmation MAC and abort on failure.
- **Abort** means: erase all pairing state, persist nothing, and close the link.
- Pairing MUST complete within the 5 s link limit of §4.4.

### 5.3 Verification codes

```
SAS  = Digits(H(lp("cairn-r1 sas") ‖ th ‖ nB), 6)     # shown as "ddd ddd"
```

- Every neighbour is stored as **Unverified**; there is no comparison at pairing [OI-27].
- A later **Verify** of an Unverified contact recomputes `SAS` from the stored `th` and `nB` on both sides. A mismatch then marks the contact **Compromised**: sending to it is blocked until the contact is removed (ADR 0009).

### 5.4 Contact card

The card is AEAD-protected inside P3/P4. Its plaintext is:

```
caps(1) ‖ bk_day(u32) ‖ BK_day(32) ‖ name_len(1) ‖ name(≤48, UTF-8) ‖ [static_ek(1184) if caps.kci]     [OI-1, OI-12]
caps bits: 0 coc, 1 kci, 2–7 reserved (MUST be 0)
```

- `BK_day` is the sender's current device beacon key for day `bk_day` (§10.2).
- `name_len` is 0 by default. A non-empty name is sent only if the user opted in to sharing a display name with new neighbours (ADR 0021).
- The KCI profile is chosen at pairing only. It is active iff both cards set `kci` and carry `static_ek`. Enabling it later requires re-pairing [OI-12].

### 5.5 Pairing output (persisted per contact)

```
pairID      = KDF(RK, "", "pairid", "", 16)
CK_0        = KDF(RK, "", "ck0", "", 32)
K_door_A→B  = KDF(RK, "", "door A", "", 32);  K_door_B→A = KDF(RK, "", "door B", "", 32)   [OI-10]
K_route     = KDF(RK, "", "route", "", 32)                                              [OI-37]
```

- The stored contact record also holds: pairing role, mode, verification state (Verified / Unverified / Compromised), `th` and `nB` (for a later Verify), the peer card, version, Resume index `n = 0`, and the peer's beacon key.
- `RK`, `ss`, `dk_A`, `nA` and `nB`-derived keys MUST be erased once the contact is persisted. `th` and `nB` are kept; neither is secret on its own.
- **Provisional contact** [OI-44]. B continues on the same link with a Resume as I (§6). Until that link carries a valid Resume message from the peer, the new contact is provisional:
  - B commits it at a valid S2, before its first DATA frame;
  - A commits it at a valid S1, before S2.
  - A provisional contact MUST NOT be persisted, reported or resumed on another link. A beacon hit or S1 for it on another link closes that link as a duplicate.
  - If the pairing link closes first, the device MUST forget the contact.

### 5.6 Admission [OI-27]

- **Stranger.** A peer whose advertised beacon matches no contact and whose `beacon` read (§4.1) also matches none.
- **Roles.** On an admission link the GATT central is pairing role B and the peripheral is pairing role A.
- **Request.** After a non-matching `beacon` read, B MAY send P0 on the same link if the limits below allow. A answers with P1 only if the limits allow; otherwise it answers BUSY.
- **One pairing in flight.** A device MUST have at most one pairing in flight, as A or B. While it has one, it MUST NOT send P0 and MUST answer BUSY to any further link that sends P0.
- **Tie-break.** If a device receives P0 while its own P0 is unanswered, it compares the two `r` values as unsigned big-endian integers:
  - incoming `r` larger: close its own outgoing link and answer the incoming P0;
  - incoming `r` smaller: answer BUSY on the incoming link;
  - equal: close its own outgoing link and answer BUSY on the incoming link.
- **Limits** (per device, both roles):
  - at most 10 neighbours admitted per rolling hour;
  - at most 30 pairing attempts started or answered per rolling hour;
  - at most 256 neighbours in total; at the cap, admission stops and nothing is evicted;
  - an address whose attempt failed is not tried again for a while [OI-30]:
    - after a **transport failure** (the link dropped, or the §4.4 deadline passed, with the pairing in flight): 2 min after the first, doubling with each further one (4, 8, 16, 32 min) up to 1 h. A link drop with no earlier failure recorded for the address is forgiven: it backs nothing off, and the next transport failure is the first [OI-42];
    - after a **protocol failure** (a malformed, unexpected or invalid frame or value): 1 h;
    - an address's failures, including a forgiven drop, are forgotten 1 h after its back-off ends, or when a pairing with it completes;
    - a P0 that the limits refuse is not a failed attempt and doesn't extend a back-off (§10.4).
- **BUSY** [OI-29]. A refusal of a P0 is a BUSY frame, so that B learns of it at once rather than at the §4.4 deadline. Android cannot drop a link that the remote central opened, so A cannot signal a refusal by closing.
  - A sends BUSY, then waits for B to close the link and closes it itself at the §4.4 deadline. Any further frame on that link closes it. The refused link is not a pairing in flight.
  - B, on a BUSY in reply to its P0, closes the link. A refusal ran no X-Wing operation, so it is not a failed attempt: B neither backs off the address nor counts the attempt against the 30 per hour. B may dial the address again under §10.4.
  - A BUSY with a body, or in any other state, is a malformed frame (§4.2).
  - BUSY is unauthenticated, like P0. An attacker who forges one can at most delay a pairing, as by dropping frames.

## 6. Resume

`n` is the **Resume index** of the chain key `CK_n` (distinct from the PQ **epoch**; see [OI-13]).

```
ctx(n)    = pairID ‖ u64(n)
K_id      = KDF(CK_n, "", "id " ‖ ρ_I,     ctx(n), 32)          # ρ_I = I's pairing role, "A" or "B" [OI-16]
K_auth_I  = KDF(CK_n, "", "auth I " ‖ ρ_I, ctx(n), 32)
K_auth_R  = KDF(CK_n, "", "auth R", ctx(n), 32)
pseudonym = Trunc8(HMAC(K_id, lp("cairn-r1 pseudonym") ‖ u8(attempt)))    attempt = min(tries, 3)  [OI-8]

S1  I→R : hdr ‖ pseudonym(8) ‖ eI(32) ‖ mac(16)              57 B
          mac = MAC(K_auth_I, "S1", hdr ‖ pseudonym ‖ eI)
S2  R→I : hdr ‖ eR(32) ‖ confirm(16)                         49 B
          th_s    = H(S1 ‖ eR)
          confirm = MAC(K_auth_R, "S2", hdr ‖ th_s)
dh        = X25519(e, E_peer)
prk       = HKDF-Extract(CK_n, dh ‖ pq)                      # pq per §9 if S1.MIX = 1, else empty [OI-4]
SK_I→R    = HKDF-Expand(prk, lp("cairn-r1 sk I") ‖ ctx(n) ‖ th_s, 32)
SK_R→I    = HKDF-Expand(prk, lp("cairn-r1 sk R") ‖ ctx(n) ‖ th_s, 32)
CK_{n+1}  = HKDF-Expand(prk, lp("cairn-r1 ratchet") ‖ ctx(n) ‖ th_s, 32)
MS_{n+1}  = HKDF-Expand(prk, lp("cairn-r1 msg seed") ‖ ctx(n) ‖ th_s, 32)    (§8)
```

**R's processing order:**
1. Look up the pseudonym in a table of `{CK_n, CK_{n+1}} × attempt 0–3` for every contact, computed with the **contact's** pairing role as `ρ_I`. On a miss, close the link. A device therefore never matches its own S1 [OI-16].
2. Verify `mac` before any asymmetric operation; on failure, close the link.
3. Apply rate limits per pseudonym, per remote address and globally (threat model §5).
4. Only then generate `eR`, compute `dh`, and send S2.

**Concurrent Resume** [OI-17]:
- A device MUST have at most one Resume per contact in flight, and MUST commit a new `CK` for a contact atomically.
- If a device receives a valid S1 from a contact while its own S1 to that contact is outstanding, the attempt whose I is pairing role A wins:
  - pairing role A closes the incoming link without answering;
  - pairing role B aborts its own attempt (erasing `eI`, keeping `CK_n`) and answers the incoming S1.

**Key commitment and desync:**
- I commits `CK_{n+1}` (erasing `CK_n`) after a valid S2.
- R keeps both `CK_n` and `CK_{n+1}` until the first DATA frame from I that opens correctly under `SK_I→R`. That frame is I's key confirmation. R then erases `CK_n`.
- Each stored CK candidate MUST carry its post-mix epoch position. The candidate `CK_{n+1}` records any epoch incorporated into it even before DATA confirms it. A recovery Resume on that candidate MUST NOT mix the same epoch again [OI-23].
- Ephemeral secrets are erased after `dh`.
- No data is sent before S2. There is no 0-RTT.

**KCI profile** (sub bit 0 = 1; both contacts MUST have exchanged static ML-KEM-768 keys) [OI-12]:
- S1 appends `ct_R = MLKEM.Encaps(static_ek_R)` before `mac`, and S2 appends `ct_I = MLKEM.Encaps(static_ek_I)` before `confirm`.
- `th_s = H(S1 ‖ eR ‖ ct_I)`, so `confirm` and every derived key cover `ct_I` [OI-18].
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
| `02` | QUEUED | `gen(1) ‖ LEB128(idx) ‖ Seal(mk_idx, 0^12, gen ‖ idx, inner) ‖ tag` (§8) [OI-6, OI-37] |
| `03` | ACK | `LEB128(msgno)`: highest contiguous message number received |
| `04` | READ | `LEB128(msgno)`: read up to and including this number |
| `05` | EXPIRED | `LEB128(from) ‖ LEB128(to)`: inclusive range the sender expired |
| `06` | KEM_EK | `LEB128(epoch) ‖ LEB128(offset) ‖ chunk` [OI-21] |
| `07` | KEM_CT | `LEB128(epoch) ‖ LEB128(offset) ‖ chunk` [OI-21] |
| `08` | CAPS | `caps(1)`: as §5.4 |
| `09` | CLOSE | `reason(1)`: 0 normal, 1 protocol error, 2 limit, 3 user [OI-14] |
| `0A` | BEACON_KEY | `day(u32) ‖ BK_day(32)` (§10.2) [OI-3] |
| `0B` | BEACON_ACK | `day(u32)` [OI-3] |
| `0C` | EPOCH_DONE | `LEB128(epoch)` (§9, *provisional*) [OI-4, OI-21] |
| `0D` | KEM_PROGRESS | `LEB128(epoch) ‖ kind(1) ‖ LEB128(next_offset)` (§9, *provisional*); kind `01` = EK, `02` = CT [OI-25] |
| `0E` | INVENTORY | `n × Trunc8(tag)`, `n ≥ 0`; an empty body ends the inventory (§8.1) [OI-37] |
| `0F` | FETCH | `tag(16)` (§8.1) [OI-37] |
| `10` | ENVELOPE | `ENV` (§8.1) [OI-37] |
| `11` | CUSTODY | `tag(16) ‖ code(1)`: 0 accepted, 1 full, 2 duplicate, 3 courier off, 4 invalid (§8.1) [OI-37] |
| `12` | TOMB | `tag(16) ‖ s(16)` (§8.1) [OI-37] |

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
- **Reseeding.** I reseeds both chains when it commits `CK_{n+1}`. R reseeds them when I's first DATA frame confirms the session (§6); until then R seals under its previous chain [OI-38]. A contact that has never completed a Resume has no chain, and nothing can be queued for it.
- **Generation retention.** The receiver keeps a superseded receive chain, and its skipped keys, for 7 days after the Resume that superseded it; any message sealed under it has expired by then [OI-38].
- **Generation collision.** If a new Resume would reuse a `gen` that still has outstanding messages, both sides treat that generation's undelivered messages as expired: the sender reports them with EXPIRED, and the receiver deletes the old chain [OI-5].
- **Sending.** Sealing advances the chain and erases `mk_i` and `MC_i`. The sealed message and the advanced chain MUST be persisted in one transaction before the UI shows "sent" (ADR 0006).
- **Delivery.**
  - A real-time CHAT that is unacked when the link drops is re-sealed as QUEUED under the same `msgno`.
  - After each Resume the sender resends every unacked QUEUED message, and the receiver drops duplicates.
  - A sender persists the numbers of unacked real-time CHATs, but not their text. If it restarts before re-sealing them, it expires them and announces them with EXPIRED [OI-38].
- **Bounds.**
  - At most 500 queued messages per contact, each kept at most 7 days. A full queue blocks sending.
  - An expired message is announced with EXPIRED.
  - Skipped keys: at most 500, each kept at most 7 days. They are deleted when used, after 7 days, or on a generation collision. EXPIRED names `msgno`s, which the receiver cannot map to chain indices, so it does not delete skipped keys [OI-38].
- **Receipts.** Delivery is reported by ACK. An ACK counts expired numbers as received, and the receiver sends it in the next DATA frame after any CHAT, QUEUED or EXPIRED record [OI-38]. READ is sent only if the global, reciprocal read-receipt setting is on (the default).
- **Inner plaintext** [OI-37]. A queued message is sealed as
  ```
  inner = LEB128(msgno) ‖ LEB128(len(text)) ‖ text ‖ 0x00 …
  ```
  padded with zeros to the smallest bucket in {32, 64, 128, 256, 512, 1024, 2048, 4048} that fits. A receiver checks the padding is zero in constant time and rejects any other length. Only messages whose `inner` is at most 2048 B are given to couriers (§8.1).
- **Text limit.** A real-time CHAT may have to be re-sealed as QUEUED, so a sender rejects any text whose `inner` exceeds 4048 B, whether or not a session is up. That is at most 4045 B of text for `msgno` 1–127 and 4044 B for `msgno` 128–16383.

### 8.1 Couriers (ADR 0033) [OI-37]

A **courier** is a contact that carries **envelopes** of queued messages for other contacts. Couriers carry only messages between existing contacts.

- **Envelope.** When it seals a queued message, the sender also computes, before erasing `mk_idx`:
  ```
  tag  = MAC(K_route, "route", dir ‖ u8(gen) ‖ LEB128(idx))     dir ∈ {"I","R"} as for MC_dir
  s    = KDF(mk_idx, "", "delivered", "", 16)
  c    = Trunc16(H(lp("cairn-r1 delivered") ‖ s))
  ENV  = tag(16) ‖ c(16) ‖ u32(expiry) ‖ u8(copies) ‖ ct        ct = the QUEUED ciphertext and AEAD tag
  ```
  `expiry` is in Unix minutes. `ct` MUST be 16 B longer than an `inner` bucket of at most 2048 B; any other length is invalid. The sender keeps `s` until the message is delivered or expired. `expiry` and `copies` are not authenticated.
- **Configuration.** Each device has a copy budget `L` (default 6, 1–16) and an envelope lifetime `T` (default 24 h, 1 h – 7 d). Couriering is on by default; the user can turn it off.
- **Deposit.** A queued message with `inner` ≤ 2048 B becomes an **own envelope** with `copies = L` and `expiry = now + T`. A device holds at most 256 own envelopes; beyond that, new queued messages wait for direct delivery only. An own envelope that expires while its message is still queued gets a new `expiry` and `copies = L` once.
- **Holding.** A courier stores an accepted envelope with `copies = min(copies, L)` and `expiry = min(expiry, now + T)`, and deletes it at `expiry`. It holds at most 16 envelopes per depositing contact (32 if that contact is Verified), 256 envelopes and 1 MiB of `ENV` in total.
- **Recipient window.** For each contact, a device computes the tags of every index whose message key it could still derive: its skipped keys (§8) and the next unreceived indices of each live receive chain, at most 500 per contact. It looks tags up in constant time (§11) by the full 16 B tag and drops a tag as soon as its index is consumed.
- **Session exchange.** After every Resume, each side:
  1. Sends INVENTORY records listing `Trunc8(tag)` of every envelope it holds, own and carried (at most 512 entries), then an empty INVENTORY. Own envelopes are listed like carried ones, except those for this peer: their messages travel as QUEUED, and they are neither listed nor deposited with it.
  2. When the peer's inventory is complete:
     - sends FETCH for each entry matching its recipient window;
     - sends TOMB for each entry matching a stored tombstone;
     - for each envelope it holds with `copies > 1` whose `Trunc8(tag)` the peer did not list and that has no tombstone, sends ENVELOPE with `copies = ⌊copies / 2⌋`, unless the peer answered CUSTODY 3 in this session.
- **On FETCH**, a holder of that tag answers ENVELOPE unchanged. It ignores a FETCH for a tag it does not hold.
- **On ENVELOPE:**
  - If `tag` is in the recipient window, the device opens `ct` with `mk_idx` and AAD `u8(gen) ‖ LEB128(idx)`. On success it handles the message as a QUEUED record (duplicates by `msgno` are dropped), stores the tombstone and answers TOMB. On failure it does not consume `mk_idx`, closes the link with CLOSE 1, and does not fetch that tag from that peer again.
  - Otherwise it acts as a courier and answers CUSTODY: 3 if couriering is off; 4 if `ct` has an invalid length, `copies = 0` or `expiry ≤ now`; 2 if it holds the tag or a tombstone for it; 1 if a limit above would be exceeded; else 0, and it stores the envelope.
  - A courier never opens an envelope.
- **On CUSTODY 0**, the giver subtracts the copies it handed over. On any other code it keeps them. Custody passes only on CUSTODY 0, so a dropped link can duplicate an envelope but never lose it.
- **Tombstones.** A device stores a tombstone `tag ‖ s` only after checking `Trunc16(H(lp("cairn-r1 delivered") ‖ s)) == c` against an envelope it holds, or after creating it as recipient or sender. A holder that receives a valid TOMB deletes the envelope. A TOMB that fails the check closes the link with CLOSE 1; a TOMB for a tag the device does not hold is ignored. A sender that receives an ACK covering a message stores the tombstone of its own envelope for it and deletes the envelope. A device keeps at most 1024 tombstones, each until the envelope's `expiry` (or `now + T` if it never held one), and drops the earliest-expiring first when full.
- **EXPIRED.** A message the sender expires (§8) deletes its own envelope; carried copies expire on their own.

## 9. Post-quantum ratchet

Status: **provisional; gated by the model in *Formal model: PQ ratchet mixing*** [OI-4].

- An epoch `e` transfers one ML-KEM-768 `ek` from its generator to the encapsulator in KEM_EK chunks, and one `ct` back in KEM_CT chunks. Offsets allow a transfer to continue in a later session.
- **Identifiers** [OI-21]: `e` is a non-wrapping `u32`, starting at 0 and encoded as canonical unsigned LEB128 in KEM_EK, KEM_CT, EPOCH_DONE and KEM_PROGRESS. Epochs MUST advance by exactly one only after the previous epoch has been mixed; identifiers MUST NOT be skipped, reused or rolled back. After mixing epoch `2^32 - 1`, the contact MUST stop further Resumes, report `epoch_exhausted` locally and require re-pairing; it MUST NOT wrap to 0.
- The generator of epoch `e` is pairing role A when `e` is even and role B when `e` is odd [OI-4].
- **Durable transfer and progress** [OI-25]:
  - Object lengths are fixed: EK = 1184 B, CT = 1088 B. The sender MUST persist the epoch's immutable object and associated key state before sending its first chunk. It MUST NOT regenerate an object when retransmitting it.
  - The receiver maintains one contiguous prefix per epoch/object kind. It MUST persist appended bytes and their next expected offset atomically before sending KEM_PROGRESS. This is an authenticated application-level durable receipt inside DATA, not a transport acknowledgement.
  - `next_offset` is cumulative, in the inclusive range 0 to the object's length. The sender MUST reject unknown kinds, a wrong epoch, an out-of-range offset or progress beyond bytes it has sent. Valid duplicate or older progress for the same immutable object does not decrease the sender's stored progress.
  - After accepting a chunk, including an exact duplicate, the receiver sends its latest cumulative progress. After a new Resume it sends current progress for each object it receives in the selected CK candidate's active epoch; 0 means no stored bytes. Retained losing branches MUST NOT send progress in that session.
  - Until progress acknowledges a chunk, the sender retains and may retransmit it. Across sessions, it continues from the durable acknowledged offset, or from 0 if no progress was received. Losing an acknowledgement MUST NOT lose bytes, regenerate a key or advance an epoch.
  - Full EK progress is not epoch completion. Full CT progress acknowledges durable ciphertext storage; it does not replace EPOCH_DONE's successful decapsulation/ready signal.
- **Strict reassembly** [OI-26]:
  - A chunk MUST be nonempty, identify the selected candidate's active epoch and correct direction/object kind, and fit wholly within the fixed object length. Bounds MUST be checked without overflowing offset arithmetic.
  - If `offset = next_offset`, append the chunk contiguously. If `offset < next_offset`, accept it only when it lies wholly within the stored prefix and every byte matches. A duplicate does not append or change state.
  - Gaps, conflicting duplicates, overlaps crossing the stored frontier, wrong epochs/kinds and out-of-bounds chunks MUST close the link without a response and report `pq_transfer_invalid` locally. Invalid input MUST NOT partially mutate durable state.
  - No sparse or out-of-order buffers are permitted. Only a fully reassembled EK may be used for encapsulation; only a fully reassembled CT may be used for decapsulation.
- **Completion.**
  - The encapsulator holds `ss_e` once it has encapsulated.
  - The generator holds `ss_e` once it has received the whole `ct` and decapsulated it. It MUST persist the completed state before sending EPOCH_DONE(`e`), and resend EPOCH_DONE after a duplicate completed CT or a new session while that epoch remains active.
- **Mixing.**
  - I MUST set S1.MIX = 1 when it holds `ss_e` and, if I is the encapsulator, has received EPOCH_DONE(`e`).
  - With MIX = 1, `pq = ss_e ‖ H(ek_e) ‖ H(ct_e)` enters the Resume KDF (§6). If R does not hold `ss_e`, R closes the link.
  - Once ready to mix, I MUST retain the pending epoch until commitment and MUST keep MIX = 1 on retries. It MUST NOT automatically retry with MIX = 0. A pending-epoch mismatch fails closed, reports `pq_recovery_required` locally and prevents new session establishment until recovery or re-pairing [OI-22]. These local reasons add no wire fields and MUST NOT include key material.
  - Mandatory MIX applies to a CK candidate that has not yet incorporated the pending epoch. On an already-mixed recovery candidate, the epoch contribution is empty; it MUST NOT be incorporated twice [OI-23].
  - I commits the new CK and its epoch position atomically at valid S2, then erases the incorporated epoch's `dk_e`, `ss_e` and buffers. R retains the old and candidate epoch positions and the state needed by the old branch until DATA or a recovery Resume confirms the candidate. It then commits the selected CK and epoch position and erases the losing branch and incorporated epoch state atomically [OI-23].
  - A party may start epoch `e + 1` only after locally committing a CK that incorporated epoch `e`. The generator still follows epoch parity.
- **Post-compromise healing** [OI-24]: after compromise ends, a genuinely exchanged fresh epoch whose decapsulation key and shared secret remain unexposed restores PQ secrecy when mixed. The attacker retains everything previously stolen. Continued active interception can prevent healing; the default profile makes no unconditional active-attacker recovery claim. Re-pairing through an authenticated in-person flow remains the recovery route for known interception.
- **Cadence:** a new epoch starts when none is in flight and ≥ 10 Resumes or ≥ 24 h have passed since the last completed epoch [OI-11]. Idle contacts Resume when ≥ 6 h have passed or an epoch is due (ADR 0008).

## 10. Beacons and doorbell

### 10.1 Beacon

```
w      = floor(unix_time / 300)
beacon = Trunc8(HMAC(BK_d, lp("cairn-r1 beacon") ‖ u64(w)))      # no role [OI-2]
BK_d+1 = KDF(BK_d, "", "beacon day", "", 32)                       d = floor(unix_time / 86400)
```

- **Receivers** keep, for every contact, the beacons of windows `{w−1, w, w+1}` in a constant-time lookup structure.
- **Advertisers** stop and restart the advertising set at every window boundary plus 0–30 s of random jitter.
- **Android** advertises flags + service data (128-bit service UUID ‖ beacon), 29 of 31 B: in an extended connectable, non-scannable advert where the controller supports it, else in legacy PDUs [OI-34]. The extended advert's primary PHY is 1M. Its secondary PHY is 1M, or 2M where the controller supports it while an iOS peer, a Cairn advert without service data, was seen less than 300 s ago; a first sighting restarts the set, and the switch back waits for a window rotation [OI-40].
- **iOS** advertises in the foreground the fixed UUID plus a beacon UUID `Trunc16(HMAC(BK_d, lp("cairn-r1 beacon uuid") ‖ u64(w)))` [OI-9]. In the background it advertises the fixed UUID only.

### 10.2 Device beacon key

- One device beacon key is created at install. It is shared with every contact in the pairing card [OI-1] and rotated to a fresh random key, with **no overlap**, when a contact is removed.
- The remaining contacts receive the new key in a BEACON_KEY record in every session until they answer with a matching BEACON_ACK [OI-3].

### 10.3 Doorbell (Android advertisers only)

```
door = Trunc8(HMAC(K_door_me→peer, lp("cairn-r1 door") ‖ u64(w)))
```

- The doorbell replaces the beacon in the same service-data slot. It carries no payload.
- An advertiser with pending queued messages rotates once per second, round-robin over its beacon and up to 8 doorbells.
- On a match, the receiver connects and Resumes. A replay within the window costs at most one wasted connection.

### 10.4 Connect policy (ADR 0008)

- Connect to an unknown or beaconless peer only if there is something to send, a contact has not been seen for 10 min, or admission (§5.6) is within its limits.
- Wait a random 0–3 s after first seeing an address before dialling it, so devices that see each other at once don't dial in step [OI-28].
- At most one attempt per address per 2 min, except that a dial that fails before the link comes up MAY be retried after a random 1–5 s and, if that fails too, after a random 5–15 s. A third failure waits 2 min [OI-28]. An Android central's link lost to a supervision timeout (HCI 0x08) MAY be redialled on the same steps: the first timeout after a random 1–5 s, the second after 5–15 s, and the third after 2 min. A timeout counts towards the next step only if its link was up for less than 2 min; otherwise it is a first timeout again. Any other loss, and a link that a core closed, waits 2 min. An iOS central whose connection ends with `CBError.connectionTimeout`, at any stage, doesn't dial that address for 45 s plus the 0–3 s spread, so the peer dials it instead. While a central that linked to it after that is still linked, it doesn't dial the address, and when that link goes down the 45 s start again [OI-42].
- **Android slot budget** (ADR 0025) [OI-31]:
  - The radio counts dials in flight, central links and devices connected to its GATT server. It uses at most 5 of them on API ≤ 34 and 6 on API 35+, with at most 1 dial in flight on API ≤ 28 and 2 otherwise. A dial that has not come up within 10 s fails.
  - Of two Android devices that both advertise a beacon (§10.1), only the one whose own advertised beacon is lower, as an unsigned big-endian number, dials. Equal beacons dial. A peer advertising only the service UUID is dialled as the iOS radio bullets below say.
  - The radio advertises only while it has a free slot, and disconnects a device that connects to a full GATT server.
  - A full radio that sees an advertising address with no link or connection, no dial in flight and no dial back-off closes its longest link idle for ≥ 30 s, at most once every 15 s (ADR 0030) [OI-35]. It never closes a stable link.
  - **Stable links** (ADR 0031) [OI-36]: at most ⌊¾ × budget⌋ links are stable. A link's RSSI is its latest reading no older than 30 s: on a central link the radio reads it every 10 s; on a peripheral link it is the RSSI of the latest scan result from that address. Links with an RSSI rank first, strongest first, then the rest, longest up first; the first ⌊¾ × budget⌋ are stable.
- **Android energy bands** (ADR 0027) [OI-33]:
  - The band is `FULL` while plugged in; otherwise `LOW` below 20 % battery, `SAVE` at 50 % or less or while Battery Saver is on, else `FULL`. A band set by level ends only 5 points above its threshold: `LOW` at 25 %, `SAVE` above 55 %.
  - `FULL`, `SAVE` and `LOW` advertise and scan at `LOW_LATENCY`, `BALANCED` and `LOW_POWER`. `LOW` caps the slot budget at 3; links above the cap stay up until eviction closes them.
  - The radio restarts the scan at most once every 10 s.
- **Android extended advertising** (ADR 0028) [OI-34]:
  - A radio whose controller supports extended advertising advertises extended (§10.1) at the band's interval, and scans for both advert kinds. If the set fails to start, it advertises legacy until next opened.
  - A radio that advertises extended dials a peer seen through a legacy advert whatever their beacons. Otherwise the beacon rule above applies.
- **iOS radio** (ADR 0037) [OI-39]:
  - In the foreground it advertises only the fixed service UUID in S3; the beacon UUID of §10.1 follows in S6. It runs both GATT roles and dials like Android (random 0–3 s first delay, the same retries, a 10 s dial timeout), without a slot budget, at most 2 dials at once, and not to a peer already linked to its GATT server.
  - The link MTU is the without-response write length + 3 as central and the update length + 3 as peripheral. Writes are with response.
  - A peripheral can't disconnect a central: closing a peripheral link ends it locally and refuses that central's further writes until it subscribes again.
  - Core Bluetooth reports an extended advert only when its secondary PHY is 2M, which Android uses while it sees iOS (§10.1) [OI-40]; iOS dials Android peers that advertise either way. An Android radio that advertises extended also dials iOS's legacy advert whatever the beacons (ADR 0028).
  - An Android radio waits for iOS to dial it (ADR 0039) [OI-41]. It dials an address whose advert has no service data only 10 s, plus the 0–3 s spread, after first seeing it. It doesn't dial an address that connected to its GATT server less than 10 s ago and hasn't subscribed. After an address's connection to its GATT server ends, with or without a link, it doesn't dial that address for 15 s plus the 0–3 s spread, so the central redials first; then it MAY dial it whatever its earlier dials did (ADR 0040) [OI-42].
- After a non-matching `beacon` read, either admit the stranger on the same link (§5.6) or disconnect; after 3 non-matching reads that the §5.6 limits refused, back off that address for 1 h. Reads refused because the address is already backed off don't count [OI-27, OI-30].

## 11. Implementation requirements

- **Constant time.** All operations on secrets MUST be constant-time, including:
  - KEM operations, MAC/AEAD verification, and SAS/QRC derivation;
  - pseudonym, beacon and doorbell table lookups;
  - padding checks.

  CI enforces this per ADR 0007.
- **Hygiene.** Secrets MUST be held in zeroize-on-drop types and MUST NOT cross the FFI, apart from the sealed persistence blob (ADR 0004).
- **Storage.** Persisted state MUST be excluded from backups. Restoring old state is out of scope, but a device that detects a non-monotonic `n` MUST require re-pairing (ADR 0006).
- **Errors.** Any protocol error closes the link without a response, so there is no error oracle. A BUSY refusal (§5.6) is not an error response: it follows only a well-formed P0 and depends only on admission state, not on secrets. CLOSE is sent only for orderly shutdown.

## 12. Constants and test vectors

- GATT UUIDs (random v4, generated for *Slice S2: Android↔Android over BLE*, [ADR 0023](../adr/0023-android-ble-adapter.md)):

  | Item | UUID |
  |---|---|
  | `cairn` service | `d8177748-2cfa-4aa1-b3d0-c46de25a0e45` |
  | `beacon` | `725e4d3d-d899-4e4e-990a-af2bac20deb4` |
  | `rx` | `eabb6cc0-aa49-4dd4-ae89-af2383e291dd` |
  | `tx` | `d91c38e6-5dbc-4eee-828b-707e41d63451` |
  | `psm` | `1446537a-3d32-4b5c-89d9-8c05f045487a` |

  `tx` carries the standard Client Characteristic Configuration descriptor (`0x2902`).
- Test vectors (pairing, Resume, DATA, QUEUED, beacon, doorbell, SAS/QRC): **pending**. They are generated from the reference adapter and cross-checked with the `aws-lc-rs` adapter during the implementation slices. Pinning them belongs to the spec freeze.

## 13. Consolidation issues (resolved 2026-10-05)

OI-1 to OI-15 come from spec consolidation, OI-16 to OI-18 from *Formal model: Resume*, OI-19 to OI-20 from *Formal model: SAS pairing*, OI-21 to OI-26 from the in-progress *Formal model: PQ ratchet mixing*, OI-27 from the owner's mesh redirection (ADR 0021), and OI-28 from the S2 device demonstration. The user accepted every proposal up to OI-44. OI-4 is accepted as *provisional*, pending *Formal model: PQ ratchet mixing*; OI-22 supersedes its classical fallback. The affected ADRs carry amendment notes.

| # | Issue | Resolution |
|---|---|---|
| OI-1 | ADR 0005 shares the device beacon key at pairing, but the draft's 64 B card has no room for it, so the P3/P4 sizes are wrong | Card carries `day(u32) ‖ BK_d(32)`: +36 B. With a 48 B name, P3 ≤ 135 B and P4 ≤ 119 B (the draft's 113/97 B assumed an illustrative 64 B card) |
| OI-2 | The beacon formula has `role ‖ window`, but a device-wide key has no pairing role | Drop `role`; use the label `"beacon"` |
| OI-3 | ADR 0008 sends the rotated beacon key "in a record at the next Resume", but there's no record type | New records `0A BEACON_KEY: day(u32) ‖ BK_d(32)` and `0B BEACON_ACK: day(u32)`. The sender includes BEACON_KEY in every session until the matching BEACON_ACK arrives |
| OI-4 | The ratchet doesn't say who generates `ek`, or how both sides agree that an epoch completed before mixing it at Resume (a lost last chunk or ack desyncs `CK`) | Alternate the generator by epoch parity. The generator sends `0C EPOCH_DONE(epoch)` after decapsulating. I sets S1 sub bit 1 = "mix pending epoch"; R mixes only if it has `ss_e`, else the Resume fails. The original MIX = 0 retry is superseded by OI-22. Settle in the ratchet model |
| OI-5 | The 1 B chain generation wraps after 256 Resumes, which can happen within the 7-day queue lifetime | Receiver keeps chains only for generations with outstanding skipped keys. A collision expires the older generation's messages (EXPIRED); alternatively use LEB128 `gen` (+1 B after 127) |
| OI-6 | QUEUED carries the global `msgno`, but the receiver needs the chain index within its generation | Body becomes `gen(1) ‖ LEB128(idx) ‖ Seal(mk_idx, …, msgno ‖ text)`; `msgno` moves inside the ciphertext, which also hides it at the session layer. Same size |
| OI-7 | The draft's `ctx = "cairn-r1" ‖ pairID ‖ epoch` is used for pairing too, but `pairID` comes from `RK`, which is circular | Pairing KDFs use only the label and `th` (as §5.2); `ctx(n)` applies from Resume on |
| OI-8 | Behaviour after attempt 3 without a valid S2 is undefined | Further attempts reuse attempt 3, so retries are linkable for one `CK_n`; accept, and back off per ADR 0008 |
| OI-9 | ADR 0003 calls the iOS beacon a "rotating 128-bit UUID" without a derivation | As §10.1. Receivers match on the first 8 B; iOS foreground only |
| OI-10 | `K_door_pair` is never derived | Two directional keys from `RK` (§5.5). They are static for the contact's lifetime, so they are not healed by the ratchet; acceptable for a hint without payload |
| OI-11 | The PQ epoch cadence ("every N sessions or T hours") was never decided | Start an epoch when none is in flight and ≥ 10 Resumes or ≥ 24 h have passed since the last completed epoch (user's choice) |
| OI-12 | The KCI profile is "opt-in per contact" but static keys travel only in the pairing card; enabling it later and the `confirm` keying are undefined | r1: choose KCI only at pairing (re-pair to enable); both cards MUST carry `static_ek`; keying as §6 |
| OI-13 | The draft's `ctx` calls the Resume counter "epoch", which clashes with the glossary (Epoch = PQ ratchet period) | Call it the **Resume index** `n` and add it to the glossary |
| OI-14 | CLOSE reason codes are undefined | As §7.3 |
| OI-15 | QR-mode authentication of B relies on `token`, but the draft's `confirm_B` places it differently (`"qr" ‖ token ‖ th`) | Equivalent; use §5.2 (`th ‖ token`) |
| OI-16 | *Formal model: Resume* falsified reflection resistance and I's agreement: `K_id` and `K_auth_I` bind only the Resume role, and both peers share `CK_n`, so a relay can return A's own S1 to A. A accepts a session with itself and advances `CK`, which B never learns: a permanent desync (DoS until re-pairing). Session keys stay secret | Bind I's pairing role `ρ_I` into the `K_id` and `K_auth_I` labels; R computes with the contact's role. 0 bytes, same table size. All Resume lemmas verify (user's choice, 2026-10-05) |
| OI-17 | Both devices can act as central and send S1 to each other at once. §4.6 closes duplicates "before Resume", but a device can't identify the peer before the pseudonym, and nothing stopped both Resumes from committing different `CK`s | At most one Resume per contact in flight; atomic commit; on collision pairing role A's attempt wins (§6). Matches §4.6 (user's choice, 2026-10-05) |
| OI-18 | KCI profile: `th_s = H(S1 ‖ eR)` leaves `ct_I` unauthenticated. An attacker who replaces `ct_I` makes I derive different keys and retire `CK_n` while R keeps it: permanent desync without any key compromise | `th_s = H(S1 ‖ eR ‖ ct_I)` in the KCI profile; 0 bytes (§6) (user's choice, 2026-10-05) |
| OI-19 | §5 doesn't require B to check `P1.mode`. An attacker rewrites `sas` to `tofu`, and B silently stores an Unverified, possibly intercepted contact although its user chose SAS | B MUST abort unless `mode` equals its user's selection (§5.1); 0 bytes (user's choice, 2026-10-05) |
| OI-20 | Pairing roles are defined by who shows the QR, which leaves SAS and TOFU without a role rule | The phone whose user picks the peer from the nearby list is B; the picked phone is A (§2.3) (user's choice, 2026-10-05) |
| OI-21 | A wrapping `u8` epoch identifier conflicts with the required non-reuse and monotonicity property | Non-wrapping `u32`, canonical LEB128 in all three epoch record types; exhaustion requires re-pairing (§7.3, §9). One byte for epochs 0–127, up to five thereafter (user's choice, 2026-10-05) |
| OI-22 | Retrying with MIX = 0 after a failed PQ-mixing attempt conflicts with the no-downgrade requirement | Once ready, keep MIX = 1 and retain the pending epoch until commitment; mismatches fail closed with a local recovery-required error (§9). No extra wire bytes (user's choice, 2026-10-05) |
| OI-23 | I can erase an epoch at S2 while R still retains the old CK after lost DATA; without per-candidate epoch metadata, recovery can mix an epoch twice or roll back its position | Store post-mix epoch positions with CK candidates; defer R's epoch erasure until branch confirmation; commit CK, position and erasure atomically (§6, §9). No extra packets (user's choice, 2026-10-05) |
| OI-24 | PQ healing after state compromise is not explicitly conditioned on a fresh exchange that a continuously active attacker did not replace | Claim conditional fresh honest-epoch healing, retaining stolen-key knowledge; do not claim recovery under continued active interception (§9, threat model) (user's choice, 2026-10-05) |
| OI-25 | Chunk offsets alone do not tell the sender which bytes survived a disconnect or a lost acknowledgement | Authenticated cumulative `0D KEM_PROGRESS(epoch, kind, next_offset)` after durable storage; re-advertise progress and pending EPOCH_DONE after Resume; resend immutable unacknowledged chunks (§7.3, §9) (user's choice, 2026-10-05) |
| OI-27 | Owner redirection to a peer-to-peer BLE mesh (2026-10-23): pairing must start automatically for every discovered peer. With no pairing screen, A can't tell which incoming link to send P1 on, OI-20's user-pick role rule has no user, and both devices can connect to each other at once | Automatic TOFU admission (§5.6): central is B and sends `P0 = hdr ‖ r(16)`; one pairing in flight with an `r` tie-break; admission limits 10/h admitted, 30/h attempts, 256 total, no eviction; only `mode = 0x03`; QR and SAS pairing retired, Verify remains; empty card name by default. +17 B once per admission. Verified models unchanged (ADR 0021) (user's choice, 2026-10-23) |
| OI-28 | S2 device demonstration (2026-10-24): two phones that see each other at once dial each other at once, both dials fail (Android status 133, HCI `0x3e`), and the 2 min attempt limit makes them retry in step and collide again | A random 0–3 s delay before the first dial; a dial that fails before link-up is retried after a random 1–5 s, then 5–15 s, then 2 min (§10.4, ADR 0008). No wire change (user's choice, 2026-10-24) |
| OI-29 | S2 fleet test (2026-10-25, issue 52): a peripheral that refuses a P0 closes the link, but Android doesn't drop a link that the remote central opened. The central waits about 5 s for its deadline with its own pairing in flight, refusing every other peer, and then backs off the address for 1 h | A refuses with a 1 B `BUSY` frame (PAIR step 5) and waits for B to close. B closes at once, without back-off, and the attempt isn't counted (§4.2, §5.1, §5.6, ADR 0021). Models unchanged: BUSY is an unauthenticated availability signal outside `th` (user's choice, 2026-10-25) |
| OI-30 | Fleet pairing plateau (2026-10-25, issue 53): every failed pairing backed the address off for 1 h, and a refused dial re-armed that hour. In a 12-phone run, 20 attempts failed, none on a protocol check (11 deadlines without a reply, 9 link drops), and 14 of 69 central links were then refused, so one radio hiccup blocked a pair of phones for the rest of the encounter | Transport failures back off 2 min, doubling up to 1 h; protocol failures keep 1 h; a completed pairing resets the count; a refused dial doesn't re-arm a back-off, and three dials refused by the limits back off 1 h as §10.4 says (§5.6, §10.4, ADR 0021). The 30 attempts per hour still bound X-Wing work. No wire change; models unchanged, no model covers admission (user's choice, 2026-10-25) |
| OI-31 | Fleet pairing plateau, cause (2026-10-25, issue 53): Android allocates one of 7–8 GATT link records per device when a connect starts. In a 15-phone run, 274 of 443 fast status-133 dial failures coincided with a full table, and the S2 radio dialled every peer, advertised while full and never freed a link | Android slot budget: 5 slots (6 on API 35+), 1–2 dials in flight, a 10 s dial timeout, the lower advertised beacon dials, advertising only with a free slot, eviction of a ≥ 30 s idle link when a new peer waits (§10.4, ADR 0025). The beacon advert is the one §10.1 already specifies. No wire change; no model covers discovery (user's choice, 2026-10-25) |
| OI-34 | Fleet pairing plateau, failed dials (2026-10-25, issue 53): an HCI snoop showed every fast status-133 dial failure is a `CONNECT_IND` lost on the primary advertising channels, so the link fails after 6 events with `0x3E` | Android advertises extended connectable PDUs where supported, so the request moves to a secondary channel and is answered by `AUX_CONNECT_RSP`; legacy otherwise; an extended advertiser dials peers it sees advertising legacy (§10.1, §10.4, ADR 0028). Advert payload unchanged; no frame changes (user's choice, 2026-10-25) |
| OI-35 | Fleet pairing plateau, slot turnover (2026-10-26, issue 53): with the slot budget, while a phone's links fill its slots, 93–100 % of the time a link idle for 30 s waits only on the 60 s eviction interval; in a 23-phone A/B a 15 s interval paired 21 % more phones in 300 s | A full radio evicts at most once every 15 s; the 30 s idle time and the waiting-peer condition are unchanged (§10.4, ADR 0030). No wire change (user's choice, 2026-10-26) |
| OI-36 | Mesh link stability (2026-10-26, issue 53): in a 900 s fleet run the pair graph connected by 90 s and the later plateau is the §5.6 admission limit, but links churn: median lifetime 27 s, none 300 s, closed by idle eviction. A mesh routes over links that stay up | A full Android radio keeps up to ⌊¾ × budget⌋ stable links, the strongest by RSSI (scan RSSI on peripheral links, else age), and evicts only the rest (§10.4, ADR 0031). No wire change (user's choice, 2026-10-26) |
| OI-33 | Energy (2026-10-25, issue 53): the Android radio advertises and scans at `LOW_LATENCY` whatever the battery, and slower modes cost about 16 % of pairs in a crowd (ADR 0026) | Android energy bands `FULL`/`SAVE`/`LOW` from battery level, plug state and Battery Saver, with hysteresis; `BALANCED` and `LOW_POWER` modes and a 3-slot cap below `FULL` (§10.4, ADR 0027). No wire change (user's choice, 2026-10-25) |
| OI-37 | Couriers (2026-10-26, ADR 0033, issue 54): ADR 0033 lets contacts carry queued messages for out-of-range contacts but leaves the pairing output, padding and records to the spec. Today's QUEUED body would show couriers `gen`, `idx` and the text length | New pairing output `K_route`; queued `inner` carries the text length and is padded to buckets; envelope `tag ‖ c ‖ expiry ‖ copies ‖ ct`; records 0E–12; inventories list 8 B tag prefixes, with full tags in FETCH, ENVELOPE, CUSTODY and TOMB (§5.5, §7.3, §8, §8.1). Model `courier.spthy` verifies P1–P4; P5 argued (user's choice, 2026-10-26) |
| OI-38 | Store-and-forward gaps (2026-10-27, ADR 0034, issue 35): the receiver cannot know which generations have outstanding messages; since OI-6 it cannot map an EXPIRED range to skipped keys; R could seal under an unconfirmed `MS_{n+1}`; an unacked CHAT is lost if the process dies before re-sealing it, which stalls the peer's ACK | Superseded receive chains are kept 7 days; skipped keys are deleted when used, after 7 days or on collision, not on EXPIRED; R reseeds on key confirmation; unacked CHAT numbers are persisted and expired after a restart; ACK counts expired numbers (§8). No byte of any frame changes (user's choice, 2026-10-27) |
| OI-39 | iOS radio (2026-10-29, ADR 0037, issue 33): CoreBluetooth can't advertise service data, can't disconnect a central from the GATT server, and reports a 512 B with-response write length whatever the MTU, and doesn't report Android's extended adverts | iOS advertises the service UUID only in S3; closing a peripheral link refuses that central's writes until it resubscribes; the link MTU comes from the without-response length; iOS dials only legacy-advertising Android peers, and extended ones dial it (§10.4; superseded by OI-40). No byte of any frame changes |
| OI-40 | iOS can't dial extended Android (2026-10-29, ADR 0038, issue 56): Core Bluetooth on iOS 17, 18 and 27 reports extended adverts only with a 2M auxiliary packet, and a fleet A/B showed an always-2M set costs Android↔Android pairs and dial timeouts | Android's extended set uses a 2M secondary PHY, where supported, only while an iOS peer (a Cairn advert without service data) was seen in the last 300 s; iOS dials extended Android peers (§10.1, §10.4). No byte of any frame changes |
| OI-41 | Crossed dials lose links (2026-10-29, ADR 0039, issue 58): iOS and Android dial each other at once; Android's dials to iOS fail with HCI 0x3E, and on Android 9 a second ACL to one address misroutes or tears down the first | Android dials an iOS peer only 10 s after first seeing it, and doesn't dial an address that connected to its GATT server less than 10 s ago (§10.4). No byte of any frame changes |
| OI-42 | Supervision timeouts (2026-10-29, ADR 0040, issue 58): links where an iPhone 12 mini is the central drop with HCI 0x08, mostly 2–4 s after link-up, mid-pairing. The iPhone's 720 ms timeout can't be changed by either app, and the 2 min attempt limit plus the OI-30 back-off kept the pair apart for 2 min or more | An Android central redials a link lost to a supervision timeout after 1–5 s, then 5–15 s, then 2 min; an iOS central leaves the peer 45 s plus the spread to dial instead; an Android radio doesn't dial an address for 15 s plus the spread after its server connection ends, so the central redials first (§10.4); the first link drop mid-pairing with an address that has no earlier failure doesn't back it off (§5.6). No byte of any frame changes |
| OI-43 | Corrupted writes (2026-10-31, ADR 0042, issue 59): a Redmi 2201117TY's controller sometimes hands its host a 512 B write from an iPhone with a 50–215 B block replaced, ending at the first link-layer PDU's last byte; the link-layer CRC passes, and the frame's MAC closes the link and loses the pairing in about 1 run in 12 | Every GATT fragment ends with a CRC-16/CCITT-FALSE check, so the body is at most `min(ATT_MTU − 6, 509)` B; a server answers a write that fails it with ATT error `0x9E`, and the central writes it again up to 3 times; centrals write `rx` with response (§4.1, §4.3). Every GATT fragment grows by 2 B; peers built before this change can't talk to ones built after it, and `cairn-r1` keeps its version as the protocol is pre-release |
| OI-44 | One-sided pairing (2026-10-31, ADR 0043, issue 58): B stored the contact before sending P4 and A on receiving it, so a link lost in between left only B with the contact; B's Resumes then failed with no signal, and a second pairing duplicated the contact on B | A paired contact stays provisional, unpersisted and unreported, until the pairing link carries a valid S2 (B) or S1 (A); if the link closes first, the device forgets it (§5.5). A lost S2 still leaves A with an orphan contact (issue 60). No byte of any frame changes |
| OI-26 | Reassembly semantics for gaps, overlaps and retransmitted chunks are unspecified | Contiguous append only; exact duplicates wholly within the stored prefix are accepted; gaps, conflicting/cross-frontier overlaps, wrong epochs and bounds violations fail closed without partial mutation (§9) (user's choice, 2026-10-05) |

## 14. Change log

- 0.24 (2026-10-31): accepted OI-42 (redial after a supervision timeout, ADR 0040), OI-43 (a check on every GATT fragment, ADR 0042) and OI-44 (provisional contact, ADR 0043). No byte of any frame changes beyond those proposals.
- 0.23 (2026-10-31): proposed OI-44: a paired contact stays provisional, unpersisted and unreported, until the pairing link carries a valid S2 (B) or S1 (A), and is forgotten if the link closes first (§5.5, ADR 0043). No byte of any frame changes.
- 0.22 (2026-10-31): proposed OI-43: every GATT fragment ends with a 2 B CRC-16/CCITT-FALSE check, the body limit becomes `min(ATT_MTU − 6, 509)`, and a write whose check fails is answered with ATT error `0x9E` and written again up to 3 times (§4.1, §4.3, ADR 0042). Every GATT fragment grows by 2 B; L2CAP CoC frames are unchanged.
- 0.21 (2026-10-29): proposed OI-42: an Android central redials a link lost to a supervision timeout after 1–5 s, then 5–15 s, then 2 min, an iOS central leaves the peer 45 s to dial instead, and an Android radio leaves the central 15 s to redial after its server connection ends (§10.4); the first link drop mid-pairing with an address is forgiven (§5.6, ADR 0040). No byte of any frame changes.
- 0.20 (2026-10-29): accepted OI-41: Android waits 10 s for an iOS peer to dial it, and doesn't dial a peer in its server's pre-auth window (§10.4, ADR 0039). No byte of any frame changes.
- 0.19 (2026-10-29): accepted OI-40: Android's extended advert moves to a 2M secondary PHY while an iOS peer is near, so iOS dials it (§10.1, §10.4, ADR 0038). No byte of any frame changes.
- 0.18 (2026-10-29): accepted OI-39: the iOS radio's advertising, MTU and peripheral close (§10.4, ADR 0037). No byte of any frame changes.
- 0.17 (2026-10-27): accepted OI-38 (store-and-forward gaps, ADR 0034): R reseeds message chains on key confirmation, superseded receive chains are kept 7 days, skipped keys are no longer deleted on EXPIRED, unacked CHATs lost to a restart are expired, and ACK counts expired numbers (§8). No byte of any frame changes.
- 0.16 (2026-10-26): accepted OI-37 (couriers, ADR 0033): new pairing output `K_route` (§5.5), padded inner plaintext of queued messages (§7.3, §8), courier envelopes, inventories and tombstones in records 0E–12 (§8.1). `courier.spthy` verifies secrecy, authenticity, once-only acceptance and tombstone unforgeability.
- 0.15 (2026-10-26): accepted OI-36: a full Android radio keeps its strongest links, up to ⌊¾ × budget⌋, and evicts only the rest (§10.4, ADR 0031). No byte of any frame changes.
- 0.14 (2026-10-26): accepted OI-35: a full Android radio evicts an idle link at most once every 15 s (§10.4, ADR 0030). No byte of any frame changes.
- 0.13 (2026-10-25): accepted OI-34: Android advertises extended connectable PDUs where the controller supports them, and an extended advertiser dials legacy advertisers (§10.1, §10.4, ADR 0028). No byte of any frame changes.
- 0.12 (2026-10-25): accepted OI-33: Android lowers its advertising and scan modes, and its slot budget, by battery band (§10.4, ADR 0027). No byte of any frame changes.
- 0.11 (2026-10-25): accepted OI-31: Android budgets its GATT connections, and the lower advertised beacon dials (§10.4, ADR 0025). No byte of any frame changes.
- 0.10 (2026-10-25): accepted OI-30: a transport failure backs off the address for 2 min, doubling up to 1 h; protocol failures keep 1 h; refusals don't extend a back-off (§5.6, §10.4). No byte of any frame changes.
- 0.9 (2026-10-25): accepted OI-29: a 1 B BUSY frame (PAIR step 5) refuses a P0 in place of a silent close; a BUSY neither backs off the address nor counts as an attempt (§4.2, §5.1, §5.6).
- 0.8 (2026-10-24): recorded the GATT service and characteristic UUIDs (§12, ADR 0023); capped fragments at the 512 B ATT value limit (§4.3, ADR 0003); accepted OI-28 (randomized first dial and two fast retries, §10.4). No byte of any frame changes.
- 0.7 (2026-10-23): accepted OI-27 (automatic neighbour admission, ADR 0021): new P0 frame and §5.6; QR and SAS pairing modes retired; card name empty by default; connect policy admits strangers. Multi-hop relaying remains unspecified (issue 47).

- 0.6 (2026-10-05): accepted OI-25 (durable cumulative KEM_PROGRESS) and OI-26 (strict contiguous reassembly); specified retransmission, reconnect receipts and fail-closed validation. Ratchet gate remains closed.
- 0.5 (2026-10-05): accepted OI-21 (non-wrapping LEB128 epochs), OI-22 (mandatory MIX), OI-23 (CK-bound recovery metadata) and OI-24 (conditional honest-epoch healing). All four public-`pairID` Resume profiles subsequently re-verified; composed ratchet proof remains pending.
- 0.4 (2026-10-05): *Formal model: SAS pairing* verified §5 and found OI-19 (mode downgrade) and OI-20 (roles without a QR); both resolved and applied.
- 0.3 (2026-10-05): *Formal model: Resume* verified §6 and found OI-16 (reflection), OI-17 (concurrent Resume) and OI-18 (unauthenticated `ct_I` in the KCI profile); all resolved and applied.
- 0.2 (2026-10-05): consolidation issues OI-1 to OI-15 resolved and applied.
- 0.1 (2026-10-05): first consolidation of ADRs 0001–0009, the wire-format draft and the threat model.
  - Clarifications that don't change any byte: the labelled KDF/MAC framing, domain-separated `commit`, and AAD = `hdr ‖ th` for P3/P4.
