---
status: accepted
date: 2026-10-23
version: cairn-r1
---

# 0022: `CairnCore` contract for the walking skeleton

## Context

[ADR 0004](0004-core-architecture.md) fixes the shape of the core:
`CairnCore.handle(event) -> List<Action>` plus read-only queries, a
single-threaded sans-IO state machine, one `Persist(blob, version)` action
and a `Restore` event. It leaves the concrete events, actions, identifiers,
blob format and crate dependencies open.

Slice S1 ([issue 31](../../.scratch/cairn-r1/issues/31-slice-s1.md)) is the
first code that needs them: automatic admission
([ADR 0021](0021-automatic-neighbour-admission.md)), TOFU pairing P1–P4, a
basic Resume, CHAT DATA records and fragmentation, between two cores over an
in-memory loopback and through UniFFI from Kotlin.

Three gaps had to be closed first:

- Spec §5.6 defines a stranger by beacon matching, but beacons were
  scheduled for S6. Without them the central cannot choose between Resume
  and admission.
- Store-and-forward (QUEUED, ACK, receipts) belongs to S5. S1 needs a rule
  for a message sent while no session is up.
- The deterministic, `no_std` state machines in `cairn-proto` need the
  `CryptoBackend` seam, which lived in a `std` crate.

## Decision

The owner chose the beacon, no-session and PR-shape rules below on
2026-10-23. The remaining rules follow from ADR 0004 and the spec.

### 1. Crates

- `cairn-crypto` becomes `#![no_std]` with `alloc`. Its error type
  implements `core::error::Error`. The adapters keep their dependencies,
  which may use `std`.
- `cairn-proto` depends on `cairn-crypto` with default features off. The
  state machines are generic over `B: CryptoBackend` and never name an
  adapter.
- `cairn-ffi` instantiates the core with the `AwsLc` adapter. It mirrors
  `Event`, `Action` and `ContactInfo` with `u64` ids, because a UniFFI custom
  type for the id newtypes adds an error path that cannot be exercised.
- Secret comparisons use `subtle` (ADR 0004). `cairn-proto` adds it with
  the first comparison that needs it.

### 2. Events

Every event carries `Clock { mono_ms: u64, unix_s: u64 }`. `mono_ms` drives
timers and rate limits; `unix_s` drives beacon windows and days (spec §10.1).

| Event | Meaning |
|---|---|
| `Restore { state: Option<Persisted> }` | First event. `Persisted` is `{ blob: bytes, version: u32 }`. `None` is a fresh install: the core creates the device beacon key and emits `Persist`. |
| `LinkUp { link, gatt_role, mtu, address }` | A BLE link is connected. `gatt_role` is `Central` or `Peripheral`; `address` is opaque bytes used only for back-off. |
| `MtuChanged { link, mtu }` | The ATT MTU changed. |
| `BeaconRead { link, beacon: bytes }` | Central only: the value read from the peer's `beacon` characteristic (spec §4.1). A value that is not 8 B long is peer misbehaviour: the core closes the link and backs off the address. |
| `Received { link, fragment: bytes }` | One ATT value from `rx` or `tx`. |
| `LinkDown { link }` | The link is gone. Partial frames are discarded (spec §4.5). |
| `TimerFired { timer }` | A timer set by the core has expired. |
| `SendChat { contact, text }` | The user sent a message. |

### 3. Actions

| Action | Kotlin must |
|---|---|
| `Send { link, fragment }` | Write or notify the fragment in order. |
| `Disconnect { link }` | Close the link. |
| `SetTimer { timer, at_mono_ms }` / `CancelTimer { timer }` | Schedule or cancel. |
| `Persist { state: Persisted }` | Seal and store the blob before executing any later action in the batch. |
| `ContactAdded { contact }` | Refresh the contact list. |
| `ChatReceived { contact, msgno, text }` | Show the message. |
| `ChatSent { contact, msgno }` | The message was sealed into DATA frames on a live session. |
| `ChatRejected { contact, reason }` | `NoSession`, `TooLong` or `Exhausted`. |

- **Ordering.** Within a batch, `Persist` precedes every `Send` that reveals
  the state it records. For example, A persists the new contact before it
  sends P4, I persists `CK_{n+1}` before its first DATA frame, R persists
  its pending `CK_{n+1}` before S2, and a sender persists a `msgno` before
  the DATA frame that carries it.
- **Peer errors.** A malformed, unexpected or failed frame produces
  `Disconnect` (spec §4.2), never an error return. `handle` returns an error
  only for caller contract violations and local failures. Contract
  violations are: an event before `Restore`, a second `Restore`, an unknown
  contact, a blob that does not decode, a reused `LinkId`, a beacon read on a
  peripheral link or a second one on the same link, and an ATT MTU below 23
  in `LinkUp` or `MtuChanged` (`InvalidMtu`).
