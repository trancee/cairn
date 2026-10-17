# Proof environment

Facts that no config file states. Read before running Tamarin, replay or `act`.

## Host

- Apple silicon macOS, 8 GiB RAM. Tamarin on `ratchet.spthy` can exceed 7 GiB.
- Tools: Tamarin 1.12.0, Maude 3.5.1, Lean 4.34.1 (pinned in `lifecycle/lean-toolchain`).
- The maintained host guard uses the root Rust `1.99.0` pin; final local
  measurements use Python `3.14.8` (CI pins `3.13.16`).
- Lean is not on `PATH`; pass it with `LEAN=<path>/bin/lean scripts/check.sh` or `check.py --lean`.
- `scripts/check.sh` also invokes the [equation convergence/boundedness checker](equations/README.md)
  with that Lean executable. It proves termination, B-coherence, confluence
  modulo natural AC and substitution-independent normalization boundedness
  for the six source equations in the typed algebra. It also checks structural
  frozen-index encoding round trips, independent raw AC/rewrite correspondence
  and typed substitution commutation, including free tuple/Node framing closure
  and controlled Fresh/natural derivation-kind abstraction (201 audits,
  28 axiom-free, none using `sorryAx`).
  An independently guarded native-sorted relation inherits proper-message
  termination, B-coherence, convergence modulo AC and the template-only bound.
  Controlled-kind framing closure and decoded-kind termination also hold.
  A separate structural bound covers the frozen-index native AST, including
  error-kind/framing contexts, given normalized variable assignments. It does
  not prove sort/image closure for arbitrary assignments.
  Exact guarded matching decoding, structural peak joining and a decreasing
  context count now establish matching termination/confluence on the entire
  frozen-index AST. Bidirectional structural AC transport also proves guarded
  quotient termination, confluence and normal-form uniqueness modulo AC,
  including controlled-kind/free framing. The full imported NAT/kind-variable
  carrier and native unification/narrowing completeness remain unproved.
  Sort-respecting native assignments have a complete typed representation and
  preserve guarded rewrites/counted paths. Their abstract assignments are
  sorted, deriving the compatible typed shadow needed for controlled-kind
  framing substitution closure. This is mathematical closure, not a verified
  runtime classifier/importer or normality-preservation theorem.
  Sorted assignments compose, preserve AC-unifier solutions and exactly
  transport proper message/natural solutions to/from the typed algebra.
  Kind solutions require compatible shadows; unrestricted natural shadows
  have cross-sort false positives. Sorted postfactor instantiation now uses
  only input-query variables and forms a preorder. Typed composition and
  all-five-sort pointwise equality/AC preserve and reflect factorization.
  Given a family on proper message/natural inputs, completeness and singleton
  most-generality transfer in both directions. This neither constructs a
  finite complete generator nor transfers arbitrary kind-shadow families.
  Every sorted solution has a finite binding-list representative agreeing
  exactly on input variables. Finite postfactors need only variables in scoped
  candidate values, not merely input variables. Completeness/most-generality
  can quantify over input-supported finite solutions without loss; restricting
  an existing family's candidates retains an explicit original-sortedness
  premise. This finite mathematical representation neither generates a family
  nor changes native lookup/duplicate policy. Kind abstraction now has a
  constructive assignment inverse and exact composition/input-support laws.
  Admissibility requires a sorted expanded assignment and exact reabstraction;
  both candidate solutions and postfactors retain that constraint. Scoped
  factorization, completeness and most-generality preserve/reflect between
  originals and admissible kind shadows. Unrestricted sorted shadow factors
  can still map Fresh residuals to `one` and are not covered. This is a
  mathematical constraint, not an executable validator or native filtering.
  Proper finite-AST occurrence strictly increases substituted function count,
  excluding AC unifiers and constructing complete empty families. An
  occurs-free sort-compatible binding is finite, supported, idempotent and
  most general in either orientation. A proof-carrying variable-equation
  solver now generates complete explicit binding-list families for identity,
  proper cycles and occurs-free bindings. Incompatible orientations are outside
  that solver's domain, not unsatisfiable; a reversed message binding can work.
  This is not general sorted AC generation or native occurs-check verification.
  Pure AC rejection also does not reject equality modulo the source equations.
  Finite equation systems now have sorted solution and explicitly scoped
  complete-family predicates. Variable elimination propagates its binding
  through all remaining pairs and lifts supplied residual complete families,
  retaining variables in prefix values even when no equation remains.
  Explicit finite binding composition substitutes second-list values into
  first-list values before appending the second list, preserving first lookup.
  Empty/reflexive systems, reversed orientations and proper-cycle rejection
  retain their scope. This is conditional system composition, not a general
  solver, constructor decomposition or sorted natural-AC generation.
  Runtime finite-support/native
  occurs-check/fresh-name correspondence, narrowing and
  native algorithm/importer correctness remain unproved.
  Ratchet acceptance callers additionally enforce the approved
  [native stream boundary](equations/README.md#native-stream-boundary):
  pinned module, proper/controlled-kind queries, proper returned bindings/results,
  frozen indices and complete private
  lifecycle evidence. Whole unsupported operations fail, without filtering
  solutions. Universal query-builder/importer correctness, complete sorted
  unification and narrowing correspondence remain unverified; this is not
  complete native query-image transfer or combined-theory/FVP acceptance.

## Commands

- Ratchet runners supply `--with-maude` automatically. Do not override it.
  Proof deadlines/options remain unchanged; native/outer teardown uses the
  `5`-second grace. Direct interactive branch work remains exploratory, not
  acceptance evidence. Resume/SAS operations do not use the ratchet-only guard.
- The pinned derivation checker changes natural variables to Fresh inside
  premise constructors. Keep these controlled kind queries supported; do not
  skip derivation checks or admit arbitrary natural-sum operands/kind variables.
- The [native guard](equations/native-proxy/README.md) is now the shared ratchet
  default after accepted native staging at `71168a1`:
  all 19 cells pass, full export `+9.6594%`, startup `+15.871115` ms.
  Resolve `$CARGO_TARGET_DIR/release/cairn-maude-proxy`, or root
  `target/native-proxy/release/cairn-maude-proxy` when unset. Relative targets
  follow Cargo's working directory; an explicitly empty target rejects.
  Build first using the reference or `scripts/check.sh`; proof commands never
  build automatically. Missing/non-executable/stale builds reject, with no
  Python fallback or temporary selector. Every version requires current source ID.
  The historical Python `+22.5%` path is deleted.
- Budgets remain three alternating pairs, six identical fixed-digest exports,
  full export at most `+10%`, startup at most `+50` ms. Current default-source
  local overhead is `+6.1498%` and `+41.960417` ms (`+37.3660%`), respectively.
  At `2fa6d16`, actual native budgets also pass: `+8.3650%` full export,
  `+25.785370` ms (`+20.7876%`) startup. Its lifecycle cell and 17/18 callers
  pass; `initial_ck_secret` fails its unchanged strict `60`-second derivation
  check during assembled export, before its selected proof. The exact local
  caller passes, not establishing a native fix. Retain that failure and require
  all current-head hosted gates; preceding staging evidence is not a substitute.
  Measured raw combined stdout and
  `1` ms final-evidence polling retain every check/event and the `5`-second grace.
  Passing proof deadlines alone is not performance acceptance.
  The existing 19-cell workflow builds once per cell with the shared Cargo
  target and retains all caller/static/stream/kernel/budget gates, without
  extra jobs or larger deadlines. The owner authorized this conditional
  cutover and promotion commits/pushes/PR updates. Do not start Colima,
  manually dispatch, merge or activate SDK/profile behavior under that approval.
  Full assembled, full-proof/memory and native FVP acceptance remain separate.
- Benchmark reports now include per-sample waited-child user/system CPU seconds
  and voluntary/involuntary context-switch deltas. Collection is outside wall
  timing; the existing `10%`/`50` ms gates and three-pair method are unchanged.
  The counters cover only reaped children and descendants whose intervening
  parents waited; they are not whole-host or per-guard attribution.
  Legacy reports may omit diagnostics, but malformed present diagnostics fail.
  The `8c54f2b` full-export failure (`+16.576923%`) remains a real blocker.
  Local diagnostic reports pass (`+6.154029%`, `+36.256333` ms), not a Linux
  reproduction, performance fix or later-head hosted acceptance.
- `--profile-tamarin` enables only a one-pair full-export screening, adding
  numeric final RTS allocation/MUT/GC/task/capability evidence and rejecting
  nonempty `GHCRTS`. It can accompany `--profile-linux`; neither profile can
  establish budget acceptance. `--profile-native` additionally records bounded
  numeric native-phase CPU/wall counters and main-driver-thread CPU on 64-bit
  native Linux. It retains complete validation, a source-identified rebuild,
  owned private reports and diagnostic-only rejection. Inherited nonempty
  `CAIRN_MAUDE_PHASE_REPORT` rejects rather than silently enabling profiling.
  The existing Linux CLI profile test reuses its one pair with all three flags.
  The core CI budget step remains unprofiled; only
  its failure can enable a separate RTS/process/phase/driver CPU pair, with sufficient remaining
  time and unchanged job ceiling. A seven-day failure artifact preserves the
  original report and explicit capture/skip/failure status.
  See the [reference](equations/native-proxy/README.md#failure-only-ci-capture).
- Diagnostic head `c270c73` also rejects actual Linux full export at
  `+11.679378%`; all other lifecycle callers, Rust and required CodeQL jobs
  pass. Borrowed-provenance and thin-LTO trials show no worthwhile local
  wall improvement and are removed. The existing native CLI suite now
  exercises one diagnostic-only Linux full-export screening pair using
  `--profile-linux`; macOS checks explicit unsupported-platform rejection.
  This samples only owned, executable-matched interactive guards, reports
  incomplete main-task CPU/runqueue counters and sampler CPU, and cannot
  claim either budget. Kernel statistics may be disabled; zero runqueue
  counters do not prove no scheduling delay. At `fb1abf4`, all hosted gates
  pass; independently validated Linux budgets are `+9.038921%` and
  `+26.309800` ms. The active guard observation is `1.07` user/`2.08` system
  CPU seconds. Sampling is incomplete and perturbs the workload; the unchanged
  native source is not a fix. Three-pair budget commands remain unprofiled.
- Readiness trial `d4bbeac` passes actual native Linux controls and budgets:
  `+8.813474%` full export/`+15.745673` ms startup. Observed guard CPU is
  `2.44` seconds versus `3.15`, but direct export is also `22.1%` faster
  across runs; normalized overhead improves only `2.49%`. This does not
  establish a worthwhile optimization or isolate its cause. Remove the
  additional `epoll` queue and obsolete Linux-only fault injector; restore
  the original native source. Keep the two general CLI pipe EOF/diagnostic
  regressions, without introducing a native-host skip or altered budget.
  Further optimization needs a controlled native-Linux comparison, not
  another unmeasured kernel/parser/compiler change.
- Removal `84d6267` still fails actual unchanged-source Linux full export at
  `+10.886877%`; startup does not run. All other callers/Rust/required CodeQL
  jobs pass, including independently verified strict result delivery.
  The owner-approved same-run comparison completes at `bbf115c`: each frozen
  `fb1abf4`/`d4bbeac` runs its own source-validating CLI/build, with matched
  inputs/environment and verified Git cleanup. Observed CPU is `2.44`/`2.43`
  seconds (`0.4098%` lower), but normalized overhead worsens `0.6546%`;
  direct rate differs `0.4132%`. It establishes no worthwhile gain.
  All actual gates/ordinary budgets pass, not a native fix.
  Remove its one-shot controller/mode/step and extra history fetch; retain
  comparison-report rejection/regression. The reproducer is committed at
  `bbf115c`, not part of the maintained CLI. No original guard, 19-job matrix,
  deadline or budget changes; cleanup still requires its own hosted gates.
  See the [reference](equations/native-proxy/README.md#same-run-native-linux-comparison).
- `scripts/check.sh` builds the host guard with the root Rust pin, checks Rust
  formatting/all-target strict Clippy, native clock unit tests and 28 native CLI/process cases, then runs
  whitespace, unit tests and `actionlint`,
  plus lifecycle/source-projection and equation convergence/boundedness proofs when pinned
  Lean is available. The pre-commit hook and CI both call it.
- `REPLAY=1 scripts/check.sh` adds the default/refined witness replays,
  eight refined-origin replays and both guard-mutation regressions.
- `python3 docs/spec/models/mutation.py --timeout 180` replays the default
  mandatory-mix claim and its `CLASSIC_FALLBACK` counterexample, preserving
  each assembled transition system and omitting helper lemmas. It is also
  part of `REPLAY=1` and has a separate lifecycle CI job. Each native command
  has its own timeout; no new proof search or retry is started.
- `python3 docs/spec/models/mutation.py --mutation NO_PREFIX_GUARD --timeout 180`
  replays the stored-prefix claim and counterexample. It checks that the
  mutation only adds the two tail rules without stored-prefix premises;
  the mandatory-mix guard remains present. It also has its own lifecycle job.
- Enable the hook once per clone: `git config core.hooksPath .githooks`.
- Disclosure-profile replay requires complete refined deconstructions.
  `--target complete_safety` replays all completed safety claims except the
  three Lean-checked serialization claims. The four existential targets are
  `executable`, `initiator_candidate_recovery`, `lost_data_recovery` and
  `fresh_epoch_after_compromise`; each preserves the full transition system.
  Individual contexts do not establish full assembled-invocation completion.
- Native export needs `--derivcheck-timeout=60`. Without it, `--quit-on-warning` fails on derivation-check timeouts.
- Mutation replay uses standard export settings with that 60-second budget,
  then replays guided certificates with `--open-chains=0 --saturation=0`
  and `--derivcheck-timeout=120`. Exact Linux binaries timed out at 60 seconds
  with the guided settings; the fallback attack replay completed in 74.24
  seconds with 120. Strict warnings and the 180-second external process cap
  remain enabled. Changing replay precomputation to defaults makes the guided
  attack skeleton incomplete, so export and replay settings are separate.
- Lemma formulas cannot contain reducible symbols such as `kdec`; use action facts such as `EpDec`.

## Proof search

- Inspect one unresolved branch through the loopback UI, close it with explicit `splitEqs` cases and `~~>` chain steps, and save the certificate. Bulk regeneration (8 or 58 lemmas) timed out at 240 s.
- Tamarin proof output carries trailing spaces; `.gitattributes` exempts `*.inc` from that whitespace check.

## Local `act` (Docker via Colima)

- Docker socket: `unix:///Users/phil/.colima/default/docker.sock`; start Colima with the VZ backend, 4 CPUs, 8 GiB.
- Rosetta 2 is required. QEMU emulation of `linux/amd64` OOM-kills Tamarin.
- Even with Rosetta, the default witness replay OOMs or exceeds the 300 s runner timeout in 8 GiB. Hosted parity needs a native x86-64 Linux runner.

## Unresolved-branch driver

`docs/spec/models/branch.py` lists, shows, applies and auto-closes unresolved branches (`paths`, `show`, `apply`, `drive`) against a loopback `tamarin-prover interactive` server. Its docstring has the usage; `drive` follows the `contradiction` > `splitEqs` > `FreshSS` disjunction > `~~>` > `!SSValue` priority used for the refined-origin migrations.
