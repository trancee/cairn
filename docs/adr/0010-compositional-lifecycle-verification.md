---
status: accepted
date: 2026-10-09
version: pqcble-r1
---

# 0010: Compositional lifecycle verification

## Context

Repeated Tamarin searches for `lock_stage_order`, `resume_serialized` and
`initial_resume_serialized` recursively expand ordinal histories and interval
goals. Timeouts are inconclusive. These three claims concern linear lifecycle
control, not primitive secrecy. A prior manually reduced model omitted the
completion-stage increment, demonstrating why an unchecked projection is
insufficient.

## Decision

Use Lean 4.34.1 induction for the unbounded lifecycle invariants, linear-token
simulation and arbitrary-key interleavings. Generate and validate a
conservative projection from Tamarin's current canonical default-rule export,
and have Lean check source-derived token/action schema equalities.
Keep the exact source claims, protocol rules, restrictions and wire terms.
Tamarin remains the verifier for the cryptographic claims.

The reproducible command and proof correspondence are documented in
[`lifecycle/README.md`](../spec/models/lifecycle/README.md).
The user approved this direction with "proceed" after the compositional
verification proposal. This adds development-time proof tooling only;
there is no application dependency or payload/API change.

## Alternatives

More heuristic/time-limit variations have repeatedly failed to terminate.
Session-bounded exploration cannot establish unbounded claims. A manually
reduced model without a checked connection to source cannot transfer its
results. Adding a serialization restriction would assume the property instead
of proving it. A formally verified Tamarin importer would reduce the trusted
boundary further, but is not implemented by this change.

## Risks and evidence boundary

Lean's kernel verifies the mathematical proofs. Source correspondence also
trusts Tamarin's export and the regression-tested Python projection checker.
It is not a kernel-verified parsing/refinement proof of full Tamarin semantics.
Report this explicitly; do not label the three claims Tamarin-verified or
change historical Tamarin replay counts. Changed lifecycle rules, target
formulas or equations must pass the regenerated projection gate.

The source-boundary hardening rejects misplaced token/action facts,
persistent freshness premises, duplicate declarations and malformed
fact syntax. Source-derived initialization certificates cover both roles
and their markers. Lean also checks fresh creation's preservation of
existing histories and global unrelated-event stuttering. Each required
theorem has a mandatory axiom audit. These checks narrow failure modes
without verifying the extractor or replacing independent expert review.

## Migration

Add the compositional command alongside existing Tamarin gates and report its
results separately. The original model needs no migration. The ratchet's
overall implementation gate remains closed until its other evidence
obligations are reconciled, including the resource-blocked lost-data replay
and source/equation evidence. CI integration remains unverified.

The [lifecycle workflow](../../.github/workflows/lifecycle.yml) now configures
the same clean runner on Ubuntu 24.04, with immutable action revisions,
Python 3.13.16 and checksum-pinned official proof tools. It runs without
path filters or cached proof outputs, with read-only repository permissions.
This automates compositional evidence only, not all ratchet obligations.
Local syntax/proof checks are not hosted CI evidence; a clean hosted run
and required-check enforcement remain external prerequisites.

The proof-only `DISCLOSURE_SOURCES` profile now adds CK/SS origin
certificates, replayed against raw sources. It leaves all transitions,
restrictions, equations and default certificate contexts unchanged.
It reduces refined partial chains from 30 to 15, but seven existing
safety proof skeletons need migration in the new source context.
It therefore remains opt-in rather than invalidating default evidence.
The witness runner and workflow check its three source certificates and
lost-data witness separately. This is not full profile verification;
see the [source evidence](../spec/models/ratchet-source-evidence.md#opt-in-disclosure-refinement).
The KEM origin skeleton is now migrated into a profile-specific generated
certificate with the same formula/attributes. Its 18-step replay is checked
separately by the runner/workflow; the default's 31-step certificate remains
unchanged. The refined safety-only context verifies 54/54 complete
certificates, not full theory completion.
