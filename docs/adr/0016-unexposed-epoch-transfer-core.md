---
status: accepted
date: 2026-10-18
version: cairn-r1
---

# 0016: Unexposed post-quantum epoch transfer core

## Context

Slice S9 (PQ ratchet) is blocked by the strict formal-model gate from
[implementation slicing](../../.scratch/cairn-r1/issues/25-implementation-slicing.md):
*Formal model: PQ ratchet mixing* remains open because FVP/importer and
full assembled-model obligations are incomplete. S9 also follows S7 (Resume),
and the S0 binding proof is still blocked by isolated-runner acceptance.

The [architecture ADR](0004-core-architecture.md) places protocol state
machines in a `no_std` + `alloc` crate named `cairn-proto`. Spec §9 defines
epoch identifiers (OI-21), generator parity (OI-4), durable cumulative
progress (OI-25) and strict contiguous reassembly (OI-26). These rules move
only public, fixed-length ML-KEM-768 objects and need no KEM operation.

## Decision

On 2026-10-18 the owner approved a narrow waiver of the strict gate:
build a Rust-only, sans-IO ratchet increment test-first, with no SDK/FFI
exposure, no wire use and no profile activation until the model ticket
resolves.

Add `core/cairn-proto` with no dependencies. It implements only:

- `Epoch`: a non-wrapping `u32`; the successor of `2^32 - 1` fails with
  `EpochExhausted` (`epoch_exhausted`). Role A generates even epochs and role
  B odd ones; the generator receives the ciphertext and the encapsulator the
  encapsulation key.
- `IncomingObject`: one contiguous prefix per epoch object. A chunk is
  validated completely before mutation. Contiguous chunks append, exact
  duplicates wholly inside the prefix are accepted without change, and every
  other chunk fails with `TransferInvalid` (`pq_transfer_invalid`).
- `OutgoingObject`: an immutable object of its kind's fixed length.
  Cumulative progress never decreases, is rejected for a wrong epoch or kind
  or beyond sent bytes, and a new session resends from acknowledged progress.

Duplicate comparison uses ordinary equality. KEM objects are public values
and the comparison involves no secret, so spec §11's constant-time rule does
not apply and no `subtle`/`ctutils` dependency is added. Miri covers the crate
as [ADR 0007](0007-ct-conformance-gates.md) requires.

## Alternatives

- Keep the gate and work only on S0 runner blockers: needs owner host
  authorization and produces no ratchet progress.
- A full S9 waiver with SDK exposure ahead of S7/S1: skips slice ordering and
  exposes an unverified composition. Rejected by the owner.
- A separate `cairn-ratchet` crate: contradicts ADR 0004's `cairn-proto`
  layout without a demonstrated need.
- Including ML-KEM, completion and mixing now: needs a KEM extension to the
  crypto seam with its own conformance evidence first (ADR 0012).

## Risks and gates

The formal model may still change §9; this code would then change with it.
Nothing here is wired into Resume, DATA records, persistence or bindings, so
the composed ratchet remains unimplemented and unverified. Persistence of
progress and the transfer state is the caller's future responsibility.
The S9 slice, its device demonstration and the model ticket stay open.
All Constitution and ADR 0007 gates apply unchanged, including 100% line
and branch coverage.

## Migration

No published API, wire format, protocol label, runtime dependency or
constant-time claim changes. Later increments add KEM completion, mixing,
record encoding and persistence. Exposure through `cairn-ffi` or any profile
activation requires the model ticket to resolve or a new owner decision.

## Amendments

2026-10-22, from [ADR 0020](0020-root-gradle-wire-ffi.md): by owner decision,
`cairn-ffi` exposes `IncomingObject`, `ObjectKind`, `ChunkOutcome` and a typed
`TransferError` for the binding proof only. The SDK, wire use, persistence and
profile activation still do not use them, and the model-ticket gate on
ratchet use is unchanged.
