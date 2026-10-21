---
status: accepted
date: 2026-10-21
version: cairn-r1
---

# 0017: Split full-context ratchet certificate acceptance

## Context

The [compositional lifecycle ADR](0010-compositional-lifecycle-verification.md)
accepts the ratchet's 56 safety certificates and four existential witnesses
as independent contexts, but states that they are not a full assembled
Tamarin result. The single 63-declaration `--disclosure-sources` invocation
never produced a summary: it was system-killed (exit 137) or timed out with
a 5 GiB heap ceiling.

Diagnosis on 2026-10-21 against the exact export (source SHA-256
`482e0125…5e80`), certificate checking only (no `--prove`), Tamarin 1.12.0,
Maude 3.5.1, `+RTS -N1 -M5G -s`:

| Context | Result | Max residency | Wall |
| --- | --- | --- | --- |
| full (63 declarations) | no result at 240 s | 4.04 GB at SIGINT | — |
| sources + `executable` | verified, 609 steps | 1.21 GB | 58.8 s |
| sources + `initiator_candidate_recovery` | verified, 507 steps | 2.62 GB | 103.5 s |
| sources + both | both verified | 4.02 GB | 210.5 s |

- Maude used 3.0 s of 219.8 s CPU; the remainder is Tamarin.
- In the full run, GC took 152.8 s of elapsed time (34.1% productivity),
  with 24.4 s maximum pause.
- The heap grew monotonically at about 20 MiB/s, mostly list cells and
  `Term.Raw.FAPP` terms.
- The four witness certificates are 97% of the 7.24 MB proof text; the
  56 safety certificates total about 0.25 MB.

Residency is additive across checked witnesses. The projected full total
of more than 7 GB exceeds the ceiling and thrashes the collector. This is
a resource limit of checking every certificate in one process, not a
simplifier explosion, a Maude failure or a counterexample.

## Decision

Accept full-context certificate checking as the conjunction of:

1. a passing partition audit
   (`replay.py --disclosure-sources --audit-partition`); and
2. the passing `complete_safety` context and each of the four witness
   contexts, already gated in `lifecycle.yml`.

Tamarin uses all `sources` lemmas when proving each non-`sources` lemma.
It also uses each syntactically earlier `reuse` lemma, minus `hide_lemma`
([manual, lemma annotations](https://tamarin-prover.com/manual/master/book/007_property-specification.html)).
Removing a lemma that is neither `reuse` nor `sources` therefore leaves
every other lemma's proof inputs unchanged. The audit checks this on the
exact export and fails closed:

- every exists-trace declaration is an `EXISTENTIAL_TARGETS` witness;
- no witness or compositional (`by sorry`, Lean-composed) claim carries
  `reuse` or `sources`;
- the contexts are `complete_safety` plus each present witness, selected by
  the same function as replay;
- every retained lemma's sources and earlier reuse lemmas in its context
  equal those in the full export. `sources` lemmas use no reuse lemmas.

`compare_replay` already requires byte-identical non-lemma declarations
in each context. The `--quit-on-warning` export already checks whole-theory
well-formedness. The audit runs no proof and is in local `REPLAY=1` checks
and the CI matrix entry `replay-full-context-partition`.

The 2026-10-21 audit reports 63 declarations, five contexts and three
compositional claims; witnesses follow only `kem_and_ct_tail_origin`.

## Consequences

- This supersedes the [ADR 0010](0010-compositional-lifecycle-verification.md)
  sentence that independent contexts are not a claimed full assembled result,
  for certificate checking only.
- A future `reuse` witness, an earlier `reuse` lemma not retained in a
  context, or an unassigned existential lemma fails the audit before replay.
- The three serialization claims keep the Lean compositional route.
- The native-guard benchmark previously required `replay.py` to equal `HEAD`
  via a working-directory-relative `git diff`. That blocked the pre-commit
  hook for any `replay.py` edit and was vacuous outside the root. It now
  resolves the repository root, fails closed outside a checkout and requires
  the committed file only for three-pair acceptance; screening labels an
  uncommitted baseline.
- Not claimed: independent mixed-equation/FVP acceptance, a single-process
  full run, default profile activation, or computational, constant-time,
  parser, persistence or BLE properties. The ratchet implementation gate
  stays closed on the remaining open obligations.
