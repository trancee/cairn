# Why the ratchet equations fit the symbolic model

Mathematical review of the default
[`ratchet.spthy`](ratchet.spthy) equation set, observed on 2026-10-09.
The `2026-10-15` [source-guarded Lean termination subgate](equations/README.md)
now kernel-checks termination, B-coherence, confluence modulo sorted natural
AC and a normalization bound independent of normalized substitutions.
These results cover the typed algebra. An independently guarded native-sorted
relation now inherits convergence and boundedness on the proper-message image.
A separate structural proof also bounds guarded normalizing paths for raw
frozen-index native templates, including controlled-kind and free framing.
Independent structural proofs now also establish guarded quotient termination,
confluence and normal-form uniqueness modulo AC across that AST.
Sort-respecting substitutions preserve guarded paths and controlled-kind
framing; their compatible typed shadows are now derived rather than assumed.
Sorted AC solutions now compose and transport exactly through the proper typed
image and compatible kind shadows, not unrestricted shadow unification.
Scoped sorted factorization now preserves/reflects completeness of a given
finite family and candidate most-generality on proper message/natural inputs.
Those transport results do not construct a complete family or verify a native
generator. A subsequent constructive solver now generates complete finite
families for variable equations whose chosen orientation has a sort-compatible
target: identity, proper cycles and occurs-free bindings. Generic finite-AST
occurs rejection and one-binding factorization justify these branches.
This is a base case for general AC generation, not that general generator
or a native-runtime correspondence proof. Finite equation-system elimination
now propagates those bindings through every remaining constraint and lifts a
supplied residual complete family. Coverage must retain variables in prefix
values, not just those in the remaining equations: an empty remainder can
otherwise make a ground family appear complete. Explicit finite binding
composition preserves the existing ordered, simultaneous first-binding
semantics. This is a proved composition layer, not a general system solver.
Native narrowing/unification and the remaining
FVP hypotheses stay separate; this is not a native FVP certificate.
The later Lean native-query FVP proof is recorded in the
[equation README](equations/README.md#native-finite-variants); it does not
certify Maude's variant generator.

## Why executed queries now need a guard

Candidate-image closure cannot establish that the backend actually receives
that image: the pinned host classifier treats lists as messages, while native
framing has sort `TOP`. The owner chose a fail-closed command/reply proxy as the
next proof-only boundary. Ratchet acceptance runners now reject unsupported
queries and complete replies before accepting proof results, without dropping
individual solutions. The shared source inventory also pins the full native
module; private lifecycle records prevent ignored startup errors from becoming
successful proof evidence.

The guard checks sorts, rigid-index provenance and the pinned importer's
original/generated variable distinction. It rejects ambiguous `#`/`%` identities
inside one solution. These checks enforce membership for executed operations,
not a kernel proof of query builders, variable renaming, importer behavior or
Maude algorithms. The [reference](equations/README.md#native-stream-boundary)
records syntax, errors, deadlines and the parse-only performance comparison.
Sorted AC-unification, admissible decomposition and full FVP transfer remain
open; neither the guard nor its four real-operation tests close that gate.

## Why derivation checks need a controlled kind extension

The published guard at `3d5dd7c` passed the lifecycle cell but rejected all
18 replay/mutation cells in
[formal run 38622779805](https://github.com/trancee/cairn/actions/runs/38622779805).
The failure is reproducible locally, not a Linux-only discrepancy. The pinned
[`MessageDerivationChecks.hs`](https://github.com/tamarin-prover/tamarin-prover/blob/82780bbaf3328a45f624ddb41e51bf75425f851c/lib/theory/src/Theory/Tools/MessageDerivationChecks.hs)
applies `natToFreshVars` recursively to premises without changing their
constructors. Consequently a valid counter input produces
`tamtplus(x0:Fresh,tamXCtone)` during derivation checking. It is an error-kind
term, even though the original protocol counter is properly sorted.

The owner selected extending the proof image instead of bypassing derivation
checks, changing equations or patching Tamarin. The extension permits only
Fresh/natural leaves in natural-sum shapes and their existing enclosing
contexts. Kind variables and returned kind-valued bindings/results remain
rejected. The one-rule real regression, default recovery replay and all
56 refined safety certificates now pass locally under unchanged deadlines.
The fix awaits current-source hosted acceptance; selected contexts do not establish full assembled
acceptance or supersede the failed hosted run.
Both real guard-mutation regressions preserve their verified defaults and
expected attacks. Representative full-export measurement initially found
`+46.3%` whole-guard overhead versus direct native execution. Owner-approved
bounded journal batching and conservative stream/parser optimizations reduce
this to `+22.5%`, preserving every event and unchanged deadlines, but merge
remains blocked under Constitution P4. The smaller parse-only result is not a substitute for
that measurement; the [reference](equations/README.md#integration-and-observed-evidence)
records methodology and the report-I/O profiling result.

The subsequent owner-approved compiled-proxy experiment reduces representative
full-export overhead to `+6.80%` across three pairs with identical bytes.
It retained the checks in a maintained, staged
[native guard](equations/native-proxy/README.md), not yet a default cutover
or a new mathematical proof. That prototype's tiny-fixture startup added `39.93` ms
(`+33.76%`). The owner approved maintained promotion with a startup-only
`50` ms cap, retaining `10%` for full export; Linux/caller/CI criteria must pass
before cutover. During staging the Python default and native FVP/full-context gates
remained unchanged. Compiled evidence identifies its reviewed source;
missing/stale builds reject rather than falling back. The existing local/CI
gates are wired to validate the candidate before cutover. Clean local fast
gates pass. The current candidate also passes its local paired budgets
(`+6.4297%` full export, `+36.531959` ms startup) and four original-cap caller
regressions: recovery, complete refined safety and both mutations.
Native run `38710117729` passes all 18 replay/mutation cells and fast gates,
but its benchmark rejects an unreviewed export before a budget verdict.
Diagnostic run `38712391261` identifies the direct baseline, before any guarded
sample: the inventory contained only the macOS export digest. The exact pinned
Linux output is now also retained, without normalizing/filtering output,
relaxing budgets or allowing different bytes within a paired measurement.
The next run, `38714285780` at `67584ea`, completes all six identical Linux
exports and genuinely fails the full-export cap at `+10.5601%`; startup
does not run. That failure is not dismissed as host noise.
An active-process sample motivates combining each fully checked reply and
prompt into one raw stdout write. The stdout-only intermediate source still
fails local startup at `+52.560041` ms; a separate profile identifies `13` ms
in a final-evidence sleep. Reducing only that poll from `10` to `1` ms,
without changing the `5`-second grace or any check, gives the passing local
budgets above. These measured optimizations are not proof of a Linux fix.
Fresh native budget acceptance and default cutover remain incomplete.
The follow-up `38719650091` at `2b642e2` passed all 18 callers/fast gates
and native full export (`+8.4987%`), without a waiver. Startup then identifies
another host-fixture assumption: only its macOS digest was retained. Pinning
the exact observed direct Linux startup digest uses the same fixed-inventory
decision; it does not learn accepted bytes from runtime samples or change
within-host byte identity and timing checks. Native startup acceptance remains
pending at that checkpoint.
Native staging `38721189200` at `71168a1` then passes all 19 cells, including
both actual budgets (`+9.6594%` full, `+15.871115` ms startup), without a waiver.
That meets the owner's condition for making the maintained compiled guard the
shared default. The temporary selector and obsolete Python validator/evidence/
parser are removed, not kept as a second implementation. All old adversarial
parser cases remain covered at the native CLI seam; every version now requires
current source identity. New default-source local budgets pass at `+6.1498%`
and `+41.960417` ms. Native run `38724991914` at `2fa6d16` passes both actual
budgets (`+8.3650%` full, `+25.785370` ms startup), independently checked,
and 18/19 cells. `initial_ck_secret` times out in its unchanged strict
`60`-second assembled-export derivation check before proof. The exact local
caller passes (11-step claim plus five origin helpers), not establishing a
native reproduction or fix. Preserve the failure and require all current-head
hosted gates, whose subsequent results are recorded by PR #9.
This changes proof tooling, not any native FVP/full-context obligation.
Full assembled and memory-performance evidence remain separate obligations.

## Exact scope

The custom equations are:

```text
kdec(kem(ss,pk(dk)),dk) = ss
flip(roleA) = roleB
flip(roleB) = roleA
```

The expanded signature also includes the standard projection and
symmetric-decryption equations:

```text
fst(<x,y>) = x
snd(<x,y>) = y
sdec(senc(x,k),k) = x
```

`h`, `kdf`, `ext`, `mac`, `kem` and `pk` have no additional equations.
`roleA` and `roleB` are distinct public nullary functions of message sort,
not quoted public-sort constants. `natural-numbers` contributes sorted
associative-commutative `%+` with `%1`; it must not be silently treated as
a free message constructor. No DH, XOR, bilinear or multiset builtin is
enabled. The [lifecycle checker](lifecycle/README.md) pins the six expanded
equations and the remaining natural-number builtin declaration. This
detects changes; it does not prove the equations' admissibility.

The [Tamarin 1.12.0 message documentation](https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/manual/src/004_cryptographic-messages.md)
requires convergence and the finite variant property (FVP), which Tamarin
does not automatically establish. It identifies subterm-convergent
equations, whose right side is a proper subterm or a ground term, as the
preferred class. It documents both the projection/decryption equations
and the sorted AC natural-number builtin.

## Termination of the message rewrite rules

Orient the six message equations left to right. Count function-symbol
occurrences in a finite message term. Every rewrite strictly decreases
this measure:

- Projection and decryption return a proper subterm, deleting at least
  the outer destructor and constructor.
- Each role rewrite replaces `flip(roleA)` or `flip(roleB)` by one
  nullary role symbol, deleting the `flip` occurrence.

Substitution does not invalidate the decrease: the returned subterm was
already inside the redex. No rule duplicates a right-side variable or
reintroduces a removed destructor. This establishes termination of these
message rewrites. It is not a termination argument for protocol executions,
proof search, or an orientation of AC associativity/commutativity.

The new typed `MessageTerm`/`NaturalTerm` model proves this for all six exact
equations, every message context and AC-equivalent representatives.
The source checker validates all 15 message ranks and generates six
kernel-checked correspondences. It shares the equation inventory and mandatory
axiom audit with the lifecycle gate. The translation/export remain trusted
boundaries, not a verified importer.

## Matching modulo AC and B-coherence

Repeated keys need equality modulo AC, not literal equality of representatives.
For example, `sdec(senc(payload, one + n), n + one)` has a decryption match
modulo natural AC even though a purely syntactic matcher cannot apply the
repeated-key rule directly. The source equation itself is unchanged.

[`Coherence.lean`](equations/Coherence.lean) models that matching relation and
closes it under every existing typed message context. It proves soundness
against the quotient rewrite relation and transport of any quotient step back
to a matching step from the original representative. It also proves a stronger
one-step form of B-coherence: if one representative takes a matching step,
every AC-equivalent representative can take a matching step to an
AC-equivalent result. The four soundness/coherence theorem audits use no
axioms; matching termination inherits the existing termination proof.

This closes the B-coherence obligation for the typed algebra, not for every
kind-completed native Maude term. It is not Maude ChC's separate rule-versus-
equation coherence check. Native query-image correspondence and FVP still
need their respective evidence.

## Kernel-checked confluence and repeated-key overlaps

Different root rules cannot compete on the same redex. The destructor
heads `fst`, `snd`, `sdec`, `kdec`, `flip` are distinct, and the two
`flip` patterns use distinct constants. Proper non-variable positions in
the left sides are only constructors/constants (`pair`, `senc`, `kem`,
`pk`, roles), never a competing destructor head.

Disjoint rewrites commute. Nested rewrites occur within substituted
variables: their reductions can be replayed in any surviving occurrence,
or are erased when the outer rule discards that variable.

The decryption rules are **not left-linear**: the key occurs twice.
Consequently, absence of non-variable overlaps alone is not an
orthogonality proof. If a nested step reduces only one occurrence of a
shared key, it may temporarily disable the outer decryption rule.
Applying the same step in the other occurrence restores the equality
test; both paths then return the same payload (with its surviving nested
reductions). The same joining argument applies to `dk` in the KEM rule.
[`Confluence.lean`](equations/Confluence.lean) checks that argument for the
matching-modulo-AC relation, using B-coherence to copy a reduction between
AC-equivalent keys. Structural induction joins all local peaks; strong
induction on the accepted weight proves global matching confluence.
[`Convergence.lean`](equations/Convergence.lean) transports complete paths
across AC representatives and proves quotient-path joinability modulo AC.
It also proves normality is AC-invariant and matching normal forms are unique.
This is a kernel proof in the typed algebra, not native-kind acceptance or a
claim that the full Tamarin proof search terminates.

## Substitution-independent normalization bound

[`Boundedness.lean`](equations/Boundedness.lean) proves a uniform bound for
every message template and every normalized message assignment, with arbitrary
natural assignments. Normalize children bottom-up. Once children are normal,
a root rewrite either returns an already normal child subterm or a normal
role constant; at most one root step remains. Summing these steps bounds
normalization by the template's unary/binary/ternary constructor count,
independent of the assigned terms' size. Natural terms have no message rewrite
steps; AC rearrangements are equality, not counted reductions.

The theorem constructs a bounded normalizing derivation, rather than bounding
all possible reduction orders. This is the quantifier order in the boundedness
criterion, not a ground-term weight bound that grows with substitutions.
The existing checker rebuilds these proofs, regression cases and all
169 required theorem audits. The typed bound does not itself establish native
substitution/narrowing closure or complete sorted AC unification.

## Frozen-index encoding foundation

[`QueryImage.lean`](equations/QueryImage.lean) models the pinned printer's
structural protocol syntax. It distinguishes rigid atom indices from
variables even when their numeric indices agree, and proves a natural/message
encoding left inverse and injectivity. The even/odd labels used to distinguish
them exist only in the mathematical carrier; Tamarin's printed indices,
protocol counters and wire formats do not change. A native natural atom
`t(0)` is not protocol natural zero.

The message recognizer rejects node terms and `TOP` list framing used
inside message constructors, as well as natural sums with message-sort
operands. These checks define a candidate proper-message image, not proof
that every actual query obeys its framing/typing discipline. Encoding round trips
alone do not establish native correspondence.

The independent raw relations now close the algebraic part of this candidate
image boundary. Structural AC acts even on improperly sorted raw children;
its decoder proof shows that recognition is invariant and preserves/reflects
typed AC. Every recognized term is exactly an encoding. Raw six-rule rewriting
under every raw context preserves the encoded message image and reflects a
typed rewrite. AC-rewrite-AC paths have the same correspondence. Source
B-coherence then realizes each encoded quotient step by matching from the
original representative, with an AC-equivalent result. The raw root rules omit
native message-sort guards; successful message recognition proves their
payload/key arguments are messages on the encoded image, not on all raw inputs.

Sort-separated natural/message substitutions also commute with encoding.
Rigid odd labels and all native index fields remain unchanged, rather than
being mistaken for variables. Public/fresh assignments stay in their respective
atom sorts; message/natural assignments range over their full typed carriers.
Node assignments stay in node atoms/variables, outside the message image.
Raw substitution preserves structural AC and rewriting even for arbitrary
assignments; image membership is asserted only for the typed assignments.

The free tuple/Node framing envelope is now closed under structural AC,
rewriting and typed substitution as well. It admits messages and node leaves
under free `TOP` constructors, but never list framing under a message function
or nodes inside natural sums. The kernel regression exposes the host-classifier
mistake on `h(list(nil))`. This envelope is wider than the printer's exact tuple
shape; closure is not proof that all actual caller-built queries belong to it.

These are mathematical relation/representation proofs, not a verified Haskell
printer/importer or Maude algorithm. The guard checks executed input/output
membership and substitution provenance. Universal query-builder/importer
correspondence, narrowing/unification closure and complete sorted AC
unification remain separate obligations.

## What the new kind abstraction does not transfer

[`QueryRelabeling.lean`](equations/QueryRelabeling.lean) proves raw AC/rewrite
preservation under structural leaf relabeling.
[`QueryKind.lean`](equations/QueryKind.lean) maps Fresh and natural leaves
injectively to disjoint natural shadow labels. Its inverse recovers the
original terms, preserving variables versus rigid atoms. This is a
mathematical encoding, not a change to actual Fresh sorts, counter values,
native syntax or wire payloads.

After abstraction, the existing decoder and framing proofs provide image
closure and raw quotient-step correspondence. The kernel also proves
termination on decoded kind messages. The substitution square holds for
arbitrary assignments. The original framed-substitution theorem has a compatible
typed-shadow premise; the sorted-assignment extension below derives it
mathematically, without proving the runtime validator/importer correct.

This does not transport the earlier proper-message matching theorem wholesale.
Raw rules deliberately omit native message-sort guards. A raw projection can
erase an ill-kind discarded pair component; actual Maude cannot match that
component to its proper `Msg` variable. For example,
`fst(pair(roleA, FreshVariable + one))` has a shadow reduction to `roleA`
but stays at `[TOP]` in the real native reduction. Termination of this
overapproximation is useful, but confluence or existence of a normalizing
shadow path does not imply those properties for the guarded native subset.
The new [`QuerySorted.lean`](equations/QuerySorted.lean) instead defines
native-shaped matching independently, requiring proper messages for each
equation variable and AC-equivalent repeated keys. It rejects this projection
without treating the whole error-kind context as frozen: a proper inner
`flip(roleA)` still reduces. Real Maude controls confirm both observations,
alongside a proper Fresh projection and AC-equivalent decryption keys.

The kernel connects each such step to the raw quotient relation and lifts typed
matching into it. On proper-message inputs, counted paths then inherit
B-coherence, confluence and normal-form uniqueness modulo AC, normality
invariance and the same template-only normalization bound. Controlled-kind
framing closure and decoded-kind termination also follow. These convergence
results still require a proper-message input.

[`QuerySortedBoundedness.lean`](equations/QuerySortedBoundedness.lean) now proves
bounded normalizing-path existence independently, by structural induction on
the frozen-index native query template. Once children are normal, any permitted
root step returns a normal subterm or role constant; an improper root can
remain blocked without blocking valid inner steps. The source context count
includes natural addition and tuple/list framing as well as message functions,
but never constructors introduced by assignments. Thus the bound covers
controlled-kind/framed templates and normalized assignments without a compatible
typed shadow. It also holds on the broader raw AST; this does not admit those
extra terms through the stream guard or prove substitution/image closure.
The theorem establishes a bounded normalizing derivation, not uniqueness of its
result or a bound for all reduction orders.

## Why guarded convergence extends beyond proper messages

The new [`QuerySortedExact.lean`](equations/QuerySortedExact.lean) proves every
guarded root redex is a proper message. Guarded steps and counted paths on that
image decode to exact typed matching, so its existing confluence theorem joins
every primitive overlap. This does not assume the entire raw source is proper:
[`QuerySortedGlobal.lean`](equations/QuerySortedGlobal.lean) joins nested peaks
structurally, including natural-addition and free tuple/Node contexts.
A strictly decreasing source-context count yields global termination and
matching confluence on all frozen-index native terms.

[`QuerySortedAC.lean`](equations/QuerySortedAC.lean) transports steps across
structural AC in both directions, including reassociation/permutation of raw
natural sums. This removes the earlier whole-source decoding premise.
[`QuerySortedQuotient.lean`](equations/QuerySortedQuotient.lean) keeps guarded
AC-rewrite-AC steps distinct from the unguarded shadow relation and realizes
each counted quotient path by guarded matching. Exact matching confluence then
gives quotient confluence and normal-form uniqueness modulo AC. Normality is
AC-invariant, matching/quotient normality agree, and the AC-invariant count
also proves guarded quotient termination.

These direct results cover the controlled-kind/free framing subset; they do
not transport shadow confluence or change the admitted grammar. Kernel cases
retain unequal AC-equivalent error-kind normal forms, framed nonlinear keys
and a raw case whose initially improper root becomes proper after an inner
rewrite. That last case is outside the stream grammar, demonstrating why
properness invariance cannot be assumed for arbitrary raw terms.
Sorted narrowing, complete AC-unification/FVP transfer, the full imported
NAT/kind-variable carrier and universal importer correspondence remain
explicit obligations, not consequences of the 169-audit count.

## Why sorted substitution no longer needs an assumed shadow

Guarded matching tests proper-message payloads and keys. Raw substitution
preservation alone would be unsound here: replacing a message variable with
a node or list can invalidate a previously permitted root match.
[`QuerySortedSubstitution.lean`](equations/QuerySortedSubstitution.lean)
instead models the exact mathematical value discipline of the five variable
sorts. Every such assignment has the existing typed representation, and every
typed assignment satisfies that discipline. Proper-message guards therefore
survive substitution, as do guarded steps and counted matching/quotient paths.

Kind abstraction maps Fresh leaves into disjoint natural shadow indices.
[`QueryKindSubstitution.lean`](equations/QueryKindSubstitution.lean) proves
this preserves proper values and yields a sorted abstract assignment. Its
typed representation provides the previously assumed compatible shadow.
Consequently the controlled-kind/free framing image is closed under all
modeled sort-respecting assignments, including node assignments, without
another shadow premise or broader native grammar.

This does not reflect rewrites through substitution: a normal expression
such as `fst(MessageVariable)` can acquire a pair argument and become reducible.
Nor does it prove native unifier completeness, returned-binding validation,
variable renaming/importer correctness or FVP. Those require correspondence
with the native algorithms, not just closure of a mathematical assignment class.

## Why solution transport is not complete unifier enumeration

Narrowing must compose substitutions without capture or silently changing their
sorts. [`QueryComposition.lean`](equations/QueryComposition.lean) proves that
applying one simultaneous assignment and then another agrees with their
composition, which remains sorted. It also proves identity, associativity and
pointwise AC congruence through message, natural and free framing contexts.
This supplies algebraic composition laws, not a proof of native name generation.

[`QueryUnification.lean`](equations/QueryUnification.lean) models an AC solution
as a sorted assignment making both substituted sides AC-equivalent. Solutions
survive sorted composition. Proper message/natural encoding preserves and
reflects them; every native solution on those encoded inputs has an existing
typed representation. Kind solutions likewise correspond when the shadow is
the abstract assignment derived from the actual original assignment.

Dropping that last condition is unsound. A Fresh variable and a natural
variable cannot have a sorted original AC unifier. Abstraction maps them to
different natural shadow variables; an unrestricted typed assignment can set
both to `one`. That shadow solves the abstracted problem but cannot come from
any sorted original assignment. Kernel cases prove both the no-solution claim
and the incompatible shadow witness. Actual pinned Maude returns no unifier
for the original variables or their mixed-kind sums, but finds a same-sort
natural unifier. This is not a guard defect and needs no filtering or broader
grammar; it prevents treating all abstract unifiers as original solutions.

Plain AC unification also does not use ordinary equations: `flip(roleA)` and
`roleB` have no AC unifier despite their rewrite equality. The kernel count
invariant and actual Maude agree. Variant unification/narrowing must account
for those equations separately. These solution-transport theorems alone do not
establish a finite complete set or most-generality. The scoped extension below
transports those properties when proved for a given family/candidate; native
generation, occurs-check/fresh-name correctness, importer correspondence and
FVP remain separate.

## Why completeness transport still does not supply a generator

Finding some solutions is weaker than covering all solutions. For `X = Y`,
assigning both variables to `one` is sound but misses the solution in which
both remain the same variable. A complete family must cover that solution
through a sort-respecting postfactor, not simply contain valid answers.
[`QueryCompletenessCases.lean`](equations/QueryCompletenessCases.lean) proves
both a complete variable-pair singleton and the ground singleton's failure.

Coverage must compare only variables of the original input query. An extra
binding for an unrelated message variable cannot invalidate an MGU for this
natural-variable problem. The same kernel control shows that adding that
unrelated variable to the comparison incorrectly rejects the scoped MGU.
[`QueryInstances.lean`](equations/QueryInstances.lean) therefore extracts exact
query supports, proves scoped substitution congruence and gives sorted
postfactor instantiation a reflexive/transitive order. Sorted instances of
solutions remain solutions. It never assumes equality on all bindings.

[`QueryTypedInstances.lean`](equations/QueryTypedInstances.lean) independently
defines typed composition and scoped equality/AC at all five sorts. Encoding
commutes with composition; the existing representation of every sorted native
assignment supplies every factor witness in the reverse direction.
[`QueryCompleteness.lean`](equations/QueryCompleteness.lean) then preserves
and reflects complete given finite families and candidate most-generality on
proper message/natural inputs. A complete singleton and a most-general member
are equivalent claims, not evidence that every problem has a singleton.

The quantifier is over a supplied family, not an algorithm producing a finite
complete family for every query. Total mathematical assignments also do not
verify native finite-support substitutions, freshness or an occurs check.
The cyclic/no-zero controls concern finite-AST solution semantics only.
Kind-solution compatibility does not by itself transfer family coverage or
its postfactors; no unrestricted shadow-completeness claim is added.
Native generation, narrowing/FVP and the complete source/importer boundary
therefore remain open despite this stronger relational correspondence.

## Why finite support still does not supply a complete generator

A finite query observes only finitely many assignment entries. Keeping those
entries and using identity elsewhere preserves the substituted inputs exactly,
even when the original mathematical assignment changes infinitely many other
variables. [`QuerySupport.lean`](equations/QuerySupport.lean) proves that
restriction is sorted when the original is, and represents it by an explicit
finite binding list. Lookup is simultaneous; inserted values are not repeatedly
substituted. This is a mathematical representation, not a runtime import policy.

Postfactors need a different support. If a candidate for `X = Y` maps both
variables to a residual `Z`, reaching the ground solution requires `Z -> one`.
Although `Z` is absent from the original input, dropping its binding destroys
factorization. [`QueryFiniteUnificationCases.lean`](equations/QueryFiniteUnificationCases.lean)
checks this with residual index `7`, including impossibility for every
input-only supported factor. The correct finite range is the variables in
the candidate's values at input variables.

[`QueryFiniteUnification.lean`](equations/QueryFiniteUnification.lean) proves
finite factor witnesses on that range, finite representatives for every
sorted solution, and equivalence between covering all solutions and covering
only input-supported finite solutions. Restricting a supplied family preserves
and reflects completeness only with the original candidates sorted. An invalid
unrelated binding must not become accepted merely because restriction erases it.

Neither finite representability nor this coverage equivalence constructs a
finite complete family for an arbitrary query. Native enumeration, occurs
checks, fresh-variable namespaces and query-builder/importer correspondence
remain separate. Kind-family transfer, narrowing/FVP and exact assembled
acceptance are not consequences of these finite-support laws.

## Why kind-shadow factors must lift too

Corresponding individual solutions do not make unrestricted shadow factoring
sound. Suppose a message candidate assigns `M -> F`, where `F` is Fresh, and
a ground candidate assigns `M -> one`. Both are sorted original assignments.
The abstraction represents `F` as an odd-indexed natural variable, so a
sorted natural shadow factor can instantiate it to `one`. No sorted original
postfactor can do that: Fresh variables can only become Fresh atoms or
variables. [`QueryKindInstanceCases.lean`](equations/QueryKindInstanceCases.lean)
proves this failure even though both candidates themselves are valid.

[`QueryKindInstances.lean`](equations/QueryKindInstances.lean) therefore
constructs an assignment expansion inverse and requires two properties of
admissible shadows: expansion has all original sorts, and reabstraction
recovers the shadow exactly. Sorted expansion alone is insufficient; the
kernel cases retain an off-image shadow with a sorted lift. These constraints
are mathematical, not a proposal to discard native solutions or a runtime
admissibility decision procedure.

Exact composition and variable-support correspondence then preserve and
reflect scoped factorization using admissible postfactors.
[`QueryKindCompleteness.lean`](equations/QueryKindCompleteness.lean) applies
the same constraint to family members and compared solutions. It proves
that a supplied original family is sound and complete exactly when its
abstracted family is complete for admissible kind shadows and factors.
Most-generality transfers too. For Fresh/natural equality, the original
empty family is complete; the admissible shadow family is also empty and
complete, whereas unrestricted shadow solutions make it incomplete.

This closes constrained kind-family transport without replacing original
sort obligations by natural shadow sortedness. It supplies neither a finite
complete family generator nor native algorithm/importer, narrowing/FVP or
full imported-carrier/assembled acceptance.

## Finite-variant rationale

The KEM equation has the same term-rewrite shape as Tamarin's documented
asymmetric-decryption rule
`adec(aenc(m,pk(sk)),sk)=m`, with renamed encryption/decryption symbols.
The repeated-key constraint is therefore not a novel algebraic operation.
The other collapsing rules are documented builtin equations. The two
role rules have finite ground left sides and ground normal right sides;
they cannot produce another role-redex.

The checked uniform bound now replaces an informal subterm/ground boundedness
rationale. Cholewa, Meseguer and Escobar's theorem 6 relates boundedness to
EMS-FVP under its decomposition hypotheses. Convergence/B-coherence and the
bound are checked in the typed algebra, with independent structural guarded
convergence/boundedness and sort-respecting substitution closure on the
frozen-index native AST. Sorted AC solutions now compose and transport through
the proper typed image and compatible kind shadows. Given proper-image families,
scoped completeness/most-generality also transfer. Admissible kind-shadow
families and postfactors now preserve/reflect their original counterparts,
but complete sort/signature,
finite complete AC-unifier generation and native-image correspondence must still be
reconciled before applying that theorem to Tamarin's backend.

There is a stronger, exhaustive flat-pattern criterion, not a sample-term
shortcut: [Maude 3.5.1 manual, section 14.2](https://maude.lcc.uma.es/maude-manual/maude-manualch14.html)
cites Cholewa, Meseguer and Escobar, *Variants of Variants and the Finite Variant
Property*, theorem 7 ([2014 technical report](https://www.ideals.illinois.edu/items/47132)).
For an already admissible convergent order-sorted decomposition, finite complete
variant sets for every required flat operator pattern establish the stronger
EMS-FVP. Termination, confluence, sort-decreasingness, coherence modulo AC,
sort/signature hypotheses and complete AC unification are prerequisites, not
outputs of merely printing `No more variants`.

A bounded local investigation completed all 17 declared protocol flat patterns
on the unchanged native module. A known non-FVP control stopped at its explicit
five-variant cap without an exhaustion marker. A separately source-checked sorted
protocol module passed CRC's local-confluence and sort-decreasingness checks.
These do not yet prove full native admissibility or conservative correspondence
between the protocol algebra, the native bookkeeping signature and the paper's
sort/kind assumptions. Maude automatically lifts operators to kinds, including
error terms without a proper sort ([manual, section 3.5](https://maude.lcc.uma.es/maude-manual/maude-manualch3.html)).
The flat-pattern criterion's manual statement uses kind-sorted variables.
Declared-sort exhaustion alone is therefore not treated as complete evidence
for that broader signature. A new bounded native diagnostic also exhausts
all 25 explicitly declared ranks at kind level (17 protocol and eight
bookkeeping/list ranks), retaining error-kind variants. Imported `NAT`
operators, native admissibility and correspondence are not discharged.
Full FVP acceptance remains open. The owner selected the actual
protocol-query image, later extending it to required derivation-kind terms,
not the entire imported arithmetic/error-kind carrier. That choice does not waive preservation,
reflection or substitution/unification/narrowing closure.

The manual cites Comon-Lundh and Delaune, *The Finite Variant Property:
How to Get Rid of Some Algebraic Properties*, RTA 2005, pages 294-307
([versioned bibliography](https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/manual/src/manual.bib)).
The present review uses the manual's documented supported-class rationale;
it does not claim to reproduce a machine-checked proof of that theorem.

## Combination boundary and security meaning

The message rules introduce no `%+` symbol or natural-sort equation.
AC permutation/reassociation preserves function-occurrence counts, so
the termination measure above remains compatible with working modulo
the builtin AC relation. Constructor terms and message variables can
still contain natural-number subterms, however; disjoint function names
alone are not a complete proof of the combined theory's FVP. Tamarin's
sorted AC unification/variant backend and its supported combination
remain part of the trusted tool boundary.

Independent acceptance of the exact mixed message/natural theory, or a
formal combination certificate, is still outstanding. This document
narrows that review to three custom equations and the explicit builtin
combination; it does not close the independent equation-evidence gate.

`kdec` is a symbolic destructor, not a claim that ML-KEM ciphertexts reveal
their encapsulated secrets or that real implicit rejection is perfect.
Unmatched ciphertexts remain destructor terms. The protocol's actual
validation, rejection behavior, constant-time execution and computational
security require separate implementation/primitive evidence.
Likewise, `flip` defines role selection, not authenticated peer identity.
No protocol behavior, equation, rule, restriction or proof annotation was
changed for this review.
