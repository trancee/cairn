# Courier: spec, formal model and implementation

Type: task
Status: ready-for-agent
Blocked by: none

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
