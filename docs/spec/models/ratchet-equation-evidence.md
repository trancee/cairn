# Why the ratchet equations fit the symbolic model

Mathematical review of the default
[`ratchet.spthy`](ratchet.spthy) equation set, observed on 2026-10-09.
The `2026-10-14` [source-guarded Lean termination subgate](equations/README.md)
now kernel-checks the termination argument below, including sorted natural AC.
Confluence/FVP arguments and the overall independent-acceptance gate remain
separate; this is not a kernel-checked combined convergence/FVP certificate.

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

## Confluence argument and repeated-key caveat

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
Together with termination, this gives a local-peak/confluence argument
for the six ordinary message rewrite rules. It needs review as an argument,
not a claimed output of an automated critical-pair checker.

## Finite-variant rationale

The KEM equation has the same term-rewrite shape as Tamarin's documented
asymmetric-decryption rule
`adec(aenc(m,pk(sk)),sk)=m`, with renamed encryption/decryption symbols.
The repeated-key constraint is therefore not a novel algebraic operation.
The other collapsing rules are documented builtin equations. The two
role rules have finite ground left sides and ground normal right sides;
they cannot produce another role-redex.

For normalized substitutions over free message constructors, the
subterm/ground shape bounds useful narrowing at a fixed term's
non-variable positions. Collapsing steps remove existing structure,
and role steps have two finite root alternatives. Reductions internal
to a substitution are accounted for by normalization rather than an
unbounded family of new message equations. This is the subterm-convergent
FVP rationale; checking finitely many sample terms would not establish
FVP for all terms.

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
These do not yet prove admissibility/coherence or conservative correspondence
between the protocol algebra, the native bookkeeping signature and the paper's
sort/kind assumptions. Full FVP acceptance remains open.

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
