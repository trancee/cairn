# Independent checkers for the ratchet equational theory's convergence/FVP

Status: **draft research** (investigation of the open independent-acceptance gate recorded in
[`ratchet-equation-evidence.md`](../spec/models/ratchet-equation-evidence.md) and the
[model README](../spec/models/README.md#evidence-index) row for the ratchet equation gate).
Scope is bounded to the exact equation theory in
[`ratchet.spthy`](../spec/models/ratchet.spthy) (`builtins: hashing, symmetric-encryption,
natural-numbers`; `functions: kdf/3, ext/2, mac/2, kem/2, kdec/2, pk/1, roleA/0, roleB/0, flip/1`;
`equations: kdec(kem(ss, pk(dk)), dk) = ss, flip(roleA) = roleB, flip(roleB) = roleA`) and to tool
applicability for checking convergence, confluence and the finite variant property (FVP) of that
theory as used by Tamarin 1.12.0. It does not touch protocol rules, lemmas, workflows or any other
doc, and does not re-litigate the equations themselves (see the linked evidence doc for that
argument).

No model equations, rules, source lemmas or workflows were changed; the evidence index and project
profile now link to this report. All commands below were actually run in this environment
(macOS/arm64, the repository's pinned `tamarin-prover 1.12.0` / `maude 3.5.1` from the
`tamarin-prover/tap` Homebrew tap); exact output is quoted or summarized with the command that
produced it so the result is reproducible.
Third-party tools fetched for this investigation (Maude Formal Environment, "Maude++") were
downloaded to `/tmp` only, are not part of the repository, and were not installed system-wide.

## 1. Summary

- Tamarin's own manual is internally split across two claims that together, and only together,
  describe the real guarantee: Tamarin does **not** decide the general convergent+FVP property
  (undecidable), but it **does** run an automated, decidable, sufficient check — "subterm
  convergence" — and warns if a user equation fails it
  ([`010_modeling-issues.md`](https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/manual/src/010_modeling-issues.md#L320-L341),
  commit `82780bbaf3328a45f624ddb41e51bf75425f851c` tagged `1.12.0`). Running the installed
  `tamarin-prover 1.12.0` binary against `ratchet.spthy` with `--quit-on-warning` confirms this
  check passes silently for the six message equations (three custom and three builtin pairing and
  symmetric-decryption equations; §2). This is a real, reproducible, built-in mechanical check —
  not independent, since it is the
  same tool whose soundness is in question, and not a complete FVP proof, since subterm convergence
  is only a sufficient condition.
- The closest **external, independent** tool is Maude's **Church-Rosser Checker (CRC)**, part of
  the Maude Formal Environment (MFE), which mechanically verified local confluence (plus
  sort-decreasingness) of the exact message-rewrite system Tamarin itself generates for
  `ratchet.spthy` — captured directly from a live `tamarin-prover` run via its `DEBUG_MAUDE`
  mechanism (§3). CRC is a genuine third-party, Maude-reflection-based prover, independent of
  Tamarin's own Haskell implementation.
- CRC has two hard limits that keep this from being a full, independent proof: (a) it explicitly
  **assumes termination** rather than proving it — the manual states the specification "is assumed
  terminating, a property for which the Maude Termination Tool (MTT) could be used"
  ([`crc3.pdf`](https://maude.lcc.uma.es/CRChC/files/crc3.pdf) §1.2) — and MTT is not available in
  the current MFE distribution (commented out of the tool list,
  [`maude-team/MFE` wiki](https://github.com/maude-team/MFE/wiki/Tools-available)); and (b) CRC
  rejects any module using Maude built-ins ("Built-in modules are not supported," `crc3.pdf` §1),
  so it cannot be run on Tamarin's literal dumped module, which `protecting NAT`s for internal
  index encoding (unrelated to the protocol's natural-numbers semantics) — it had to be run on a
  hand-reduced module with that internal encoding stripped (§3, limitation recorded there).
  Termination therefore still rests only on the hand argument already in
  `ratchet-equation-evidence.md`, now with CRC's confluence result as a second, differently-sourced
  data point rather than a replacement for it.
- No tool was found — in Maude core, MFE (SCC/CRC/ChC), or Tamarin itself — that decides the
  **finite variant property** in general; FVP decidability for arbitrary theories is open, and the
  only complete method found in the literature is the defining theorem of Comon-Lundh and Delaune,
  *The Finite Variant Property: How to Get Rid of Some Algebraic Properties*, RTA 2005 (the same
  paper Tamarin's manual cites, [`manual.bib`](https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/manual/src/manual.bib)
  entry `Comon-LundhD05`): subterm-convergent theories have FVP by construction, which is exactly
  the syntactic criterion Tamarin automates in its own warning. Maude's `get variants` command
  (core Maude, no extension needed) can be used to **sample** whether narrowing terminates on
  chosen terms, which is useful corroborating evidence but is explicitly not a proof for all terms
  (§4); it is the same class of check the existing equation-evidence doc already describes as
  "checking finitely many sample terms would not establish FVP for all terms."
- The natural-numbers builtin (`%+`/`%1`) contributes **zero equations** — in the Maude module
  Tamarin generates, `tamtplus` is declared `[comm assoc]` with no equations at all (§3) — so the
  open "mixed message/natural theory" combination question reduces to combining a (candidate)
  subterm-convergent/FVP message theory with a pure free-AC symbol carrying no rewrite rules. That
  is a strictly simpler setting than general modular combination of two equational theories with
  their own rewrite rules, but no primary source stating a general "FVP is preserved when combined
  disjointly with an equation-free AC symbol" theorem was located in the time available; this
  narrowing is reported as an observation, not a closed combination proof (see §5).
- **Recommendation:** the CRC confluence run in §3 is the strongest reproducible, independent,
  primary-sourced evidence currently available and is worth keeping as a second artifact next to
  the existing hand argument, with its exact scope and the module-reduction caveat stated plainly.
  It does not, by itself, let the model README's "Independent review open" line be closed: it adds
  independent confluence evidence for the reduced message rewrite system, but termination and the
  combination with the natural-numbers AC sort are still not independently verified, and FVP
  itself is still backed only by applying a cited theorem's syntactic criterion (automated by
  Tamarin, not by an external tool).

## 2. Tamarin 1.12.0's own automated subterm-convergence check

### 2.1 What the manual says, read together

Two passages of the Tamarin 1.12.0 manual (fetched at the `1.12.0` git tag,
`https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/manual/src/`) look contradictory in
isolation and are not:

- [`004_cryptographic-messages.md:96-100`](https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/manual/src/004_cryptographic-messages.md#L96-L100):
  "The symbolic proof search used by Tamarin supports a certain class of user-defined equations,
  namely *convergent* equational theories that have the *finite variant property*
  [@Comon-LundhD05]. Note that Tamarin does *not* check whether the given equations belong to this
  class, so writing equations outside this class can cause non-termination or incorrect results
  *without any warning*."
- [`010_modeling-issues.md:320-341`](https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/manual/src/010_modeling-issues.md#L320-L341)
  ("Subterm Convergence Warning"): "The equational theory used by Tamarin must always be convergent
  … and have the finite variant property. Tamarin verifies if the equational theory is subterm
  convergent. If it is subterm convergent, it is guaranteed to be convergent and to have the finite
  variant property. However, if it is not subterm convergent, it does not necessarily imply
  non-convergence; it only indicates a potential risk of non-convergence." It further defines the
  criterion: "An equation is subterm convergent if the right-hand side is a constant … or a subterm
  of the left-hand side," gives the counter-example `f(x) = g(x)`, and documents a `[convergent]`
  equation annotation to silence the warning for equations the user asserts (without tool proof) to
  be convergent/FVP anyway.
- [`014_limitations.md:5-8`](https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/manual/src/014_limitations.md#L5-L8):
  "Currently, apart from the builtins, only subterm-convergent theories are supported. The
  underlying verification problems are undecidable in general, so Tamarin is not guaranteed to
  terminate."

Read together: Tamarin does not decide the target property (convergent + FVP) in general — that is
undecidable — but it does implement and run, automatically, a decidable **sufficient** syntactic
condition (subterm convergence) and surfaces a warning when a user equation fails that specific
syntactic test. Passing the check does not retroactively prove the general property from first
principles independently of the cited theorem; it mechanically confirms the syntactic precondition
that the cited theorem (Comon-Lundh and Delaune, RTA 2005) attaches the property to.

### 2.2 Confirming the check exists and runs, and that it is silent for `ratchet.spthy`

The warning is implemented in `checkEquationsSubtermConvergence` in Tamarin's own wellformedness
checker (verified directly in the `1.12.0`-tagged source, cloned from
`https://github.com/tamarin-prover/tamarin-prover` at commit `82780bbaf3328a45f624ddb41e51bf75425f851c`):

```text
lib/theory/src/Theory/Tools/Wellformedness.hs:1222-1231
-- | Checks if all equations are subterm convergent.
checkEquationsSubtermConvergence :: OpenTranslatedTheory -> WfErrorReport
checkEquationsSubtermConvergence thy
  | null nonSubtermEquations = []
  | otherwise = [(topic, doc)]
  where
    equations = thyEquations thy
    nonSubtermEquations = filterNonSubtermCtxtRule equations
    topic = underlineTopic "Subterm Convergence Warning"
    doc = text "User-defined equations must be convergent and have the finite variant property. …"
```

`thyEquations` reads `stRules` off the theory's Maude signature, i.e. the check runs over the full
set of equations Tamarin hands to Maude (user equations plus activated builtin equations), not just
the three custom lines.

Tested directly in this environment: a minimal theory with the explicitly non-subterm-convergent
equation `f(x) = g(x)` (the manual's own counter-example) does trigger the warning under
`--quit-on-warning`:

```text
$ tamarin-prover /tmp/subterm_test.spthy --prove --quit-on-warning
…
Subterm Convergence Warning
===========================
  User-defined equations must be convergent and have the finite variant property. The following
  equations are not subterm convergent. …
    f(x) = g(x)
```

Run against the real model, the same check is silent — no Subterm Convergence Warning, and no other
wellformedness failure besides an expected, unrelated "no matching lemma" notice from using a
deliberately absent `--lemma` filter to stop before starting proof search:

```text
$ cd /Users/phil/Projects/cairn
$ tamarin-prover docs/spec/models/ratchet.spthy --open-chains=0 --saturation=0 \
    --derivcheck-timeout=0 --quit-on-warning --lemma=__nonexistent__
maude tool: 'maude'
 checking version: 3.5.1. OK.
 checking installation: OK.
[Theory CairnRatchet] Theory loaded
[Theory CairnRatchet] Theory translated
[Theory CairnRatchet] Theory closed
quit-on-warning mode selected - aborting on wellformedness errors.

WARNING: the following wellformedness checks failed!

Check presence of the --prove/--lemma arguments in theory
=========================================================
  --> '__nonexistent__' from arguments do(es) not correspond to a specified lemma in the theory
```

A second run with a real (slow) wellformedness pass (`--derivcheck-timeout=120`, letting
precomputation and all lemmas run) likewise produced no Subterm Convergence Warning anywhere in
its output before proceeding straight to lemma analysis. This corroborates — mechanically, using
Tamarin's own shipped check — the subterm-convergence argument `ratchet-equation-evidence.md`
already makes by hand for the six custom/builtin message equations. It is still the tool under
test checking itself, not an independent party, and it is a sufficient-condition check, not a
complete proof of FVP for the fully combined (message + AC natural-number) theory.

## 3. Independent confluence checking with Maude's Church-Rosser Checker (CRC)

### 3.1 Extracting Tamarin's exact Maude module

Tamarin's Haskell source starts a persistent Maude subprocess and feeds it a generated module; the
exact text sent is observable via an undocumented debug flag in
[`lib/term/src/Term/Maude/Process.hs:103-119`](https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/lib/term/src/Term/Maude/Process.hs#L103-L119)
(`DEBUG_MAUDE` environment variable, tees Maude's stdin/stdout to `/tmp/maude.input`/`.output`).
Running it against the repository's real model:

```text
$ cd /Users/phil/Projects/cairn
$ DEBUG_MAUDE=1 tamarin-prover --parse-only docs/spec/models/ratchet.spthy
$ cat /tmp/maude.input
```

produced the exact Maude functional module (`fmod MSG`) Tamarin builds for `ratchet.spthy`,
reproduced in full:

```maude
fmod MSG is
  protecting NAT .
  sort Pub Fresh Msg Node TamNat TOP .
  subsort Pub < Msg .
  subsort Fresh < Msg .
  subsort TamNat < Msg .
  subsort Msg < TOP .
  subsort Node < TOP .
  op f : Nat -> Fresh .
  op p : Nat -> Pub .
  op c : Nat -> Msg .
  op n : Nat -> Node .
  op t : Nat -> TamNat .
  op list : TOP -> TOP .
  op cons : TOP TOP -> TOP .
  op nil  : -> TOP .
  op tamXCtone : -> TamNat .
  op tamtplus : TamNat TamNat -> TamNat [comm assoc] .
  op tamXCext : Msg Msg  -> Msg .
  op tamXCflip : Msg  -> Msg .
  op tamXCfst : Msg  -> Msg .
  op tamXCh : Msg  -> Msg .
  op tamXCkdec : Msg Msg  -> Msg .
  op tamXCkdf : Msg Msg Msg  -> Msg .
  op tamXCkem : Msg Msg  -> Msg .
  op tamXCmac : Msg Msg  -> Msg .
  op tamXCpair : Msg Msg  -> Msg .
  op tamXCpk : Msg  -> Msg .
  op tamXCroleA :  -> Msg .
  op tamXCroleB :  -> Msg .
  op tamXCsdec : Msg Msg  -> Msg .
  op tamXCsenc : Msg Msg  -> Msg .
  op tamXCsnd : Msg  -> Msg .
  eq tamXCflip(tamXCroleA) = tamXCroleB [variant] .
  eq tamXCflip(tamXCroleB) = tamXCroleA [variant] .
  eq tamXCfst(tamXCpair(x0:Msg,x1:Msg)) = x0:Msg [variant] .
  eq tamXCkdec(tamXCkem(x0:Msg,tamXCpk(x1:Msg)),x1:Msg) = x0:Msg [variant] .
  eq tamXCsdec(tamXCsenc(x0:Msg,x1:Msg),x1:Msg) = x0:Msg [variant] .
  eq tamXCsnd(tamXCpair(x0:Msg,x1:Msg)) = x1:Msg [variant] .
endfm
```

Two structural facts fall directly out of this, with no interpretation needed: (1) there are
exactly six equations — the three custom equations plus the three builtin pairing/`sdec` equations
— matching the signature stated in the task and in `ratchet-equation-evidence.md`; (2) the
natural-numbers AC operator `tamtplus` carries **no equations at all**, only the `[comm assoc]`
attribute. Tamarin's natural-numbers builtin is a pure free-AC symbol generated by `%1`
(consistent with the manual's own description in
[`004_cryptographic-messages.md`](https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/manual/src/004_cryptographic-messages.md):
"this guarantees that any term of sort `nat` is essentially a sum of `%1`"), not a rewrite system
that could conflict with the message equations.

### 3.2 Running Maude's Church-Rosser Checker

The Church-Rosser Checker (CRC) and Coherence Checker (ChC) are Maude-reflection-based tools
distributed as part of the **Maude Formal Environment (MFE)**, `https://github.com/maude-team/MFE`
(wiki: `https://github.com/maude-team/MFE/wiki`). Per the tool's own manual
(Durán and Meseguer, *CRC 3: A Church-Rosser Checker Tool for Conditional Order-Sorted Equational
Maude Specifications*, `https://maude.lcc.uma.es/CRChC/files/crc3.pdf`, fetched and text-extracted
in this investigation): "CRC is a tool to help checking whether a (possibly conditional)
order-sorted equational specification satisfies the Church-Rosser property modulo any combination
of associativity, and/or commutativity, and/or identity axioms" — i.e. AC operators like Tamarin's
`tamtplus` are within its stated scope, unlike plain unsorted confluence checkers.

CRC requires the "Maude++" extended Maude build (Full Maude plus CRC/ChC/SCC), release-tagged to
match the exact Maude version Tamarin 1.12.0 depends on:
`https://github.com/maude-team/MFE/releases/tag/mfe-3.5.1` (asset `MFE.zip`, SHA-256
`3e9907754bd4d87e3a01c2a69d4aaf5f6bc9d201e7a0bd9f1262280418cc0c22`, matching the GitHub Releases
API's recorded digest — verified by direct re-hash in this environment) and the darwin-arm64
Maude++ binary at `https://maude.ucm.es/strategies/maudext/maude++-3.5.1-darwin-arm64.tar.xz`.
**Provenance caveat:** Maude++ is a third-party, community-maintained extension of official Maude
built by R. Rubio (UCM), not SRI's official Maude distribution
(`https://github.com/maude-team/MFE/wiki/How-to-install-the-tool`: "The extended version is
compiled by R. Rubio (@ningit) from UCM, and extends the official distribution of Maude with the
CETA library"). `maude++ --version` reports `3.5.1`, matching the repository's pinned Maude
dependency, but this binary was downloaded fresh to `/tmp` for this investigation, is not
vendored or pinned in the repository, and was not independently audited beyond the checksum match
above; a reader who wants to rely on this result should treat the binary as a research tool, not a
trusted build dependency, and ideally build MFE from source against the already-trusted `maude`
binary already in the repository's toolchain. CRC and ChC themselves are documented to work with
plain official Maude too (same wiki page: "On the official version, CRC and ChC are still fully
operational"); only the Sufficient Completeness Checker (SCC) needs the Maude++ extension.

**Setup was verified against the tool's own documented example first** (MFE wiki,
`How-to-use-the-tool.md`, the commutative `MYNAT1` example with a non-joining critical pair), to
confirm the tool chain is working as documented before trusting any result on the ratchet theory.
The reproduction matched the documented output exactly:

```text
$ ./maude MFE/MFE/src/mfe.maude <<< '
set include BOOL off .
fmod MYNAT1 is … endfm
select tool CRC .
ccr MYNAT1 .'
…
Church-Rosser check for MYNAT1
The following critical pairs must be proved joinable:
  cp MYNAT14
    s (N:MyNat + (#2:MyNat + (N:MyNat * #2:MyNat )))
    = s (#2:MyNat + (N:MyNat + (N:MyNat * #2:MyNat ))).
The module is sort-decreasing.
```

**CRC rejects Tamarin's literal dumped module** because of its `protecting NAT .` line: CRC's own
manual states plainly (`crc3.pdf` §1, restrictions list): "Built-in modules are not supported, and
built-in operations such as, e.g., `_==_` and `_=/=_` in the `BOOL` predefined module are not
allowed." Feeding the exact module from §3.1 verbatim produces:

```text
MFE> Error: The use of built-ins is not supported by the checker.
```

`protecting NAT` in Tamarin's module is used only to index internal constants (`f : Nat -> Fresh`,
`p : Nat -> Pub`, etc. — Tamarin's own term representation for fresh/public-name counters), and is
unrelated to the protocol's `natural-numbers` equational theory (which, as shown in §3.1, carries
no equations to check). It was therefore removed, along with the then-unused `Nat`-indexed
operators and sorts, producing a CRC-admissible module with the identical message equations,
identical signature shape, and the same AC `tamtplus` declaration:

```maude
fmod MSG is
  sort Msg TamNat .
  subsort TamNat < Msg .
  op tamXCtone : -> TamNat .
  op tamtplus : TamNat TamNat -> TamNat [comm assoc] .
  op tamXCext : Msg Msg -> Msg .
  op tamXCflip : Msg -> Msg .
  op tamXCfst : Msg -> Msg .
  op tamXCh : Msg -> Msg .
  op tamXCkdec : Msg Msg -> Msg .
  op tamXCkdf : Msg Msg Msg -> Msg .
  op tamXCkem : Msg Msg -> Msg .
  op tamXCmac : Msg Msg -> Msg .
  op tamXCpair : Msg Msg -> Msg .
  op tamXCpk : Msg -> Msg .
  op tamXCroleA : -> Msg .
  op tamXCroleB : -> Msg .
  op tamXCsdec : Msg Msg -> Msg .
  op tamXCsenc : Msg Msg -> Msg .
  op tamXCsnd : Msg -> Msg .
  vars x0 x1 : Msg .
  eq tamXCflip(tamXCroleA) = tamXCroleB .
  eq tamXCflip(tamXCroleB) = tamXCroleA .
  eq tamXCfst(tamXCpair(x0,x1)) = x0 .
  eq tamXCkdec(tamXCkem(x0,tamXCpk(x1)),x1) = x0 .
  eq tamXCsdec(tamXCsenc(x0,x1),x1) = x0 .
  eq tamXCsnd(tamXCpair(x0,x1)) = x1 .
endfm
```

(The `[variant]` equation attribute, a Maude/Tamarin-specific marker for narrowing-eligible
equations unrelated to confluence checking, was also dropped; it is not part of CRC's input
language and carries no information CRC uses.)

Running `ccr` (Church-Rosser check) on this module:

```text
$ ./maude MFE/MFE/src/mfe.maude <<< '
set include BOOL off .
fmod MSG is … endfm
select tool CRC .
ccr MSG .'
…
Church-Rosser check for MSG
All critical pairs have been joined.
The specification is locally-confluent.
The module is sort-decreasing.
```

**This is the strongest independent, reproducible, tool-based result obtained in this
investigation:** a genuinely separate implementation (Maude's reflective CRC tool, written and
maintained independently of Tamarin's Haskell codebase) mechanically computed all critical pairs of
the exact six message equations Tamarin uses — including the AC combination via `tamtplus`, within
CRC's documented scope of "any combination of associativity, and/or commutativity, and/or identity
axioms" — and confirmed they all join, i.e. the equations are locally confluent (and
sort-decreasing, meaning no sort annotation is lost along either joining path). Given termination
(established separately, see §3.3), local confluence plus termination gives confluence (the
Church-Rosser property) by Newman's lemma — but CRC's "Church-Rosser check" result already folds in
that standard final step for a terminating system, which is exactly why it both assumes termination
and reports "locally-confluent" as its finding (see crc3.pdf §2.1-2.3 for the precise formal
definitions CRC implements, not reproduced here in full).

### 3.3 What CRC does not establish: termination

CRC's own manual states the limitation directly (`crc3.pdf`, Introduction, restriction list):
"the specification is assumed terminating, a property for which the Maude Termination Tool (MTT)
could be used." MTT is not available to independently discharge this assumption here: the current
MFE release's tool list comments MTT out entirely
(`https://github.com/maude-team/MFE/wiki/Tools-available`: "Three tools are available from the
latest MFE's version … <!-- the Maude Termination Tool (MTT) -->", i.e. commented out of the active
list), and no working MTT distribution or back-end termination tool (AProVE, CiME, muTerm) was
installed or located in this environment. Termination of the six message rewrites therefore still
rests entirely on the hand-constructed decreasing measure (function-symbol-occurrence count)
already given in `ratchet-equation-evidence.md`; CRC's confluence result is additive evidence, not
a replacement for that argument, and the combined "Church-Rosser" framing in §3.2's CRC output
should be read as conditional on that externally-supplied termination argument, exactly as CRC's
own documentation requires.

## 4. Maude's variant-generation commands as empirical samples, not an FVP decision procedure

Maude core (the same `maude 3.5.1` binary Tamarin already depends on, no extension needed)
implements `get variants`, which computes the finite or infinite set of most-general variants of a
term under the module's equations. Run directly against the reduced message theory from §3.2 (core
Maude, not MFE):

```text
$ maude /tmp/variant_test.maude
get variants in MSG : tamXCkdec(X:Msg, Y:Msg) .
Variant 1: tamXCkdec(#1:Msg, #2:Msg)
Variant 2: %1:Msg   [X:Msg --> tamXCkem(%1:Msg, tamXCpk(%2:Msg)), Y:Msg --> %2:Msg]
No more variants.

get variants in MSG : tamXCsdec(tamXCsenc(X:Msg, Y:Msg), Z:Msg) .
Variant 1: tamXCsdec(tamXCsenc(#1:Msg, #2:Msg), #3:Msg)
Variant 2: %1:Msg   [X:Msg --> %1:Msg, Y:Msg --> %2:Msg, Z:Msg --> %2:Msg]
No more variants.

get variants in MSG : tamXCfst(tamXCsnd(tamXCpair(X:Msg, tamXCpair(Y:Msg, Z:Msg)))) .
Variant 1: #2:Msg
No more variants.
```

Each sampled term's variant search terminates quickly (0-2 rewrite steps), which is consistent
with — but does not prove — FVP for the full theory. This is exactly the limitation the existing
`ratchet-equation-evidence.md` already names: "checking finitely many sample terms would not
establish FVP for all terms." No Maude command, built-in or MFE-provided, decides FVP for a
*generic* term with variables in general; `get variants` is documented and used in the
primary-source literature as the mechanism whose *termination on all terms* is the definition of
FVP, not as a checker that can certify that termination holds universally. No primary source found
in this investigation (Maude's own CRC/ChC/SCC tool set, or the Comon-Lundh/Delaune paper itself)
describes a complete, general decision procedure for FVP; this matches Tamarin's own framing that
the underlying verification problem is undecidable in general
(`014_limitations.md`, quoted in §2.1).

## 5. Combination boundary: message theory versus the natural-numbers AC sort

As shown directly in the dumped Maude module (§3.1), Tamarin's `natural-numbers` builtin contributes
only the free-AC operator `tamtplus`/`%1` with **no equations** — there is nothing for the message
rewrite rules to interact with at the equation level, and the AC interaction is already inside
CRC's checked scope (`[comm assoc]` is part of the module CRC accepted and confirmed locally
confluent). This narrows, but does not close, the "mixed message/natural theory" combination
question `ratchet-equation-evidence.md` leaves open: disjoint-signature combination of a
(candidate) subterm-convergent/FVP theory with an equation-free AC symbol is a simpler case than
general modular combination of two theories that each have their own rewrite rules, because there
is only one side with rewriting to reason about. No primary source was located in the time
available for this investigation (search terms tried included the Comon-Lundh/Delaune paper's own
citations and follow-on Maude variant-combination literature by Escobar, Meseguer and Sasse) that
states a named theorem of the form "FVP is preserved under disjoint combination with an
equation-free AC symbol"; this is reported as an observation about the specific signature, not as
an independently verified combination theorem. The existing document's framing — "Tamarin's sorted
AC unification/variant backend and its supported combination remain part of the trusted tool
boundary" — remains accurate and unweakened by this investigation.

## 6. What would close the gap, and what is not recommended

- **Recommended, reproducible, low-cost:** keep both results from this investigation as
  supplementary, explicitly-scoped evidence: (1) Tamarin's own silent subterm-convergence check on
  `ratchet.spthy` (§2.2, reproducible with the repository's existing pinned toolchain, no new
  dependency); (2) the external CRC confluence result on the hand-reduced message module (§3.2,
  reproducible with the downloaded MFE/Maude++ artifacts, which are not part of the trusted
  toolchain and were used here only as a research probe). Neither should be represented as closing
  the "Independent review open" line in the model README: (1) is not independent of Tamarin, and
  (2) is independent but covers confluence only, assumes termination, required module reduction
  outside CRC's accepted input language, and does not address FVP directly (only the same
  sufficient condition already used elsewhere).
- **Not recommended as a drop-in dependency:** adding the Maude++ / MFE toolchain to the
  repository's CI or developer setup. It is a third-party research extension (§3.2 provenance
  caveat), its MTT component (the one piece that could discharge CRC's termination assumption) is
  unavailable in the current release, and running it required hand-reducing Tamarin's generated
  module outside the normal Tamarin workflow — there is no single command that runs CRC against an
  arbitrary `.spthy` file unmodified.
- **Not found and not claimed:** an authoritative, complete, independent FVP checker or a published
  theorem that certifies FVP for this exact combined (message + natural-numbers) theory beyond the
  subterm-convergence criterion both Tamarin and this investigation already apply. No independent
  expert review of these equations is claimed by this document; none was sought or obtained.

## Sources consulted

- Tamarin-prover GitHub repository, tag `1.12.0` (commit `82780bbaf3328a45f624ddb41e51bf75425f851c`),
  cloned read-only to `/tmp/tamarin-prover` for source inspection: manual chapters
  `004_cryptographic-messages.md`, `010_modeling-issues.md`, `014_limitations.md`, `manual.bib`;
  source files `lib/theory/src/Theory/Tools/Wellformedness.hs`,
  `lib/term/src/Term/Maude/Process.hs`, `lib/term/src/Term/Narrowing/Variants/Check.hs`.
  `https://github.com/tamarin-prover/tamarin-prover`
- Installed `tamarin-prover 1.12.0` / `maude 3.5.1` from the `tamarin-prover/tap` Homebrew tap
  (the repository's own pinned toolchain per `docs/spec/models/README.md#tooling`); all commands
  in §2-§4 were executed against these exact binaries unless stated otherwise.
- Maude Formal Environment (MFE), `https://github.com/maude-team/MFE` and its wiki
  (`Tools-available.md`, `How-to-install-the-tool.md`, `How-to-use-the-tool.md`), release
  `mfe-3.5.1` (`MFE.zip`, SHA-256 `3e9907754bd4d87e3a01c2a69d4aaf5f6bc9d201e7a0bd9f1262280418cc0c22`,
  verified against the GitHub Releases API digest).
- "Maude++" extended Maude 3.5.1 darwin-arm64 build,
  `https://maude.ucm.es/strategies/maudext/maude++-3.5.1-darwin-arm64.tar.xz` (third-party,
  R. Rubio/UCM; provenance caveat in §3.2).
- Francisco Durán and José Meseguer, *CRC 3: A Church-Rosser Checker Tool for Conditional
  Order-Sorted Equational Maude Specifications*, `https://maude.lcc.uma.es/CRChC/files/crc3.pdf`
  (fetched and text-extracted in this investigation).
- CRC/ChC tool page, `https://maude.lcc.uma.es/CRChC/` (command reference and worked example used
  to validate the local setup in §3.2).
- Hubert Comon-Lundh and Stéphanie Delaune, *The Finite Variant Property: How to Get Rid of Some
  Algebraic Properties*, RTA 2005, pp. 294-307 (cited via Tamarin's own `manual.bib`
  `Comon-LundhD05` entry; the paper itself was not independently re-fetched beyond this citation
  record).
- [`ratchet.spthy`](../spec/models/ratchet.spthy),
  [`ratchet-equation-evidence.md`](../spec/models/ratchet-equation-evidence.md) and
  [`docs/spec/models/README.md`](../spec/models/README.md) (repository sources defining the exact
  theory and the existing evidence this investigation supplements).
