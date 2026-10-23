# BLE mesh design pivot: prior art and options — 2026-10-23

Status: research draft, not an approved design. Any adoption requires an ADR
(Constitution O3), a new or extended formal model, and expert review (S6).
Nothing here changes `cairn-r1` ([spec](../spec/cairn-r1.md),
[threat model](../spec/threat-model.md), ADRs 0001–0009).

## Question

The owner has decided to pivot `cairn` from pairwise contact-to-contact
messaging to a peer-to-peer BLE **mesh**, where pairing starts automatically
the instant a new peer is found (always-auto-TOFU, no pairing screen, no user
action), and any connected peer can participate in the network. What does
prior art (Bluetooth Mesh, Briar, Bridgefy, BitChat, Meshtastic, and adjacent
systems) teach about admission, identity, multi-hop end-to-end encryption,
routing and abuse in exactly this setting, and what architecture options does
that give `cairn`, concretely against the existing threat model's adversaries
A1–A7 and with real wire sizes computed from the existing crypto suite
(ADR 0001)? This is research only: no spec or ADR changes, no code.

## TL;DR

Every mesh system that lets strangers auto-admit into message relaying
either (a) gives up strong peer authentication at first contact (Bluetooth
Mesh's provisioning, Meshtastic's TOFU node keys, BitChat's cleartext
identity announcements) or (b) keeps strangers as **routers only**, with
end-to-end encryption and trust restricted to an explicit social graph
(Briar's contacts-only model). No system in this review safely combines
"instant, unattended trust" with "end-to-end-authenticated, PQ, small
payload" messaging; `cairn-r1`'s own X-Wing/ML-KEM-768 handshake (1251/1137 B,
[spec §5.1](../spec/cairn-r1.md#51-messages)) is already far larger than any
mesh system's per-link admission message, and that gap gets worse, not
better, once sealing has to reach a *non-adjacent* peer. The owner's
always-auto-TOFU requirement is a direct, explicit conflict with
[threat model §5](../spec/threat-model.md#5-availability-best-effort)
("Pairing is accepted only while the user has a pairing screen open") and
with [ADR 0009](../adr/0009-pairing-ux.md)'s UX decision that TOFU is a
secondary, discouraged link — both must change, and the threat model's
A1/A3/A7 rows need new entries for a per-hop asymmetric-operation attacker
that no longer needs a user to tap anything. §3 below lays out three
concrete architecture options, each reusing different parts of `cairn-r1`
and each with different consequences for the threat model's adversary table.

---

## 1. Prior art

### 1.1 Bluetooth SIG Mesh Protocol (managed flooding, provisioning, keys)

Primary source: Bluetooth Mesh Protocol v1.1, adopted 2023-09-12, Mesh
Working Group
([spec index](https://www.bluetooth.com/specifications/specs/mesh-protocol/),
[HTML](https://www.bluetooth.com/specifications/specs/html/?src=MshPRT_v1.1/out/en/index-en.html)).

- **Admission ("provisioning").** A device starts **unprovisioned** (cannot
  send/receive mesh messages, only advertises presence). A **Provisioner**
  (typically a phone) runs an authenticated key exchange derived from the
  Bluetooth Core Security Manager Protocol, adapted for minimal-UI devices
  (a blinking light counts as an out-of-band factor), and hands it a
  **network key** and a **unicast address**, making it a **node**
  (§2.2.2–§2.2.3). This is explicit, operator-driven admission — the
  opposite of auto-admission; there is no TOFU mode in the spec.
- **Trust/key model.** Nodes on a subnet share one **network key**; a
  **Configuration Manager** separately provisions per-application
  **application keys** and a per-node **device key** (§2.2.1, §3.9.6.1–.4).
  Relaying only needs the network key (a relay decrypts/re-encrypts the
  *network* layer); application payloads stay opaque to a relay unless it
  also holds the app key. This is a **shared-secret mesh**, not a pairwise
  end-to-end one: every network-key holder reads traffic metadata
  (TTL, addresses), and anyone with an app key (which can be shared
  mesh-wide) reads that app's payloads.
- **Routing: managed flooding.** Every Network PDU carries a 7-bit **TTL**
  and a 24-bit **SEQ** in a fixed header — `IVI(1) | NID(7) | CTL(1) |
  TTL(7) | SEQ(24) | SRC(16) | DST(16) | TransportPDU | NetMIC(32/64)`
  (§3.4.4, Table 3.10, confirmed directly from spec text). Relays decrement
  TTL, drop at 0; a cache suppresses an already-seen `(SRC, SEQ)`. No
  routing table is needed.
- **IV index.** A 32-bit mesh-wide anti-replay counter, incremented via a
  slow, rate-limited **IV Update procedure** propagated from the **primary
  subnet** (§3.11.5) — a mesh-wide clock every node must track or desync.
- **Low-power/friend nodes.** A **Low Power Node** sleeps and polls one
  **Friend Node** that caches/forwards on its behalf (§2.2.5, §3.6.6) — a
  built-in store-and-forward relationship between two specific nodes, not
  every peer.
- **Privacy.** v1.1 added **Private Beacons** and **Directed Forwarding**
  (v1.0.1→v1.1 changelog, same URL) specifically to reduce plaintext beacon
  broadcast and avoid full flooding — an acknowledgement that the original
  always-flood, always-beacon model leaked too much to passive observers.
- **Trust model, summarized:** a **managed, operator-admitted mesh** —
  strong admission control, weak payload confidentiality from the relays'
  point of view, no attempt at auto-trust between strangers. It is the
  clearest primary-source case that "anyone can relay" and "relays can
  decrypt" are deliberately paired in this design family; `cairn`'s owner
  wants auto-admission *without* giving relays decryption, a harder
  combination this spec does not attempt.

### 1.2 Briar / Bramble protocol suite (contacts-only, multi-transport)

Primary sources: Bramble Handshake Protocol (BHP) v0.1 and Bramble
Transport Protocol (BTP) v4
([index](https://code.briarproject.org/briar/briar-spec/raw/master/README.md),
[BHP](https://code.briarproject.org/briar/briar-spec/raw/master/protocols/BHP.md),
[BTP](https://code.briarproject.org/briar/briar-spec/raw/master/protocols/BTP.md)).

- **Contacts-only, explicit admission.** BHP requires the two peers to have
  *already exchanged long-term public keys*; it "does not specify how this
  should be done" and warns that if an adversary replaced those keys during
  that prior exchange, BHP "does not detect or prevent man-in-the-middle
  attacks" (BHP §1.1). Briar's QR protocol (BQP) and Rendezvous Protocol
  (BRP) are the actual out-of-band mechanisms (listed in the index, not
  fetched here — **Unverified** wire detail). There is no TOFU and no
  stranger admission at the handshake layer: Briar's mesh only ever carries
  traffic between devices whose owners already became contacts.
- **Transport design.** BTP separates **concealability** (no distinguishing
  plaintext headers) from confidentiality/integrity/authenticity/forward
  secrecy, with an explicit adversary model: "The adversary can observe,
  block, delay, replay and modify traffic on all underlying transports"
  (BTP §1.3). Forward secrecy comes from a root key plus a one-way KDF
  deriving successive temporary keys (BTP §1).
- **Multi-transport, not multi-hop-through-strangers.** BTP runs "over any
  transport that can deliver... bytes... on a best-effort basis," including
  Bluetooth, Wi-Fi, Tor, or "disks sent through the mail" (BTP §1.1–1.2).
  Briar's "mesh" property is carrying one contact relationship across many
  transports and via store-and-forward through a contact's own other
  devices, not routing through arbitrary non-contact strangers' phones the
  way Bluetooth Mesh or BitChat do (architecture page referenced from the
  index; **Unverified** — its full content did not render as plain text in
  this pass and was not re-fetched as raw HTML).
- **Relevance to `cairn`:** the strongest precedent for "keep strong
  pairwise authentication, add transport flexibility, never auto-trust a
  stranger" — essentially option (iii) in §3, generalized across
  transports.

### 1.3 Bridgefy and the two published breaks

Primary sources: Albrecht, Blasco, Jensen, Mareková, *"Mesh Messaging in
Large-scale Protests: Breaking Bridgefy"*, CT-RSA 2021
([eprint 2021/214](https://eprint.iacr.org/2021/214), DOI
10.1007/978-3-030-75539-3_16); Albrecht, Eikenberg, Paterson, *"Breaking
Bridgefy, again: Adopting libsignal is not enough"*, USENIX Security 2022
([conference page](https://www.usenix.org/conference/usenixsecurity22/presentation/albrecht)).

- **CT-RSA 2021 (original Bridgefy):** the abstract states the protocol, as
  analysed, "permitted its users to be tracked, offered no authenticity, no
  effective confidentiality protections and lacked resilience against
  adversarially crafted messages," letting an adversary "produce social
  graphs about them, read their messages, impersonate anyone to anyone and
  shut down the entire network with a single maliciously crafted message."
  The canonical case study that a protest-oriented BLE mesh can fail at
  confidentiality, authenticity, tracking-resistance *and* availability
  simultaneously if the crypto design is weak.
- **USENIX Security 2022 (post-libsignal fix):** after Bridgefy adopted
  Signal/libsignal's double ratchet, the follow-up found (abstract):
  "(i) the protocol persisted to be susceptible to an active
  attacker-in-the-middle, (ii) an adversary continued to be able to
  impersonate other users in the broadcast channel..., (iii) the DoS attack
  using a decompression bomb was still applicable..., and (iv) the privacy
  issues of Bridgefy remained largely unresolved," plus a new TOCTOU attack
  that "side-steps Signal's guarantees."
- **Takeaway:** bolting a well-audited pairwise ratchet onto a mesh does
  **not** by itself fix authentication-at-admission, broadcast-channel
  impersonation, or DoS — those are properties of *how peers are admitted
  and how broadcast/relay keys are shared*, exactly the question the
  owner's auto-TOFU decision raises. "Adopting libsignal is not enough" is
  a direct warning against assuming good pairwise crypto suffices once the
  surrounding admission/broadcast protocol is unverified.

### 1.4 BitChat (Jack Dorsey / permissionlesstech, 2025)

Primary source: `permissionlesstech/bitchat` Protocol Whitepaper v2.0,
2026-07-06
([WHITEPAPER.md](https://github.com/permissionlesstech/bitchat/blob/main/WHITEPAPER.md)).
**Unverified**: no third-party published security analysis of BitChat was
found in this pass — a gap worth flagging, since this is the most
structurally similar prior art to `cairn`'s pivot.

- **Architecture.** "Every device is simultaneously a GATT central and
  peripheral, relaying packets in a controlled flood. No infrastructure,
  pairing, or accounts" (§2) — the architecture the owner is asking
  `cairn` to move toward.
- **Identity is long-term and auto-exposed.** A permanent Curve25519 static
  key (Noise identity) and Ed25519 signing key per device; the 8 B on-mesh
  peer ID is "the first 8 bytes of the SHA-256 fingerprint of the device's
  Noise static key," stable across sessions, reboots, reinstalls (§3).
  Critically: "Signed announcements additionally carry the nickname, the
  Noise static public key, and the Ed25519 signing public key **in
  cleartext**... so a passive receiver in radio range can link a device
  across time and place regardless of the peer ID. **Unlinkable presence is
  not a property this protocol currently provides**" (§3) — a self-reported
  A6-style tracking failure versus `cairn-r1`'s beacon design
  ([ADR 0005](../adr/0005-wire-format.md), threat model row A6).
- **Admission is instant and automatic** (no pairing step), matching the
  owner's requirement; authentication is per-message, not per-admission:
  announcements are signed, live sessions use Noise **XX** (mutual auth,
  forward secrecy), offline "courier" mail uses Noise **X** sealed to the
  recipient's static key with **no forward secrecy** — flagged by the
  whitepaper itself as a risk (§5.1–5.2, §8).
- **Flood control, concretely (§4.2):** packets start at **TTL 7**; a relay
  with ≥6 live links clamps outgoing TTL to 5, one with ≤2 links relays at
  full incoming depth; an LRU seen-set (1000 entries, 5-minute expiry,
  keyed on sender+timestamp+type+payload digest) deduplicates; relay jitter
  is random 10–220 ms; broadcast fanout subsets to roughly log₂(degree) of
  links excluding the ingress link ("split horizon"), while directed
  traffic (handshakes, private messages, courier envelopes) relays
  deterministically at TTL−1 with tight jitter and full fanout. The most
  concrete, primary-sourced managed-flooding parameter set found in this
  review, directly transferable to a `cairn` mesh.
- **Routing beyond flood (§4.3):** announcements carry up to 10
  direct-neighbor IDs (60 s-fresh, one-hop topology); a bidirectionally-
  confirmed path is source-routed, else flooding.
- **Store-and-forward, layered (§6):** (1) per-peer sender outbox (100
  msgs, 24 h TTL, 8 resend attempts); (2) **couriers** — up to 3 connected
  peers carry a sealed envelope addressed by "an opaque... 16-byte rotating
  recipient tag" (HMAC of the recipient's static key and the UTC day,
  unlinkable to couriers), a "spray and wait" copy budget (starts at 4,
  capped at 8, halved on each handover), trust-tiered deposit quotas
  (favorites: 5 slots each; any verified peer: 2, into a 20-of-40 shared
  pool); (3) gossip-synced public history via compact GCS filters, ~15 s
  cadence, 6 h retention; (4) Nostr relay mailboxes for mutual favorites.
- **Self-reported security considerations (§8):** "Relay nodes cannot read
  private traffic." "A malicious courier can drop mail... but cannot read
  it, link it across days, or amplify it." "Flooding abuse is bounded by
  TTL clamps, deduplication, per-depositor quotas, connect-rate limits, and
  announce-rate limiting." Most relevant to the pivot: "**Metadata is the
  weakest part of this design, and the peer ID does not help**" — the
  stable ID plus cleartext announcements let a passive listener "enumerate
  participants and follow a device between places," and the neighbor list
  "hands a single sniffer the local adjacency graph." §9 lists "rotating
  on-air identity" as unsolved, acknowledged future work.
- **Takeaway:** BitChat proves instant, automatic mesh admission is
  achievable, but its own authors have *not* solved unlinkable presence or
  forward-secret offline sealing — exactly the two properties `cairn-r1`
  already provides for pairwise contacts (ADR 0005 beacons; ADR 0002
  message-key chain) that a naive port of BitChat's architecture would
  lose.

### 1.5 Meshtastic (LoRa; channel-key/PKI model and limitations)

Primary sources: Meshtastic docs, "Encryption"
([meshtastic.org/docs/overview/encryption](https://meshtastic.org/docs/overview/encryption/))
and "Known Limitations"
([meshtastic.org/docs/about/overview/encryption/limitations](https://meshtastic.org/docs/about/overview/encryption/limitations/)).
LoRa, not BLE, but directly relevant: its admission/identity model is TOFU
over an open broadcast medium — structurally the owner's request.

- **Two trust tiers.** Channel messages use a channel-wide PSK with
  AES-CTR (unauthenticated; anyone with the PSK can forge as anyone else)
  or, since firmware 2.8.1, optional AES-CCM/AEAD. Direct messages (since
  2.5) use per-node X25519 keys: "The sender combines its private key with
  the recipient's public key using X25519... That key encrypts the message
  with AES-256-CCM." Broadcasts can carry a 66 B XEdDSA signature (2.8+);
  oversized broadcasts ship unsigned, and unsigned-traffic policy is
  per-node configurable (default: accept). Direct messages are **not**
  themselves signed — "the shared key already shows who sent them," a
  KCI-style assumption, not an unforgeable signature.
- **Node identity and TOFU, explicitly acknowledged as forced:** "Nodes
  trust the first public key they hear for a node number, because there is
  no central authority to vouch for keys." The limitations page states
  plainly this is "by necessity... essentially a hard requirement of a
  decentralized mesh network," then documents the resulting attack:
  constrained NodeDB memory (120 nodes typical, oldest/least-interesting
  evicted, favorites exempt) means "an attacker on the channel can quickly
  create fake nodes, and cause legitimate nodes to roll off the NodeDB
  sooner," after which a spoofed key cannot be detected — "anticipated...
  and accepted as an inevitable result of building an ad-hoc, decentralized
  mesh." Node numbers are a CRC-32 of the public key, not globally unique
  or authenticated by construction.
- **Takeaway:** Meshtastic consciously accepted TOFU-with-eviction-driven
  impersonation as the cost of decentralized, unattended, any-stranger
  mesh admission, and documents it candidly rather than claiming it away —
  direct validation that always-auto-TOFU at scale creates a Sybil/
  impersonation problem needing an explicit owner tradeoff, not a protocol
  tweak.

### 1.6 Berty/Wesh, Serval, FireChat

No primary specification, whitepaper, or source repository for any of these
three was retrieved in this time-boxed pass (**Unverified** — not confirmed
absent, only not found). Berty's "Wesh" protocol (libp2p-based,
contact-graph end-to-end claims) is the closest conceptual peer to option
(iii) below and should be read directly before any design decision leans
on it.

### 1.7 Apple Find My offline finding (relay/privacy reference)

Primary source: Heinrich, Hollick, Stute et al. (TU Darmstadt), *"Who Can
Find My Devices? Security and Privacy of Apple's Crowd-Sourced Bluetooth
Location Tracking System"*, PETS 2021
([arXiv:2103.02282](https://arxiv.org/abs/2103.02282)) — a peer-reviewed
reverse-engineering, since Apple's own whitepaper PDF 404'd in this pass
(**Unverified** against Apple's original text).

- Any nearby Apple device (a "finder," not the owner) silently relays an
  encrypted location report for a device it has never met, using only a
  rotating public key overheard in a BLE advertisement; the finder learns
  nothing of the content, the owner learns nothing of the finder (abstract:
  "OF aims to ensure finder anonymity, untrackability of owner devices, and
  confidentiality of location reports"). The strongest precedent that
  **anonymous, unattested relaying by strangers can work for a narrow,
  well-specified payload** — it is a relay, never a mesh member admitted
  into a shared keyspace, and it never decrypts. Find My's owner/finder
  never mutually authenticate or become peers, so the analogy to `cairn`
  is limited to "relay without trust and without decrypting" (§2.d/§2.c),
  not to admission.
- Even so, the paper "discover[ed] two distinct design and implementation
  flaws that can lead to a location correlation attack and unauthorized
  access to the location history of the past seven days" (abstract),
  later partially fixed by Apple — a caution that a careful, narrowly
  scoped anonymous-relay design still had real gaps between stated goals
  and implementation.

### 1.8 Google/Apple Exposure Notification (rotating identifiers, tracking reference)

Primary source: the joint Apple/Google announcement
([covid19.apple.com/contacttracing](https://covid19.apple.com/contacttracing));
the full cryptography specification PDF linked from that page was not
textually extracted in this pass (**Unverified** at the byte-layout level,
cited for the architectural claim only). The publicly stated design
broadcasts frequently rotating Bluetooth identifiers derived one-way from a
private daily key, so passive observers cannot link a device across
rotations without that day's key — the architecture `cairn-r1`'s own beacon
already follows (a rotating HMAC-derived 8 B beacon,
[ADR 0005](../adr/0005-wire-format.md)), cited here only as the public
reference point for "rotating identifier as the standard answer to passive
BLE tracking," which the mesh pivot must preserve or explicitly give up.

---

## 2. Design questions for `cairn`

### 2.a Admission under always-auto-TOFU

- **Role assignment without a user pick.** `cairn-r1`'s pairing role (A/B)
  is currently assigned by who shows/scans a QR, or by user pick in SAS/
  TOFU mode ([ADR 0009 amendment](../adr/0009-pairing-ux.md#amendments),
  OI-20). With no user action, role must derive from data both sides
  already have at first contact. Briar's BHP assigns Alice/Bob
  "according to the lexicographic order of their long-term public keys,
  compared as byte strings" (BHP §1.2) — a deterministic, symmetric,
  zero-coordination tie-break. Bluetooth Mesh avoids the question entirely
  (a human Provisioner always initiates, §1.1). A `cairn` auto-TOFU design
  should adopt Briar's lexicographic rule rather than invent a new
  coordination message — it is already a verified pattern, and free.
- **Simultaneous mutual connection tie-break.** `cairn-r1` already has this
  rule for Resume ("the attempt whose I is pairing role A wins,"
  [spec §6](../spec/cairn-r1.md#6-resume), OI-17); the same deterministic
  key-ordering tie-break generalizes directly to first-contact admission if
  role is assigned the Briar way.
- **Rate limiting pre-auth asymmetric work from strangers** is the
  sharpest new problem. `cairn-r1`'s threat model states the current
  invariant precisely: "Before authentication, an attacker can make the
  device do at most one MAC per S1. No asymmetric operation happens before
  the MAC check" ([threat model §5](../spec/threat-model.md#5-availability-best-effort)).
  That holds only because Resume is run against an *existing* contact with
  a pre-shared MAC key; at first contact with a stranger there is no
  pre-shared key, so an X-Wing/ML-KEM decapsulation (a real asymmetric op,
  [spec §5.2](../spec/cairn-r1.md#52-computation)) must run before any
  authentication exists. Every reviewed system that auto-admits strangers
  pays this cost somewhere: Bluetooth Mesh avoids it via a human
  Provisioner (no stranger auto-admits); Meshtastic avoids it by using no
  per-admission asymmetric handshake at all (bare X25519 announced
  in-band); BitChat pays it on every live connection via Noise XX (a cheap
  DH, but still asymmetric work for an unauthenticated peer, §5.1). A
  `cairn` mesh must budget/cap concurrent unauthenticated admissions
  explicitly (the existing cap in
  [ADR 0003 §4.4](../adr/0003-ble-transport.md#44-limits) — "Implementations
  MUST cap the number of concurrent unauthenticated links" — needs a
  parallel, likely much lower, cap for KEM-decapsulating first contacts),
  and should prefer a cheaper first-contact primitive (X25519-only, as
  Meshtastic and BHP both do), amortizing the PQ KEM afterward the way
  `cairn-r1`'s own PQ ratchet already amortizes ML-KEM-768 chunks into
  DATA-frame padding post-Resume ([ADR 0005](../adr/0005-wire-format.md)).
- **Sybil resistance.** No TOFU-based system reviewed solves this;
  Meshtastic documents it as an accepted, unsolved cost of decentralization
  (§1.5). An always-auto-TOFU `cairn` inherits the same problem: a
  well-resourced attacker can flood a location with fabricated "peers,"
  each admitted automatically and consuming a slot in whatever
  per-stranger memory/rate structure exists. The only mitigations found
  are capacity bounds with LRU eviction (Meshtastic's NodeDB, BitChat's
  1000-entry dedup cache) plus per-address/per-identity rate limits
  (`cairn-r1`'s existing per-pseudonym/per-address/global limits,
  [threat model §5](../spec/threat-model.md#5-availability-best-effort),
  generalize directly) — none is cryptographic Sybil resistance, only
  resource bounding.
- **What "member of the network" means.** Two qualitatively different
  answers: (1) **open network** (Bluetooth Mesh, BitChat, Meshtastic): any
  device speaking the protocol and holding whatever minimal shared secret
  exists can relay and often decrypt some traffic; (2) **bounded,
  contacts-only network** (Briar): only devices whose owners previously,
  explicitly became contacts ever share keys; strangers never enter the
  trust graph even if they physically relay bytes. The owner's "becomes
  part of the network instantly" language reads as (1); §3 gives one
  option matching each plus a hybrid.
- **Whether a network/group secret is needed.** Bluetooth Mesh's network
  key is the clearest case for "yes, one shared secret buys cheap
  relay-layer authentication and anti-spam, at the cost of every member
  being able to forge/replay at the network layer within TTL/SEQ bounds."
  `cairn-r1` has no precedent for a group secret today (every secret is
  pairwise, [ADR 0001](../adr/0001-crypto-suite.md)); introducing one, even
  for hop-authentication only, is a new trust primitive the formal models
  (§2.f) do not yet cover.

### 2.b Identity

- **No PQ signatures in the suite.** `cairn-r1` deliberately has none:
  "Signatures: **None.** Authentication comes from pairing verification
  plus MAC/KEM" ([ADR 0001](../adr/0001-crypto-suite.md)), with ML-DSA-65
  rejected for its "1952 B public keys and 3309 B signatures, with no
  benefit for pairwise, in-person-verified peers" (same ADR). A mesh where
  a peer authenticates itself to a *non-adjacent* party it never meets
  changes that calculus: pairwise, in-person SAS/QR verification
  ([spec §5.3](../spec/cairn-r1.md#53-verification-codes)) cannot, by
  construction, happen several hops away. The three systems reviewed that
  authenticate non-adjacent/asynchronous peers all use a long-term
  asymmetric identity key checked directly by the recipient: BitChat's
  Ed25519 signing key over every announcement (§3); Meshtastic's
  XEdDSA-signed broadcasts (firmware 2.8+); Signal's PQXDH, which still
  signs the classical prekey bundle with XEdDSA, relying on "the hardness
  of the discrete log problem for mutual authentication in this revision
  of the protocol" even though its KEM secret is post-quantum
  ([PQXDH spec §1](https://signal.org/docs/specifications/pqxdh/)). None is
  a PQ signature; all accept a classical-signature identity layer
  specifically because PQ signatures are too large for their wire budgets
  — matching ADR 0001's rationale almost exactly.
- **KEM-only authentication as the PQ-consistent alternative.** PQXDH's
  security considerations state its mutual authentication still rests on
  classical EC identity keys (XEdDSA) even though *forward secrecy* is
  already post-quantum via the pqkem (PQXDH spec §4.1, §4.6–4.8) — it is
  not, as shipped, KEM-only-authenticated. `cairn-r1`'s own
  **KCI-resistant profile** is the closest thing here to "authenticate with
  a static KEM key": an opted-in contact exchanges a **static ML-KEM-768
  key** at pairing, and each of Resume's S1/S2 adds one `MLKEM.Encaps`
  ciphertext keyed to it ([spec §6, "KCI profile"](../spec/cairn-r1.md#6-resume),
  "S1 1145 B, S2 1137 B"). This is already a KEM-based static-identity
  mechanism — but opt-in, pairwise, and run only between devices that
  already paired; it does not let a third, non-adjacent party verify that
  identity without itself decapsulating (requiring the static decapsulation
  key, i.e. being the intended recipient, not a relay). Extending it to
  "any node can authenticate any other node's static key" needs either
  (a) a signature wrapped around the static ek, reintroducing the
  ML-DSA-65 size cost ADR 0001 rejected, or (b) a KEMTLS/PQXDH-style design
  where only the intended recipient — never a relay — is convinced by
  successfully decrypting a bound payload, i.e. it authenticates
  sender-to-recipient, not sender-to-network.
- **How a non-adjacent peer learns and authenticates a key.** Three
  patterns found: **gossip** (BitChat's up-to-10-neighbor announcements
  build a one-hop map enabling source-routing once bidirectionally
  confirmed, §4.3 — but the *key* arrives in the cleartext announcement, so
  gossip distributes keys, not trust); **TOFU-at-distance** (Meshtastic:
  "nodes trust the first public key they hear for a node number," no
  verification step, explicitly accepted as insecure against a targeted
  first-contact attacker); **out-of-band verify** (`cairn-r1`'s QR/SAS,
  fundamentally two-party and in-person, not generalizable past one hop).
  **Key transparency** (a public, append-only, auditable log binding
  identities to keys) was not found in any BLE mesh system reviewed — it
  is a server-backed pattern (cf. CONIKS, Signal's key-transparency work)
  assuming always-on internet, contradicting `cairn`'s offline-BLE-only
  goal, so **not directly applicable** without inventing a mesh-distributed
  append-only log (an open problem, unresolved by any source here).
  **Conclusion:** no prior art gives multi-hop key authentication without
  either (a) trusting first contact (TOFU-at-distance, Meshtastic's risk
  profile) or (b) requiring a verified, already-paired path of
  intermediate contacts to vouch (web-of-trust/contact-graph, closer to
  Briar — requiring every hop to already be a `cairn` contact, i.e. *not*
  strangers, which contradicts instant auto-admission for multi-hop reach
  specifically).
- **Consequences for the per-contact Resume/pseudonym design.**
  `cairn-r1`'s pseudonym derives from `CK_n`, which exists only between two
  parties that completed pairing ([spec §6](../spec/cairn-r1.md#6-resume)).
  Where a non-adjacent peer must recognize/authenticate a device it never
  paired with (gossip or TOFU-at-distance), the pseudonym/beacon model as
  specified cannot extend past one hop without either (a) sharing some
  per-contact secret mesh-wide (breaking the A5 "✓ learns nothing beyond
  its own pairing" row of the current threat model,
  [threat model §3](../spec/threat-model.md#3-security-goals)), or (b) a
  *second*, mesh-wide identity/beacon layer alongside the existing
  pairwise one — two separate trust domains on the same radio, each
  needing its own formal model.

### 2.c Multi-hop E2E

- **Core size problem, from `cairn`'s own primitive sizes**
  ([ADR 0001](../adr/0001-crypto-suite.md),
  [pqc-over-ble findings §9](../research/2026-10-05-pqc-over-ble-findings.md)):
  X-Wing `ct` is **1120 B**, ML-KEM-768 `ct` is **1088 B**, ML-KEM-1024
  `ct` is **1568 B**. A default negotiated BLE ATT MTU is commonly 23–247 B
  (20–244 B usable payload, [ADR 0003 §4.3](../adr/0003-ble-transport.md#43-fragmentation)),
  so **sealing one KEM ciphertext to a single non-adjacent recipient costs
  5–70 fragments** depending on negotiated MTU, repeated per hop if sealing
  is not end-to-end. `cairn-r1` already solved the analogous pairwise
  problem — no KEM ciphertext per connection, only once at pairing, with
  the ongoing PQ ratchet's ML-KEM-768 chunks amortized into DATA-frame
  padding over many frames ([ADR 0005](../adr/0005-wire-format.md)). Any
  multi-hop PQ sealing design should reuse this amortization rather than
  invent a new one.
- **PQXDH as the closest "seal to an offline peer" reference.** Signal's
  PQXDH is explicitly "designed for asynchronous settings where one user
  (`Bob`) is offline but has published some information to a server"
  that `Alice` fetches
  ([PQXDH spec §1](https://signal.org/docs/specifications/pqxdh/)) — it
  requires a **prekey server**, a role `cairn` has no equivalent of
  (no infrastructure, BLE-only). A `cairn` mesh wanting PQXDH-style sealing
  to a non-adjacent peer needs either (a) the peer's own device acting as
  its prekey "server" when physically in range (collapsing to single-hop),
  or (b) the mesh storing/forwarding a prekey bundle — an unauthenticated-
  by-relays data-availability problem unresolved by any source here.
- **ML-KEM-only ratchets (Signal SPQR / Triple Ratchet, 2025).** Signal's
  blog describes SPQR as "an additional regularly advancing post-quantum
  ratchet," mixed with the Double Ratchet into a "Triple Ratchet," adding
  post-compromise/forward security against a future quantum adversary
  without replacing the classical ECDH ratchet
  ([signal.org/blog/spqr](https://signal.org/blog/spqr/)). The blog covers
  motivation/composition only; SPQR's own spec/paper (exact ciphertext
  sizes, cadence) was not retrieved — **Unverified**. `cairn-r1`'s own PQ
  ratchet (spec §9, amortized ML-KEM-768 chunks mixed at Resume,
  [ADR 0005 amendments](../adr/0005-wire-format.md#amendments), OI-21–OI-26)
  is independently similar in spirit and explicitly "adapted from Signal
  SPQR" per
  [the original research note](../research/2026-10-05-pqc-over-ble-findings.md)
  (line 252). Extending it to a *non-adjacent* recipient still needs epoch
  chunks to reach that recipient through relays that cannot authenticate or
  decrypt them, reopening §2.a/§2.d.
- **Sealed sender / onion-style relays.** No BLE-specific primary source
  was found. Signal's sealed sender (hides sender from the delivery
  server, not the recipient) and Tor-style onion routing both assume a
  trusted-enough server or enough hop diversity to defeat traffic
  correlation; a dense BLE mesh's small hop count and locally-correlated
  radio topology likely defeat onion routing's anonymity-set assumptions
  without dedicated study. **Unverified / open problem.**
- **Metadata exposure to relays.** BitChat's own packet header exposes
  **sender ID, optional recipient ID, size, TTL, timestamp** to every
  relay even though "relay nodes cannot read private traffic" (§4.1, §8) —
  self-described as "the weakest part of this design." Bluetooth Mesh's
  Network PDU similarly exposes `SRC`, `DST`, `TTL` in cleartext to every
  relay by design (§3.4.4). Any `cairn` mesh relay layer inherits this
  minimum exposure (addressing/size are structurally required for
  forwarding/dedup) unless onion-style indirection is added.
- **Replay/duplicate suppression.** Three comparable mechanisms: Bluetooth
  Mesh's cache keyed on `(SRC, SEQ)` plus the 32-bit IV Index counter
  (§3.4.4, §3.11.5); BitChat's LRU seen-set (1000 entries, 5-min expiry,
  §4.2) plus a 6 h gossip-sync cache (§6.3); `cairn-r1`'s own per-direction
  AEAD counter plus cumulative ack
  ([spec §7.1](../spec/cairn-r1.md), [ADR 0002](../adr/0002-store-and-forward.md)).
  A mesh relay layer needs a *new* bounded-memory dedup structure like
  BitChat's seen-set, since the existing per-contact counter only dedupes
  against one peer, not N relay paths re-delivering the same envelope.

### 2.d Routing/relaying over BLE

- **Managed flooding vs. gossip vs. routing tables.** Bluetooth Mesh uses
  pure managed flooding (TTL decrement + seen cache, no routing table) for
  small home/building-scale networks (§3.4.4). BitChat adds a lightweight
  gossip-routing layer on top: a 60 s-fresh one-hop neighbor table from
  announcements, source-routed when a bidirectional path is confirmed,
  flooding as fallback (§4.3) — the most BLE-realistic pattern found, since
  it needs no routing-table convergence protocol (BLE's connection churn
  makes classic distance-vector/link-state convergence unreliable) while
  still saving radio time on stable local links.
- **TTL and message IDs/bloom-style filters.** BitChat's TTL-7 with
  degree-based clamping plus LRU seen-set (§4.2) is the most concrete,
  copy-ready parameter set found; Bluetooth Mesh's TTL/SEQ/cache triad adds
  a network-wide replay counter (§3.4.4, §3.11.5). Neither source uses an
  actual Bloom filter for per-packet dedup; BitChat's gossip-sync uses
  "compact GCS filters" (a Bloom-filter relative) only for reconciliation
  (§6.3).
- **Store-carry-forward (DTN).** BTP is explicitly a DTN transport usable
  over transports "with latencies varying from milliseconds to days,"
  including "disks sent through the mail" (BTP §1.1–1.2) — the strongest
  precedent for a human carrying a phone as a store-carry-forward link.
  BitChat's courier system operationalizes this for BLE specifically:
  opaque tag-addressed envelopes with a decaying spray-and-wait copy budget
  handed between connected strangers until one encounters the recipient
  (§6.2). `cairn-r1`'s existing store-and-forward
  ([ADR 0002](../adr/0002-store-and-forward.md)) is pairwise-only (messages
  wait for *that* contact's next Resume); a mesh courier layer is a
  structurally new capability, since the carrying node is by definition
  neither the message's author nor its recipient.
- **Bandwidth/energy budgets for iOS background limits.** `cairn`'s own
  prior research already measured the binding constraint: "Each iOS
  background wake gets about 10 s"
  ([ADR 0003](../adr/0003-ble-transport.md), citing
  [the background BLE research](../research/2026-10-05-android-ios-background-ble.md)),
  and iOS cannot advertise service/manufacturer data in the background. A
  mesh relay role multiplies connect/notify cycles competing for that 10 s
  budget per wake; no source reviewed measures this for the Android↔iOS
  background case specifically (BitChat and Bluetooth Mesh both assume
  more continuous radio availability than an iOS background app
  realistically has). **Unverified**: needs `cairn`'s own device-lab
  measurement (cf.
  [the energy methodology note](../research/2026-10-05-energy-measurement-methodology.md)),
  extended to a relay role.
- **Connection-oriented (GATT) vs. advertising-based bearers.** Bluetooth
  Mesh explicitly supports both an advertising bearer and a point-to-point
  GATT bearer, with "a single provisioning protocol... used over both
  bearers," specifically so legacy phones without mesh-advertising support
  can still provision/relay via GATT (Mesh Protocol v1.1 §2.2.3).
  `cairn-r1` made the equivalent choice for its pairwise design (GATT
  primary, optional L2CAP CoC upgrade,
  [ADR 0003](../adr/0003-ble-transport.md)), with no advertising-only
  message transport ("connectionless use should be a 'doorbell' only," per
  [the original PQC-over-BLE research](../research/2026-10-05-pqc-over-ble-findings.md#97-connectionless-advertising-only-messaging)).
  A mesh relay layer inherits that constraint: relaying still needs a GATT
  connection per hop (or L2CAP CoC), bounding relay throughput to a
  phone's concurrent-GATT-link limit (typically single digits to ~20
  depending on chipset/OS — **Unverified**, no primary source for an exact
  current limit was retrieved).

### 2.e Abuse

- **Flooding/DoS.** BitChat's mitigations ("TTL clamps, deduplication,
  per-depositor quotas, connect-rate limits, announce-rate limiting," §8)
  and the Bridgefy papers' finding that **a single maliciously crafted
  message could shut down the entire network** (eprint 2021/214 abstract)
  bracket the risk: a naive relay implementation can be trivially DoS'd by
  one bad packet if parsing isn't fail-closed and bounded, while a
  disciplined one (TTL + dedup + per-source quotas) only degrades
  gracefully. `cairn-r1`'s existing fail-closed parsing discipline (reject
  reserved frame types, close the link silently,
  [spec §4.2](../spec/cairn-r1.md#42-frame-header)) is the right posture to
  extend to relay frames.
- **Battery drain.** Both Bluetooth Mesh (§2.2.5: relaying devices "are
  likely to use significantly more power than could be provided by typical
  small batteries") and `cairn-r1`'s own 2 %/24 h background-idle battery
  target ([ADR 0008](../adr/0008-beacon-discovery-tuning.md)) flag the same
  concern: relaying for strangers costs the relay's own battery with no
  direct benefit to its owner — both an abuse vector (numerous mesh
  "customers" draining a relay) and an adoption risk (users/OS throttling
  the app if relay cost is visible).
- **Spam from auto-admitted peers.** Not addressed by Bluetooth Mesh (no
  auto-admission exists); Meshtastic's anti-spam mechanism, if any, was not
  reached in the sources read (**Unverified**). BitChat's per-tier deposit
  quotas (favorites: 5, any verified peer: 2, shared pool bounded, §6.2) is
  the only concrete mitigation found, and it only bounds *storage* abuse,
  not conversational spam into a user's inbox — unaddressed by any source
  here and needing its own design (e.g. a per-stranger inbox separate from
  the verified-contact inbox).
- **Tracking via always-on discoverability** is the sharpest, best-
  evidenced risk in this review. BitChat's authors call cleartext static-
  key/nickname announcements "the weakest part of this design" for exactly
  this reason (§8); the PETS 2021 Find My paper shows that even a design
  built from the start around rotating identifiers still had two
  exploitable location-correlation flaws (abstract, §1.7). `cairn-r1`'s
  beacon rotation ([ADR 0005](../adr/0005-wire-format.md),
  [ADR 0008](../adr/0008-beacon-discovery-tuning.md)) is explicitly only
  unlinkable *to strangers*; the threat model already concedes it is
  **linkable to one's own contacts**
  ([threat model §6](../spec/threat-model.md#6-non-goals-explicitly-not-claimed)).
  Always-auto-TOFU turns every nearby stranger into a de facto "contact"
  instantly, which — unless the beacon/identity design is reworked — would
  extend that linkability concession to *everyone physically near the
  device*, a much larger privacy regression than today's design accepts.
- **Malicious relays (drop/delay/tag).** Bluetooth Mesh's spec architecture
  accepts that any network-key holder can drop or delay traffic; only TTL
  and application acks can detect non-delivery (dedicated Mesh Security
  Overview PDF text not extracted — **Unverified** at that detail level).
  BitChat's courier design accepts the same: "A malicious courier can drop
  mail (redundant copies and deposit retry mitigate this)" (§8) — the only
  defense found anywhere against a dropping relay is **redundancy**, never
  detection or punishment. "Tagging" (a relay marking traffic for later
  correlation) is not addressed by any source read — **Unverified / open
  problem**.
- **Partition and eclipse attacks.** Not directly addressed by name in any
  source retrieved. Bluetooth Mesh's friend-node relationship (§2.2.5,
  §3.6.6) is the closest structural analogue: a Low Power Node depends
  entirely on its one Friend Node, so a malicious/compromised Friend can
  fully isolate it. BitChat's reliance on whichever couriers are in range
  has the same shape more loosely coupled (spray to up to 3, §6.2), which
  mitigates but does not eliminate a well-positioned attacker controlling
  all nearby relays in a sparse or bottlenecked area. **Unverified / open
  problem**: no source quantifies how many colluding relays are needed to
  eclipse a victim at realistic BLE density.

### 2.f Formal verification implications

- **What carries over.** `cairn-r1`'s Tamarin models cover **pairwise**
  properties only: `resume.spthy` (Resume, all four profiles, the
  reflection-attack falsification that justified role binding, OI-16, the
  KCI ciphertext-substitution witness that justified binding `ct_I` into
  `th_s`, OI-18), `sas.spthy` (QR/SAS/TOFU pairing and Verify), and
  `ratchet.spthy` (the PQ epoch ratchet, not fully gated — "the composed
  ratchet implementation gate remains closed," [spec status line](../spec/cairn-r1.md)),
  per [`docs/spec/models/README.md`](../spec/models/README.md). Every model
  assumes exactly two principals per session and a persistent, pre-shared
  `CK_n`/pairID; none models a relay, a third party, or an attacker that is
  itself a legitimate (TOFU-admitted) mesh member. **None of the verified
  properties automatically carries over** to a mesh topology: they prove
  e.g. "R never matches its own reflected S1," true for any single Resume
  between two already-paired principals, but say nothing about what a third
  principal relaying that Resume's frames can or cannot do.
- **What breaks or needs a new model.** (1) The **TOFU first-contact MITM
  property** in `sas.spthy` assumes a user-attended TOFU contact marked
  Unverified, later verifiable via Verify/SAS in person
  ([spec §5.3](../spec/cairn-r1.md#53-verification-codes)); an
  always-auto-TOFU peer a user may never meet has no "later verify" step
  modeled or UX-reachable per [ADR 0009](../adr/0009-pairing-ux.md) — that
  implicit assumption no longer holds. (2) **Multi-hop authentication**
  (§2.b) has no existing model at all; per Constitution O3/S6 it needs its
  own from-scratch Tamarin (or equivalent) model before implementation,
  mirroring how `resume.spthy`/`sas.spthy` were each built and gated. (3)
  **Relay frame forwarding** (TTL decrement, dedup-cache admission,
  store-carry-forward custody transfer) is a new class of protocol step —
  "a principal that is neither sender nor recipient nonetheless holds and
  forwards the ciphertext" — none of the three existing models represent
  it, and industry prior art (§1.1–1.4) shows this is exactly where
  Bridgefy's authentication and DoS failures lived (§1.3's findings are
  squarely about this layer, not the pairwise ratchet). A `cairn` mesh
  model should include a Dolev-Yao-style principal that is TOFU-admitted
  (valid protocol credentials) but adversarial — closest to the existing
  **A5 "Malicious contact"** row, but A5 today assumes a *paired,
  verified-or-not* contact, not an automatically admitted stranger with no
  verification path ([threat model §2](../spec/threat-model.md#2-adversaries)).

---

## 3. Options for `cairn`

All three options reuse the existing crypto suite (ADR 0001) unless stated
otherwise; sizes are computed only from primitive sizes already cited in
`cairn`'s own ADRs/spec or §1/§2 above, nothing invented. Adversary IDs are
from [threat model §2](../spec/threat-model.md#2-adversaries).

### Option (i): hop-by-hop `cairn-r1` links + an end-to-end layer on top

Every BLE hop is a full `cairn-r1` pairwise relationship (pairing + Resume +
DATA, unchanged), auto-admitted instead of user-gated. A new, separate
**message envelope** is end-to-end sealed to the final recipient (key from
a prior direct pairing, or a mesh-distributed static KEM key per §2.b's
KCI-profile extension) and carried as an opaque DATA record inside each
hop's already-authenticated session — structurally like Bluetooth Mesh's
network/app-key layering (§1.1) or Briar's "any transport" pattern extended
to hop-by-hop auto-pairing.

- **Reuse:** everything — pairing, Resume, DATA framing, padding, beacons,
  the PQ ratchet, and all three Tamarin models stay valid *per hop*, since
  each hop is still exactly the two-party relationship they cover.
- **New work:** the auto-TOFU admission flow (§2.a); an end-to-end envelope
  format and key-agreement (needs §2.b/§2.c resolved); a new model for "a
  principal relays an opaque envelope it cannot open."
- **Sizes:** per-hop admission unchanged — **1251 B / 1137 B** (P1/P2,
  X-Wing) once, then **57 B / 49 B** per Resume
  ([spec §5.1](../spec/cairn-r1.md#51-messages),
  [spec §6](../spec/cairn-r1.md#6-resume)) — plus the new envelope cost (at
  minimum one AEAD tag, **16 B**, if the end-to-end key already exists; a
  full KEM exchange to a never-met recipient adds **1088–1568 B**,
  amortized as in §2.c).
- **Threat-model consequences:** A1/A3 are largely unaffected at the hop
  layer (each hop is still a verified Resume), but **auto-admission itself
  is new A1/A7 exposure**: an attacker can now force unlimited pairing-cost
  asymmetric work just by being nearby, where today this requires an open
  pairing screen ([threat model §5](../spec/threat-model.md#5-availability-best-effort)).
  A5 ("malicious contact") now effectively includes every stranger ever in
  range, so its "✓ learns nothing beyond its own pairing" / "✗ can track
  your device beacon" rows ([threat model §3](../spec/threat-model.md#3-security-goals))
  must be read as applying to a vastly larger, uncurated contact set.
  TOFU — by definition unverified — becomes the *default* case for the
  entire mesh, not the discouraged exception ADR 0009 treats it as.
- **What must change:** [threat model §5](../spec/threat-model.md#5-availability-best-effort)'s
  pairing-screen gate is directly superseded; [ADR 0009](../adr/0009-pairing-ux.md)'s
  TOFU-discouraged decision is inverted for mesh peers (it could remain
  as-is for a narrower "direct contact" relationship layered on top — see
  option (iii)).

### Option (ii): open flooding mesh with per-recipient PQ sealing

Modeled on Bluetooth Mesh's network-key layer (§1.1) plus BitChat's
flood-control parameters (§1.4): every auto-TOFU'd device shares enough to
relay (at minimum, enough to authenticate a frame as coming from *some*
legitimate mesh member, and to run TTL/dedup), but payloads are always
sealed end-to-end to the specific recipient, so relays never decrypt
content — closer to Bluetooth Mesh's app-key/network-key split than to the
common practice of sharing one app key mesh-wide.

- **Reuse:** the DATA frame format, AEAD, padding buckets, and the PQ
  ratchet's amortization pattern ([ADR 0005](../adr/0005-wire-format.md))
  reuse directly for the *sealed payload*. Resume does **not** reuse as-is
  — it authenticates a pairwise `CK_n`, and this option has no such thing
  between arbitrary mesh members; it needs a new group-style
  hop-authentication key instead.
- **New work:** a shared/broadcast hop-authentication secret (a `cairn`
  analogue of Bluetooth Mesh's network key) with its own provisioning/
  rotation design (a wholly new trust primitive, §2.a); managed-flooding
  parameters (TTL, dedup cache, §2.d); a mesh-wide sealing key-discovery
  mechanism (§2.b/§2.c, no equivalent exists today).
- **Sizes:** hop authentication can be cheap — Bluetooth Mesh's Network PDU
  MIC is **32 or 64 bits** (4 or 8 B, §3.4.4 Table 3.10), within
  `cairn-r1`'s own truncation conventions (8 B pseudonym/beacon tags,
  [ADR 0001](../adr/0001-crypto-suite.md)). The expensive part is unchanged
  from option (i): a full KEM-sealed envelope to a non-adjacent recipient
  costs **1088–1568 B**, amortized as the PQ ratchet already is.
- **Threat-model consequences:** the closest match to Bluetooth Mesh's
  trust model: **A5 is redefined from "a legitimately paired peer" to "any
  mesh member,"** a much larger, less controllable set; the A5 "✓ cannot
  impersonate you to others" row needs re-proof under a shared
  hop-authentication key, since a network key is, by design, something
  every holder can use to forge network-layer traffic within TTL/sequence
  bounds (§1.1) — strictly weaker per-member than `cairn-r1`'s current
  pairwise MACs. This option also reproduces Bridgefy's broadcast-channel-
  impersonation failure (§1.3) most directly, being closest to Bridgefy's
  own shared-network-key broadcast design — the USENIX paper's finding
  (impersonation survived even after adopting Signal's ratchet) should be
  treated as a design requirement to falsify in a Tamarin model, not just
  an engineering detail.
- **What must change:** essentially all of [ADR 0001](../adr/0001-crypto-suite.md)'s
  "no group secret" implicit assumption; all of
  [threat model §3](../spec/threat-model.md#3-security-goals)'s per-A5
  claims; [ADR 0009](../adr/0009-pairing-ux.md) in full (there is no
  "pairing screen" concept left once admission is driven by a shared
  network-style secret rather than a one-to-one ceremony).

### Option (iii): contacts-graph mesh (Briar-style), auto-TOFU only for immediate neighbours

Directly modeled on Briar (§1.2): `cairn-r1`'s pairwise pairing/Resume/
contact model is kept **entirely unchanged** for the relationship between
two devices that have ever auto-TOFU'd at close range (a "neighbour"), and
multi-hop reach is achieved only by **routing through a chain of
already-neighboured devices**, each hop individually authenticated exactly
as today — no new trust primitive, no stranger ever relaying for someone
they are not a neighbour of. Always-auto-TOFU applies only to the
*neighbour* relationship (replacing today's pairing-screen gate with
instant admission, [ADR 0009](../adr/0009-pairing-ux.md)); reaching a
non-neighbour is a Briar-style introduction/store-and-forward-via-
neighbours problem, not a new sealing primitive.

- **Reuse:** everything in the current spec, unchanged — pairing (now
  auto-triggered), Resume, DATA framing, the message-key chain, the PQ
  ratchet, and critically, **all three existing Tamarin models remain
  valid without modification**, since every pairwise relationship here is
  exactly the relationship those models already cover — by far the
  cheapest option to formally verify, since it adds no new pairwise
  primitive.
- **New work:** an auto-TOFU admission flow (§2.a, shared with option (i));
  a routing/introduction layer deciding which neighbour relays toward which
  non-neighbour (closest to BitChat's one-hop gossip/source-routing
  fallback-to-flood, §1.4, or Briar's own introduction/rendezvous clients,
  §1.2, not independently verified here beyond the spec index);
  store-carry-forward custody rules for a neighbour holding mail not
  addressed to it (BitChat's courier design, §1.4, including its
  trust-tiered deposit quotas, is the most concrete transferable template).
- **Sizes:** identical per-hop costs to option (i) (1251/1137 B pairing
  once, 57/49 B per Resume); a courier-style envelope to a non-neighbour
  needs, at minimum, an opaque routing tag (BitChat's is **16 B**, an HMAC
  of the recipient's static key and the day, §6.2 — directly transferable
  to `cairn`'s existing HMAC-SHA-384-truncated-tag conventions) plus the
  sealed payload itself.
- **Threat-model consequences:** the **smallest** threat-model delta. A5
  can keep its current definition ("a legitimately paired peer")
  essentially unchanged, since every principal that can decrypt anything
  is still, structurally, a direct neighbour under today's pairwise rules;
  what changes is only that the neighbour set grows automatically without
  user attention, so the implicit assumption that a contact list is small,
  curated, and the product of deliberate user action
  ([GLOSSARY.md](../../GLOSSARY.md), "Contact": "A peer that this device
  has paired with") no longer holds — A6 tracking and A7 battery/DoS risk
  both scale with however large and uncurated the auto-admitted neighbour
  set becomes, same as option (i), but **A5's cryptographic guarantees do
  not need re-proof**, only its practical scope does. Carrying mail for a
  non-neighbour (courier role) does introduce a new adversary not in
  today's A1–A7 list: a neighbour honest about its own pairwise traffic
  that drops, delays, or (if the routing-tag scheme is weak)
  de-anonymizes carried mail for others — closest to BitChat's self-
  assessed "malicious courier... cannot read it... but can drop mail" (§8).
- **What must change:** [threat model §5](../spec/threat-model.md#5-availability-best-effort)'s
  pairing-screen gate (same as option (i)); [ADR 0009](../adr/0009-pairing-ux.md)'s
  TOFU-is-discouraged UX decision, specifically for the *neighbour*
  relationship (a courier/routing UI is new, not addressed by ADR 0009 at
  all); a new ADR and Tamarin model for the courier/routing layer only —
  the pairwise core is explicitly **not** reopened.

### Which conflicts most directly with the current threat model and ADR 0009

All three options conflict with
[threat model §5](../spec/threat-model.md#5-availability-best-effort)'s
"Pairing is accepted only while the user has a pairing screen open" and
with [ADR 0009](../adr/0009-pairing-ux.md)'s decision to make TOFU a
discouraged, secondary path — that conflict is **inherent to the owner's
instruction**, not specific to any option, and must be resolved by a new
ADR amendment regardless of architecture. Options (i) and (ii) additionally
conflict with the threat model's implicit assumption that A5 is a small,
user-curated set (option (ii) breaks this most severely, by design, since
it has no per-pair relationship left once hop-authentication is a shared
secret); option (iii) is the only one that keeps A5 scoped to "whoever a
user's device happened to auto-admit as a neighbour," which — while still a
meaningful expansion of risk versus today's deliberately-paired contact
list — does not require re-deriving any of `cairn-r1`'s existing
cryptographic security proofs, only its usage-scope assumptions.

---

## Sources

- Bluetooth SIG, *Mesh Protocol 1.1*, adopted 2023-09-12 —
  [spec index](https://www.bluetooth.com/specifications/specs/mesh-protocol/),
  [HTML](https://www.bluetooth.com/specifications/specs/html/?src=MshPRT_v1.1/out/en/index-en.html)
  (§2.2.1–2.2.5, §3.4.2–3.4.4, §3.6.6, §3.9.6, §3.11.5 fetched directly).
- Bluetooth SIG, *Mesh security overview*, v2, 2025-10-13 —
  [overview page](https://www.bluetooth.com/bluetooth-resources/mesh-security-overview/)
  (PDF content not textually extracted in this pass; cited for existence
  and date only).
- Briar / Bramble protocol specifications —
  [index](https://code.briarproject.org/briar/briar-spec/raw/master/README.md),
  [Bramble Handshake Protocol v0.1](https://code.briarproject.org/briar/briar-spec/raw/master/protocols/BHP.md),
  [Bramble Transport Protocol v4](https://code.briarproject.org/briar/briar-spec/raw/master/protocols/BTP.md).
- Albrecht, Blasco, Jensen, Mareková, *"Mesh Messaging in Large-scale
  Protests: Breaking Bridgefy"*, CT-RSA 2021 —
  [IACR eprint 2021/214](https://eprint.iacr.org/2021/214), DOI
  10.1007/978-3-030-75539-3_16.
- Albrecht, Eikenberg, Paterson, *"Breaking Bridgefy, again: Adopting
  libsignal is not enough"*, USENIX Security 2022 —
  [conference page](https://www.usenix.org/conference/usenixsecurity22/presentation/albrecht).
- `permissionlesstech/bitchat`, *Protocol Whitepaper v2.0*, 2026-07-06 —
  [WHITEPAPER.md](https://github.com/permissionlesstech/bitchat/blob/main/WHITEPAPER.md).
- Meshtastic Project, *Encryption*
  ([meshtastic.org/docs/overview/encryption](https://meshtastic.org/docs/overview/encryption/))
  and *Known Limitations of Meshtastic's Encryption*
  ([meshtastic.org/docs/about/overview/encryption/limitations](https://meshtastic.org/docs/about/overview/encryption/limitations/)).
- Heinrich, Hollick, Stute et al., *"Who Can Find My Devices? Security and
  Privacy of Apple's Crowd-Sourced Bluetooth Location Tracking System"*,
  PETS 2021 — [arXiv:2103.02282](https://arxiv.org/abs/2103.02282).
- Apple / Google, *Exposure Notification* joint announcement —
  [covid19.apple.com/contacttracing](https://covid19.apple.com/contacttracing)
  (cryptography specification PDF linked from that page was not textually
  extracted in this pass).
- Signal, *The PQXDH Key Agreement Protocol*, Revision 3, 2023-05-24 /
  updated 2024-01-23 —
  [signal.org/docs/specifications/pqxdh](https://signal.org/docs/specifications/pqxdh/).
- Signal, *"Sparse Post Quantum Ratchet (SPQR)"* blog announcement —
  [signal.org/blog/spqr](https://signal.org/blog/spqr/).
- Noise Protocol Framework specification —
  [noiseprotocol.org/noise.html](http://www.noiseprotocol.org/noise.html)
  (table of contents and structure confirmed; message-size arithmetic in
  §2.c is derived from the framework's own DH-key-length/AEAD-tag rules,
  not independently re-quoted per handshake pattern in this pass).
- `cairn` repository, read for context and direct quotation:
  [`docs/spec/cairn-r1.md`](../spec/cairn-r1.md),
  [`docs/spec/threat-model.md`](../spec/threat-model.md),
  [`docs/spec/models/README.md`](../spec/models/README.md),
  [`docs/adr/0001-crypto-suite.md`](../adr/0001-crypto-suite.md),
  [`docs/adr/0002-store-and-forward.md`](../adr/0002-store-and-forward.md),
  [`docs/adr/0003-ble-transport.md`](../adr/0003-ble-transport.md),
  [`docs/adr/0005-wire-format.md`](../adr/0005-wire-format.md),
  [`docs/adr/0008-beacon-discovery-tuning.md`](../adr/0008-beacon-discovery-tuning.md),
  [`docs/adr/0009-pairing-ux.md`](../adr/0009-pairing-ux.md),
  [`GLOSSARY.md`](../../GLOSSARY.md),
  [`docs/research/2026-10-05-pqc-over-ble-findings.md`](2026-10-05-pqc-over-ble-findings.md).

## Unverified / limitations

- **Berty/Wesh, Serval Project, FireChat:** no primary source was fetched
  for any of the three in this pass (time-boxed search). This is a real gap
  given Berty/Wesh's conceptual closeness to option (iii); a follow-up pass
  should read Berty's own repository/spec before relying on anything about
  it beyond general reputation.
- **Bluetooth Mesh Security Overview PDF** (v2, 2025-10-13): located and
  dated, but its PDF content could not be textually extracted by the
  fetch tool in this session; claims about Bluetooth Mesh's privacy/relay
  threat model beyond what the main Mesh Protocol v1.1 HTML spec itself
  states directly are not independently confirmed from that overview.
- **Apple's own Find My offline-finding whitepaper** (`apple.com` PDF URL)
  returned 404 in this session; §1.7's claims are sourced to the
  peer-reviewed PETS 2021 reverse-engineering paper instead, which is a
  primary academic source but is not Apple's own specification text.
- **Google/Apple Exposure Notification Cryptography Specification PDF:**
  located and linked, but its content was not textually extracted (binary
  PDF response); §1.8's architectural claim (rotating identifiers derived
  one-way from a daily private key) is standard public knowledge about the
  system but was not re-verified byte-for-byte against the spec PDF in this
  pass.
- **Signal SPQR / Triple Ratchet detailed specification:** only the blog
  announcement was read; no paper or formal spec with exact per-message
  ciphertext sizes, ratchet cadence ("sparse" interval), or ML-KEM
  parameter choice was retrieved. Any numeric claim about SPQR's wire cost
  would be speculation and is deliberately not included above.
- **Briar's BQP (QR) and BRP (Rendezvous) protocols**, and the Briar wiki
  "Quick Overview of the Protocol Stack" page: listed in the spec index but
  not fetched (the wiki page failed to render as plain text and was not
  retried as raw HTML given time constraints). Claims about how Briar
  peers actually exchange long-term keys out-of-band are inferred from BHP
  §1.1's description of its own prerequisites, not from BQP/BRP directly.
- **Concurrent GATT connection limits on current Android/iOS BLE stacks:**
  no primary source was fetched in this pass; §2.d's relay-throughput
  bound is stated qualitatively only.
- **iOS-background mesh-relay energy/latency budget:** no source in this
  review measures this; it is flagged in §2.d as needing `cairn`'s own
  device-lab measurement, extending the existing
  [energy measurement methodology](2026-10-05-energy-measurement-methodology.md).
- **Partition/eclipse-attack quantification and "tagging" by a malicious
  relay:** no primary source addressed either by name; both are flagged as
  open problems in §2.e, not resolved findings.
- **Key-transparency for mesh-distributed identity (§2.b):** noted as
  structurally in tension with an offline, BLE-only design and not solved
  by any source in this review; this is an assessment based on the
  reviewed sources' absence of any such mechanism, not a proof that none
  could work.
- Nothing in this note was computed from invented numbers: every byte size
  traces to either `cairn`'s own ADRs/spec/research notes (already cited
  primary sources within this repository) or a directly quoted/fetched
  external primary source cited inline and in §Sources.
