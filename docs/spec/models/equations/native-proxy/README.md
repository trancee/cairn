# Compiled Maude guard candidate

Maintained host-only candidate at the existing CLI/native-stream boundary.
This is **not the default acceptance proxy**, a native FVP certificate or
approval to bypass rollout criteria, change proof deadlines, protocol behavior
or implementation gates.
The owner approved promotion after the prototype's performance experiment.
Linux parity and caller/CI gates must pass before central default cutover.
The Python default is retained only for this staged migration, not as a
fallback when the compiled candidate fails.

## Commands

From the repository root, using the existing Rust `1.99.0` toolchain pin,
Python and pinned Tamarin `1.12.0`/Maude `3.5.1`:

Measure against the shared pinned `PATH` backend without a
`CAIRN_MAUDE_BINARY` override.

```bash
cargo build --locked --release \
  --manifest-path docs/spec/models/equations/native-proxy/Cargo.toml \
  --target-dir target/native-proxy
python3 docs/spec/models/equations/native-proxy/check.py \
  --proxy target/native-proxy/release/cairn-maude-proxy
python3 docs/spec/models/equations/native-proxy/experiment.py \
  --proxy target/native-proxy/release/cairn-maude-proxy --workload full-export
python3 docs/spec/models/equations/native-proxy/experiment.py \
  --proxy target/native-proxy/release/cairn-maude-proxy --workload startup
```

`check.py --proxy <executable>` runs the 18 CLI/native-stream/process/proof
checks. `scripts/check.sh` builds the guard, runs Rust formatting/strict Clippy
and these checks, then the existing model/lifecycle/Lean gates.

`experiment.py` requires exactly one of `--proxy <executable>` or
`--check-report <JSON file>`. `--workload {full-export,startup}` defaults to
`full-export`. The startup workload is exactly
[`derivation.spthy`](derivation.spthy), not an arbitrary model.
`--rounds {1,3}` applies to measurement and defaults to three. One pair is
explicitly screening only; it never reports budget acceptance.

Three alternating pairs compare unchanged committed `replay.run` with the
shared guarded runner and explicit candidate. Every export must match a
retained workload digest, and all six exports in a measurement must be
byte-identical. The medians must satisfy **full export at most
`+10%`** and **startup at most `+50` ms**. The tiny allowance never applies
to the full export. Each command retains `120` seconds,
`--derivcheck-timeout=60` and `5` seconds for shutdown reconciliation.

JSON records platform/architecture/CPU/RAM, baseline revision, compiler,
source/binary/model/export identities, all samples, medians, both overhead
metrics and explicit budget status. Source/binary changes during measurement
reject the run. `--check-report` rechecks the schema, current source/fixture
identities, three-pair method and budget math; it does not attest that an
untrusted report was actually measured. Missing, malformed, incompatible,
stale, incomplete or over-budget evidence fails with `FAIL:` and exit `1`.
Unreviewed exports identify the phase and expected/observed SHA-256 values,
not the export payload.

Retained full-export digests are
`aaaf873a9b7baff6fbf209f1cf87088581552498ade6f9a5e471ee2b5ea6fb5d`
(observed macOS) and
`1b66b2a76902af6c98de7b22edbe6f4d8fddc27cd2adb580db6d5eff639dbd48`
(observed pinned native Linux). The startup digest remains
`ecd7e735a4f3fc7119dbd00d2edbd245c01900b6035c0dd2e271bea4c5607b64`.
No runtime sample creates a new accepted digest, no output is normalized or
filtered, and different retained digests cannot be mixed within a measurement.

## Candidate routing and source freshness

`CAIRN_MAUDE_GUARD_CANDIDATE` explicitly selects the compiled executable for
every existing guarded acceptance caller. It must be an absolute executable
path. An empty/relative/missing/non-executable value rejects the proof command;
there is no automatic build, Python fallback or user `--with-maude` override.
The benchmark's explicit `--proxy` uses the same runner and identity checks.

