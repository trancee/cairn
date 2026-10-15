# Why the ratchet equations fit the symbolic model

Mathematical review of the default
[`ratchet.spthy`](ratchet.spthy) equation set, observed on 2026-10-09.
The `2026-10-14` [source-guarded Lean termination subgate](equations/README.md)
now kernel-checks termination, B-coherence, confluence modulo sorted natural
AC and a normalization bound independent of normalized substitutions.
These results cover the typed algebra. Native query-image transfer and the
remaining FVP hypotheses stay separate; this is not a native FVP certificate.

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
It retains the checks and is now a maintained, opt-in
[candidate](equations/native-proxy/README.md), not a default cutover
or a new mathematical proof. Tiny-fixture startup still adds `39.93` ms
(`+33.76%`). The owner approved maintained promotion with a startup-only
`50` ms cap, retaining `10%` for full export; Linux/caller/CI criteria must pass
before cutover. The default Python route and all native FVP/full-context gates
remain unchanged. Compiled evidence now identifies its reviewed source;
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
The follow-up `38719650091` at `2b642e2` now passes all 18 callers/fast gates
and native full export (`+8.4987%`), without a waiver. Startup then identifies
another host-fixture assumption: only its macOS digest was retained. Pinning
the exact observed direct Linux startup digest uses the same fixed-inventory
decision; it does not learn accepted bytes from runtime samples or change
within-host byte identity and timing checks. Native startup acceptance remains
pending, so the default is still unchanged.
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
67 required theorem audits. The typed bound does not itself establish native
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
arbitrary assignments, while framed substitution closure has a compatible
typed-shadow premise not yet derived for every runtime-validated assignment.

This does not transport the earlier proper-message matching theorem wholesale.
Raw rules deliberately omit native message-sort guards. A raw projection can
erase an ill-kind discarded pair component; actual Maude cannot match that
component to its proper `Msg` variable. For example,
`fst(pair(roleA, FreshVariable + one))` has a shadow reduction to `roleA`
but stays at `[TOP]` in the real native reduction. Termination of this
overapproximation is useful, but confluence or existence of a normalizing
shadow path does not imply those properties for the guarded native subset.
Native sorted matching/narrowing and complete AC-unification/FVP transfer
remain explicit obligations, not consequences of the 67-audit count.

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
bound are checked in the typed algebra, but the complete sort/signature,
AC-unification and native-image correspondence obligations must still be
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
