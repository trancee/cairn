# Research findings: post-quantum peer-to-peer security over BLE

Status: research draft, not an approved design. No ADR exists yet. Any adoption
requires an ADR (Constitution O3), a formal model, and expert review (S6).

## 1. Summary

1. **The premise in `PROMPT.md` that radio bytes dominate cost is inverted for
   isogenies.** A full ML-KEM-768 exchange is about 2.3 KB, which is about
   13 ms of airtime on the 2M PHY. A single constant-time CSIDH-512 group
   action costs about 125 M cycles on x86 (CTIDH). On a phone that is tens of
   milliseconds of CPU time, and on a Cortex-M4 it takes far longer.
2. **The CSIDH-to-ML-KEM hybrid in `PROMPT.md` is not secure as written.** See
   §3.
3. **Proposed approach:** don't shrink the public-key primitive. Move it out of
   the per-connection path:
   - Introduce once (app-layer, no BLE pairing) with a standard hybrid KEM (about 2.4 KB, done once).
   - Resume every connection with a **PQ-secure symmetric ratchet** and a
     classical X25519 ephemeral: **106 bytes total, 1 PDU each way.**
   - Restore PQ post-compromise security with an **amortized ML-KEM ratchet**
     whose chunks travel inside encrypted, padded data frames (adapted from
     Signal SPQR).
   - Data frames carry **17 B of overhead**, or 9 B in a compact profile. The
     `PROMPT.md` design uses 28 B.
4. Every primitive is standardized or widely deployed and has constant-time
   implementations. The novelty is the protocol composition, not the
   mathematics.

### Terminology: "introduction" is not BLE pairing

Everything here runs at the **application layer** over ordinary, unbonded GATT
or L2CAP CoC connections. Bluetooth OS pairing and bonding are never used. In
this document, an **introduction** is the first app-level key exchange
between two peers. After that they share `RK` and use cheap resumption.

What an introduction needs depends on how much authentication the first
contact must have:

| Introduction mode | Bytes | Active MitM on first contact |
|---|---:|---|
| Unauthenticated (TOFU, like SSH) | ~2.4 KB | Possible, but only at that moment. Later sessions are pinned to `RK`. |
| User-verified SAS (6 digits on both screens) | ~2.4 KB + 2×16 B | Probability ≤ 2⁻²⁰ |
| QR or NFC commitment | ~2.4 KB | Prevented |
| Pre-shared identity (directory, prior channel) | ~2.4 KB | Prevented |

