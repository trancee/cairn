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
  14 reports and checks sorted composition, pointwise AC congruence and
  AC-unifier solution transport, including compatible kind shadows;
- kernel-checks `QueryInstances.lean`, `QueryTypedInstances.lean` and
  `QueryCompleteness.lean`, audits 14 reports and checks query-variable-scoped
  factorization, its preorder/solution closure, all-five-sort typed
  correspondence and conditional completeness/most-generality transport;
- kernel-checks `QuerySupport.lean` and `QueryFiniteUnification.lean`, audits
  14 reports and checks finite binding-list representations, exact input
  restriction, finite residual-variable postfactors and finite-solution
  completeness/most-generality equivalences;
- kernel-checks `QueryKindInstances.lean` and `QueryKindCompleteness.lean`,
  audits 14 reports and checks constructive assignment lifting, exact kind
  composition/support, admissible postfactors and constrained family/MGU
  correspondence, including unrestricted-shadow counterexamples;
- kernel-checks `QueryOccurs.lean`, audits four reports and checks proper
  finite-AST occurrence rejection, including controlled-kind/free framing;
- kernel-checks `QueryVariableBindings.lean` and `QueryVariableGeneration.lean`,
  audits 13 reports and checks finite, supported, idempotent one-binding MGUs
  and complete generated families for sort-compatible variable equations;
- kernel-checks `QuerySystems.lean` and `QuerySystemBindings.lean`, audits
  15 reports and checks finite equation systems, explicit coverage scopes,
  residual-factor lifting, finite binding composition and variable elimination;
- kernel-checks `QueryConstructors.lean` and `QueryConstructorSystems.lean`,
  audits 18 reports and checks free-constructor inversion/decomposition,
  fixed-head clashes and termination of constructor decomposition;
- kernel-checks `NaturalMultiplicity.lean`, audits seven reports and checks
  exact AC/multiplicity equivalence and decoding without an empty natural term;
- kernel-checks `NaturalLinearization.lean`, audits two reports and checks
  exact substitution counts with repeated variables and frozen rigid labels;
- kernel-checks `IntegerWords.lean`, `IntegerZeroSum.lean`, `IntegerWordBasis.lean`,
  `IntegerWordInclusion.lean`, `IntegerWordPruning.lean`,
  `IntegerBasisCompleteness.lean`, `IntegerBasisExtension.lean` and
  `IntegerMatrixBasis.lean`, audits 19 reports and checks finite complete
  homogeneous matrix bases with signed/zero coefficients and primitive pruning;
- kernel-checks `IntegerWordExpansion.lean`, `IntegerWordMixture.lean`,
  `IntegerMatrixFactors.lean`, `IntegerWordFamily.lean`,
  `IntegerMixtureAlgebra.lean`, `IntegerMixtureSoundness.lean`,
  `IntegerFamilySoundness.lean` and `IntegerFamilyCompleteness.lean`, audits
  19 reports and checks complete nonempty homogeneous semigroup families
  with globally nonempty residual factors on the explicit input scope;
- kernel-checks the seven `IntegerRigid*`/mixture-component/transport modules,
  audits 14 reports and checks finite rigid-column choices, singleton
  constants and complete globally nonempty factorization;
- kernel-checks `NaturalResiduals.lean`, audits four reports and checks fresh,
  bounded native indices with injectivity on actual basis members;
- kernel-checks `IntegerWordLinear.lean` and `NaturalColumns.lean`, audits
  14 reports and checks exact concrete matrix characterization of natural systems;
- kernel-checks `IntegerRigidScope.lean`, `NaturalSystemFamily.lean`,
  `NaturalBindings.lean`, `NaturalAtomSubstitution.lean`,
  `NaturalSystemScope.lean`, `NaturalSystemRealization.lean` and
  `NaturalSystemCompleteness.lean`, audits 21 reports and checks generated
  finite native natural-system bindings, original input scope, frozen constants,
  fresh residuals and globally sorted complete postfactorization;
- kernel-checks the six sort-intersection/shape/requirement/refinement/principal/
  fingerprint modules, audits 11 reports and checks exact post-substitution
  value sorts without rejecting message-to-natural refinement;
- kernel-checks the 27 full-AST generation/lifting modules in
  [`general_audits.py`](general_audits.py), including the definitions-only
  `QueryRawGeneration.lean`, audits 122 reports and checks unrestricted raw
  soundness, complete marker realization, fresh residuals and actual finite
  sorted-family completeness with globally sorted postfactors;
- generates and kernel-checks a certificate translating every source equation
  to its exact `PrimitiveRewrite` constructor.

