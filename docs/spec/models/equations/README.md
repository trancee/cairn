# Equation convergence and image correspondence checker

Reference for the source-guarded typed convergence/boundedness and structural image subgate. This does **not** close
independent combined-theory/FVP acceptance or the ratchet implementation gate.
The [equation explanation](../ratchet-equation-evidence.md) describes that boundary.

## Command

```bash
python3 docs/spec/models/equations/termination.py --lean /path/to/lean
```

`--lean` defaults to `lean` on `PATH`. The checker requires the existing
[`lifecycle/lean-toolchain`](../lifecycle/lean-toolchain) pin, Lean `4.34.1`,
Tamarin `1.12.0` and Maude `3.5.1`. It creates fresh temporary build outputs;
there is no retained proof-result cache or application dependency.

The command:

- reads Tamarin's current canonical default export through the mandatory
  fail-closed native stream boundary described below;
- requires the exact 15 message-function ranks, six equations and sole
  `natural-numbers` builtin;
- kernel-checks `Termination.lean` and audits all six required theorem reports;
- kernel-checks `Coherence.lean`, audits its five required theorem reports and
  checks the AC-equivalent repeated-key regression cases;
- kernel-checks `Boundedness.lean`, audits three reports and checks uniform
  template bounds with arbitrary normalized message/natural assignments;
- kernel-checks `Confluence.lean` and `Convergence.lean`, audits eight reports
  and checks nonlinear key-copy peaks and quotient-path joinability;
- kernel-checks `QueryImage.lean`, audits four round-trip/injectivity reports
  and checks variable/rigid-index distinctions and improper-sort rejection;
- kernel-checks `QueryRecognition.lean`, `QueryAC.lean`, `QueryRewrite.lean`
  and `QueryMatching.lean`, audits 18 reports and checks image closure,
  structural AC/rewrite reflection and quotient-to-matching realization;
- kernel-checks `QuerySubstitution.lean`, audits six reports and checks
  sort-separated substitutions and frozen rigid indices;
- kernel-checks `QueryFraming.lean`, audits three reports and checks
  free tuple/Node image closure and rejection of framing beneath message functions;
- kernel-checks `QueryRelabeling.lean` and `QueryKind.lean`, audits 14 reports
  and checks disjoint Fresh/natural shadow labels, controlled derivation-kind
  membership and the distinction between raw rewriting and proper-sort matching;
- kernel-checks `QuerySorted.lean` and `QuerySortedConvergence.lean`, audits
  14 reports and checks guarded native-shaped matching, proper-message
  convergence/boundedness, controlled-kind closure and decoded-kind termination;
- kernel-checks `QuerySortedBoundedness.lean`, audits three reports and checks
  normalizing paths bounded only by native query templates, including
  error-kind, natural-addition and free tuple/Node contexts;
- kernel-checks `QuerySortedExact.lean`, `QuerySortedGlobal.lean`,
  `QuerySortedAC.lean` and `QuerySortedQuotient.lean`, audits 18 reports and
  checks exact guarded matching decoding, full frozen-index AST peak joining,
  structural AC transport and guarded quotient convergence/normal-form uniqueness;
- kernel-checks `QuerySortedSubstitution.lean` and `QueryKindSubstitution.lean`,
  audits 12 reports and checks all-sort assignment representation, guarded
  path preservation and controlled-kind framing substitution closure with a
  derived, not assumed, compatible shadow;
- kernel-checks `QueryComposition.lean` and `QueryUnification.lean`, audits
  13 reports and checks sorted composition, pointwise AC congruence and
  AC-unifier solution transport, including compatible kind shadows;
- generates and kernel-checks a certificate translating every source equation
  to its exact `PrimitiveRewrite` constructor.