Even TOFU is fully PQ-confidential against passive recording ("harvest now,
decrypt later"). The mode can be chosen per introduction.

Decisions so far:

- Pairwise P2P only.
- Targets: iOS, Android, desktop. All have hardware AES and native
  constant-time libraries.
- No Bluetooth pairing.

## 2. Verified constraints and numbers

| Item | Value | Source / confidence |
|---|---|---|
| ML-KEM-512 / 768 / 1024 (ek, ct) | 800/768, 1184/1088, 1568/1568 B | FIPS 203; high |
| X-Wing (ML-KEM-768 + X25519) | ~1216 / 1120 B; still an IETF draft (-11) | draft-connolly-cfrg-xwing-kem; medium on exact bytes |
| ML-KEM on Cortex-M4 (pqm4 m4fspeed) | 512: 0.39/0.39/0.43 M cycles; 768: 0.64/0.66/0.71 M (keygen/encaps/decaps) | github.com/mupq/pqm4 benchmarks.md; high |
| CSIDH-512 security | Below NIST level 1 (Peikert 2019/725; Bonnetain–Schrottenloher 2018/537) | high |
| CSIDH at level 1 | Needs a much larger prime, roughly 2048–4096-bit class (SQALE, ePrint 2020/1520) | medium |
| CTIDH-512 cost | 125.53 M Skylake cycles per action (ePrint 2021/633) | high |
| Classic McEliece 348864 | pk 261,120 B, **ct 96 B**; NIST didn't select it in 2025 | classic.mceliece.org; high |
| HQC | NIST backup KEM (March 2025); about 100× ML-KEM cycles on M4 | NIST IR 8545, pqm4; high |
| Falcon-512 | pk 897 B, sig 666 B; FIPS 206 (FN-DSA) still in draft. `PROMPT.md` wrongly calls Falcon "FIPS 205", which is SLH-DSA. | falcon-sign.info, NIST; high |
| ML-DSA-44 signature | 2420 B | high |
| Ascon-AEAD128 | NIST SP 800-232 final | high |
| Signal SPQR | ML-KEM ek/ct split into erasure-coded chunks piggybacked on messages | signal.org/blog/spqr; high |
| PQNoise | KEM-based Noise patterns with proofs (ePrint 2022/539) | high |
| BLE | ATT_MTU ≤ 517; LL payload 27 (legacy) / 251 (DLE, 4.2+); LL MIC 4 B; L2CAP CoC on iOS 11+ and Android 10+ | Core spec / platform docs; well known, **not re-fetched** |

Still unverified (search tooling was blocked): published PQC-over-BLE energy
papers, nRF52840 datasheet currents, exact SMAUG-T and Rudraksh sizes.

### Airtime model

Run `python3 docs/research/ble_airtime.py`. It assumes encrypted LL PDUs, DLE,
one ACK per PDU, and no retransmissions.

| Design | Bytes | PDUs @251 | PDUs @27 | 2M PHY | 1M PHY |
|---|---:|---:|---:|---:|---:|
| `PROMPT.md` CSIDH-512 (insecure level) | 146 | 1 | 6 | 1.00 ms | 1.69 ms |
| CSIDH at a level-1 size (est.) | 1042 | 5 | 40 | 6.27 ms | 10.96 ms |
| ML-KEM-512 ephemeral per session | 1608 | 7 | 61 | 9.37 ms | 16.53 ms |
| X-Wing introduction (once) | 2376 | 10 | 90 | 13.70 ms | 24.25 ms |
| **Proposed resume (S1+S2)** | **106** | **1** | **5** | **0.84 ms** | **1.37 ms** |
| Proposed amortized ML-KEM-768 rekey | 2272 | 10 | 86 | 13.29 ms | 23.42 ms |

On BLE, fragmentation is mainly a reliability and implementation problem: GATT
long-write handling and queue overflows on legacy Android stacks. Airtime is
not the issue. L2CAP CoC or a correct GATT operation queue solves the
reliability problem. Still, the proposal keeps every per-connection message to
one PDU.

### NIST security levels

Each NIST category means "at least as hard to break as" a reference problem.

| Level | Reference | KEM | Ratchet epoch bytes (ek+ct) | 2M airtime per epoch |
|---|---|---|---:|---:|
| 1 | AES-128 key search | ML-KEM-512 | 1568 | ~9 ms |
| 2 | SHA-256 collision | (ML-DSA-44, signatures only) | n/a | n/a |
| 3 | AES-192 key search | ML-KEM-768 | 2272 | ~13 ms |
| 4 | SHA-384 collision | (signatures only) | n/a | n/a |
| 5 | AES-256 key search | ML-KEM-1024 | 3136 | ~18 ms (est.) |

Trade-offs:

- **Level 1 (ML-KEM-512)**
  - Pros: smallest and fastest.
  - Cons: smallest margin against future lattice-attack improvements. Its
    estimated Core-SVP hardness is about 118 bits.
  - BSI and some other agencies recommend 768 or higher. This isn't
    re-verified here.
- **Level 3 (ML-KEM-768)**
  - The mainstream default: X-Wing, Signal SPQR, Chrome and Cloudflare
    hybrids. It has a comfortable margin.
  - Cons: about 45% more bytes than level 1.
- **Level 5 (ML-KEM-1024)**
  - Pros: maximum margin. It's required by NSA CNSA 2.0.
  - Cons: twice the bytes of level 1, and slower.

In this design the KEM runs only at introduction and once per amortized
ratchet epoch. Per-connection traffic stays at 106 B regardless of level. All
symmetric keys are 256-bit, which is level-5-equivalent even under Grover. The
level choice therefore costs only about 4–9 ms of airtime per epoch. That makes
**ML-KEM-768 the recommended default**, with ML-KEM-1024 as an option if
CNSA 2.0 matters.

## 3. Problems in the `PROMPT.md` design

| # | Issue | Impact |
|---|---|---|
| P1 | CSIDH-512 is below NIST level 1 quantum security. | It doesn't deliver the claimed PQ security. |
| P2 | At secure sizes, CSIDH keys are about 4–8× larger and the group action is much slower. Neither variant is standardized. | Loses the size advantage and violates S6. |
| P3 | "ML-KEM state engine" seeded from `K_isogeny`: the security is exactly CSIDH's. ML-KEM adds zero entropy and nothing goes over the air. | Security theater, plus extra code and attack surface. |
| P4 | CSIDH is a non-interactive key exchange, not a KEM. "encap/ciphertext" is a second ephemeral public key. | The spec is wrong about its own primitive. |
| P5 | `AuthTag` covers `Session_ID ‖ ciphertext` only, not the client key, nonces, or roles. | A replayed Packet B passes authentication. Identity isn't bound to the session (UKS/replay). |
| P6 | Only the peripheral authenticates. | Any device can open sessions to the peripheral. |
| P7 | `Session_ID` is a constant `0x01`, with no epochs or counters. | No replay protection and no state machine. |
| P8 | A 12-byte explicit IV on every message. | It wastes 12 B per frame; the nonce can be implicit on an ordered channel. |
| P9 | It assumes a PSK anyway. | If a PSK exists, a symmetric ratchet gives PQ security much more cheaply than any asymmetric primitive (§4). |
| P10 | The DoS mitigation still runs about 100 ms of math per unauthenticated packet. | It's cheap to drain a victim's battery. |

## 4. Proposed protocol (working name `pqcble-r1`)

The protocol has three layers. Only the first one needs large public-key
material.

```
 Introduction (once)       Session resume (every connection)       Data
 ┌─────────────────┐       ┌──────────────────────────────┐       ┌──────────────┐
 │ X-Wing KEM      │  RK   │ PSK ratchet CK_n + X25519    │  SK   │ AEAD, 17 B   │
 │ + SAS / QR / NFC├──────►│ 57 B →  ← 49 B (1 RTT)       ├──────►│ implicit nonce│
 └─────────────────┘       └──────────────▲───────────────┘       └──────┬───────┘
                                          │ mix ss into CK                │ piggyback chunks
                                  ┌───────┴──────────────────────────────┘
                                  │ Amortized ML-KEM-768 ratchet (PQ PCS)
                                  └──────────────────────────────────────
```

### 4.1 Introduction: once per peer pair, size doesn't matter

- KEM: X-Wing (ML-KEM-768 + X25519). This is hybrid, so security never drops
  below today's classical security.
- Transport: L2CAP CoC when available, otherwise a queued GATT long write.
- Authentication: one of
  - **OOB**: a QR code or NFC tag carries `H(ek_I)` (32 B). That makes the
    in-band exchange MitM-proof.
  - **SAS**: commit-then-reveal nonces, as in LE Secure Connections numeric
    comparison. Both screens show a 6-digit code `Trunc(H(transcript))`.
    A MitM succeeds with probability ≤ 2⁻²⁰ per attempt.
- Output: root key `RK = KDF(ss, transcript)`, then `CK_0`, a pair ID, and
  pseudonym keys.

### 4.2 Session resume: per connection, one PDU each way

```
S1  I→R : type(1) | pseudonym(8) | eI X25519(32) | mac(16)              = 57 B
S2  R→I : type(1) | eR X25519(32)  | confirm(16)                        = 49 B

ctx       = "pqcble-r1" ‖ pairID ‖ n           # n = epoch counter; bound into EVERY KDF/MAC
pseudonym = PRF(K_id(CK_n), ctx ‖ attempt)[0..8]   # attempt ∈ 0..3; one-shot per try, so retries are unlinkable
mac       = MAC(K_auth_I(CK_n, ctx), "S1" ‖ S1-without-mac)   # checked before ANY asymmetric op
dh        = X25519(eI, eR)
th        = H(S1 ‖ eR)
confirm   = MAC(K_auth_R(CK_n, ctx), "S2" ‖ th)  # separate key, not SK (Dowling–Paterson WireGuard fix)
SK_I→R, SK_R→I = KDF(CK_n, dh, th, ctx, role labels)
CK_{n+1}  = KDF(CK_n, dh, th, ctx, "ratchet")      ; erase CK_n after key confirmation
```

Changes from the prior-art review (§9.3):

- Role labels and `ctx` go inside every KDF and MAC, not just in framing.
  This defeats Selfie/reflection attacks (Drucker–Gueron, ePrint 2019/347;
  RFC 9258 App. A).
- `K_auth_I` and `K_auth_R` are distinct keys.
- A replayed S1 yields nothing, because R contributes a fresh `eR` and the
  attacker lacks `eI`'s secret. The only cost is one X25519 operation, which
  is rate-limited per pseudonym.

- **PQ confidentiality and mutual authentication** come from the 256-bit
  symmetric `CK_n`.
- **PQ forward secrecy** comes from the one-way ratchet with erasure. A device
  stolen later doesn't reveal past sessions.
- **Hybrid healing:** mixing `dh` into `CK_{n+1}` gives classical
  post-compromise security against a passive attacker who stole the state.
- **Desync safety:** R keeps `{CK_n, CK_{n+1}}` until the first valid data
  frame from I arrives. I commits after a valid S2. Losing any single message
  is recoverable, and the forward-secrecy window is one epoch.
- **DoS:** an unauthenticated S1 costs one MAC (microseconds), versus about
  100 ms for CSIDH.
- **Lookup:** the pseudonym gives an O(1) table lookup by a public value.
  There's no trial decryption, so no secret-dependent timing.
- Optional 0-RTT early data under `CK_n`. It's replayable within the desync
  window, so it's restricted to idempotent payloads.

### 4.3 Data frames

```
hdr(1: type|key-phase|pad-class) | ciphertext | tag(16)     # compact profile: tag(8)
nonce = direction(1 bit) ‖ 64-bit counter   (implicit; L2CAP CoC / GATT are ordered and reliable)
```

- AEAD: ChaCha20-Poly1305 (constant-time in software on every target), or
  AES-256-GCM where hardware AES exists. All targets (phones, desktop) have
  either option. Truncated GCM tags are discouraged.
- A truncated tag fails closed: the first failure kills the session. Resuming
  costs only about 1 ms of airtime, so strict failure is affordable.
- Pad to size classes so frames that carry KEM chunks look the same as frames
  that don't.

### 4.4 Amortized PQ ratchet: PQ post-compromise security at almost no per-message cost

- Adapted from Signal SPQR. One side generates an ML-KEM-768 key pair, and the
  `ek` is chunked into the padding slack of encrypted data frames, or flushed
  in idle connection events. The peer encapsulates and returns `ct` the same
  way. Both then set `CK ← KDF(CK, ss, H(ek)‖H(ct), ctx, epoch)`.
  - Explicit `ek`/`ct` binding prevents the KEM re-encapsulation class of
    attacks found in PQXDH (Bhargavan et al., USENIX Sec 2024;
    Fiedler–Günther, ePrint 2024/702).
  - The state machine and its correctness properties should follow Signal's
    ML-KEM Braid (SCKA) spec verbatim rather than ad-hoc chunking.
- The chunks travel inside the AEAD, so they're authenticated, and BLE
  connections are reliable. **Erasure codes are needed only for a future
  connectionless (advertising) mode.**
- Policy is configurable: every N sessions, every T hours, or every M bytes.
  For example, N = 10 adds about 227 B per session on average.
- Cost: about 10 ms of ML-KEM work on a 64 MHz M4 per epoch, and negligible
  work on phones.

### 4.5 Byte comparison per connection

| Design | Handshake bytes | Per-message overhead | PQ secure | PQ FS | PQ PCS | Mutual auth |
|---|---:|---:|:-:|:-:|:-:|:-:|
| `PROMPT.md` | 146 | 28 | ✗ | ✗ | ✗ | ✗ |
| ML-KEM-512 + PSK per session | ~1608 | 17 | ✓ | ✓ | ✓ | ✓ |
| **`pqcble-r1`** | **106** (+~227 amortized) | **17 / 9** | ✓ | ✓ | ✓ (per KEM epoch) | ✓ |

## 5. Alternatives considered

| Option | Verdict |
|---|---|
| Custom compact LWE (Rudraksh, SMAUG-T, aggressive rounding) | Rejected. Not standardized (S6), and it saves only about 30–40% versus ML-KEM-512. Amortization makes that saving irrelevant. |
| Classic McEliece KK with static keys (96 B ct each way) | Interesting: it's KCI-resistant and stateless. Rejected for v1: the 261 KB pk per peer, no NIST selection, and no PQ forward secrecy without a ratchet anyway. Candidate optional profile. |
| Per-session signatures (Falcon, ML-DSA, HAWK) | Unnecessary after introduction. KEM and PSK authentication is smaller. |
| Layering on BLE LE Secure Connections (P-256) only | Classical only. Kept as an outer layer, but the app can't bind to the LTK on iOS. |
| PQNoise patterns (KEM-based Noise) | A good fallback for unpaired first contact (§6). Start from the published proofs. |

## 6. Constant-time and implementation requirements

- Libraries: see §9.5. In short, a shared Rust core over UniFFI using
  `mlkem-native` (with HOL-Light object-code constant-time proofs) plus
  libsodium. CryptoKit is a gated fast path on iOS/macOS ≥ 26.
- Android's JCA has no general ML-KEM API; Conscrypt exposes ML-KEM only as
  TLS groups. JVM ML-KEM through BouncyCastle is *not* guaranteed
  constant-time because of the JIT, so native code is required.
- Protocol code:
  - Constant-time MAC and tag comparison.
  - No branching on secret data.
  - All failures silently dropped with identical timing and uniform typed
    internal reasons (S5).
  - Use ML-KEM implicit rejection.
- Zeroize old `CK`, decapsulation keys, and session keys. Persist the ratchet
  state atomically (write-ahead) so a crash can't fork the state.
- Known inherent limits:
  - PSK-based authentication is **not KCI-resistant**. Someone who steals A's
    state can impersonate B to A until the next KEM epoch heals it.
  - There is no non-repudiation. Deniability is a feature here.

## 7. Validation plan

1. Formal model in Tamarin or ProVerif covering secrecy, mutual
   authentication, forward secrecy, post-compromise security, and desync, for
   S1/S2, the ratchet, and the KEM epoch.
2. Known-answer vectors for every message type. Wycheproof and ACVP vectors for
   the primitives.
3. Adversarial tests (T10): truncated, replayed, reordered, and cross-epoch
   frames, and desync after every possible drop point.
4. Constant-time checks with `dudect`/`ctgrind`-style analysis on the
   protocol layer, plus verification of on-device benchmarks (P1–P2).
5. External cryptographic review before any release (S6).

## 8. Open questions (need product decisions)

- Minimum OS versions. Native CryptoKit PQ needs iOS/macOS 26; anything older
  requires bundled native crypto.
- Is an Android/desktop "bridge" acceptable for iOS↔iOS background
  discovery, or is foreground-only discovery acceptable on iOS?
- Should the KCI-resistant profile ship in v1? It adds a static ML-KEM KEM per
  session, about +1.1 KB.
- Is FIPS 140-3 required? No active certificate covering ML-KEM could be
  confirmed (§9.5).
- Kotlin Multiplatform shell plus a Rust core (UniFFI), or a pure-native
  shell per platform?

## 9. Deep research results (round 2)

Security level decided: **ML-KEM-768 (L3)**. Topology decided: pairwise P2P.
Platforms: iOS, Android, desktop.

### 9.1 Background discovery

| Platform | Finding | Consequence |
|---|---|---|
| iOS background peripheral | Local name dropped; service UUIDs moved to the "overflow area", visible only to iOS centrals explicitly scanning for that UUID. | No custom beacon data while backgrounded. |
| iOS background central | Scans coalesced and throttled; duplicate filtering forced on. | **Two backgrounded iPhones won't reliably find each other.** |
| iOS foreground advertising | About 28 B: local name plus service UUIDs only; no manufacturer or service data. Extended advertising not exposed to apps. | Beacon must be encoded in a 128-bit service UUID or the local name. |
| iOS state restoration | The system relaunches the app for matching BLE events. | Resume can run without user action once connected. |
| Android 12+ | `BLUETOOTH_SCAN` with `neverForLocation`, plus `ADVERTISE`/`CONNECT`. Screen-off scans need filters. Android 14 needs the `connectedDevice` FGS type. Extended and periodic advertising via `startAdvertisingSet` when supported. | Android is the most capable always-on peer. |
| Windows | Publisher is "best effort" and contended. Flags and UUID-list AD types are reserved; only manufacturer data and custom types are allowed. | Use manufacturer-data beacons and expect retries. |
| Linux BlueZ | `LEAdvertisement1` with service, manufacturer, and raw data, scan response, and `SecondaryChannel` (extended advertising). | Full control. |
| Exposure Notification / AccessorySetupKit | OS-entitled or accessory-only; not usable for app P2P. | Not applicable. |

**Discovery strategy:**

1. Beacon via service data or manufacturer data on Android, Windows, Linux,
   and macOS. Use a rotating 128-bit service UUID on iOS in the foreground.
2. When an iOS peer is backgrounded, it advertises only a *fixed* app UUID.
   Any central connects and reads a GATT "beacon" characteristic, then
   resumes. The fixed UUID reveals the app, but link-layer RPAs still rotate.
3. iOS↔iOS with both apps backgrounded is unsupported unless an
   Android/desktop peer bridges. This is to be validated on devices.

### 9.2 Unlinkable beacons (only introduced peers can recognize them)

```
BK_d   = KDF(RK, "beacon", day d)  ; one-way daily chain, erased after use (forward privacy)
beacon = Trunc_8..16(PRF(BK_d, role ‖ window w))     window = 5 min
```

- The receiver precomputes `{w−1, w, w+1}` for each of N peers, so 3N table
  entries give an O(1) hash lookup. Skew of ±5 min is tolerated.
- The beacon chain is independent of `CK`, so a ratchet desync never breaks
  discovery.
- A beacon proves nothing; it's only a hint. Relay and replay within a window
  are possible. Authentication comes from S1/S2. App-level BLE can't do
  distance bounding.
- Change the beacon and the BLE address together where the platform allows,
  because Becker et al. (PETS 2019) tracked devices across asynchronous
  rotations. On iOS and Android the app can't control RPA timing, which is a
  residual risk.
- Unlike AirDrop (PrivateDrop, USENIX Sec 2021), the beacon is keyed by a
  256-bit secret, so it can't be brute-forced from low-entropy identifiers.

### 9.3 Prior art and hardening of S1/S2

| Prior art | What it gives `pqcble-r1` |
|---|---|
| TLS 1.3 `psk_dhe_ke` (RFC 8446) | S1/S2 has the same shape: a PSK plus fresh DH. 0-RTT is replayable by design. |
| Aviram–Gellert–Jager (ePrint 2019/228) | Formal forward security of resumption needs single-use (puncturable) credentials. Single use of `CK_n` is a MUST. |
| RFC 9258 + Drucker–Gueron Selfie (ePrint 2019/347) | Bind roles and context into every KDF. **Applied in §4.2.** |
| Dowling–Paterson WireGuard (ePrint 2018/080) | Use an explicit, separately keyed confirmation. **Applied: `K_auth_R`.** |
| Alwen–Coretti–Dodis (ePrint 2018/1037) | FS-AEAD plus CKA as the target security notions for the ratchet. |
| Signal ML-KEM Braid / SPQR | SCKA state machine and correctness properties for the §4.4 KEM epochs. |
| PQXDH analyses (USENIX Sec 2024; ePrint 2024/702) | KEM binding and domain separation. **Applied in §4.4.** |
| Rosenpass (ProVerif; "biscuit" stateless responder) | Option: R echoes encrypted pending state instead of storing `{CK_n, CK_{n+1}}`. |
| Apple PQ3 | "Level 3" target: PQ at setup and ongoing PQ rekeying. `pqcble-r1` matches. |

Further rules from the pitfall analysis:

- **Rollback:**
  - Ratchet state must never enter backups: use iOS
    `…ThisDeviceOnly` keychain items and Android Keystore-wrapped no-backup
    storage.
  - A device that can't prove its epoch counter is monotonic must
    re-introduce, never resume.
- **Forward-secrecy window:** keep `CK_n` only until the first valid frame
  from I. The window is bounded by one connection setup.
- **KCI:** inherent to PSK authentication. Optional profile: each peer holds a
  static ML-KEM-768 key, and S1/S2 add a KEM ciphertext to the peer's static
  key. That's KCI-resistant (KK pattern) at about +1.1 KB per session.

### 9.4 Introduction modes (UX)

| Mode | Security | Usability evidence | Recommendation |
|---|---|---|---|
| QR scan of `H(ek)‖pairing nonce` | Strong, needs no user comparison | Lowest error | **Default when co-located** |
| SAS, 6 digits, commit-then-reveal over the full transcript (Vaudenay SAS-MCA; MANA-IV needs non-malleable commitments) | 2⁻²⁰ per attempt | Long fingerprint comparison fails often (Vaziripour et al., SOUPS 2017). Emoji/word SAS helps (Matrix). | Fallback. Show digits plus emoji. Never use Passkey-Entry-style bit-by-bit. |
| TOFU | No active-MitM protection at first contact; PQ-passive-secure | Zero friction | Allowed only when flagged "unverified" in the UI, with a later SAS/QR upgrade |

### 9.5 Constant-time library matrix

| Primitive | iOS/macOS ≥ 26 | iOS/macOS < 26, Android, desktop |
|---|---|---|
| ML-KEM-768 | CryptoKit `MLKEM768` (corecrypto; Isabelle functional-correctness proofs) | `mlkem-native` (CBMC plus HOL-Light constant-time proofs for asm; in AWS-LC and liboqs) |
| X-Wing | CryptoKit `XWingMLKEM768X25519` (**cites draft -06**) | Compose it from `mlkem-native` plus X25519 per the draft. RustCrypto `x-wing` is unaudited. |
| X25519, ChaCha20-Poly1305, AES-GCM, HKDF, HMAC | CryptoKit | libsodium / RustCrypto |

Notes:

- Binding: one Rust core exposed via UniFFI to Kotlin (cargo-ndk) and Swift,
  following the Signal and Mozilla precedent.
- **Interop risk:** CryptoKit implements X-Wing draft -06 while the draft is
  at -11. Cross-check with test vectors before relying on it.
- FIPS 140-3: no active certificate covering ML-KEM was confirmed. AWS-LC-FIPS
  v4.0 is "in process".
- Constant-time CI:
  - `dudect` per target ABI.
  - valgrind secret-taint checks, the same pattern as `mlkem-native` CI.
  - Binsec/Rel for the pre-release audit.

### 9.6 Energy: what the measurements say

- Liu, Ramachandran, Jurdak (arXiv 2602.18708, 2026) measured ML-KEM-512, 768,
  and 1024 on an nRF52840 with a PPK2 over BLE 1M.
  - **Radio was 57–63% of PQ key-exchange energy with small PDUs.** With DLE
    it falls to about 37%.
  - DLE alone cuts the total by 25–34%.
  - PQ key exchange costs 2.5–8.5× more than ECDH pairing.
- Back-of-envelope for ML-KEM-768 on a 64 MHz M4: about 31 ms of compute
  versus about 13 ms of 2M airtime. That's the same order of magnitude.
- **Both claims in `PROMPT.md` are wrong as blanket statements.** Radio
  doesn't dominate "by orders of magnitude", and compute isn't free. The
  winning move is avoiding *both* per connection. `pqcble-r1` does that: about
  0.1 ms of X25519 work plus 106 B on air per resume.
- No phone-side measurements were found. They need our own benchmarks (P1/P2).

### 9.7 Connectionless (advertising-only) messaging

- iOS can send only legacy-style foreground advertising, with about 20 usable
  bytes encoded as a UUID or name. Extended advertising (up to 1650 B,
  chained) works only on Android (if supported), Linux, and possibly Windows.
- **Verdict:** connectionless use should be a **"doorbell"** only, not a
  message transport.

  ```
  nudge = beacon(8) ‖ ctr(4) ‖ AEAD(K_nudge, ctr, flags(1–4)) tag(8)   ≈ 21–24 B
  ```

  - Replay protection: a strictly increasing `ctr` per sender, as with
    Bluetooth Mesh SEQ/IV.
  - Loss: tolerated through idempotent re-broadcast.
- Bluetooth 5.4 Encrypted Advertising Data (AES-CCM, randomizer plus MIC) is
  the matching standard. Its exact byte layout is still unverified (the spec
  is behind SIG access).

### 9.8 Remaining unverified items

- Exact BLE core numbers (517 MTU, EAD layout, Mesh NetMIC) were not re-fetched
  from the SIG spec.
- nRF52840 datasheet currents were blocked by bot protection.
- iOS rotating-UUID beacons and iOS↔iOS background discovery need **on-device
  experiments**.
- Whether X-Wing changed between draft -06 and -11 is unknown.
