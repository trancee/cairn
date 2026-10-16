# Native Maude guard

Maintained, dependency-free host guard at the existing CLI/native-stream boundary.
It is the shared ratchet acceptance default after the owner-approved native
staging criteria passed at `71168a1`. There is no Python validator or fallback.
All current-head hosted gates remain required. This is not
a native FVP certificate or approval to change proof deadlines, protocol
behavior, implementation gates or SDK/profile activation.

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

`check.py --proxy <executable>` runs the 25 CLI/native-stream/process/proof
checks. On native Linux it includes one diagnostic-only full-export screening
pair with process sampling and six readiness-failure injections; macOS
checks explicit unsupported profiling and skips the Linux-loader test.
`scripts/check.sh` builds the guard, runs Rust formatting/strict Clippy
and these checks, then the existing model/lifecycle/Lean gates.

`experiment.py` requires exactly one of `--proxy <executable>` or
`--check-report <JSON file>`. `--workload {full-export,startup}` defaults to
`full-export`. The startup workload is exactly
[`derivation.spthy`](derivation.spthy), not an arbitrary model.
`--rounds {1,3}` applies to measurement and defaults to three. One pair is
explicitly screening only; it never reports budget acceptance.

Three alternating pairs compare unchanged committed `replay.run` with the
shared guarded runner and explicit executable. Every export must match a
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
(observed pinned native Linux). Retained startup digests are
`ecd7e735a4f3fc7119dbd00d2edbd245c01900b6035c0dd2e271bea4c5607b64`
(observed macOS) and
`59548c48458d4bdf8e7fee57ba0257642f0a21bfd94c2004a4fb990781659fae`
(observed pinned native Linux).
No runtime sample creates a new accepted digest, no output is normalized or
filtered, and different retained digests cannot be mixed within a measurement.
The cause of cross-host output differences remains unestablished.

## Child-resource diagnostics

New measurements include `waited_child_resources`, keyed by `baseline` and
`compiled_guard`. Each list follows that label's timing-sample order and
contains:

| Field | Type and unit | Scope |
|---|---|---|
| `user_seconds` | Nonnegative finite number, CPU seconds | Delta of `RUSAGE_CHILDREN.ru_utime` |
| `system_seconds` | Nonnegative finite number, CPU seconds | Delta of `RUSAGE_CHILDREN.ru_stime` |
| `voluntary_context_switches` | Nonnegative integer | Delta of `RUSAGE_CHILDREN.ru_nvcsw` |
| `involuntary_context_switches` | Nonnegative integer | Delta of `RUSAGE_CHILDREN.ru_nivcsw` |

Snapshots bracket each command outside its measured wall interval. They cover
reaped children and only those further descendants whose intervening parents
waited for them. They do not identify per-guard costs, include all host work
or guarantee complete descendant accounting. Counter interpretation is
platform-specific; CPU time can exceed wall time for parallel work.

Diagnostics impose no new acceptance threshold and cannot replace either
wall-time budget. Older reports without this field remain compatible.
If present in an acceptance report, it requires both labels, three samples
per label, exactly these four fields and valid values; malformed diagnostics
fail with `FAIL: malformed native guard child-resource diagnostics`.
The one-pair screening mode reports one sample per label and still cannot
claim budget acceptance. These fields do not attest that an untrusted
report was actually measured.

## Native Linux process profiles

`--profile-linux` is opt-in and requires `--proxy`, `--rounds 1` and
`--workload full-export`. It rejects report-checking, three-pair/startup modes
and non-Linux hosts with `FAIL:` and exit `1`, before running the workload.
For example, on native Linux:

```bash
python3 docs/spec/models/equations/native-proxy/experiment.py \
  --proxy target/native-proxy/release/cairn-maude-proxy \
  --workload full-export --rounds 1 --profile-linux
```

Output adds `native_process_profiles`, with one observation per label under
`baseline` and `compiled_guard`. The sampler discovers descendants through
all parent task lists every `100` ms and samples known guards every `10` ms.
Only interactive processes matching the selected executable's device/inode
are retained. PID plus process-start clock ticks distinguish PID reuse.
The owned sampling thread is stopped and joined outside wall timing.