Exit `0` means all typed subgates passed. Exit `1` reports `FAIL:` for
a missing/malformed toolchain pin, unreviewed/malformed source, unsupported tools,
a failed native command, missing/duplicate theorem reports or unexpected axioms. Native commands retain
the existing `120`-second bound; version checks use `30` seconds.
Invalid command-line syntax uses argparse's exit `2`; `--help` exits `0` without
checking a proof.
Only `propext`, `Classical.choice` and `Quot.sound` are permitted by the shared
axiom audit. Twenty-five of the 127 audited theorems use no axioms. The three
uniform normalization-bound theorems, assignment/shadow representation and
closure/solution-representation audits depending on those witnesses use all
three permitted axioms. Other audits use at most `propext` and `Quot.sound`.
Assignment witnesses use classical choice only in the mathematical proof,
not an executable native fallback.
No audited theorem uses `sorryAx` or a user-added axiom.

Successful output includes the canonical source SHA-256, all required axiom
reports and an explicit typed image correspondence scope statement.

## Mathematical scope

`NaturalTerm` contains positive-natural atoms and binary addition, with only
associativity/commutativity. It has no zero or identity. Natural terms embed in
`MessageTerm`; public, fresh and generic message atoms remain distinct tags.
The `Nat` identifiers label atoms/variables; they do not add natural zero.
`roleA`/`roleB` are message-sort nullary functions, not public-sort literals.
The remaining constructors have the source's exact unary/binary/ternary ranks.

`PrimitiveRewrite` has precisely the six expanded equations. Arbitrary payload
and repeated-key substitutions are quantified over message terms, including
embedded natural terms. `Rewrite` closes these steps under every message
constructor. `ModuloACRewrite` additionally permits AC-equivalent representatives
before and after a rewrite. The kernel proves that every such step strictly
decreases an AC-invariant natural-valued measure, then proves well-foundedness.
It does not orient AC reassociation/permutation as terminating rewrite rules.

`MatchingPrimitiveRewrite` expresses matching modulo AC, rather than requiring
literally identical repeated-key representatives. Its two decryption rules
require `MessageAC` between the inner and outer key. `MatchingRewrite` closes
these steps under every message constructor. The kernel proves that each
matching step is a quotient rewrite, and each quotient rewrite is realizable
by a matching step from the original representative, with an AC-equivalent
result. It also proves the stronger one-step B-coherence property: a matching
step from one representative can be replayed from any AC-equivalent
representative. Matching inherits the existing well-foundedness proof.

`MatchingSteps` counts actual matching rewrites. `MessageTemplate` separates
message variables from rigid atoms and natural templates; instantiation uses
independent message/natural assignments. If every assigned message is normal,
normalization takes at most `templateFunctionCount` matching steps. The bound
counts unary/binary/ternary template constructors, not substitution size,
natural AC rearrangements or nullary symbols. It is an existence bound for a
normalizing derivation, not a bound on every reduction order.

`Confluence.lean` joins every one-step peak, including reducing only one copy
of a nonlinear decryption key, and derives global matching confluence by
strong induction on the accepted weight. `Convergence.lean` proves normality
is AC-invariant, transports matching sequences across AC representatives,
proves matching-normal-form uniqueness and realizes quotient sequences by
matching sequences. Arbitrary quotient paths join to AC-equivalent results.

`QueryImage.lean` models the pinned printer's structural protocol syntax,
with closed atom indices kept distinct from sorted variables. In the
mathematical carrier only, label `2*i` represents a variable at native index
`i`, and `2*i+1` represents a rigid atom at that index. This does not change
Tamarin's printer, protocol counters or wire encoding. Natural rigid atoms
use the same disjoint labels; native `t(0)` is an atom with index zero, not
protocol natural zero. Natural/message encoding has a checked left inverse
and is injective. The message recognizer rejects node terms, list framing
inside message functions and improperly sorted natural sums.

`QueryRecognition.lean` proves the converse: every recognized term is exactly
an encoding. `QueryAC.lean` independently defines structural AC in the raw
syntax, including natural-addition and list/cons contexts with arbitrary raw
children. Encoding preserves and reflects AC. AC preserves recognition and
the exact encoded image; malformed natural sums cannot become recognized
messages by AC rearrangement.

`QueryRewrite.lean` independently defines the six root rules and every raw
context, including natural addition and list/cons framing. It overapproximates
native rule instances by omitting message-sort guards. From an encoded message,
however, every raw rewrite has recognized message payload/key arguments,
reflects a typed rewrite and remains in the exact image. The same statements
hold for AC-rewrite-AC decomposition. `QueryMatching.lean` transports source
matching to raw quotient steps and realizes encoded quotient steps by source
matching, with an AC-equivalent result. These are relational correspondence
proofs, not correctness proofs of Maude's matching algorithm.