Exit `0` means all typed subgates passed. Exit `1` reports `FAIL:` for
a missing/malformed toolchain pin, unreviewed/malformed source, unsupported tools,
a failed native command, missing/duplicate theorem reports or unexpected axioms. Native commands retain
the existing `120`-second bound; version checks use `30` seconds.
Invalid command-line syntax uses argparse's exit `2`; `--help` exits `0` without
checking a proof.
Only `propext`, `Classical.choice` and `Quot.sound` are permitted by the shared
axiom audit. Thirty of the 453 audited theorems use no axioms. The three
uniform normalization-bound theorems, assignment/shadow representation and
closure/solution-representation, sorted factorization, admissible-shadow
composition and family/most-generality
transport audits depending on those witnesses use all three permitted axioms.
The finite-support and finite-unifier audits use at most `propext` and `Quot.sound`.
The new kind-instance/family audits also use at most those two, except
admissible-shadow composition, which inherits classical choice from sorted composition.
System substitution and elimination also inherit classical choice from sorted
composition; their explicit binding-list construction is executable without it.
The natural multiplicity equivalence inherits all three permitted axioms from
the standard library's permutation/count characterization; atom-list
equivalence, nonemptiness and addition counts use only `propext`.
The linear count substitution theorem uses `propext` and `Quot.sound`; its
AC-unifier equivalence inherits the count characterization's classical choice.
Integer-word coverage, primitive extraction and finite-family factorization
may use classical choice in their proofs; the actual finite generators do not.
Other audits use at most `propext` and `Quot.sound`.
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
Correspondence with native sorted unification, narrowing completeness and
backend algorithm correctness remain unproved.

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
inventory is in `../equation_fixtures.py`; independent omission scenarios are
in `../equation_audit_cases.py`. General-generation fixture reports are literal
and independent in `../equation_general_fixtures.py`. The checker owns build order
and imports additive/general report names from `additive_audits.py` and
`general_audits.py`. These responsibility splits
retain the same public command and keep maintained files below the hard size limit.

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

`QueryInstances.lean` extracts the variable support of every raw query context.
Rigid atoms contribute no variables; sort/index pairs stay distinct.
`NativeAssignmentACOn` compares assigned values only at listed variables.
`NativeACInstanceOn variables general specific` has a sorted postfactor whose
composition with `general` is pointwise AC-equivalent to `specific` on that
support. General/specific assignments are not themselves required sorted by
this predicate. The relation is reflexive/transitive; if `general` solves a
query and `specific` is sorted, factoring on both input supports makes
`specific` a solution too. Duplicate support entries have no effect.

`QueryTypedInstances.lean` independently defines ordered typed composition
and scoped typed comparison: equality for public/fresh/node labels,
`MessageAC` for messages and `NaturalAC` for naturals. Encoding commutes with
composition and preserves/reflects scoped comparison and factorization.
The AC leaf invariant retains constructor, sort and rigid/variable distinctions.
Typed factor witnesses exist for every modeled sorted native factor.

`QueryCompleteness.lean` defines sound complete families separately from
individual solutions. Completeness covers every sorted solution by an instance
of a family member, comparing only variables of the original two input terms.
Most-generality requires a candidate solution covering every solution on that
same support; a singleton family is complete exactly when its member is most
general. On proper message/natural encoded inputs, mapping an existing finite
typed family preserves/reflects completeness and candidate most-generality.
These theorems quantify over given lists and total mathematical assignments.
They do not construct a family for every query, prove irredundancy or finite
support, verify a native generator/occurs check/fresh namespace, or transport
arbitrary kind-shadow families.

The three new kernel case modules retain all-five-sort support/composition,
frozen same-index rigid labels, natural AC comparison and sorted-factor
rejection. For `X = Y`, a variable-pair singleton is complete, but assigning
both variables to `one` is sound and incomplete. An unrelated message binding
does not affect the scoped MGU; adding that variable to the comparison would
incorrectly reject it. Empty-family, cyclic finite-AST solution and positive
natural/no-zero controls remain distinct from native algorithm verification.

`QuerySupport.lean` defines `restrictNativeAssignment variables assignment`
to keep the listed assignments and use identity elsewhere.
`NativeAssignmentSupportedOn` requires identity outside a given finite list.
`nativeBindingAssignment` interprets a finite list of sort/index/value bindings
by first-binding, simultaneous lookup, with identity for unbound variables.
`NativeFiniteAssignment` requires representation by such a list. Restriction
has that representation, preserves sortedness and leaves substitutions exactly
unchanged when the list contains the input's variables. Rigid atoms stay frozen;
duplicate support entries and different sorts at the same index remain distinct.
This mathematical lookup definition does not change the runtime parser or
certify its duplicate handling.

`QueryFiniteUnification.lean` defines `nativeAssignmentVariables variables
assignment` as the variables occurring in the values assigned to the listed
variables. Every scoped sorted postfactor has a finite binding-list witness
supported on that range. The range can contain residual variables absent from
the original query. Every sorted AC solution also has a finite representative
supported on the two inputs, agreeing exactly at those variables.
Completeness and most-generality are equivalent to covering only those
input-supported finite solutions. Restricting an existing finite family's
candidates preserves/reflects completeness with an explicit premise that the
original candidates are sorted. Unsound original bindings cannot be accepted
by erasing them. These results do not construct a complete family.

`QuerySupportCases.lean` retains all five sorts, free framing, simultaneous
insertion, rigid/sort distinctions, empty/duplicate finite lookup and invalid
sorted values. `QueryFiniteUnificationCases.lean` uses the MGU mapping both
original variables to residual variable `7`: a factor fixing `7` to `one`
works, while every factor supported only on the original variables fails.
The restricted singleton remains complete; an invalid original assignment
and its well-sorted restriction remain separate.