- **Local failures.** A `CryptoBackend` failure, such as the platform RNG
  failing, returns `CoreError::Crypto`. It is not blamed on the peer, so the
  address is not backed off. The error discards that batch's actions; the
  link's pairing state is already reset, so the link idles until its
  deadline timer fires and the core disconnects it.
- **Poisoning.** A panic inside the core reaches Kotlin as UniFFI's
  `InternalException` and may leave the core between invariants, so
  `CairnCore` refuses every later call with `CoreException.Poisoned`. The
  app must recreate the core and restore it from the last persisted blob.
- **Unknown links.** Events for a link the core does not know, or has
  already disconnected, are ignored. Kotlin may still deliver a queued
  fragment or `LinkDown` after the core's `Disconnect`, so this is not a
  contract violation.

### 4. Identifiers and queries

- `LinkId` is a `u64` chosen by Kotlin. `TimerId` and `ContactId` are `u64`
  values allocated by the core. `ContactId` is persisted; `pairID` and all
  keys stay inside the core.
- Queries: `contacts()` returns id, the name the neighbour shared in its
  card (empty if none; the app derives a local label) and verification state.
  `beacon(unix_s)` returns the 8 B value for the local `beacon`
  characteristic. It derives forward from the stored key without mutating
  state, so a GATT read callback can call it.

### 5. Minimal beacons in S1

- S1 implements the spec §10.1 beacon value, the forward `BK` day ratchet,
  the device beacon key in the pairing card, and matching of a
  `BeaconRead` against every contact's beacons for windows `{w−1, w, w+1}`
  in constant time.
- The central decides from that match. On a hit it starts Resume as I; on
  a miss it sends P0 as B if the admission limits allow, and otherwise
  disconnects and backs off the address (spec §10.4). A peripheral that
  refuses a P0 answers BUSY; a central that receives BUSY disconnects
  without back-off (spec §5.6, OI-29).
- A hit for a contact that already has a link in Resume or in session
  closes the new link (§10).
- A day before a key's stored day, for example after the wall clock moved
  back, uses the stored key; keys only ratchet forward.
- Advertising, the advertised-beacon match, iOS beacon UUIDs, key rotation
  on removal and BEACON_KEY/BEACON_ACK records remain in S6.

### 6. Sending

`SendChat` for a contact with no Resume-completed link returns
`ChatRejected { reason: NoSession }`. Nothing is held or persisted. S5 adds
queuing. A text that does not fit one CHAT record in the 4079 B bucket
returns `TooLong`. A contact that has already been sent `msgno` 2^32 − 1
returns `Exhausted`; `msgno` never wraps (spec §8). A session whose DATA
counter is exhausted is closed and the chat returns `NoSession`.

### 7. Persistence

- `version` is the blob format version, `1` for S1. Restore rejects any
  other version; r1 has no released blobs, so there is no migration yet.
- The blob is one canonical, strictly decoded encoding (fixed-width
  big-endian integers, no trailing bytes) of the whole durable state: the
  device beacon key and its day, the next
  `ContactId`, and per contact the pairing role, mode, verification state,
  `pairID`, `th`, `nB`, peer card, peer beacon key and day, door keys,
  Resume index `n`, `CK_n` (with the uncommitted `CK_{n+1}` while R
  awaits key confirmation), and the last `msgno` sent to the contact.
- The core does not seal the blob; Kotlin seals it with the platform
  keystore (ADR 0004).
- Admission and back-off ledgers use `mono_ms` and are not persisted. A
  process restart resets them.

### 8. Testing and gates

- Rust tests drive two cores through an in-memory loopback with a test-only
  `CryptoBackend`. It draws randomness from a seeded generator and uses the
  `Reference` deterministic key generation and encapsulation helpers. It is
  compiled only for tests and is never exported.
- The KMP loopback uses the real backend and asserts outcomes only.
- S1 switches on fuzzing of the frame header and reassembly, the record
  parser and the S1/S2 and P0–P4 parsers, plus the constant-time taint check
  on `cairn-proto`'s secret paths: beacon and pseudonym lookup, MAC checks and
  the padding check ([ADR 0007](0007-ct-conformance-gates.md)). As built:
  - `core/fuzz` targets `framing` (arbitrary fragments, and the
    `fragment`/`Reassembler` round trip at every MTU) and `records` (parse
    invariants and the `chat_plaintext` round trip).
  - The `session` target drives two `Core`s through the test loopback,
    pairing, resuming and chatting. The input drops, truncates, corrupts or
    replaces fragments in flight. It reaches the P0–P4 and S1/S2 parsers
    through `handle`, not through standalone parser targets. It fails if
    `handle` returns an error for a contract-valid event, or if a received
    chat is not one the peer sent under that number.
  - Each secret comparison is a branch-free inner function returning a
    `subtle::Choice`. The protocol declassifies it with one `bool::from`.
    The hidden `probes` feature exposes these functions to the `core/ct`
    Memcheck harness, which taints beacon keys, chain keys, the expected P3/P4
    confirmation and DATA padding. It requires each verdict and found index to
    stay tainted on both backends.
  - The AES-GCM tag verdict that guards the P3/P4 confirmation is public by
    design and stays unchecked, as in ADR 0019.