`QuerySubstitution` assigns public/fresh variables to atoms or variables of the
same sort, message variables to arbitrary messages and natural variables to
arbitrary naturals. Public/fresh assignments use the same parity labels.
Substitution changes even variable labels only; odd rigid labels and closed
native atom indices stay frozen. Encoding commutes with these substitutions
and their results remain recognized. Node assignments use parity labels for
node atoms/variables, remaining outside messages. The raw substitution operation
also preserves structural AC and raw rewriting for arbitrary assignments.
That latter statement does not assert well-sortedness of arbitrary assignments.

`NativeFramedImage` admits recognized message leaves, node atoms/variables and
free `list`/`cons`/`nil` trees at `TOP`. It is closed under structural AC, raw
rewriting and the typed substitution, including node-variable assignments.
It rejects framing or nodes inside message functions/natural sums. This is a
free framing envelope, wider than the printer's fixed `list(cons(...,nil))`
shape; it does not certify how actual callers construct those tuples.

`QueryKind.lean` adds the owner-approved derivation-kind image. In proof-only
raw syntax, `kindAbstraction` sends natural atoms/variables at index `i` to
natural shadows at `2*i`, and Fresh atoms/variables to natural shadows at
`2*i+1`. Atom and variable constructors stay distinct. A structural inverse
recovers every original raw term; native indices and actual protocol sorts
are unchanged. `NativeKindFramedImage` requires the abstracted term to inhabit
`NativeFramedImage`. This admits natural sums with Fresh/natural leaves,
including their enclosing message/free framing contexts, not arbitrary
message/public/function/list operands in sums.

The relabeling preserves raw AC, rewriting and quotient rewriting; the inverse
reflects them on the abstracted image. Image closure, quotient-step decoding
and termination follow for proof-carrying decoded kind messages. Substitution
commutes with abstraction for arbitrary raw assignments. The original framed-substitution theorem has an explicit compatible typed
shadow premise. The sorted-assignment extension below derives that premise
for every modeled sort-respecting assignment; correspondence with every
runtime substitution remains part of the unverified native/importer boundary.

Raw rewriting omits native proper-message guards. On the kind image, shadow
rewrites may therefore exist without native counterparts. For example, the
raw rule reduces `fst(pair(roleA, FreshVariable + one))` to `roleA`, while
real Maude leaves the expression at error kind `[TOP]`: its discarded pair
argument is not a proper message. Thus raw-overapproximation termination
bounds actual subset steps, but does not transfer native confluence,
normalizing-path existence, narrowing completeness or FVP. The original
proper-message correspondence and its stronger matching results remain separate.

`QuerySorted.lean` independently defines the six native-shaped root patterns
with proper-`Msg` guards and AC-equivalent repeated keys. It closes matching
under every raw context, including error-kind and free framing contexts.
The relation is not defined by the source matching relation. Typed matching
steps preserve it, and every native-sorted step is a raw quotient step.
Consequently proper-message steps decode to typed quotient steps. The kernel
also proves well-foundedness on the encoded proper-message carrier, closure of
the controlled-kind framing envelope and well-foundedness on decoded kind
messages. The blocked projection above remains blocked, while proper inner
rewrites remain possible inside its error-kind context.

`QuerySortedConvergence.lean` transports counted paths, one-step B-coherence,
confluence modulo AC, normal-form uniqueness modulo AC and normality invariance
to this independently guarded relation on the proper-message image. Encoded
instantiations of the existing templates have the same substitution-independent
normalizing bound. These transferred results require proper-message input.

`QuerySortedBoundedness.lean` separately proves a structural normalization bound
for the entire frozen-index `NativeQueryTerm` AST using the actual guarded
relation, not shadow rewrites. For every template and assignment of normal
terms to its sorted variables, there exists a normalizing path of at most
`nativeQueryFunctionCount template` steps. The count includes unary, binary,
`kdf`, natural-addition, list and cons contexts in the source template; rigid
leaves and variables count zero. It does not count assigned-term size or AC
rearrangements, and does not bound every reduction order. Normal children leave
at most one root step, whose result is a normal subterm or role constant.
The same proof covers controlled-kind/free framing templates without a
compatible typed-shadow premise. Its broader mathematical AST domain does not
widen the stream grammar or prove sort/image closure for arbitrary assignments.