`QueryKindInstances.lean` maps variable keys with `kindVariableKey`: original
Fresh index `i` becomes natural index `2*i+1`, natural index `i` becomes
`2*i`, and the public/message/node keys remain unchanged.
`expandKindAssignment` reads the mapped key and applies `kindExpansion`.
Expansion after abstraction is exactly the original assignment; abstraction
is injective, commutes with ordered simultaneous composition and maps every
raw input's variable support exactly, including controlled-kind/free framing.

`NativeKindAdmissibleAssignment shadow` requires both
`NativeSortedAssignment (expandKindAssignment shadow)` and
`abstractKindAssignment (expandKindAssignment shadow) = shadow`.
It is equivalent to being the exact abstraction of a sorted original assignment;
the inverse supplies that original constructively. Admissibility implies shadow
sortedness and is closed under composition. It is a mathematical predicate,
not an executable admissibility decision procedure or native reply filter.
Sorted expansion alone does not establish the exact-image condition.

`NativeKindACInstanceOn` uses an admissible postfactor, not just a sorted
shadow postfactor. It preserves/reflects original scoped AC factorization on
the mapped input support. `QueryKindCompleteness.lean` defines
`NativeKindCompleteACUnifiers` and `NativeKindMostGeneralACUnifier`, requiring
admissible candidate solutions, compared solutions and postfactors. Mapping
any supplied original family by `abstractKindAssignment` preserves/reflects
sound completeness; candidate most-generality and singleton completeness
correspond as well. All original sortedness obligations survive the inverse.
No family is generated and no unrestricted shadow family theorem is asserted.

`QueryKindInstanceCases.lean` checks parity-separated keys, rigid labels,
all five sorts and framing. It separates a sorted lift outside the exact image
from an admissible shadow. Two sorted original candidates can be related by
an ordinary shadow factor that maps a Fresh residual to `one`, while no sorted
original factor exists; the admissible relation excludes it.
`QueryKindCompletenessCases.lean` checks a mixed-kind commutative MGU and the
empty complete family for Fresh/natural equality. That same empty family is
not complete for unrestricted shadow solutions.

### Constructive variable equations

`QueryOccurs.lean` proves that substituting a proper occurrence of a variable
strictly increases function count over its assigned value. Structural AC
preserves that count, so `X = term` has no finite-AST AC unifier when `X`
occurs properly in `term`. The empty family is then sound and complete.
The weak occurrence bound includes identity; the strict bound excludes it.
Variable keys include both sort and index; rigid atoms are not occurrences.

`QueryVariableBindings.lean` constructs the explicit binding
`nativeBindingAssignment [((sort, index), value)]`. It is finite, supported on
that key and sorted exactly when `NativeSortedValue sort value` holds.
If the key is absent from `value`, substitution fixes `value` and the binding
is idempotent. Every sorted solution factors through it pointwise modulo AC,
using that solution itself as the sorted postfactor. This proves most-generality
and singleton completeness in both equation orientations.

`QueryVariableGeneration.lean` defines `nativeVariableBindingFamily sort index
value`, where `value` carries a proof of `NativeSortedValue sort value.val`.
It returns explicit finite binding lists: `[[]]` for the identical variable,
`[]` for a proper cycle, or `[[((sort, index), value.val)]]` when the key is
absent. Mapping these lists through `nativeBindingAssignment` gives a sound
complete family for `queryVariable sort index = value.val`; every candidate
has a finite representation. This is a constructive solver on that
proof-carrying domain, not a runtime sort classifier or a general sorted AC
generator. An incompatible orientation is outside the domain, not a verdict
that the equation has no solutions.

`QueryOccursCases.lean` and `QueryVariableBindingCases.lean` check all five
sorts, same-index sort/rigid distinctions, identity/proper/repeated occurrences,
all enclosing AST constructors, natural AC reordering and residual variables,
finite support/idempotence, invalid sorted bindings and a valid reversed
cross-sort orientation. Computed families cover identity, a proper cycle and
an occurs-free residual binding. A sorted cyclic binding still executes
simultaneously but is neither idempotent nor an AC unifier. AC rejection
does not imply equational rejection: `X = fst(pair(X, roleA))` has a complete
empty AC family, while the source projection rewrites its right side to `X`.
These mathematical results do not verify the native occurs check, fresh-name
allocation, finite-family generation, importer or narrowing.

### Finite systems and variable elimination

`QuerySystems.lean` defines `NativeEquationSystem` as a finite list of term
pairs. `nativeSystemVariables` collects both sides' variable keys, preserving
sort/index distinctions and ignoring rigid atoms. `substituteNativeSystem`
applies one simultaneous assignment to every pair. `NativeACSystemUnifier`
requires a sorted assignment solving every pair modulo structural AC.

`NativeCompleteACSystemOn equations variables family` requires soundness on
all equations and coverage on the explicitly supplied variable scope.
Use `nativeSystemVariables` of the original system for full input coverage.
The scope is not implicitly recomputed after simplification. Single-equation
completeness on its input support agrees with `NativeCompleteACUnifiers`;
empty systems have the identity singleton on any scope. Reflexive-head
removal and equation reversal retain that same scope.

