---
status: accepted
date: 2026-10-09
version: cairn-r1
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

### Guarded native command/reply boundary (2026-10-14)

The owner explicitly selected `guarded-maude-boundary` and approved stream
tests rather than requiring a universal upstream query-builder proof first.
Keep the six equations, attacker, claims, transitions and proof deadlines.
Route every repository ratchet acceptance operation through the fail-closed
proxy and require private lifecycle evidence before accepting tool success.
Validate the complete pinned module, proper-sort query terms and every returned
solution; reject the whole operation, never filter solutions.
Use the [reference contract](../spec/models/equations/README.md#native-stream-boundary).

Pinned importer inspection requires generated variables for unification/variants
and original variables for matching. Reject `#`/`%` identity collisions within
one solution, since the importer merges those prefixes. These runtime checks
do not kernel-certify injective variable renaming or importer correctness.
The alternative source-linked route remains possible, but is not implemented.

Missing/malformed evidence, native EOF, report I/O, incompatible substitutions
and shutdown diagnostics fail closed. Metadata includes no terms or protocol
material. Keep the independent native-module fixture and stream cases together
above the 300-line recommendation, below 500, rather than introducing
fixture/import coupling. The observed parse-only overhead is below the 10%
merge limit; full-search and memory overhead remain unmeasured. No new proof
budget, dependency, CI cell, protocol/API/wire or constant-time claim.

This is checked membership of executed operations under a trusted Python/tool
boundary, not backend algorithm correctness or native FVP acceptance.
Complete sorted AC-unification, admissible decomposition/theorem applicability
and full assembled replay remain required. Publication, hosted CI, merge and
activation are not authorized by this owner selection.
The pinned `Console.hs` installation check invokes Maude without arguments and
feeds exactly `quit\n`. A real tiny exact-signature proof initially exposed that
legitimate unsupported invocation. Supporting only that source-linked probe
restores proof startup without permitting unguarded protocol operations.

### Free tuple/Node framing closure (2026-10-14)

Extend the structural candidate image to recognized message leaves, node
atoms/variables and free `list`/`cons`/`nil` trees at `TOP`. Prove closure under
raw structural AC, rewriting and typed substitution. Node assignments use
the same disjoint labels, rather than staying fixed. The kernel red admits
`h(list(nil))` by treating arbitrary framing as a message argument; requiring
message recognition makes it green. Keep framing and nodes out of message
functions/natural sums.

This free framing envelope includes more shapes than the printer's fixed
tuples. Closure therefore does not establish actual caller membership, exact
tuple construction or complete native unification/narrowing. Require the
three new audits/cases in the same checker/cell, for 53 total. A valid earlier
50-audit transcript fails closed after its intended CLI red/green test.
No equation, runtime, wire/API, resource limit or acceptance change.
The earlier node-fixed substitution checkpoint below is superseded here;
actual backend query/substitution provenance remains open.

### Structural image algebra and substitution correspondence (2026-10-14)

The frozen-index round trips do not connect native-shaped equations/AC to the
typed algebra. Define independent raw structural AC and six-rule/context
rewriting, including natural-addition and list/cons contexts. Prove decoder
invariance, recognition converses, exact image closure and preservation/
reflection. Reuse the accepted source B-coherence theorem to realize encoded
quotient steps by typed matching, modulo AC. Reusing only the source relations
as definitions would make correspondence circular.

Keep the raw rewrite relation an explicit overapproximation without native
message-sort guards. For encoded messages, decoder reflection establishes
proper message payloads/keys and excludes natural/framing rewrite contexts.
This does not identify all raw terms with the actual Maude carrier.
Use sort-separated typed substitutions, changing even variable labels only.
The intended kernel red incorrectly replaces an odd rigid natural leaf;
freezing it makes the substitution/encoding square commute. Native atom index
fields are never traversed. The induced assignment fixes node variables;
arbitrary node substitutions and actual query framing are not certified.

Require all 24 new audits and the new kernel cases through the existing
checker/cell, for 50 audits total. CLI reds accept the old 26- and 44-audit
transcripts before the new reports become mandatory; the final gate rejects
them. Retain the previously justified single-file CLI fixture deviation from
the 300-line recommendation, still below the 500-line limit.

Actual backend input/output membership, Haskell importer correctness,
substitution provenance, narrowing/unification closure, complete sorted
AC unification and theorem applicability remain open. The local/unpublished
increment changes no equations, protocol, API, wire, primitives, constant-time
claims, runtime dependencies, CI jobs or resource ceilings. This is not
native FVP acceptance or implementation authorization.

### Frozen-index query-image encoding (2026-10-14)

As a foundation for the owner-selected query-image route, model the pinned
printer's protocol syntax with rigid indices distinguished from sorted
variables. Use disjoint even/odd labels in the mathematical carrier to
represent the two literal kinds without changing native indices or wire data.
Prove natural/message encoding left inverses and injectivity. The kernel red
merges a rigid atom with a variable sharing its index; separating their labels
makes it green. Recognizers reject node/list framing as messages and message
operands in natural sums. Require all four new audits and cases in the existing
cell; the full command now audits 26 theorems. Missing image reports fail closed.
Keep the source/CLI regression fixture in `test_equations.py`, slightly above
the 300-line recommendation but below the 500-line limit: splitting this
increment would add fixture/import coupling without another behavior boundary.

A name-index label without its literal kind would lose injectivity. Conversely,
round trips alone do not establish native AC/matching/substitution reflection
or framing/unification/narrowing closure. Tamarin's host term sort classifier
is not a native proper-sort proof. The Python source bridge and Haskell
printer/importer correspondence remain trusted/unverified boundaries.
This local/unpublished proof foundation changes no application, protocol,
payload, public API, primitive or constant-time claim; FVP acceptance stays open.

### Typed convergence and uniform boundedness (2026-10-14)

Continue the approved kernel/CLI seams with indexed matching-step sequences.
For every template and normalized substitution, prove a normalizing derivation
bounded by the template's unary/binary/ternary constructor count. Bottom-up
normalization leaves at most one root step per constructor. This is independent
of substitution size and proves existence, not a bound on every reduction order.

Join all local peaks, explicitly copying a reduction to the other occurrence
of a nonlinear AC-equivalent decryption key. Use the accepted weight and
strong induction to prove global matching confluence. Transport sequences
across AC, prove normality invariance and unique matching normal forms, then
prove quotient paths join modulo AC. All 22 audits and the regression cases
are mandatory in the existing checker/cell. Missing boundedness/confluence
audit transcripts fail closed after intended CLI red/green checks.

An ordinary ground-term measure is not a uniform substitution bound, and
syntactic non-overlap alone is not confluence for these nonlinear rules.
The kernel proofs replace those informal arguments in the typed scope.
The owner selected the actual typed protocol-query image for native
correspondence rather than expanding to every error-kind/arithmetic term.
Preservation/reflection and substitution/unification/narrowing closure remain
required; sorted AC-unification and the FVP theorem hypotheses remain open.
This addition is local/unpublished. No model, protocol, API, wire, primitive,
constant-time, runtime, gate or resource-limit change is authorized.

### Typed equation B-coherence (2026-10-14)

Continue the owner-approved source/CLI/kernel proof seams with a matching-
modulo-AC relation for the same six equations and typed algebra. A syntactic
matcher cannot decrypt when the two natural key representatives have
different AC order. The kernel regression observes that intended red; the
new relation requires equality modulo AC and makes it green.

Prove both matching soundness against quotient rewriting and realization of
every quotient step from the original representative, then the stronger
one-step B-coherence property. Matching termination follows from the existing
well-founded quotient relation. Audit all five new theorem reports and compile
the kernel cases through the existing command/cell. The CLI rejects a
termination-only audit transcript. No additional CI job or resource ceiling.

An informal non-overlap argument or a ChC result would not provide this
kernel-checked equation-versus-axiom property. Conversely, this typed proof
does not establish native kind/error-term or bookkeeping conservativity,
native FVP or full assembled replay. The later typed convergence/boundedness
increment above supplies additional kernel evidence, not native acceptance.
Source export/translation remain trusted; equations,
rules, restrictions, attacker, protocol, API, wire, runtime and constant-time
claims are unchanged. The profile stays opt-in and implementation closed.
The new addition is local/unpublished at authoring; the earlier termination
checkpoint passed final-source hosted acceptance at `70c1c19` in PR #9.

### Source-guarded equation termination (2026-10-14)

The owner approved reproducible CLI/kernel/checker test seams for the exact
equational-theory gate. Add a Lean `4.34.1` termination subgate for the six
expanded equations modulo sorted natural AC. Validate all message-function
ranks and generate source-to-kernel rule correspondences; reuse the lifecycle
equation inventory and mandatory theorem axiom audit. Run it in the existing
fast/CI lifecycle cell, without another job, application dependency or larger
resource ceiling. The kernel red rejects a constructor-only measure on both
ground role rewrites; the all-function-symbol measure passes.

This is an additional accepted proof mechanism, not a waiver of full
assembled replay or independent mixed-theory/FVP acceptance. CRC local
confluence/sort-decreasingness and finite flat-pattern enumeration do not
discharge source/signature-transfer or AC-coherence hypotheses automatically.
The Python translation and Tamarin export remain trusted. The source equations,
rules, restrictions, attacker model, wire/API/runtime behavior and proof
certificates are unchanged. Keep the profile opt-in and implementation closed.
At authoring, local kernel/source checks pass and hosted validation is pending.
Published revision status is recorded by its PR/CI. See the
[checker reference](../spec/models/equations/README.md).

### Current proof-only increment (2026-10-13)

The owner requested continued ratchet proof completion. Add the generated
`kem_and_ct_tail_origin [sources, use_induction]` certificate only to
`DISCLOSURE_SOURCES`. Joint induction proves KEM and encrypted CT-tail
payload provenance against raw sources in 60 steps; certificate-only replay
has no search bound. Refined deconstructions now complete, while raw sources
retain 30 chains. No equation, rule, restriction, compromise capability,
wire contract or runtime dependency changes.

All 56 completed safety certificates replay together. Regenerate only the
stale `fresh_ss_origin` proof tree through Tamarin, retaining its exact formula
and attributes; it verifies in 85 steps. Replay all four existential witnesses
separately with all source certificates and the unchanged transition system.
The owning runner now requires complete refined-source output and rejects
any unexpected incomplete safety certificate. Add the joint-source, complete
safety and missing witness targets to existing local/CI gates.

This replaces the earlier 16-chain limitation, not the acceptance policy.
The full assembled invocation was system-killed with exit 137 before a
summary. A full-context variant hiding ordinary reuse hints only from the
existential witnesses also timed out at 240 seconds and was not adopted.
All 19 formal jobs passed at `85aa105` in
[run 38442377893](https://github.com/trancee/cairn/actions/runs/38442377893).
Independent combined-equation/FVP acceptance remains unverified.
Keep the profile opt-in and the ratchet
implementation gate closed. Independent contexts are not a claimed full
assembled Tamarin result. The three serialization claims still use the
accepted Lean compositional route. See the
[current evidence](../spec/models/ratchet-source-evidence.md#current-result-2026-10-13).

### Earlier observations

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
Local syntax/proof checks are not hosted CI evidence. All 11 formal jobs
passed on final PR #2 head `ce54305` in
[run 37972978282](https://github.com/trancee/cairn/actions/runs/37972978282).
Required-check enforcement remains an external prerequisite; the last
settings inspection found no rulesets or `main` protection.

The proof-only `DISCLOSURE_SOURCES` profile now adds CK/SS origin
certificates, replayed against raw sources. It leaves all transitions,
restrictions, equations and default certificate contexts unchanged.
It reduces refined partial chains from 30 to 15. All eight affected
safety proof skeletons have now been migrated in the new source context.
It remains opt-in because SS source closure and full assembled-context
verification are incomplete, rather than invalidating default evidence.
The witness runner and workflow check its three source certificates and
lost-data witness separately. This is not full profile verification;
see the [source evidence](../spec/models/ratchet-source-evidence.md#opt-in-disclosure-refinement).
The KEM origin skeleton is now migrated into a profile-specific generated
certificate with the same formula/attributes. Its 18-step replay is checked
separately by the runner/workflow; the default's 31-step certificate remains
unchanged. The refined safety-only context verifies 54/54 complete
certificates, not full theory completion.

Native mutation evidence remains separate from Lean's lifecycle projection.
The mandatory-mix regression now exports both assembled transition systems,
checks that `CLASSIC_FALLBACK` removes only `mandatory_mix`, retains the exact
target formula/attributes and replays without any helper lemmas. The default
claim must verify and the mutation must produce a solved native counterexample.
The attack skeleton is generated from a guided native export and omits
unselected alternatives, not protocol behavior. See the
[mutation reference](../spec/models/README.md#native-mandatory-mix-mutation-regression).
This adds a proof-only include and CI job, with no protocol, wire, API or
runtime migration. The stored-prefix regression uses the same approach:
`NO_PREFIX_GUARD` may add only the two tail rules without `!EK0`/`!CT0`
premises and with renamed diagnostic actions; all default declarations,
including `mandatory_mix`, remain unchanged. Its target `no_partial_mix`
must verify by default and falsify under mutation. The generated native CT
trace reaches mixed Resume without a prefix event. This establishes the
second guard's sensitivity, not full protocol correctness or a separate EK
attack. The shared generator is `extract_attack.py`; both mutation jobs are
separate from the lifecycle projection. Source/equation and full-context
gates remain open; hosted execution of the new jobs remains unverified.
