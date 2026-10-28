# Courier: spec, formal model and implementation

Type: task
Status: resolved
Blocked by: 35

## Question

Turn [ADR 0033](../../../docs/adr/0033-courier-relaying.md) into the spec,
a proved model and code, in that order (Constitution O3/S6).

1. **Spec (OI-37).** Add `K_route` to §5.5; inner padding of queued
   messages to §8; a courier subsection to §8 (envelope, spray-and-wait,
   clamps, inventory window, tombstones, limits, failures); the DATA records
   for inventory, fetch, envelope, deposit, accept or refuse, and tombstone
   to §7.3, with their sizes and how an inventory of 256 tags is split
   across records.
2. **Model.** `docs/spec/models/courier.spthy` with couriers as the
   Dolev-Yao attacker, proving P1 secrecy, P2 authenticity, P3 once-only
   acceptance and P4 tombstone unforgeability; P5 tag unlinkability is
   argued in prose. Add the run commands to the models README.
3. **Implementation.** Rust core first (envelope, tag window, courier store
   with quotas and clamps, tombstones), then the SDK configuration for the
   copy budget (default 6, 1–16) and lifetime (default 24 h, 1 h – 7 d),
   then a fleet run that measures delivery to an out-of-range contact.

Done when the spec and model are merged with all lemmas proved, the core
and SDK pass their gates at 100% coverage, and a fleet run delivers a
message through at least one courier.

## Comments

2026-10-26: created by ADR 0033, rule 9.

2026-10-26: step 1 done in spec draft 0.16 (OI-37, §5.5, §7.3, §8, §8.1).
The owner chose 8 B tag prefixes in inventories (I8). Queued `inner` gains
the text length and bucket padding up to 4048 B; only `inner` ≤ 2048 B is
couriered. Next: `courier.spthy`.

2026-10-26: step 2 done. `courier.spthy` verifies P1–P4 in about 1 s; the
`OPEN_COMMIT` and `REUSABLE_SLOT` mutations falsify P4 and P3. P5 is argued in
the models README. Next: Rust core.

2026-10-27: step 3 is blocked by issue 35. Couriers carry QUEUED ciphertexts and
need message chains, skipped keys and ACK, none of which the core has yet. The
owner chose to build S5's store-and-forward core first (ADR 0034), then
couriers on top.

2026-10-28: step 3 core and SDK done ([ADR 0036](../../../docs/adr/0036-courier-state.md)).
The Rust core seals own envelopes, keeps the recipient tag window, exchanges
INVENTORY, FETCH, ENVELOPE, CUSTODY and TOMB after every Resume, and stores
carried envelopes and tombstones as courier rows. The SDK seals courier rows
(kind 3) and exposes `LinkDriver.setCourier`. Both pass their gates at 100%
coverage. Remaining: the fleet run.

2026-10-28: step 3 done; resolved. Fleet run on `main` at `cea4a64` with
three Android phones: A = Nothing Phone (2) (`1f1dad34`), B = Motorola edge
30 fusion (`ZY22GCD9ST`), C = Galaxy Z Flip4 (`R5CT83ACSJX`). Bluetooth
reset and app data cleared on all three first. The phones share a desk, so
"out of range" means A and C never ran at the same time.

1. Paired A–B, B–C and A–C, two apps at a time: 11 s, 11 s, 10 s.
2. A alone sent "viaB" to C: one queued row, "Waiting for a connection".
3. A and B: B stored A's envelope as a courier row 7 s after B started
   (a 145 B DATA frame at 483 ms on the link).
4. A stopped; B and C: C opened the envelope 8 s after C started. C stored
   its tombstone and showed "viaB" under A's contact.
5. B stopped; A and C: A's queued row was deleted on C's ACK 8 s after A
   started, and A kept the tombstone of its own envelope. C showed the
   message once.

Evidence is row counts per table read from each phone's `cairn.db` with
`run-as` (rows are sealed, so only counts), logcat frame sizes and the
screen text. Not measured: delivery over real distance, iOS couriers, and
the battery cost of the exchange. On the B–C link, B sent two 145 B frames:
the FETCH answer and the halved spray copy, both decided at inventory
completion. The spec allows this. The duplicate is answered with CUSTODY 2
and costs one frame.