`QuerySortedExact.lean` proves every guarded root redex is a proper message,
and decodes guarded steps/count-preserving paths to exact typed matching,
not merely quotient rewriting. It joins proper-message paths at an identical
representative. `QuerySortedGlobal.lean` uses that result only at primitive
overlaps; structural induction joins same-child peaks and commutes independent
child steps in every raw context. Every guarded rewrite strictly decreases
`nativeQueryFunctionCount` on the actual term, proving termination and exact
matching confluence across the entire frozen-index AST.

`QuerySortedAC.lean` proves the context count AC-invariant and transports a
guarded step across arbitrary structural AC, with no decoding premise. Paired
forward/reverse transport handles symmetry, associativity, commutativity and
all message/natural/framing congruences. `QuerySortedQuotient.lean` defines
`NativeSortedModuloACRewrite` and its counted paths separately from the
unguarded shadow quotient. It proves termination, AC-invariant normality,
equivalence of matching/quotient normality, count-preserving matching realization,
quotient confluence and normal-form uniqueness modulo AC. These results cover
controlled-kind/free framing as a subset without widening the stream grammar.
Regression cases retain distinct AC-equivalent error-kind normal forms,
framed nonlinear key-copy peaks, `kdf` and explicitly marked raw terms outside
the stream grammar. They do not claim properness invariant on that larger AST.
Complete sorted unification, narrowing completeness and backend algorithm
correctness remain unproved.

`QuerySortedSubstitution.lean` independently defines `NativeSortedValue` for
the five variable sorts: public/fresh atoms or same-sort variables, recognized
messages/naturals, and node atoms/variables. `NativeSortedAssignment` requires
that value discipline at every sort/index. Every existing `QuerySubstitution`
induces such an assignment, and every such assignment has a representation by
`nativeQueryAssignment`. Proper-message guards survive substitution, so
guarded matching and quotient steps/count-preserving paths do too, under every
raw context. Substitution remains simultaneous and freezes rigid indices.

`QueryKindSubstitution.lean` proves kind abstraction preserves recognized
naturals and proper messages. The abstract assignment is sorted, including
the disjoint even-natural/odd-Fresh shadow indices. Its typed representation
supplies the earlier compatible-shadow premise and proves controlled-kind/free
framing substitution closure without assuming a shadow. No arbitrary unsorted
assignment is admitted. Sorted substitutions can create new redexes, so these
are preservation, not reflection or normality-preservation, theorems.
Kernel cases retain all-sort rejection, same-index rigid/variable and Fresh/
natural distinctions, blocked ill-kind projections, framed substitution,
nonlinear AC-key paths and redex creation. The independent CLI transcript
inventory is in `../equation_fixtures.py`, separate from the shared process
fixture to keep maintained files below the hard size limit.

`QueryComposition.lean` defines `composeNativeAssignments first second` by
applying `first`, then `second`, not the reverse. It proves identity,
associativity, the simultaneous-substitution composition law, closure of all
five sorted value classes and pointwise AC congruence through every raw context.
Rigid atom indices remain frozen, and inserted values are not recursively
resubstituted during either individual application.

`QueryUnification.lean` defines `NativeACUnifier` as a sort-respecting assignment
whose substituted terms are structurally AC-equivalent. Sorted composition
preserves solutions. Existing typed assignments preserve/reflect message and
natural AC solutions, and every native solution on those encoded inputs has a
typed representation. For kind terms, the equivalence uses the assignment's
derived abstract assignment, not any sorted shadow. Decoded kind-message
solutions have a compatible typed-shadow representation; the raw equivalence
also covers free framing. These are relational solution correspondences,
not a finite complete unifier set, a most-generality or occurs-check theorem,
narrowing completeness, equality modulo rewrite equations or native algorithm
verification.