System substitution corresponds exactly to ordered assignment composition,
with sortedness of both assignments retained explicitly. Sorted composition
alone does not establish sortedness of its second assignment: the first can
hide an invalid binding. Pointwise AC-equivalent sorted assignments preserve
system solutions. Exact agreement on the original system's variables also
preserves solutions when the replacement assignment remains sorted.
Prefix composition lifts scoped factorization only when
the residual scope includes `nativeAssignmentVariables variables prefix`,
including variables in prefix values that no residual equation mentions.

`QuerySystemBindings.lean` defines `composeNativeBindings first second` by
substituting `second` into every value of `first`, then appending `second`.
Its interpreted assignment equals `composeNativeAssignments`; finite
assignments are closed under this operation. Lookup remains simultaneous
and first-binding. Raw concatenation is not composition, and reversing the
lists changes its meaning. This does not change native duplicate handling.

For a sort-compatible occurs-free head `X = value`, eliminate that binding
from every remaining equation. A family complete for the residual system
on the prefix-value scope lifts to a complete family for the original system
by prefix composition. The proof constructs the factorization, not just
solution soundness. The reversed equation orientation has the same result.
A proper occurs cycle has a complete empty family regardless of the tail.
These are conditional family-composition rules, not an automatic general
equation-system solver or a complete natural-addition AC generator.

`QuerySystemCases.lean` and `QuerySystemBindingCases.lean` retain all-five-sort
support, rigid labels, empty/reflexive/singleton systems, sortedness premises,
shared-variable propagation, genuine AC residual solving, composition order,
overlapping/duplicate binding precedence, finite witnesses and reversed
Fresh/message elimination. A ground residual binding is complete on the
empty remaining-equation support but yields an incomplete family for `X = Y`;
retaining the prefix-value scope excludes that false completeness claim.

### Free-constructor systems

`QueryConstructors.lean` defines `nativeQueryHead` with constructor symbols,
sorts and rigid indices retained. Structural AC preserves this head.
`nativeFreeChildren` gives the ordered arguments of unary/binary message
functions, `kdf`, `list` and `cons`; constants have no children. Natural
addition deliberately has no ordered free children. `NativeChildrenAC`
requires equal-length lists with pointwise structural AC.

For a non-addition left head, structural AC is equivalent to equal heads
and AC-related free children. This gives exact inversion laws for all five
non-nullary free-constructor forms, without assuming that natural addition
is ordered or that different native sorts/rigid indices coincide.

`QueryConstructorSystems.lean` lifts these laws to
`NativeCompleteACSystemOn`: replace a matching constructor equation by its
ordered argument equations, preserving the tail, explicit variable scope
and candidate family in both directions. `NativeFixedHead` excludes query
variables. Substitution preserves every fixed head, so two different fixed
heads give a complete empty AC family regardless of the tail.
No clash is inferred merely from a variable's original head.

`NativeConstructorDecomposition` contains the five decomposition steps.
Each strictly decreases `nativeSystemFunctionCount`, giving a well-founded
relation. This proves termination of constructor decomposition, not of a
general AC solver incorporating variable elimination or additive branching.

`QueryConstructorCases.lean` checks symbolic constructor parameters, nested
addition, ordered pairs, symbol/rigid-index/sort clashes, free framing,
variable binding and the addition exclusion. An AC-empty `flip(roleA) =
roleB` system still has the source `flipA` rewrite: these clash results do
not reject equality modulo the six equations.