- A peer's X-Wing key in P1 that fails the ML-KEM modulus check, or an X25519
  share in P1 or P2 that gives an all-zero secret, fails pairing as a
  malformed frame. The link closes and the peer address backs off. Only local
  backend failures reach the caller as `CoreError::Crypto`. The `session`
  fuzz target found this; a pairing unit test pins it.

### 9. Delivery

S1 ships as stacked PRs:
1. this ADR and the `no_std` seam;
2. framing, admission, pairing and persistence;
3. beacons, Resume and DATA/CHAT;
4. the UniFFI `CairnCore`, the KMP loopback and the reference-app migration;
5. the fuzz targets and the constant-time taint check on `cairn-proto`, behind
   a hidden, non-default `probes` feature.

The owner split the fourth PR in two on 2026-10-23, with the beacon length
and poisoning rules above.

### 10. Resume and DATA in S1

Decided while building PR 3; the owner chose the key confirmation.

- **Resume after pairing.** After P4, B (the central) sends S1 on the same
  link as I, under a fresh 5 s deadline. Later links resume on a beacon hit.
- **Key confirmation.** I sends one empty DATA frame (a 32 B all-zero
  plaintext, 49 B on the wire) right after a valid S2. R commits its pending
  `CK_{n+1}` when the first DATA frame opens, so it does not wait for the
  first real message (spec §6, §7).
- **Retries.** A device that still holds a pending `CK_{n+1}` from an
  unconfirmed Resume as R tries it on even attempts and `CK_n` on odd ones,
  so either side's loss converges. The attempt counter is in memory and
  resets when the chain key changes.
- **One link per contact.** A new link for a contact that already has a
  Resume or a session on another link is closed, at the central's beacon
  hit and at R's S1 match. This stands in for the concurrent-Resume rule
  (OI-17), which issue 31 defers. Cost: a session R thinks is live blocks a
  new one until its `LinkDown`.
- **Session frames.** Establishing a session raises the reassembly limit
  from 2560 B to 4096 B (spec §4.4).
- **Beacon keys.** The card sent at pairing carries the device key ratcheted
  to the current day in memory; the stored device key is not advanced. A
  received card whose `bk_day` is more than one day from the local day fails
  pairing, because spec §5 makes it the sender's current key and an old day
  would cost a ratchet step per day on every read. Each beacon read ratchets
  the stored contact keys forward to the day of window `w−1` in place; the
  next `Persist` records them. Erasing old keys belongs to S6 with key
  rotation.
- **Deferred.** Resume rate limits and the full OI-17 rule.

## Consequences

- `cairn-proto` gains its first dependency on `cairn-crypto`.
- The FFI surface in §2–§4 is the SDK contract. Changing it after release
  is a breaking change (ADR 0004).
- A restart forgets admission attempts, so an attacker who can restart the
  app can reset the hourly budget. That needs control of the device.
- GATT UUIDs (spec §12) are still needed for the device demonstration, not
  for the loopback.

## Alternatives considered

- **Kotlin tells the core whether a peer is a stranger.** Smaller S1, but
  it deviates from spec §5.6 until S6 and moves a security decision outside
  the core.
- **Hold unsent messages in memory.** Silently lost on restart, and would be
  replaced by S5 anyway.
- **`cairn-proto` defines its own crypto trait.** Duplicates the seam and
  its tests.
- **Persist the admission ledgers.** Survives restarts, but adds a write
  per attempt and depends on the wall clock for rolling windows.
- **One S1 PR.** Too large to review.
- **Confirm with the first real message.** No extra frame, but R keeps two
  candidate keys until the user sends something, and a quiet session never
  confirms.
- **A dedicated confirmation record.** Needs a new record type for what an
  empty padded DATA frame already proves.
- **The full concurrent-Resume rule now.** Issue 31 defers it with rate
  limits; closing the new link is safe and simple.

## Amendments

2026-10-27, from [ADR 0034](0034-store-and-forward-core.md):
- §6: a message sent with no session is queued once the contact has a message chain; `NoSession` remains only before the first Resume, and a full queue returns `QueueFull`.
- §7: the single `Persist` blob and blob `Restore` are replaced by device, contact and queued-message rows (blob version 2).
