# Proof environment

Facts that no config file states. Read before running Tamarin, replay or `act`.

## Host

- Apple silicon macOS, 8 GiB RAM. Tamarin on `ratchet.spthy` can exceed 7 GiB.
- Tools: Tamarin 1.12.0, Maude 3.5.1, Lean 4.34.1 (pinned in `lifecycle/lean-toolchain`).
- Lean is not on `PATH`; pass it with `LEAN=<path>/bin/lean scripts/check.sh` or `check.py --lean`.

## Commands

- `scripts/check.sh` runs the fast gates: whitespace, unit tests, `actionlint`, lifecycle proofs. The pre-commit hook and CI both call it.
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
- Native export needs `--derivcheck-timeout=60`. Without it, `--quit-on-warning` fails on derivation-check timeouts.
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