For example, after building at the path above:

```bash
export CAIRN_MAUDE_GUARD_CANDIDATE="$PWD/target/native-proxy/release/cairn-maude-proxy"
python3 docs/spec/models/replay.py --target lost_data_recovery --timeout 180
```

Cargo embeds a deterministic SHA-256 of the Rust sources, Cargo/build/generator
inputs, shared inventory/recognizer, candidate selector/reconciler and root Rust
pin. [`source_inputs()`](../maude_candidate.py) is the inventory. Cargo watches
those inputs and the Rust source directory. Every native `version` event adds
`source_id`; the parent requires it to match current source before accepting
the complete journal. Old or stale executables fail with explicit rebuild
guidance. This is freshness evidence, not signed build/toolchain attestation.

The existing 19-cell lifecycle workflow builds the candidate once per cell
and selects it for all existing callers. The lifecycle cell also runs static/
stream gates and both three-pair budgets; no job or deadline is added.
The workflow names the internal host-tool exclusion from SDK coverage.
Native execution is observed below; full budget acceptance remains incomplete.
Only after Linux/caller/performance acceptance may the default change and
the temporary selector and obsolete Python validator/tests be removed.

## Implementation boundary

The standalone Cargo package has no third-party dependencies and is not a
member of the application workspace. Cargo generates the module/function
inventory from the existing reviewed Python source into `OUT_DIR`; generated
inventory is not edited or committed. The normal Python module checker uses
the same inventory without changing its acceptance contract.

The guard implements the pinned module/setup, all four operations,
iterative term recognition, controlled Fresh/natural kinds, proper returned
sorts, original/generated variable provenance, rigid indices and every solution.
Replies remain buffered until the whole reply passes. Private operation
journaling preserves every event, checks regular-file/no-follow/nonblocking
append writes and close errors, and closes before successful shutdown evidence.
Installation/version checks and deadlines are unchanged.

`unix.rs` contains the host-only POSIX FFI for poll, signals, owned-child
termination and checked descriptor close. The signal handler only stores an
atomic flag. No application/core unsafe-code policy or shipped dependency
changes. Compile-time platform branches cover macOS and Linux; only native
Apple-silicon macOS execution is presently verified.

The CLI cases cover real operations, malformed terms and replies, kind/sort/
namespace boundaries, deep framing, changed equations, complete bulk evidence,
capacity/FIFO failures, ready/pending interruption and actual Tamarin derivation/
normalization probes. These are bounded regression evidence, not a verified
parser or exhaustive equivalence proof. Local maintained checks pass; native
Linux, full caller and performance acceptance are recorded separately.
Native FVP and full assembled proof acceptance remain open.

## Prior prototype result (2026-10-15)

On Apple-silicon macOS `27.0.1`, 8 GiB RAM, with Rust `1.99.0` and the pinned
proof tools, three alternating complete-export pairs measured direct/prototype
medians of `24.281`/`25.931` seconds (`+6.80%`). All six exports have SHA-256
`aaaf873a9b7baff6fbf209f1cf87088581552498ade6f9a5e471ee2b5ea6fb5d`.
This representative workload is below the `10%` limit; it is not a global
performance waiver or evidence of full-proof/memory performance.

