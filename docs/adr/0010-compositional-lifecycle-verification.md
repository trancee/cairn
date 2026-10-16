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

### Native budget diagnostics (2026-10-16)

Kind-family head `8c54f2b` passes actual hosted 169-audit kernel checks,
18 lifecycle callers, all 11 Rust jobs and six required CodeQL jobs.
Its lifecycle core cell nevertheless fails the unchanged full-export cap:
three-pair medians `24.513057061`/`28.576567731` seconds give `+16.576923%`,
above `10%`. Startup does not run. Final rollup is 36 successes, one failure
and one intentional simulator skip. The native source/Linux binary match
preceding accepted measurements; neither that identity nor local success
establishes the cause or accepts the failed head.

The owner selected `diagnose-and-fix-native-performance`, approving bounded
native-performance diagnosis and a justified fix beyond the proof-only
checkpoint. Preserve all equations, grammar, validation, strict gates,
deadlines, jobs and budgets; no unchanged rerun, dispatch, merge or SDK/profile
activation. Start with a distinguishing diagnostic, not speculative native
algorithm, scheduler or signal-handling changes.

An unchanged local three-pair baseline gives `+6.403659%`, so the Linux
failure is not locally reproduced. The first process sample catches an idle
worker and cannot locate active costs. A second sample selects an owned
interactive worker with increasing CPU time and shows predominantly stdin/
native-output poll waits. Python profiling charges `0.151` seconds to final
journal reconciliation, not most of the added latency. These bounded local
observations motivate separating waited-child CPU/context-switch changes
from wall latency; they do not prove Linux scheduling or parser causation.

Add per-sample `RUSAGE_CHILDREN` user/system seconds and voluntary/involuntary
context-switch deltas to the existing benchmark report. Snapshot outside wall
timing, preserving sample order, three alternating pairs, fixed digests and
both budgets. Accounting covers reaped descendants only when intervening
parents waited; it cannot isolate each guard or all host work. Keep older
reports compatible, validate present diagnostics strictly, and never use
diagnostic values as an acceptance fallback. This is additive internal
proof-tool reporting, not a shipped SDK/wire/API change or performance fix.

Alternatives were treating the previous pass as current acceptance, retrying
unchanged CI, raising the cap, guessing an I/O optimization or adding new CI
jobs. None supplies the missing native evidence under the approved bounds.
Existing benchmark/native CLI seams cover a real screening report plus
malformed diagnostics, compatible old/new reports and unchanged budget
rejection. Both missing-report and malformed-report reds precede implementation.
All 17 report tests and 20 native CLI/process/proof cases pass; the three
changed Python files remain below 300 lines.

Current local diagnostic three-pair medians are `24.282312`/`25.776653` seconds
(`+6.154029%`) and `0.112028`/`0.148284` seconds (`+36.256333` ms) for
full export/startup. All six exports per workload are fixed-identical; both
reports independently pass their current-source/workload validators.
The guard source and executable are unchanged. A new diagnostic head still
requires actual own-head CI and actual resource evidence; even a passing
measurement alone would not establish a fix for the earlier failure.

### Admissible kind-shadow factors and families (2026-10-16)

Continue the approved proof-only phase with constructive assignment expansion,
exact abstraction/expansion round trips, ordered composition and mapped input
supports. A shadow is admissible only if its expansion is sorted in every
original sort and reabstraction equals the shadow exactly. The inverse
constructs the original; this predicate is not an executable validator.

Require admissibility of both solutions and postfactors. Sorted shadow factors
alone are too broad: two sorted original message candidates, respectively
mapping to a Fresh residual and `one`, have an unrestricted shadow factor but
no sorted original factor. A sorted off-image lift also shows why expansion
sortedness cannot replace exact reabstraction. Preserve/reflect scoped
factorization, supplied-family sound completeness and most-generality under
the full constraint. A mixed-kind commutative MGU and empty-family
Fresh/natural equality distinguish admissible coverage from unrestricted
shadow coverage. Do not filter native replies or weaken original sortedness.

Two intended missing-report CLI reds (`0 != 1`) become rejecting greens.
Fourteen new reports bring the total to 169, retaining 25 axiom-free and no
`sorryAx`. Only admissible-shadow composition inherits classical choice from
existing sorted composition; other new audits use at most `propext` and
`Quot.sound`. All four proof/case modules remain below 300 lines. The central
audit registry (320 lines) and shared CLI fixture (422) remain cohesive,
avoiding duplicated inventory/process setup, below the mandatory 500 limit.

