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
- generates and kernel-checks a certificate translating every source equation
  to its exact `PrimitiveRewrite` constructor.

Exit `0` means all typed subgates passed. Exit `1` reports `FAIL:` for
a missing/malformed toolchain pin, unreviewed/malformed source, unsupported tools,
a failed native command, missing/duplicate theorem reports or unexpected axioms. Native commands retain
the existing `120`-second bound; version checks use `30` seconds.
Invalid command-line syntax uses argparse's exit `2`; `--help` exits `0` without
checking a proof.
Only `propext`, `Classical.choice` and `Quot.sound` are permitted by the shared
axiom audit. Eighteen of the 53 audited theorems use no axioms. The uniform
normalization-bound theorem uses all three permitted axioms; the other
non-constructive audits use at most `propext` and `Quot.sound`.
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

The source bridge trusts Tamarin's export, the reviewed signature/term translation
and their regressions. It is not a verified Tamarin/Maude importer, a proof of
native bookkeeping `NAT`, backend kind-completed terms or finite variants.
Convergence and boundedness are proved for the typed algebra, with algebraic
correspondence to the candidate structural message/natural image. Executed
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

The executable `maude_boundary.py` requires Maude `3.5.1`, the pinned five
interactive flags, the three standard setup commands and the entire exact
native module derived from the shared 15-function/six-equation inventory.
It accepts only `reduce`, `unify in MSG`, `match in MSG` and
`get variants in MSG`. Terms must inhabit the proper message/natural/Node/free
framing image; atom indices must be canonical closed decimals.
Bookkeeping `Nat`, `TOP` and kind variables, imported arithmetic, unreviewed
constructors and framing beneath message functions are rejected.
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
attestation against a malicious proof executable.

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
The published termination checkpoint passed hosted CI at `70c1c19`; this
convergence/image addition is local and unpublished at authoring. No hosted acceptance
of the addition is claimed.

Native boundary reds cover wrong query/reply sorts, altered equations, absent
evidence, duplicate fields hiding failure, non-ASCII query syntax, blocking FIFO
reports, incompatible/conflated variable namespaces, missing per-stream version
evidence and ignored shutdown diagnostics. Maintained tests also reject an
entire reply with a bad later solution without forwarding its earlier valid
solution, and reject truncated EOF. Real Maude tests cover all four operations;
a tiny exact-signature Tamarin normalization witness exercises actual guarded
proof/precomputation streams and the source-linked installation check.

Local parse comparison on Apple silicon/macOS `27.0.1`, `8` GiB RAM, with pinned
Tamarin/Maude, used three alternating baseline/guarded pairs at the existing
`120`-second deadline. Inputs were unchanged from committed `70c1c19`.
`replay.run(["tamarin-prover", "--parse-only", <absolute ratchet.spthy>], 120)`
was compared with `run_guarded_tamarin` on the identical command. Median times
were `1.393`/`1.442` seconds (`+3.5%`), with byte-identical exports at the SHA above.
This measures parsing only, not precomputation/full replay or memory overhead.