The one-rule derivation fixture separately measures `0.118`/`0.158` seconds
(`+39.93` ms, `+33.76%`), also across three alternating pairs. Its relative
overhead still exceeds `10%`. The owner subsequently approved an additive
startup-only cap of `50` ms, while retaining `10%` for the complete export;
see [ADR 0010](../../../../adr/0010-compositional-lifecycle-verification.md#maintained-proxy-promotion-and-startup-only-budget-2026-10-15).
Do not conceal the relative result behind the larger workload's percentage.
The default Python path remains at `+22.5%` and remains performance-blocked.

All 18 prototype checks, Rust formatting/strict Clippy and the then-default
fast gate passed. That checkpoint reported 117 model tests, 50 lifecycle tests,
43 projections, six source correspondences and 67 audits. The tested prototype
binary SHA-256 is
`4bc6cd2ad4fb883f84811b233905d404025f492f47fbd3b0ed092c9680dafce0`.
The reduction and missing-unification behavior reds preceded their green
implementations. These timings/hash precede source identity and maintained
integration; they are not final maintained-candidate acceptance measurements.

The clean maintained-candidate fast gate now passes 18 native checks, 134
model tests, 50 lifecycle tests, 43 projections and 67 equation audits.
The missing-identity behavior red, unsupported budget-CLI red and real
stale-executable rejection are retained, as are controlled source-input and
inventory-output I/O reds. No compiled default cutover or merge
has occurred.

## Maintained-candidate evidence (2026-10-15)

Final-source three-pair measurements use macOS `27.0.1`/`arm64`, eight logical
CPUs, 8 GiB, Python `3.14.8`, Rust `1.99.0` and the pinned proof tools.
The unchanged direct runner baseline is committed `3d5dd7c`.

| Workload | Direct / guarded median seconds | Overhead | Approved gate |
|---|---|---|---|
| Complete strict export | `24.235925` / `25.894241` | `+6.8424%` | Pass, at most `10%` |
| Paired-counter startup | `0.115764` / `0.162232` | `+46.467751` ms (`+40.1399%`) | Pass, at most `50` ms |

Every export matches its retained digest. Both saved reports also pass the
independent `--check-report` path. The measured source ID is
`ea4222469f57cad7978b5e2acbef3925b9805c0c6f043a79761c9a44cfd1d1c1`;
the binary SHA-256 is
`6e6c3c809a7a6e5b64688ea67e189633e84c19ddd6daa0b335a2fe3b549e05fa`.

The final build also passes the original `180`-second-cap recovery replay
(826-step witness plus nine-step owner helper), complete refined safety
(all 56 certificates) and both mutation regressions (verified defaults and
504-/526-step counterexamples). All 43 rules/13 restrictions and non-lemma
declarations remain unchanged. These are four selected local caller
regressions, not native Linux/19-cell CI or full assembled acceptance.
The two genuine tiny Tamarin probes also pass with candidate selection
unset, preserving the existing Python default.

The owner authorized promotion checkpoints in PR #9 for existing native CI,
including necessary fixes and conditional cutover after the required criteria
pass. Full native acceptance remains incomplete; merge and SDK/profile activation
are not authorized. The local budgets do not measure full-proof or memory overhead,
establish FVP, authorize a default cutover or supersede the failed hosted run.

## Native staging result (`2e7b429`)

[Run `38710117729`](https://github.com/trancee/cairn/actions/runs/38710117729)
passes all 18 replay/mutation cells and the lifecycle fast gates. The benchmark
then rejects an unreviewed export before any timing-budget verdict.
The earlier generic error did not distinguish an unexpected direct export
from a guarded mismatch. A public benchmark CLI regression now requires the
phase and expected/observed SHA-256 values, without logging output payloads.
No export, evidence, budget or deadline check is relaxed.
Native performance acceptance and default cutover remain blocked.

[Diagnostic run `38712391261`](https://github.com/trancee/cairn/actions/runs/38712391261)
at `942f8d8` again passes all 18 callers and the fast gates. It identifies
the **direct baseline**, before any guarded sample: the retained macOS digest
does not match the pinned Linux tool's observed digest above.
The inventory now retains both fixed outputs rather than assuming cross-host
byte identity. Paired runs still require exact byte identity on the actual host.
All 13 public budget/diagnostic CLI cases pass, including the intended Linux
fixture red/green, its unchanged relative cap and rejection of applying the
startup allowance to it. Both retained macOS reports still pass.
Native full-export/startup budget acceptance has not yet been established.