The constructor increment has fresh standalone Lean/kernel and fixture-backed
CLI evidence. Real native source/export acceptance is deferred at the owner's
request; the default command and its native checks remain unchanged.
Constructor decomposition alone does not generate mixed AC families; the actual
full-AST generator is specified [below](#general-sorted-ac-families).

### Exact natural multiplicities and linearization

`NaturalMultiplicity.lean` defines the computable `naturalAtomCodes` list:
literal `one` has code `0`, and variable/atom label `index` has code `index + 1`.
These are proof representation tags, not natural terms or changed native/wire
indices. Addition concatenates the lists; every term's list is nonempty.
`naturalMultiplicity atom term` counts one code in that list.

`natural_ac_atoms_iff` proves structural natural AC exactly when the lists
are permutations. `natural_ac_multiplicity_iff` proves the equivalent
pointwise count characterization in both directions; count invariance alone
would not suffice. `natural_multiplicity_add` proves counts add under addition.
Private optional folds handle an empty list during the proof without adding
an empty/zero term to `NaturalTerm` or any substitution.

`NaturalMultiplicityCases.lean` checks repeated labels, literal/label
separation, arbitrary reassociation/permutation and equal-weight terms with
different counts. For every term, adding literal `one` changes its AC class;
`one` is not an identity. This closes the multiplicity representation layer,
not finite Diophantine-basis generation, sorted residual-variable construction,
combined-solver termination or finite-family completeness.

`NaturalLinearization.lean` computes `naturalVariableOccurrences` with
repetitions retained and rigid odd labels omitted. `naturalRigidMultiplicity`
counts only literal `one` and frozen rigid labels. `naturalLinearCount` adds
this constant to the finite sum of assigned atom counts, one per variable
occurrence. Thus `X + X` has coefficient two, not one. It does not recursively
substitute inside assigned values.

`natural_linear_count_substitution` proves that this finite occurrence-form
linear expression equals the actual substituted term's multiplicity.
`natural_linear_unifier_iff` proves that two substituted naturals are AC
equivalent exactly when their expressions agree for every atom, including
residual labels absent from the input. `NaturalLinearizationCases.lean`
checks repeated variables, rigid/variable parity separation, residual labels,
simultaneous substitution and the unsatisfiable equation `X + X = one`.
These are exact constraints, not by themselves an enumeration or completeness
proof for natural systems with rigid constants.

### Finite homogeneous semigroup generation

An integer word encodes a nonnegative column vector by repeating column
labels. `integerWordSum row word` is its signed dot product. The zero-sum
proof reorders bounded weights so every prefix stays in `[-B,B]`; repeated
prefix states extract a nonempty zero-sum subword of length at most `2*B+1`.
`B` is the maximum absolute alphabet weight, including zero. The one-row
generator enumerates this finite word bound. Recursive row intersection
generates a complete homogeneous matrix basis and prunes permutation
duplicates and generators containing a smaller nonempty generator after
each row. The universal coverage theorem instantiates the concrete
generator; it does not assume a complete family supplied by a caller.

`integerMatrixWordFamily alphabet rows` enumerates subsets of that basis
and retains only candidates with nonempty images for every alphabet column.
For a duplicate-free alphabet, all candidates satisfy every row for every
output atom. Every nonempty word-valued solution factors through a candidate,
on the explicit alphabet scope, using a globally nonempty residual assignment.
Arbitrary solution atoms outside the input remain covered. Empty intermediate
words represent inactive generators only, not natural zero or empty candidate
images/postfactors. Residual names are the basis words themselves in a separate
namespace; this is not yet an allocation into native natural-variable indices.

The generators are total by structural recursion on finite budgets, rows and
selection lists. Well-founded extraction uses decreasing remaining word
length. `IntegerWordCases.lean`, `IntegerFactorCases.lean` and
`IntegerFamilyCases.lean` check universal coverage/factorization and computed
zero columns, empty alphabets/rows, cancellation failure, coupled rows,
the `2X = 3Y` coefficient ratio and all seven nonempty branches of
`X + Y = Z + W`. The homogeneous milestone passed 263 audits and 31 case
modules. Its word residual namespace is encoded by the native layer below.

### Finite rigid and native natural systems

`integerRigidWordFamily` enumerates inactive, ground-singleton and residual
choices per matrix generator. It retains only nonempty column images and
exact singleton rigid columns. Every retained candidate satisfies every row;
every nonempty solution factors through the actual finite family, with a
globally nonempty postfactor fixing every ground atom. The seven rigid/
component/transport modules prove these properties without a supplied
complete arithmetic oracle.

`naturalResidualIndex` allocates above all original live indices, using the
first position in the generated basis. Allocation is bounded and injective
on distinct basis members, even with duplicate basis entries.
`naturalTermFromAtomCodes` reuses the existing optional fold: it returns
`none` exactly for the empty list and otherwise reconstructs the exact code
list. Code `0` still denotes literal `one`, not zero.

`NaturalColumns.lean` extracts live query-variable and frozen rigid columns,
deduplicates their finite alphabet and computes signed occurrence rows.
The rows balance exactly when all substituted natural equations hold.
`IntegerWordLinear.lean` supplies the count-pairing and flat-map identities;
rigid names remain even codes and fresh residuals become odd variable codes.

`nativeNaturalSystemBindingFamily` accepts a finite `NaturalEquationSystem`.
It generates rigid word candidates, encodes residuals at fresh native indices
and decodes all original variable images into finite bindings. A failed image
rejects the whole candidate, not an individual binding.
`natural_system_candidate_realization` proves valid generated candidates
never fail decoding and their binding assignments are globally sorted,
agreeing exactly with their typed representations on the original input scope.

`native_natural_system_family_complete` proves every generated binding
assignment solves every encoded equation and every sorted solution factors
through a generated candidate on `nativeSystemVariables` of the original
system. The constructed postfactor is globally sorted and covers residual
variables absent from the input. Substitution is simultaneous, including
inside assigned words; rigid constants remain fixed. Generator definitions
are structurally total over finite lists and introduce no empty natural term.
Mathematical witness selection may use classical choice; the actual candidate
generator does not.

`NaturalColumnCases.lean` checks exact row/solution equivalence.
`NaturalSystemCases.lean` checks universal native-family completeness and
computed literal/frozen-index bindings, `2X = 3Y`, all seven branches of
`X + Y = Z + W`, residual freshness, empty systems, contradictory constants,
`2X = one` and cancellation without zero.
The natural-system/sort-refinement milestone passed 331 audits (29 axiom-free,
no `sorryAx`) and 38 case modules; all 42 public equation-command fixture controls passed,
including mandatory completeness, scope, encoding and factor audits.
Real native source/export/replay/runtime work remains deferred.

This subsolver generates proper-natural systems, not mixed-sort,
controlled-kind or free-constructor systems by itself. The
[full-AST generator](#general-sorted-ac-families) uses its unconditional
completeness. No efficiency claim or changed native gate, budget, protocol or
activation follows from these proofs.

### Residual sort refinement and abstraction

`nativeSortedValueCheck sort term` decides `NativeSortedValue sort term`.
`nativeSortIntersection first second` returns their strongest common value
sort or `none` when no common value is possible. Message includes public,
fresh and natural values; Node intersects only Node.

`nativeSortRequirements expected template` returns `none` for an impossible
value shape or `some constraints` for finite variable requirements.
Each constraint pairs an original variable key with its required refined sort.
`native_sort_requirements_iff` proves that, under any globally sorted
assignment, the substituted raw template has the requested value sort exactly
when those requirements hold. The template itself need not be a proper value:
a message variable inside addition may subsequently receive a natural value.
Free framing and controlled-kind terms remain valid input ASTs, not new
admissible assignment-value sorts.

`nativePrincipalSort term` checks public, fresh, natural, message and Node
in that order, returning the first accepted sort or `none` if no modeled
value sort accepts the term. `native_principal_sort_iff` proves that every
proper value and a variable of its principal sort satisfy exactly the same
requested value sorts, for any replacement index. Narrow public/fresh/natural
sorts retain their inclusion in message without being replaced by an
unrestricted message variable.

`native_sort_fingerprint_substitution` proves that two globally sorted
assignments agreeing on every value-sort test preserve and reflect sorting
through every raw native template. Agreement on principal sorts suffices.
This concerns value sorting, not equality or preservation of solutions.
`QuerySortRequirementCases.lean` and `QueryPrincipalSortCases.lean` exercise
message-to-natural refinement, all five principal sorts, invalid natural sums,
Node beneath message functions and framing rejection as assignment values.
These characterization theorems supply the finite residual-sort choices used
by the full generator below; they do not generate a family by themselves.

### General sorted AC families

`nativeRawACSystemBindingFamily equations` and
`nativeSortedACSystemBindingFamily equations` return finite lists of finite
binding lists for any `NativeEquationSystem`. The latter interprets each list
with the existing first-binding, simultaneous `nativeBindingAssignment`.
Input terms may use the entire modeled frozen-index AST, including mixed sorts,
controlled-kind contexts and free framing. Assigned values must still satisfy
the five existing `NativeSortedValue` classes; framing and error-kind terms
are not new assignment-value sorts.

`QuerySourceTerms.lean` collects the original finite subterm table.
`QueryRawPlans.lean` enumerates bounded label words of exactly that table's
length. A consistent plan equates original equation roots and retains the
exact heads and ordered children of fixed nodes sharing a label.
Addition compiles to an auxiliary natural sum, not an ordered free constructor.
Every class is included in the proper-natural subsolver's explicit scope.
Rigid source nodes have separate frozen markers.

`QueryRawGeneration.lean` applies the actual complete natural-system generator
to each consistent plan. Marker rendering removes the current marker from
the available list before recursion, so it terminates by that list's length.
All markers, class words and original-variable bindings must render successfully.
The unconditional raw soundness theorem proves these bindings solve the
original equations; there is no output-equation validation filter.

`QuerySolutionLabels.lean` through `QueryRawRealization.lean` construct a
solution-derived finite class/atom model, apply actual natural-family
completeness and prove successful rendering. Every marker used in a parent's
child word has strictly smaller decoded function count. This proves rendering
completeness without assuming a topological ordering. Semantic source labels
are proved equivalent to an actually enumerated executable lookup table.
Classical quotient representatives are proof witnesses only.

Finite residual retyping enumerates all five principal-sort choices and
retains whole candidates whose binding values satisfy their required sorts.
Every sorted solution is represented by such a choice.
`QueryFreshGeneration.lean` proves that no variable in a generated binding
image has an original input index, regardless of sort.
`native_sorted_ac_system_family_complete` unconditionally proves
`NativeCompleteACSystemOn equations (nativeSystemVariables equations)` for
the actual generated binding assignments: every candidate is globally sorted
and solves every input equation, and every sorted solution factors through
one on the original input-variable scope with a globally sorted postfactor.
No supplied raw-completeness hypothesis or empty natural value is introduced.

`QueryGeneralCases.lean` checks that exact unrestricted contract, original
scope, sorted factors, fresh residuals and existence for controlled-kind/free
framing systems containing unary/binary/`kdf` constructors. Twelve executable
controls cover empty systems, literal `one`, frozen/variable index collisions,
Message/Fresh refinement with fresh shared residuals, Fresh/Public and
Message/Node incompatibility, fixed-head clashes, framing, proper cycles,
nonempty-semigroup rejection and AC versus six-rule equality.
Fresh strict Lean passes 453 audits (30 axiom-free, no `sorryAx`) and
39 case modules at that checkpoint; all 43 public equation-command fixture controls pass after
intended missing-report reds. Definitions-only modules compile without
requiring nonexistent theorem reports; all declared theorem audits remain mandatory.

This completes the modeled general sorted AC generation task. Enumeration is
finite but can be very expensive; no efficiency or irredundant/minimal-family
claim is established. This is not equality modulo the six rewrite equations,
native generator/importer correspondence, narrowing/FVP acceptance or runtime
validation. Real Tamarin/Maude source/export/replay/runtime work remains deferred,
with its default gates unchanged.

## Native finite variants

`QueryVariants.lean` proves the finite variant property for the guarded
six-rule relation on the full native query AST, modulo natural AC. It builds
variants directly in the sorted native algebra, so no narrowing-to-variant
lifting hypothesis is needed.

`nativeVariantSchemes term next` walks the term bottom-up. At each `fst`, `snd`,
`flip`, `sdec` or `kdec` node it either keeps the node or applies one rule
pattern, using fresh `Message` variables from `next` and recording the
matching equations. Other nodes are rebuilt from their children's schemes.
`nativeVariants term` starts above every input index (`nativeFreshBase`)
and attaches each scheme to the complete sorted AC-unifier family of its
equations, also including the term and scheme value.

| Theorem | Result |
| --- | --- |
| `native_variant_schemes_scope` | Scheme variables are input variables or fresh `Message` indices in `[next, after)`. |
| `native_variant_schemes_reach` | Any sorted solution of a scheme's equations rewrites the instantiated term to its value modulo AC. |
| `native_variant_schemes_cover` | For a sorted, normalized assignment, one scheme and an extension at fresh indices solve the equations. That extension's value is AC-equal to a normal form of the instance. |
| `native_finite_variants_sound` | Each listed variant has a sorted substitution and is reachable from the instantiated term. |
| `native_finite_variants_complete` | Every sorted, normalized instance is a sorted AC instance of a listed variant on the term's variables. That variant's normal form maps to the instance's normal form. |

As in Escobar-Meseguer variant semantics, completeness covers normalized
assignments. A variant's own instance is shown to be normal: a rewrite would
lift through the sorted factor and contradict AC invariance of normality.
All five audits depend only on `propext`, `Classical.choice` and `Quot.sound`.
`QueryVariantCases.lean` checks concrete scheme lists (`fst`, `snd ∘ fst`,
`flip`, `hash`, `sdec`) and both public theorem shapes.

The family is finite but unminimized and potentially large. This theorem is
about the Lean native query algebra. It does not prove correspondence with
Tamarin/Maude variant generation, the importer or native bookkeeping `NAT`, or
the full kind-completed carrier.

### Native variant differential

`QueryVariantExport.lean` renders 21 protocol-shaped queries to Maude syntax
and exports, per scheme, its value and exact `nativeVariantSystem`. The queries
cover single and nested destructors, nonlinear and already-reducible terms,
natural AC, `Pub` keys, `kdf`, list/`Node` framing and shared variables.
`termination.py --variant-export PATH` writes that output from the same build.
`variant_differential.py --export PATH` then compares it with the native proxy:

- Lean family F: each scheme value and the term's variables under every native
  AC `unify` solution of the scheme system;
- native family G: `get variants`;
- every G tuple must `match` some F tuple, and every reduced F tuple must
  `match` some G tuple;
- every F value must `reduce` like its unifier's term instance.

`scripts/check.sh` runs it after the Lean gate. `test_variant_differential.py`
checks the parsers and that a missing rule scheme or wrong value fails. This is
differential corpus evidence. Native AC unification stands in for the Lean
unifier family, and the check is not a proof of Maude's variant generator.

### Native module correspondence

`QueryModule.lean` defines the native Maude syntax of the query AST in Lean:
a renderer `nativeMaudeTerm`, a fuel-bounded parser `nativeMaudeParse` that
reads canonical decimals and right-nests flattened `tamtplus` sums, the six
rule templates and the module text `nativeMaudeModule`. Its audited theorems:

- `native_maude_parse_render`: parsing a rendered term returns it;
- `native_maude_term_injective`: distinct terms render differently;
- `native_rule_templates_sound`/`complete`: template instances are exactly
  the `NativePrimitiveRewrite` steps;
- `native_maude_function_heads_complete`: every unary/binary symbol, `kdf`,
  `roleA` and `roleB` is declared.

`QueryModuleExport.lean` prints `nativeMaudeModule` and then a syntax corpus.
`termination.py` requires the module text to equal `reviewed_module()` byte
for byte and the corpus to equal the committed
[`syntax_corpus.txt`](native-proxy/tests/syntax_corpus.txt). Its lines are:

- `ACCEPT` with the expected sort, variables and atoms of a rendered term
  (leaves of every sort, every head, nested sums, framing and both sides of
  every rule). The sort is the proper Maude sort, or else the controlled kind
  `KindNatural`, `KindMessage` or `KindFraming` of its `kindAbstraction`
  image, which reads `Fresh` as natural: `Fresh` operands of sums and every
  message/framing context above them;
- `REJECT` with rendered terms that have neither a sort nor a kind
  (message, `Pub`, `Node` or framing operands of sums; framing or `Node`
  beneath message functions);
- flattened n-ary sums as Maude prints them, `ACCEPT`ed with the sort or
  kind of the right-nested term the Lean parser reads, or `REJECT`ed when
  that term has neither (a `Msg`, `nil`, `Node` or message-function operand
  anywhere in the chain);
- `REJECT` with each single-character deletion that the Lean parser rejects;
  by the round-trip theorem none of them renders any query term;
- `EQUAL` or `DISTINCT` with two rendered or flattened terms, labelled by
  `nativeACEqual` (below): bracketings and orders of nine summand multisets in
  seven contexts, flattened texts against their canonical and shortened sums,
  and near misses (non-commutative `pair`, multiplicity, AC inside `tamXCh`).

The Rust unit test `recognizer_agrees_with_the_lean_syntax_corpus` requires
`syntax::term` to agree on every line. Accepting a leading-zero index, a
`Msg` sum operand or a `Node` message argument, or classifying `tamtplus` as
`Msg` or kind framing as `TOP`, fails it, as do accepting only binary sums
or checking only the first two sum operands. This is corpus evidence for the
Rust recognizer, not a proof.
Tamarin's Haskell importer remains trusted.

`QueryACCanonical.lean` defines an executable AC canonical form
`nativeACCanonical`: flatten each natural sum, sort the canonical summands by
rendering and right-nest them. Its audited theorems:

- `native_ac_canonical_related`: every term is AC-equal to its canonical form;
- `native_ac_canonical_iff`: `NativeQueryAC` holds exactly when canonical
  forms are equal;
- `native_ac_equal_iff`: the Boolean `nativeACEqual` decides `NativeQueryAC`.

The Rust unit test `certificate_agrees_with_the_lean_ac_corpus` requires the
guard's reply certificate to agree with every `EQUAL`/`DISTINCT` line; omitting
the summand sort or the flattening, or deduplicating summands, fails it.
This is corpus evidence for the Rust certificate, not a proof.

`QuerySyntacticUnification.lean` defines a fuelled sorted unifier
`nativeSyntacticUnify` and matcher `nativeSyntacticMatch` for systems whose
solutions need no natural-sum reasoning. Sort intersections in the native
lattice are one of their arguments or empty, so such a system has at most one
most general unifier and needs no fresh variables. Each returns `solved`,
`failed` or `unsupported` (fuel, a residual above 4096 nodes, a `tamtplus`
head or a sort refinement that would need a new variable). Its audited theorems:

- `native_syntactic_unify_spec`: `solved σ` is a complete singleton family and
  `failed` means no sorted AC unifier exists;
- `native_syntactic_match_solved`/`native_syntactic_match_failed`: `solved`
  is a sorted AC matcher and `failed` means none exists;
- `native_ac_instance_match_iff`: one assignment generalizes another exactly
  when the binding pairs have a matcher;
- `native_complete_family_cover_iff`: given a most general unifier, a sound
  family is complete exactly when one member generalizes it;
- `native_complete_empty_family_iff`: when no unifier exists, only the empty
  family is complete.

The export adds 751 `UNIFY`/`MATCH` lines with Lean's result and bindings. The
Rust unit test `unifier_and_matcher_agree_with_the_lean_corpus` requires
`native-proxy/src/unifier.rs` to reproduce every line; omitting the occurs
check, the sort check, the AC lookup for repeated pattern variables or the
head-clash failure fails it. This is corpus evidence for the Rust mirror, not
a proof. The Rust mirror also reports `unsupported` for terms or composed
bindings above 4096 nodes; `unsupported` makes no claim.

The source bridge trusts Tamarin's export, the reviewed signature/term translation
and their regressions. It is not a verified Tamarin/Maude importer, a proof of
native bookkeeping `NAT`, the entire kind-completed carrier or finite variants.
Convergence and boundedness are proved for the typed algebra; independent
structural results cover the guarded relation on the full frozen-index AST,
including controlled-kind and free framing contexts. Executed
native operations additionally require the boundary checks below; a universal
source-linked query-builder/importer proof remains unverified.
The Lean finite-variant theorem above is discharged for the native query
algebra. Correspondence with Tamarin/Maude sorted AC unification, backend
narrowing/variant generation and the importer is not discharged by this command.
The native guard checks the soundness of each returned `unify`/`match`
solution and, for queries the verified syntactic unifier decides, the
completeness of the family (below). Natural sums are decided by cancelling
AC-equal summands; completeness for queries the procedure leaves
`unsupported` stays trusted.

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
Each `unify` solution must make both sides of every equation AC-equal, and
each `match` solution must instantiate the pattern to an AC-equal copy of the
unchanged subject. Equality compares flattened, sorted sums, the procedure
`QueryACCanonical.lean` proves decides `NativeQueryAC`. A non-solution rejects
the entire reply.

The guard also runs the Lean-mirrored syntactic unifier or matcher.
Natural sums are flattened and AC-equal summands cancelled greedily: both
sides empty succeeds, one side empty fails, and a single remaining summand
on one side is unified with the rebuilt other side. Matching cancels only
variable-free pattern summands and never reverses the equation; any other
remainder is `unsupported`. If it returns `solved`, `No unifier.` or
`No match.` rejects the entire reply. For `unify`, some returned solution must
generalize the most general unifier: matching its bindings (generated
variables bindable) against the unifier's (original variables constant) must
not fail. By `native_complete_family_cover_iff` this decides completeness of
the already-certified family. `failed` needs no extra check: every returned
solution already fails the certificate. `unsupported` keeps family
completeness trusted.
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
The module text is now rendered by Lean and the Rust recognizer is checked
against a Lean corpus ([module correspondence](#native-module-correspondence)).
The Python module checker, pinned tool implementations and
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
and unchanged 43 rules/13 restrictions. With the partition audit these
contexts are accepted full-context certificate checking
([ADR 0017](../../../adr/0017-split-full-context-acceptance.md)), not a single
63-declaration process or a native FVP certificate.
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
Native FVP remained open at that checkpoint; see [Native finite variants](#native-finite-variants).
