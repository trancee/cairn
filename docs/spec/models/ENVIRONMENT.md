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
  and controlled Fresh/natural derivation-kind abstraction (67 audits).
  The kind results concern raw-overapproximation relations, not native
  proper-sort matching completeness or convergence.
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
- `scripts/check.sh` builds the host guard with the root Rust pin, checks Rust
  formatting/strict Clippy and 19 native CLI/process cases, then runs
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