This closes mathematical constrained kind-family transport, not finite
complete native generation, runtime lookup/occurs-check/fresh-namespace/
importer correctness, narrowing/FVP, the full imported carrier or exact
assembled acceptance. Native source-ID inputs, equations, grammar, protocol/
API/wire/runtime, strict options/deadlines, jobs and numeric budgets are
unchanged. Existing proof-checkpoint publication approval applies, subject
to actual new-head hosted acceptance; no dispatch, merge or activation.

### Finite solution support and residual postfactors (2026-10-16)

Continue the approved proof-only phase by connecting total mathematical
assignments to explicit finite binding lists. Restrict assignments to input
variables with identity elsewhere, preserving sortedness and exact substituted
inputs. Mathematical lookup is first-binding and simultaneous; it is not a
change to the native parser/importer or its duplicate policy.

Postfactors must instead retain variables in candidate values. A variable-pair
MGU maps both inputs to residual variable `7`; reaching `one` needs a binding
for `7`, absent from the original support. Kernel controls reject every
input-only supported factor. Prove finite range-supported factor witnesses,
finite representatives for all sorted solutions, and equivalence of complete
coverage/most-generality with input-supported finite solutions. Restricting an
existing family preserves/reflects completeness only when its original
candidates are sorted; erasing an invalid binding cannot justify acceptance.

Two vertical missing-report CLI reds (`0 != 1`) become rejecting greens.
Fourteen reports bring the total to 155, retaining 25 axiom-free and no
`sorryAx`; the new audits use at most `propext` and `Quot.sound`.
Two kernel case modules retain all five sorts, framing, simultaneous lookup,
frozen indices, duplicates/empty lists, residual factors and invalid-original
versus valid-restriction separation. New proof/case modules stay below 300
lines. The central audit registry (302 lines) and shared CLI fixture (418)
remain cohesive rather than duplicating their inventories/process setup;
both remain below the mandatory 500-line limit.

This closes mathematical finite representability, not finite complete family
generation, native occurs-check/fresh-namespace/importer correctness,
kind-family transport, narrowing/FVP or exact assembled acceptance.
No equation, native source-ID input, grammar, protocol/API/wire/runtime,
option/deadline, job or numeric budget changes. Existing proof-checkpoint
publication approval applies, with actual new-head hosted acceptance required;
no dispatch, merge or SDK/profile activation is authorized.

### Scoped AC factorization and conditional completeness (2026-10-16)

Continue the approved proof-only phase by separating valid solutions from
sound complete families. Define sorted postfactor instantiation modulo AC on
the variables of the two original input queries, not on every assignment
binding. A variable-pair MGU with an unrelated message binding demonstrates
why the global alternative is too strong: extending its comparison scope
would reject a valid scoped MGU. Grounding both query variables to `one`
demonstrates the independent gap between soundness and completeness.

Extract source supports through every raw context, excluding rigid atoms and
retaining sort/index distinctions. Prove scoped substitution congruence,
postfactor preorder laws and solution closure with an explicit sorted-specific
premise. Independently define typed composition and all-five-sort scoped
equality/AC. Encoding commutes with composition; preserve/reflect factor
witnesses through the existing exact representation of sorted assignments.
On proper message/natural inputs, transport completeness of a supplied finite
family in both directions.
Likewise transport candidate most-generality, with a separate singleton
completeness equivalence. Do not infer general finite enumeration, irredundancy,
finite-support/native occurs-check/fresh-name correctness, kind-shadow family
transfer, narrowing/FVP or importer verification.

Three vertical missing-report CLI reds (`0 != 1`) become rejecting greens.
Fourteen mandatory reports bring the total to 141, retaining 25 axiom-free
and no `sorryAx`. Three kernel case modules cover all-sort support/composition,
order, frozen indices, natural AC, sorted-factor rejection, a complete singleton,
incomplete/empty families, an unrelated-variable scope counterexample and
cyclic/no-zero finite-AST solution controls. New proof/case files remain below
300 lines; the cohesive independent CLI fixture remains below 500 under the
preceding shared-fixture rationale.