`QueryUnificationCases.lean` retains all-sort composition, order sensitivity,
frozen indices, framed `kdf` AC congruence and compatible kind solutions.
It proves Fresh/natural variables have no sorted original AC unifier, while
their abstracted natural variables have an unrestricted typed solution that
cannot be a compatible shadow. Actual pinned Maude controls confirm the
cross-sort failures, including a mixed-kind sum, and a same-sort success.
A separate negative control retains that plain `unify` does not use the
ordinary `flip` equation. No solutions are filtered or grammar widened.

The source bridge trusts Tamarin's export, the reviewed signature/term translation
and their regressions. It is not a verified Tamarin/Maude importer, a proof of
native bookkeeping `NAT`, the entire kind-completed carrier or finite variants.
Convergence and boundedness are proved for the typed algebra; independent
structural results cover the guarded relation on the full frozen-index AST,
including controlled-kind and free framing contexts. Executed
native operations additionally require the boundary checks below; a universal
source-linked query-builder/importer proof remains unverified.
Complete sorted AC unification, backend narrowing/unification closure and the
remaining finite-variant theorem hypotheses are not discharged by this command.

## Native stream boundary

`maude_runner.run_guarded_tamarin(command, timeout)` returns the original
Tamarin stdout or raises `GuardError`. Ratchet equation/projection checks,
export/round-trip/precompute/replay, mutation and extracted-attack runners use
it. Ordinary version checks and unrelated Resume/SAS models are unchanged.
Caller-supplied `--with-maude` overrides are rejected.

The compiled [`cairn-maude-proxy`](native-proxy/README.md) requires Maude `3.5.1`, the pinned five
interactive flags, the three standard setup commands and the entire exact
native module derived from the shared 15-function/six-equation inventory.
It accepts only `reduce`, `unify in MSG`, `match in MSG` and
`get variants in MSG`. Terms must inhabit the proper message/natural/Node/free
framing image or its controlled derivation-kind extension. Natural sums admit
only `TamNat`, `Fresh` and recursively extended natural operands. Their
enclosing message/framing contexts retain kind classification internally;
this does not make them proper native message terms. Atom indices must be canonical closed decimals.
Bookkeeping `Nat`, `TOP` and kind variables, imported arithmetic, unreviewed
constructors and framing beneath message functions are rejected.
Returned bindings still require their declared proper sorts. Kind-valued
bindings and `[TOP]` reduction/variant headers remain unsupported and reject
the entire operation, matching the pinned importer's boundary.
The pinned Tamarin installation check is also supported: no arguments and
exactly `quit\n` on stdin, with a successful diagnostic-free real backend exit.
It cannot execute a protocol query without the reviewed module.

Every returned solution is checked before any reply bytes are forwarded:
result/binding sorts, known binding domains and original variables, unchanged
rigid atom indices, solution headers, substitutions and variant exhaustion.
Matching/reduction use original `x` variables; unification/variants use generated
`#`/`%` variables. Opposite generated prefixes with the same index/sort in one
solution are rejected because the pinned importer conflates them.
There is no per-solution filtering or success fallback.

`CAIRN_MAUDE_BINARY` selects the underlying executable, otherwise `maude` is
resolved on `PATH`; recursive self-invocation is rejected.
The runner supplies a private absolute regular-file
`CAIRN_MAUDE_GUARD_REPORT` destination. Records contain only lifecycle events,
operation kinds, PIDs and fixed reasons, never terms/substitutions. Missing,
truncated, duplicate-field, malformed, failed or inconsistent records reject
the entire proof command. Each started stream requires its own version/module
evidence and completed shutdown. Version-only evidence is permitted when no
native stream starts. Records are consistency evidence, not cryptographic
attestation against a malicious proof executable. Every `version` record also
requires the current source identity; there is no unversioned Python route.
The default executable comes from the shared Cargo target, with missing/stale
builds rejecting rather than building automatically or falling back.

The owner-approved I/O optimization retains every `begin`/`accepted` event.
The native [`evidence.rs`](native-proxy/src/evidence.rs) appends operation records through one validated descriptor
per process, flushing at 16 KiB plus at most one record. Other lifecycle
events retain immediate checked writes. The operation journal is flushed
and closed before a successful `shutdown` record; final reconciliation still
requires every event. Partial writes, exhausted report capacity, invalid
destinations and late failures reject the whole command. This bounds only
pending metadata, not query/reply sizes or proof search.