| Observation field | Type and meaning |
|---|---|
| `accounting` | Explicit incomplete-accounting description |
| `sampling_interval_seconds`, `discovery_interval_seconds` | Requested intervals, not timing guarantees |
| `sampler_cpu_seconds` | CPU consumed by the sampling thread, excluding the main thread |
| `scheduler_statistics_at_start` | `enabled`, `disabled` or `not-exposed` from the scheduler sysctl |
| `clock_ticks_per_second` | Positive integer `SC_CLK_TCK` conversion for process CPU ticks |
| `disappeared_reads` | Expected process/task-file disappearance count |
| `processes` | Last observations of matching interactive guards |

Each process has integer `pid`, `start_clock_ticks` and `samples`, plus
`first_seen_seconds`/`last_seen_seconds` relative to sampling start.
`last_observed_cpu_nanoseconds`, `last_observed_runqueue_nanoseconds` and
`last_observed_timeslices` are the three main-task
[`/proc/<pid>/schedstat` counters](https://docs.kernel.org/scheduler/sched-stats.html#proc-pid-schedstat).
The guard is single-threaded; its Maude child is not included in these
counters. They are lifetime counters at the last read, not complete totals
or paired resource deltas. Short-lived processes and final activity can
be missed. Linux can return zero for all three scheduler fields when
[`sched_info_on()` is false](https://github.com/torvalds/linux/blob/v6.17/fs/proc/base.c).
Independent `last_observed_user_clock_ticks` and
`last_observed_system_clock_ticks` come from `/proc/<pid>/stat` fields 14/15,
excluding children. Divide by `clock_ticks_per_second` for CPU seconds.
Zero scheduler counters do not establish no CPU use or scheduling delay. Sampler activity can
perturb the workload, so its wall times are diagnostic only.

Missing observations of an interactive guard, unexpected I/O or malformed
kernel data fail explicitly. Expected process disappearance is counted.
Profiling itself changes no sysctl, affinity, service, native guard, proof
option or deadline.
Fixed export digests, current source/binary identities and complete native
lifecycle evidence remain mandatory. Profiled reports retain
`budget_checked: false`/`budget_passed: false`; any report containing
`native_process_profiles` is rejected by `--check-report`, even if relabelled
as three-pair evidence. Normal three-pair acceptance never enables sampling.
The existing Linux CLI test prints its actual profile in the core CI log;
local macOS checks do not establish native-Linux profiling success.

## Backend readiness

On Linux, the current trial keeps one owned, close-on-exec `epoll` queue per
interactive backend. It registers stderr/stdout once with level-triggered
input readiness. Error/hangup notifications still lead to checked pipe reads;
stderr is processed before stdout, and stderr EOF removes that watch.
The atomic interruption check and interrupted-wait handling are unchanged.
Successful shutdown requires checked queue closure after child/output
reconciliation and before shutdown evidence. Failure paths retain owned-child
teardown. Frontend input, capture/shutdown polling and macOS remain unchanged.

The event structure follows Linux's
[`eventpoll.h`](https://github.com/torvalds/linux/blob/v6.17/include/uapi/linux/eventpoll.h):
packed C layout on x86-64, ordinary C layout elsewhere. Invalid returned tags
reject with `native process: invalid readiness event`; syscall/close failures
use the existing controlled I/O error. The Linux CLI failure test builds a
temporary loader interposer with pinned Rust/rustfmt/Clippy, then injects
creation, registration, wait, invalid-tag, removal and checked-close failures.
It is not linked into the guard or enabled for measurements.

This is a one-variable performance trial, not an established fix.
Actual Linux correctness, representative CPU/wall improvement and the
unchanged unprofiled budgets remain required; cross-target checks and
macOS measurements do not establish those outcomes. See the
[decision](../../../../adr/0010-compositional-lifecycle-verification.md#native-linux-readiness-trial-2026-10-16).

## Default executable and source freshness

Every guarded ratchet caller resolves
`$CARGO_TARGET_DIR/release/cairn-maude-proxy`, or
`<repository>/target/native-proxy/release/cairn-maude-proxy` when that variable
is unset. Relative target directories follow Cargo's working-directory semantics;
an explicitly empty value rejects. The temporary candidate selector is removed.
Missing/non-executable/stale builds reject with build guidance; proof commands
never build automatically or fall back to another validator.
The CLIs resolve their `--proxy` path before using the shared runner's
`proxy: Path` keyword, which requires an absolute executable. Both routes
use the same identity/evidence checks.
User `--with-maude` overrides remain rejected.

For example, after building at the path above:

```bash
python3 docs/spec/models/replay.py --target lost_data_recovery --timeout 180
```

Cargo embeds a deterministic SHA-256 of the Rust sources, Cargo/build/generator
inputs, shared inventory, native selector/reconciler and root Rust
pin. [`source_inputs()`](../maude_native.py) is the inventory. Cargo watches
those inputs and the Rust source directory. Every native `version` event adds
`source_id`; the parent requires it to match current source before accepting
the complete journal. Old or stale executables fail with explicit rebuild
guidance. This is freshness evidence, not signed build/toolchain attestation.

The existing 19-cell lifecycle workflow builds the guard once per cell
and exports the shared Cargo target for all callers. The lifecycle cell runs static/
stream gates and both three-pair budgets; no job or deadline is added.
The workflow names the internal host-tool exclusion from SDK coverage.
Native staging acceptance is recorded below. The temporary selector, obsolete
Python validator/evidence/parser and nine duplicate parser tests are removed.
Their adversarial cases remain in the native CLI tables, including standalone
framing-under-message and incompatible returned-Pub binding cases.

## Implementation boundary

The standalone Cargo package has no third-party dependencies and is not a
member of the application workspace. Cargo generates the module/function
inventory from the existing reviewed Python source into `OUT_DIR`; generated
inventory is not edited or committed. The Python module builder remains the
shared source of the reviewed inventory, not a second runtime validator.

The guard implements the pinned module/setup, all four operations,
iterative term recognition, controlled Fresh/natural kinds, proper returned
sorts, original/generated variable provenance, rigid indices and every solution.
Replies remain buffered until the whole reply passes. Private operation
journaling preserves every event, checks regular-file/no-follow/nonblocking
append writes and close errors, and closes before successful shutdown evidence.
Installation/version checks and deadlines are unchanged. Each already-validated
owned reply has its original prompt restored and is forwarded through one
checked raw stdout write, avoiding line-buffered body/prompt splitting.
The output descriptor is cloned once per process and explicitly closed with
error checking. Final evidence is polled every `1` ms with the same
`5`-second deadline and complete audit.

`unix.rs` contains the host-only POSIX FFI for poll, signals, owned-child
termination and checked descriptor close. The signal handler only stores an
atomic flag. No application/core unsafe-code policy or shipped dependency
changes. Compile-time platform branches cover macOS and Linux. The accepted
staging source passes native Linux caller/fast and both performance gates;
the subsequent cutover run and its retained timeout are recorded below.

The CLI cases cover real operations, malformed terms and replies, kind/sort/
namespace boundaries, deep framing, changed equations, complete bulk evidence,
capacity/FIFO failures, ready/pending interruption and actual Tamarin derivation/
normalization probes. These are bounded regression evidence, not a verified
parser or exhaustive equivalence proof. Local maintained checks pass; native
Linux, full caller and performance acceptance are recorded separately.
Native FVP and full assembled proof acceptance remain open.

Approval rationale, prototype results, rejected native budgets, fixture
corrections and measured stdout/teardown fixes are retained in
[ADR 0010](../../../../adr/0010-compositional-lifecycle-verification.md#migration)
and [issue 28](../../../../../.scratch/cairn-r1/issues/28-formal-model-ratchet.md).

## Current default-source evidence (2026-10-15)

Current-source three-pair measurements use macOS `27.0.1`/`arm64`, eight logical
CPUs, 8 GiB, Python `3.14.8`, Rust `1.99.0` and the pinned proof tools.
The unchanged direct runner baseline is committed `71168a1`.

| Workload | Direct / guarded median seconds | Overhead | Approved gate |
|---|---|---|---|
| Complete strict export | `24.324896` / `25.820824` | `+6.1498%` | Pass, at most `10%` |
| Paired-counter startup | `0.112296` / `0.154256` | `+41.960417` ms (`+37.3660%`) | Pass, at most `50` ms |

Every export matches its retained digest. Both saved reports also pass the
independent `--check-report` path. The measured source ID is
`96295e1ecba13e26eac68929ff5dbff673651f5e0eb61a8fe16ae847f2ccf0a8`;
the binary SHA-256 is
`aa8b30c421366c5f77bcce80aff804aad1ccd7708f2e2d6d68d030cb883a3838`.
All samples are retained; acceptance uses the approved median, not filtering.
Earlier-source reports reject as stale and are historical evidence only.

The preceding accepted staging build passed the original `180`-second-cap recovery replay
(826-step witness plus nine-step owner helper), complete refined safety
(all 56 certificates) and both mutation regressions (verified defaults and
504-/526-step counterexamples). All 43 rules/13 restrictions and non-lemma
declarations remain unchanged. These are four selected local caller
regressions, not native Linux/19-cell CI or full assembled acceptance.
The current default fast gate passes 19 native checks, 131 model tests,
50 lifecycle tests, 43 projections and 67 audits without a temporary selector.
The intended default-selection red preceded implementation. All malformed
lifecycle fixtures now carry valid source identity where appropriate and assert
the intended failure reason, rather than rejecting early for missing identity.

The owner authorized promotion checkpoints in PR #9 for existing native CI,
including necessary fixes and conditional cutover after the required criteria
pass. Merge and SDK/profile activation are not authorized.
The local budgets do not measure full-proof or memory overhead,
establish FVP or supersede current-head hosted acceptance.

## Native default-source checkpoint (`2fa6d16`)

[Run `38724991914`](https://github.com/trancee/cairn/actions/runs/38724991914)
uses the source ID above and Linux binary SHA-256
`af8d464b6aaebf770181e08436e16156eff948cfe57804a2aabc1750ecb74b28`.
Its actual three-pair budgets both pass:

| Workload | Direct / guarded median seconds | Overhead |
|---|---|---|
| Complete strict export | `44.715197` / `48.455601` | `+8.3650%` |
| Paired-counter startup | `0.124042` / `0.149827` | `+25.785370` ms (`+20.7876%`) |

All six exports per workload match the fixed Linux digest and each other;
both saved reports independently pass `--check-report`.
The lifecycle cell and 17/18 callers pass, but `replay-initial_ck_secret`
fails its unchanged strict `60`-second derivation check during assembled
export, before its selected proof. The exact local caller passes its
11-step claim and five origin helpers; that is not a native reproduction
or a fix. The cause remains unestablished. No timeout/warning relaxation,
unchanged manual rerun or selective sample removal is used.
Companion Rust `38724991821` and four-language CodeQL `38724992020` pass.
This snapshot is not all-green hosted acceptance. All current-head checks
remain required; [PR #9](https://github.com/trancee/cairn/pull/9/checks)
records subsequent documentation-only checkpoints.

## Accepted native staging (`71168a1`)

[Run `38721189200`](https://github.com/trancee/cairn/actions/runs/38721189200)
passes all 19 cells: every replay/mutation caller, fast gates and both actual
three-pair budgets. Native full export measures `32.023234268` /
`35.116483184` seconds (`+9.659389%`); startup measures `0.103666940` /
`0.119538055` seconds (`+15.871115` ms, `+15.3097%`). All six exports per
workload match the fixed Linux digest and each other. Both saved reports
independently passed before the cutover changed source identity.
Staging source ID was
`d9ce5de97da68e702ad2c7c54b705f2c8ff2cf85032b608c93ce55e3af89c367`,
Linux binary SHA-256
`70b5d14f77e9f4173a8e6a55f4bdd922ac49312d9d98186a29e587b453bd740a`.
Rust `38721189142` and four-language CodeQL `38721189358` also pass,
including the Apple preflight.
These actual native criteria permit the owner-authorized central default
change, not a merge or SDK/profile activation. These preceding-source results
do not replace current-head hosted acceptance.