The owner's separate all-Actions request updates the three CodeQL Action pins
to verified stable `v4.39.0`; see [ADR 0015](0015-build-backed-kotlin-codeql.md#action-release-refresh-2026-10-16).
No equation, guard source-ID input, native grammar, attacker, claim, rule,
restriction, strict option/deadline, job, numerical budget or runtime/API/wire
change. Existing checkpoint publication approval applies; actual current-head
hosted acceptance remains mandatory, with no manual dispatch, merge or
SDK/profile activation.

### Sorted AC-unifier composition and image correspondence (2026-10-15)

Continue the approved proof-only phase with simultaneous assignment composition
and relational AC solutions. Applying first then second must agree with their
composition, preserve all five sort-value classes and freeze rigid indices.
Prove identity, associativity and pointwise AC congruence under every context.
Define AC solutions separately from equality modulo the six rewrite equations.
Sorted solutions compose; proper message/natural solutions preserve/reflect
through the existing typed representation, with a representation for every
sorted native solution on those inputs.

Kind correspondence must retain the abstract assignment derived from the
original sorted assignment. A Fresh variable and natural variable have no
sorted original unifier, but their two abstract natural variables can both be
assigned `one` by an unrestricted typed shadow. The kernel proves that witness
cannot be compatible. Actual pinned Maude confirms cross-sort failures,
including a mixed-kind sum, and a same-sort success. Plain unification also
does not apply the `flip` equation. Reject the tempting alternative of treating
all shadow solutions as original solutions; do not filter native solutions,
widen grammar or assume finite complete unifier generation.

Three vertical missing-audit CLI reds become rejecting greens for assignment
algebra, sorted solutions and compatible kind solutions. Thirteen mandatory
reports bring the total to 127, with 25 axiom-free. Kernel cases retain
all-sort composition/order, rigid indices, framed `kdf` AC congruence, typed
solution representations and compatible/incompatible shadows. One additional
real-operation case preserves the approved native-stream seam. The cohesive
independent process fixtures stay below 500 lines: `test_equations.py` 409,
`test_maude_boundary.py` 384, transcript inventory 111. Keeping their shared
setup intact avoids coupling fixtures solely to meet the 300-line recommendation.

Finite complete enumeration, sorted most-generality, occurs-check/fresh-name
correctness, narrowing/FVP and native algorithm/importer correspondence remain
open. This is mathematical solution transport, not algorithm verification.
The existing `publish-proof-checkpoints` approval covers publication subject
to local gates, scanning and actual exact-head hosted acceptance. Equations,
native source-ID inputs, grammar, jobs, strict options/deadlines and budgets
stay unchanged. No SDK/profile activation, manual dispatch or merge.

### Sort-respecting guarded substitution closure (2026-10-15)

Continue the approved proof-only phase by modeling native values at each of
the five variable sorts. Arbitrary raw assignments can turn proper equation
arguments into nodes, framing or ill-kind sums; unguarded substitution closure
cannot justify guarded matching. Instead prove both directions between
sort-respecting native assignments and the existing typed substitution
representation. This preserves proper-message guards and guarded
matching/quotient steps and count-preserving paths under simultaneous
substitution, while rigid indices stay frozen.

Kind abstraction preserves recognized natural/proper-message values, and its
abstract assignment is sorted. A typed representation therefore supplies the
previously assumed compatible shadow. Controlled-kind/free framing closure
now follows for every modeled sorted assignment, without a second premise.
Do not claim arbitrary assignment closure, rewrite reflection or normality
preservation: even a normal sorted pair assignment can create a new root redex.
Native unification/narrowing completeness, algorithm/classifier/importer
correctness, namespace correspondence and FVP remain open.

A green 38-case equation baseline precedes extracting the independent
transcript inventory to `equation_fixtures.py`; the same 38 cases remain green.
The shared process fixture stays cohesive at 405 lines, below the 500-line
hard limit, without importing the production audit inventory into its oracle.
Two vertical missing-audit CLI reds become rejecting greens; 12 new reports
bring the total to 114, with 24 axiom-free. Representation witnesses and their
derived substitution results use the already allowed classical choice only
in the mathematical proof, not the executable guard.
Kernel cases retain all-sort rejection, simultaneous substitution, frozen
same-index atoms, Fresh/natural shadow separation, controlled-kind framing,
blocked root matches, nonlinear AC keys, counted paths and redex creation.

Publication is covered by `publish-proof-checkpoints`, subject to local gates,
full-file scanning and actual new-head hosted acceptance. Native guard
source-ID inputs, grammar, equations, options, deadlines, jobs and numeric
budgets remain unchanged; no SDK/profile activation or merge is authorized.

### Guarded native convergence beyond proper messages (2026-10-15)

Continue the owner's approved proof-only checkpoints without changing native
equations or grammar. A guarded root redex is always a proper message, even
when the surrounding context is not. Prove exact typed matching decoding
and proper-message exact joins, then use them only for primitive overlaps.
Structural induction joins same-child peaks and commutes disjoint child steps
through every raw context. A strictly decreasing source-context count proves
termination and global matching confluence on the frozen-index AST.

Do not transfer unguarded shadow confluence or assume arbitrary raw properness
invariant: a function inside a natural sum can make a formerly improper
expression proper after reduction. Instead prove paired forward/reverse
structural AC transport, including natural associativity/commutativity and
message/framing congruences. The guarded quotient relation remains distinct
from `NativeModuloACRewrite`. Count-preserving matching realization establishes
guarded quotient confluence, AC-invariant normality and normal-form uniqueness
modulo AC; AC-invariant strict decrease also establishes quotient termination.
These universal frozen-index AST results cover controlled-kind/free framing,
but neither widen the stream grammar nor verify the full imported NAT/kind
carrier, native algorithms, sorted narrowing/unification/FVP or the importer.

Four successive missing-audit CLI reds become fail-closed greens after each
vertical proof slice. Eighteen new mandatory reports bring the total to 102,
with 24 axiom-free. Kernel cases cover distinct AC-equivalent error-kind normal
forms, exact matching decoding, free framing/nonlinear key-copy peaks, `kdf`
and clearly marked raw-AST cases outside the stream grammar.
The cohesive CLI fixture is 488 lines, retaining the preceding D9 rationale
for its shared independent process fixture and staying below the hard limit.
No equation, protocol, public API, wire, runtime dependency, native guard
source-ID input, job, deadline or numeric budget changes. Current-head hosted
acceptance remains required; publication is covered by the existing
`publish-proof-checkpoints` approval, not merge or SDK/profile activation.

### Guarded native query normalization bound (2026-10-15)

Continue the approved proof-only phase by proving normalizing-path existence
directly on the frozen-index native AST. Transferring the raw shadow normalizer
would incorrectly erase blocked ill-kind components; restricting to proper
messages would leave required derivation-kind queries uncovered. Instead use
structural bottom-up normalization with the existing guarded relation and
`substituteNativeQuery`. Normal children leave at most one root step, whose
result is a normal subterm or role constant. Shared unary/binary composition
handles the demonstrated repeated message, natural-addition and framing cases.

The source-only count includes unary/binary/kdf/natural-add/list/cons contexts
and excludes variable-assignment size and rigid indices. The theorem quantifies
over every native template and normalized assignment, not sampled terms,
without requiring a compatible typed shadow. Its broader raw-AST domain does
not widen the approved stream grammar or establish arbitrary substitution/image
closure. Controlled-kind confluence, sorted narrowing/unification, namespace/
importer correctness and native FVP remain open; the bound concerns existence
of a normalizing derivation, not every reduction order or native algorithms.

Three new mandatory audits bring the total to 84, with 24 axiom-free.
The existing CLI first accepts an 81-audit transcript without these reports;
its intended `0 != 1` red becomes a rejecting green. Kernel cases retain
the blocked projection's one-step inner normalization, source-only bounds,
arbitrary normal replacements, tuple/Node framing, nonlinear keys and `kdf`.
A fresh fast gate passes 19 native/135 model/50 lifecycle cases, 43 projections
and all audits. The cohesive source/CLI fixture remains below 500 lines under
the preceding documented D9 rationale.

This increment is covered by the owner's `publish-proof-checkpoints` approval.
There is no protocol/equation/API/wire/runtime dependency, native guard source-ID
input or resource-budget change, nor SDK/profile activation or merge approval.
Current-head authoritative hosted acceptance is still required; immutable
preceding observations are not rewritten to imply acceptance of a later head.

### Native proper-sort relation transfer (2026-10-15)

Continue the approved kernel/CLI proof seams with independently defined native
root patterns: proper-`Msg` guards on equation variables and AC-equivalent
repeated keys, closed under every raw context. Do not define this relation by
the source matching relation or replace native matching with the unguarded
kind abstraction. Real Maude controls retain the blocked error-kind projection,
proper Fresh projection, inner rewrite inside an error-kind context and
AC-key decryption. The raw shadow relation intentionally remains separate.

Typed matching lifts to the guarded relation, and every guarded step is a raw
quotient step. This transports proper-message termination, B-coherence,
confluence/normal-form uniqueness modulo AC, normality invariance and the
source-template-only normalizing bound. Controlled-kind framing closure and
decoded-kind termination also hold; controlled-kind convergence and bounded
normalizing paths do not follow. Nor does this prove complete sorted
AC-unification, narrowing/FVP, universal importer correspondence or Maude's
algorithm implementation.

Fourteen new mandatory audits bring the total to 81, with 22 axiom-free.
Missing matching/convergence reports have intended CLI reds followed by
fail-closed greens, plus a complete-transcript positive control. Kernel cases
cover all six rules, improper discarded components/keys, Node/list rejection,
AC keys, a nonlinear key-copy peak and the template bound. Fresh
`scripts/check.sh` passes 19 native/134 model/50 lifecycle tests, 43 projections
and all audits at unchanged limits. Keep the existing cohesive source/CLI
fixture above the 300-line recommendation but below 500 rather than adding
cross-fixture coupling.

This proof-only increment has no native guard source-ID input or
equation/protocol/API/wire/runtime/performance-budget change. Existing native
guard measurements remain source-identical; no new performance result is
claimed. The owner subsequently selected `publish-proof-checkpoints`,
authorizing commits, normal pushes and PR-description updates for the proof-only
phase and necessary fixes in PR #9, separately from the completed promotion.
Current-head hosted acceptance remains required. No manual dispatch, merge,
protocol/equation/deadline/budget change or SDK/profile activation is authorized.

### Maintained-proxy promotion and startup-only budget (2026-10-15)

The owner selected `promote-with-50ms-startup-budget`. Prepare maintained
compiled proof tooling, but require Linux parity, all caller regressions and CI
integration before default cutover. That selection did not authorize publication.
The owner subsequently selected `publish-promotion-checkpoints`, authorizing
commits, pushes and PR-description updates limited to this promotion, necessary
fixes and conditional default cutover after the required criteria pass.
Use PR #9's existing native CI; no manual dispatch, merge, SDK work or profile
activation is authorized.

The approved budget is narrowly workload-specific:

| Workload | Environment and method | Threshold |
|---|---|---|
| Complete strict `ratchet.spthy` MSR export | Apple-silicon macOS `27.0.1`, 8 GiB, pinned Rust `1.99.0`/Tamarin `1.12.0`/Maude `3.5.1`; three alternating direct/guarded pairs, identical bytes and complete evidence | Guarded median at most `10%` above direct median |
| One-rule paired-counter [`derivation.spthy`](../spec/models/equations/native-proxy/derivation.spthy) export | Same environment, toolchain and three-pair method | Guarded median at most `50` ms above direct median |

The rationale is the measured `39.93` ms fixed cost on a `118.29` ms fixture,
while representative overhead is `6.80%`. Only the tiny startup workload gets
an additive allowance; it is not a blanket relative waiver or larger proof
deadline. The preceding Python path failed its representative budget and is
removed by the accepted cutover below.
The maintained [CLI reference](../spec/models/equations/native-proxy/README.md)
records reproducible measurement and rejecting report/budget gates.
The same limits apply per recorded native-host environment in CI; do not mix
hosts or reuse an earlier binary's performance as current-source acceptance.
Other platforms and full-proof/memory performance still require their own
evidence; the local result is not native Linux or hosted acceptance.

The guard is a standalone `cairn-maude-proxy` Cargo package under
`equations/native-proxy`, outside the SDK workspace. Build once per gate/cell.
Embed a deterministic source ID from reviewed Rust/build/generator/shared
inventory/reconciler inputs and the root Rust pin; include it in each
`version` record and require a current match before accepting native evidence.
Missing/stale binaries or journals fail closed with rebuild guidance, without
extra per-proof version subprocesses or a Python fallback.

Staging used one temporary explicit candidate route through the shared runner
for local and existing 19-cell CI caller validation. The benchmark's explicit
executable used the same runner. This established Linux acceptance before
default cutover without duplicating CI jobs. The accepted cutover below removes
that selector and the obsolete Python implementation/tests.

Alternatives were leaving an unmaintained prototype, accepting stale binaries,
adding per-operation builds or doing an unverified immediate cutover.
Those do not satisfy the approved freshness/performance/rollout constraints.
The source hash is not signed build attestation; native parsing/FFI and the
Python/tool/measurement boundary remain trusted. CI explicitly names this
internal host tool's SDK-coverage exclusion and runs its static, adversarial
CLI/native-stream/process and performance checks instead.

The staging local gate passed 19 native cases, 138 model tests,
50 lifecycle tests, 43 projections and 67 equation audits. Missing-identity and
budget-mode reds precede implementation; a real stale compiled executable
also rejects after source changes. Source-read/encoding and generator-output
I/O errors have intended reds and controlled failure regressions.

Staging-source three-pair direct/guarded medians were `24.248549`/`25.807651`
seconds for the complete export (`+6.4297%`) and `0.110541`/`0.147073`
seconds for the exact startup fixture (`+36.531959` ms, `+33.0482%`).
Both approved gates pass, with unchanged export bytes and saved reports
independently rechecked by the CLI. The reference retains source/binary
identities and environment. Final-build default recovery, all 56 refined
safety certificates and both native mutation regressions pass at the
original `180`-second caps, preserving 43 rules/13 restrictions.
These four selected local regressions are not native Linux/all 19 CI cells;
run `38710117729` at `2e7b429` passes all 18 native replay/mutation cells and
the lifecycle fast gates, but its benchmark rejects an unreviewed export
before reaching a budget verdict. Preserve every digest/budget check and
report only the failing phase and expected/observed SHA-256 identities to
distinguish an unexpected direct baseline from a changed guarded export.
Diagnostic run `38712391261` at `942f8d8` identifies the unguarded baseline:
the inventory retained only the macOS full-export digest. Also retain the exact
pinned native Linux export digest recorded in the reference. Do not derive an
accepted digest from the first runtime sample: every export must match the
fixed inventory and all six must be byte-identical within a measurement.
No output normalization, filtering, source/evidence or numeric-budget change
is permitted. Public report CLI reds/greens cover the Linux fixture and both
relative-limit and startup-allowance rejection. Both retained macOS reports
passed at that fixture-only checkpoint. Run `38714285780` at `67584ea` then
completes all six identical Linux exports but fails the unchanged full-export
limit: `35.220242`/`38.939536` seconds (`+10.5601%`). Startup does not run.

An active native-process sample identifies stdout write/flush cost; the parent
full-journal audit takes only `0.151` profiled seconds locally. Forward each
already-validated owned reply plus its original prompt through one raw stdout
descriptor, cloned once per process, with checked writes/flush/close. This avoids
line-buffered body/prompt splitting without removing any validation or event.
The stdout-only intermediate source passes local full export (`+6.4369%`) but
fails startup (`+52.560041` ms). An isolated exact-digest startup profile shows
`13` ms in one final-evidence sleep, not missing native validation. Poll complete
evidence every `1` ms instead of `10` ms, keeping the same `5`-second grace and
every audit. This trades more frequent bounded teardown checks for less fixed
startup latency, not a retry of failed proofs. Closed-consumer I/O failure has
a public native-stream regression, green before and after the refactor.
The resulting local budgets pass as recorded above; no unchanged budget rerun
or allowance increase is used. Earlier source reports are historical and reject
as stale against this source. Fresh native acceptance is still required.
Run `38719650091` at `2b642e2` passes all 18 callers/fast gates and the actual
native full-export budget: `37.767068`/`40.976767` seconds (`+8.4987%`), with
all six outputs identical. Startup then rejects an unreviewed direct baseline,
not a timing failure. Apply the same fixed per-host inventory decision to the
exact observed Linux startup digest recorded in the reference; retain the macOS
digest, the requirement that all six exports be byte-identical, and `50` ms cap. Public report
CLI red/green and above-cap rejection cover both startup fixtures. Native guard
source/binary identities are unchanged by this benchmark-only correction;
the two current macOS reports and native full-export report still pass.
At that checkpoint full native budget acceptance and default cutover were
blocked. Full-proof/memory overhead remains unmeasured.

### Accepted native staging and central default cutover (2026-10-15)

Run `38721189200` at `71168a1` passes all 19 native cells: every replay/mutation
caller, fast gates and both actual three-pair budgets. Linux medians are
`32.023234`/`35.116483` seconds for full export (`+9.6594%`) and
`0.103667`/`0.119538` seconds for startup (`+15.871115` ms, `+15.3097%`).
Both workload exports match the retained per-host digest and all six bytestrings
within each measurement are identical. This meets the owner-approved staging
condition for central default cutover, not a merge or SDK/profile activation.

Make the compiled guard the only shared ratchet default. Resolve
`CARGO_TARGET_DIR/release/cairn-maude-proxy`, or root
`target/native-proxy/release/cairn-maude-proxy` when unset. Relative targets
follow Cargo's working directory; explicitly empty targets reject, as Cargo does.
Keep the benchmark/process CLI's explicit absolute executable via the `proxy`
keyword. Require source identity on every version; remove the optional legacy
identity branch, temporary selector and obsolete Python validator/evidence/
parser. Preserve the reviewed module builder and generated inventory.
Proof commands reject missing/stale builds with guidance, never build or fall
back automatically. `scripts/check.sh` and existing CI build once and share
their Cargo target with all consumers.

The intended guarded-command default-selection red precedes implementation.
All nine obsolete private-parser test groups have native CLI counterparts;
the standalone framing and leading-blank incompatible Pub binding are retained
explicitly. Malformed lifecycle fixtures now include valid identity where
appropriate and assert the intended reason. The current default fast gate
passes 19 native/131 model/50 lifecycle cases, 43 projections and 67 audits.
Current-source local budgets pass at `+6.1498%` full export and `+41.960417` ms
startup (`+37.3660%`). At `2fa6d16`, actual native budgets pass at `+8.3650%`
full export and `+25.785370` ms startup (`+20.7876%`), with independently
checked saved reports. Native run `38724991914` passes 18/19 cells:
`initial_ck_secret` fails its unchanged strict `60`-second derivation check
during assembled export, before its selected proof. The exact local caller
passes its 11-step claim and five origin helpers, not establishing a native
reproduction or fix. Preserve the failure; do not raise limits, relax warnings
or manually rerun it unchanged. All current-head hosted gates remain required
and subsequent publication checks are recorded by PR #9.
Leaving a permanent dual validator, keeping aliases to the temporary
route, or reusing an older source report were rejected alternatives.
No shipped API, protocol, wire, primitive, runtime dependency or constant-time
claim changes; the proof tool/parser/compiler/importer remain trusted.

### Compiled proof-proxy feasibility prototype (2026-10-15)

After I/O optimization left `+22.5%` representative overhead, the owner selected
`prototype-compiled-proxy`: a bounded local experiment retaining every validation
and evidence check, with measurement before any cutover. Continuing speculative
Python changes or accepting a budget exception were alternatives; neither was
selected. No publication, merge or default activation approval is implied.

The [standalone Rust prototype](../spec/models/equations/native-proxy/README.md)
has no third-party dependencies and does not join the application workspace.
Cargo generates its module/function inventory from the existing reviewed Python
inventory. Extracting that inventory builder leaves the default Python module
checker's contract unchanged. The existing independent native-stream fixture
also accepts the explicit prototype executable for opt-in tests.

Retain full iterative term recognition, sort/kind/namespace/index checks, all
solutions, buffered whole-reply forwarding, per-process version/module/shutdown
evidence and complete operation journals. Checked close/write failures and
ready-versus-pending interruption remain fail closed. Host-only POSIX FFI is
isolated in `unix.rs`; no crypto/core unsafe-code rule or shipped dependency
changes. This port is not kernel-verified or exhaustively equivalent to Python.
Native Linux execution and all compiled acceptance callers remain unverified.

Reduction and missing-unification behavior reds precede their implementations.
All 18 opt-in CLI/process/proof cases, strict Clippy/format checks and the
117-model/50-lifecycle/67-audit default fast gate pass. Three alternating
complete-export pairs on macOS measure `24.281`/`25.931` seconds (`+6.80%`),
with identical bytes. The one-rule fixture separately adds `39.93` ms
(`0.118`/`0.158` seconds, `+33.76%`), still exceeding the relative limit.
No exception had been approved at that checkpoint; the subsequent narrow
startup budget is recorded above. Passing the representative workload alone
is not a full-proof/memory measurement.

At that checkpoint the prototype was outside default acceptance/CI selection.
The later approved maintained staging above supersedes that status, not the
Linux/caller criteria. At that prototype checkpoint the default proof route
remained Python at `+22.5%`, still blocked. Native sorted
matching/narrowing, complete AC-unification/FVP transfer and full-context proof
acceptance remain independent open gates. No protocol/API/wire/primitive or
constant-time claim changes.

### Checked evidence I/O optimization (2026-10-15)

The owner selected `optimize-evidence-io` after the actual complete ratchet
export exposed `+46.3%` overhead; the initial parse-only `+2.7%` figure
was not representative. No performance budget exception was approved.
Profiling identified 181,760 per-event report opens/writes/closes across
90,874 operations, with `8.619` instrumented seconds in report handling.

Keep every event and the existing record schema. Batch only operation
`begin`/`accepted` records through one validated regular-file descriptor per
process, flushing at 16 KiB plus at most one record. Flush and close before
writing successful shutdown evidence. Keep immediate lifecycle/failure
records, no-follow/nonblocking file validation, complete-write checks and
mandatory final reconciliation. Missing/partial records and report-capacity
failure still reject the whole proof command. The buffer does not impose
a query, reply or proof-search cap.

Reuse the selector and share checks between canonical-leaf and full term
recognition. Accept canonical operation JSON through an exact checked
grammar; keep the complete field/type/duplicate audit for other JSON.
Bulk 512-operation and real report-capacity tests exercise the existing
CLI/native-stream seams. All 117 model tests, 50 lifecycle tests and 67
equation audits pass. The shared native fixture remains above the 300-line
recommendation, below 500, for its existing independent module/stream seam.

Final-source three-pair medians are `24.303`/`29.761` seconds direct/guarded
(`+22.5%`), with unchanged full export and deadlines. This improves the initial
guard's elapsed time by approximately 16%, but still fails Constitution P4.
A single-pass token experiment did not materially improve performance and
was removed. That optimization decision did not authorize compiled/upstream
rewrites, performance waivers, publication, merge or activation; the separately
approved prototype above does not authorize a default replacement.
The initial measurements below remain historical evidence.

### Required derivation-kind image (2026-10-14)

Hosted formal run `38622779805` at published `3d5dd7c` passed the lifecycle
cell but failed all 18 replay/mutation cells on a query containing
`tamtplus(x0:Fresh,tamXCtone)`. The exact valid one-rule input reproduced the
failure locally. Pinned `MessageDerivationChecks.hs` calls `natToFreshVars`
inside premise constructors, so the proper-sort query image was too narrow.
The owner explicitly selected `extend-derivation-kind-image`, rather than a
Tamarin patch or keeping the blocker. Skipping derivation checks is not an
alternative.

Extend only the required grammar: Fresh/natural leaves in natural sums and
their existing enclosing message/free framing contexts. Keep native proper
sorts on returned bindings/results and reject kind variables, `[TOP]` result
headers, arithmetic and arbitrary message/public/function/list sum operands.
Preserve exact equations, attacker, claims, strict warnings, proof options
and deadlines. No solution filtering, backend patch or success fallback.

Use proof-only disjoint even/odd natural shadows for original natural/Fresh
leaves, preserving variables versus rigid atoms. Prove structural inverse/
injectivity, raw AC/rewrite preservation/reflection, image closure, substitution
commutation and termination on decoded kind messages. Framed substitution
closure retains an explicit compatible typed-shadow premise. Three generic
relabeling and eleven kind audits bring the mandatory total to 67; 21 are
axiom-free. The collision kernel red and old 53-audit CLI red are green, as is
the actual one-rule derivation regression.

Raw rewrite rules omit native proper-message guards. A projection can erase
an ill-kind discarded component in the shadow/raw algebra even when actual
Maude cannot match it. These proofs do not transfer native confluence,
normalizing-path existence, sorted narrowing/unification completeness or FVP.
The [explanation](../spec/models/ratchet-equation-evidence.md#what-the-new-kind-abstraction-does-not-transfer)
records the concrete counterexample and remaining hypotheses.

The default recovery and all 56 refined safety certificates replay locally;
the latter has complete refined sources. These are selected contexts, not
full assembled acceptance. The extension remains unpublished and hosted
acceptance unverified. Final parse-only median overhead is `+2.7%` with
identical exports, but complete ratchet export overhead is `+46.3%`
(`24.178`/`35.385` seconds direct/guarded median), blocking merge under
Constitution P4. Profiling identifies per-operation report open/write/close
cost; no optimization or budget exception is accepted. Both mutation
regressions also pass with their expected attacks. Full-search/memory overhead
remains unmeasured. Passing existing deadlines is not a performance waiver.
The earlier pure proper-sort contract below is superseded only for the
controlled derivation-kind grammar. No protocol/API/wire/primitive,
constant-time, dependency, CI-job, budget, merge or activation change.

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