The iterative native recognizer checks every leaf's sort/namespace.
Canonical operation records have an exact JSON-grammar
fast path with the same lifecycle transitions; other JSON still receives the
complete duplicate-field/type/field audit. None of these paths bypasses query,
reply, solution or lifecycle validation.

Existing proof deadlines/options remain unchanged. Version checks use
`30` seconds; native termination and outer shutdown reconciliation use the
existing `5`-second teardown grace, not a proof-search retry. Child pipes close
before shutdown acknowledgment, and unexpected exit/remaining output/stderr
fails closed. Replies are buffered in full; no new byte/heap cap is introduced.
The Python recognizer/module checker, pinned tool implementations and
variable renaming/importer remain trusted or unverified, not Lean-certified.

## Integration and observed evidence

`scripts/check.sh` runs the new regressions and this checker whenever the pinned
Lean executable is available. The existing lifecycle CI cell supplies the pinned
tools and therefore runs it; no matrix job or resource limit is added.
The lifecycle projection and this checker share one equation inventory and one
toolchain/axiom-audit implementation.

Local `2026-10-14` evidence: all six source correspondences and required theorem
audits pass at canonical export SHA-256
`663f04c055cf01d4f08343a71f002b438ccd3000bf696534b83779f1a5fe4434`.
The intended kernel red rejected a constructor-only measure that did not decrease
on either role-flip rule. Counting every function symbol makes that obligation
green. Separate source-boundary red/green cases cover an unrepresented function,
malformed equations, quoted declaration spoofing and excessive arity.
Real CLI regressions also reject missing, truncated, malformed and non-ASCII
toolchain pins with controlled diagnostics before invoking proof tools.
The coherence kernel red rejects a syntactic matcher when repeated natural
keys have opposite AC order; matching modulo AC makes the case green.
The CLI red accepts an old termination-only audit transcript; requiring all five
coherence reports makes it fail closed. Native-command fixtures check the audit
boundary, not the actual kernel proof, which is rebuilt separately.
The boundedness kernel red rejects a one-step role reduction when counted
steps allow only reflexivity. The indexed step constructor makes it green.
Additional CLI reds accept transcripts missing boundedness or confluence
reports; mandatory audits make both fail closed. Kernel cases exercise
projection/role bounds and decryption with AC-reordered natural keys.
Nonlinear peak cases reduce one key copy in symmetric/KEM decryption.
The query-image kernel red merges a rigid atom with a variable having the
same native index; disjoint mathematical labels make it green. A CLI red
accepts a valid earlier transcript without the four image audits; their
requirement makes it fail closed.
The structural AC kernel red rejects syntactic equality for reordered natural
operands; independent ambient AC makes it green. The substitution kernel red
replaces a rigid natural atom because its source carrier uses a variable-shaped
leaf; distinguishing odd rigid labels from even variable labels makes it green.
Further CLI reds accept the older 26- and 44-audit transcripts; requiring the
algebraic correspondence and substitution reports makes both fail closed.
The framing kernel red admits `h(list(nil))` by treating a framing argument as
a message; requiring message recognition rejects it. Another CLI red accepts
the prior 50-audit transcript; the three framing reports now make it fail closed.
The convergence/image/boundary checkpoint was published at `3d5dd7c`.
Its [formal run 38622779805](https://github.com/trancee/cairn/actions/runs/38622779805)
passed the lifecycle cell but failed all 18 replay/mutation cells on a
Fresh-in-natural derivation-check query. The pinned
[`MessageDerivationChecks.hs`](https://github.com/tamarin-prover/tamarin-prover/blob/82780bbaf3328a45f624ddb41e51bf75425f851c/lib/theory/src/Theory/Tools/MessageDerivationChecks.hs)
calls `natToFreshVars` on premise terms. A one-rule paired-counter input
reproduced the failure locally; the owner selected `extend-derivation-kind-image`.
The real regression now passes without skipping derivation checks. A kernel
red collided Fresh/natural shadow indices; disjoint labels make it green.
A CLI red accepted the old 53-audit transcript; all 14 new reports are now
mandatory. This local extension evidence is not hosted acceptance.

Native boundary reds cover wrong query/reply sorts, altered equations, absent
evidence, duplicate fields hiding failure, non-ASCII query syntax, blocking FIFO
reports, incompatible/conflated variable namespaces, missing per-stream version
evidence and ignored shutdown diagnostics. Maintained tests also reject an
entire reply with a bad later solution without forwarding its earlier valid
solution, and reject truncated EOF. Real Maude tests cover all four operations;
a tiny exact-signature Tamarin normalization witness exercises actual guarded
proof/precomputation streams and the source-linked installation check.

At the derivation-kind extension checkpoint, local `scripts/check.sh` with pinned Lean passed 117 model tests,
50 lifecycle tests, 43 projections, six source correspondences and 67 audits.
The guarded default `lost_data_recovery` replay verifies the 826-step witness
and nine-step ownership helper in `106.77` seconds of reported proof processing.
The guarded `--disclosure-sources --target complete_safety` context verifies
all 56 safety certificates in `44.85` seconds, with complete refined sources
and unchanged 43 rules/13 restrictions. These are selected contexts, not a
full 63-declaration replay or a native FVP certificate.
Both final-source mutation runners also pass: default/`CLASSIC_FALLBACK`
verifies/falsifies in 2/504 steps (`48.50`/`55.13` seconds), and
default/`NO_PREFIX_GUARD` in 4/526 steps (`49.82`/`56.79` seconds).
These are reported proof-processing times, not paired performance comparisons;
the deadlines are unchanged.

The initial parse comparison on Apple silicon/macOS `27.0.1`, `8` GiB RAM, with pinned
Tamarin/Maude, used three alternating baseline/guarded pairs at the existing
`120`-second deadline. Inputs were unchanged from committed `3d5dd7c`.
`replay.run(["tamarin-prover", "--parse-only", <absolute ratchet.spthy>], 120)`
was compared with `run_guarded_tamarin` on the identical command. Median times
were `1.494`/`1.535` seconds (`+2.7%`), with byte-identical exports at the SHA above.
This measures parsing only, not precomputation/full replay or memory overhead.

The historical representative complete ratchet export through the now-removed Python guard,
including derivation checks, remains **performance-blocked under Constitution
P4**. Three alternating direct-native/
guarded pairs of the following command, each bounded at `120` seconds, produced
identical export bytes:

```bash
tamarin-prover docs/spec/models/ratchet.spthy \
  --quit-on-warning --derivcheck-timeout=60 --output-module=msr
```

Before optimization, `replay.run(command, 120)` took `24.178` seconds median,
versus `35.385` for `run_guarded_tamarin(command, 120)` (`+46.3%`), at SHA-256
`aaaf873a9b7baff6fbf209f1cf87088581552498ade6f9a5e471ee2b5ea6fb5d`.
The model and direct runner are unchanged from committed `3d5dd7c`. This
compares the whole guard with direct native execution, not the incremental
kind-parser cost relative to the already committed guard. The tiny one-rule
derivation fixture additionally measures `0.116`/`0.417` seconds
(`+0.301` seconds, `+259.5%`), exposing fixed startup cost.

A diagnostic standard-library profile retained the checked boundary and
identical full-export digest. It observed 90,874 operations and 181,760
lifecycle-record calls, each opening/writing/closing the report; record
handling consumed `8.619` seconds in that instrumented run. Profiling timings
are not benchmark timings.

The owner then selected `optimize-evidence-io`, without approving a budget
exception. After bounded journal batching, selector reuse and conservative
recognizer/audit fast paths, the final-source three-pair medians are
`24.303`/`29.761` seconds (`+22.5%`), with the same export digest and deadlines.
This reduces whole-export guard time by approximately 16% versus the initial
guard measurement, but still exceeds P4. A streamed-token parser experiment
did not materially improve the result and was removed. No larger rewrite,
budget exception or performance acceptance is implied. The unchanged proof
deadlines passing and the small earlier parse-only percentage do not waive
the remaining regression. Full-proof-search and memory overhead remain unmeasured.

The owner subsequently selected a bounded
[compiled proxy prototype](native-proxy/README.md), without default
cutover. It shares the reviewed inventory and retains the stream/evidence
checks. All 18 opt-in CLI/process/proof cases and the existing default fast
gate pass. Three alternating complete-export pairs measure `24.281`/`25.931`
seconds direct/prototype (`+6.80%`), with the identical full-export SHA above.
The separate one-rule fixture adds `39.93` ms (`+33.76%`). The owner subsequently
approved maintained promotion with a startup-only `50` ms cap, retaining
`10%` for the full export; Linux/caller/CI criteria must precede cutover.
The maintained staging candidate used source-identified build evidence and the
shared guarded runner, with explicit pre-cutover selection for local/CI
callers. The existing 19-cell workflow is wired without larger ceilings.
The staging local gate passed 19 native cases, 138 model tests, 50 lifecycle
tests, 43 projections and 67 equation audits. Its CLI rejects malformed/stale/
incompatible performance reports and workload-specific budget failures.
Staging-source paired medians were `24.248549`/`25.807651` seconds for full export
(`+6.4297%`) and `0.110541`/`0.147073` seconds for startup (`+36.531959` ms,
`+33.0482%`), passing both approved limits with unchanged exports.
The final compiled build preserves the original-cap default recovery,
56-certificate refined safety context and both mutation regressions.
Native run `38710117729` at `2e7b429` passes all 18 replay/mutation cells
and fast gates, but rejects an unreviewed export before any budget verdict.
Diagnostic run `38712391261` identifies the direct baseline, before any guarded
run: only the macOS full-export digest was retained. The observed pinned Linux
digest is now also retained; every sample must still match the fixed inventory
and all six outputs must be byte-identical. No normalization, filtering or
budget change. Run `38714285780` at `67584ea` then genuinely fails full export:
`35.220242`/`38.939536` seconds (`+10.5601%`), all six exports identical;
startup does not run. Current source avoids line-buffered body/prompt splitting
with one checked raw output handle and polls final evidence every `1` ms,
retaining the `5`-second grace and all validation. The stdout-only intermediate
source fails local startup at `+52.560041` ms; a measured final-evidence sleep
motivates the subsequent poll change and passing local budgets above.
At that checkpoint native budget acceptance and default cutover remained blocked.
Follow-up `38719650091` at `2b642e2` passes all 18 callers/fast gates and the
native full-export budget (`37.767068`/`40.976767` seconds, `+8.4987%`).
Startup rejects the direct baseline before a timing verdict: its inventory
was also macOS-only. The exact observed Linux startup digest is now pinned
alongside macOS, with all six outputs still required to match and the `50` ms
cap unchanged. The native guard identity is unchanged; both current macOS
reports and native full-export report still passed. Native startup remained pending at that checkpoint.
The four selected local regressions are not full assembled or memory-performance acceptance.
Those staged failures were superseded by native run `38721189200` at `71168a1`:
all 19 cells and both actual budgets pass (`+9.6594%` full export,
`+15.871115` ms startup), without filtering, larger budgets or deadlines.
That satisfies the owner-approved condition for central default cutover.
The default is now the compiled guard; the temporary selector, obsolete Python
validator/evidence/parser and nine duplicate parser tests are removed, with
their cases retained in native CLI tables. Current default-source local
medians are `24.324896`/`25.820824` seconds (`+6.1498%`) and
`0.112296`/`0.154256` seconds (`+41.960417` ms, `+37.3660%`).
Its fast gate passes 19 native/131 model/50 lifecycle cases, 43 projections
and 67 audits. Actual native cutover run `38724991914` at `2fa6d16` passes
both budgets (`+8.3650%` full export, `+25.785370` ms startup) and 18/19 cells.
`initial_ck_secret` times out during its strict `60`-second assembled-export
derivation check, before its selected proof; the exact local replay passes.
This is not a native reproduction or fix, and the failed run remains evidence.
All current-head hosted gates are still required; subsequent checks are
recorded by [PR #9](https://github.com/trancee/cairn/pull/9/checks).
Native FVP remains open.
