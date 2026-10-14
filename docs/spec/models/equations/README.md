# Equation termination checker

Reference for the source-guarded termination subgate. This does **not** close
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

- reads Tamarin's current canonical default export;
- requires the exact 15 message-function ranks, six equations and sole
  `natural-numbers` builtin;
- kernel-checks `Termination.lean` and audits all six required theorem reports;
- generates and kernel-checks a certificate translating every source equation
  to its exact `PrimitiveRewrite` constructor.

Exit `0` means this termination subgate passed. Exit `1` reports `FAIL:` for
a missing/malformed toolchain pin, unreviewed/malformed source, unsupported tools,
a failed native command, missing/duplicate theorem reports or unexpected axioms. Native commands retain
the existing `120`-second bound; version checks use `30` seconds.
Invalid command-line syntax uses argparse's exit `2`; `--help` exits `0` without
checking a proof.
Only `propext`, `Classical.choice` and `Quot.sound` are permitted by the shared
axiom audit. In the observed build the six theorems use `propext` and `Quot.sound`,
not `sorryAx` or any user-added axiom.

Successful output includes the canonical source SHA-256, all required axiom
reports and an explicit termination-only scope statement.

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

The source bridge trusts Tamarin's export, the reviewed signature/term translation
and their regressions. It is not a verified Tamarin/Maude importer, a proof of
native bookkeeping `NAT`, confluence, AC coherence or finite variants.

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
Hosted validation was pending when this snapshot was written; the published
revision's PR/CI records subsequent acceptance separately.
