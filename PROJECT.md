# PROJECT

state=protocol research/specification/formal models + host-only Rust foundation; SDK/application=not implemented.

## Current typed equation convergence/image evidence (2026-10-17)

The [equation checker](docs/spec/models/equations/README.md) kernel-checks
B-coherence, global matching confluence, quotient-path confluence modulo AC
and a normalization bound depending only on the source template, not the
normalized substitution. Nonlinear key-copy overlaps are joined even when
keys have different AC representatives. A structural frozen-index image
encoding also has checked left inverses/injectivity, distinguishing variables
from rigid atoms with the same native index. Independent raw AC and six-rule/
context relations preserve and reflect this image, and encoded quotient steps
are realizable by typed matching modulo AC. Sort-separated natural/message
substitutions commute with encoding and preserve image membership while rigid
indices stay frozen. Free tuple/Node framing is closed under AC, rewriting and
typed substitution, including node assignments; framing remains excluded from
message functions. All 187 theorem audits and the kernel
regression cases run in the existing lifecycle cell, without a new job or
larger ceiling. Twenty-seven audits use no axioms; none uses `sorryAx`.

The new independent native-sorted relation requires proper-`Msg` equation
variables and AC-equivalent repeated keys instead of using unguarded shadow
rewrites. On proper-message inputs it inherits termination, B-coherence,
confluence/normal-form uniqueness modulo AC, normality invariance and the same
source-template-only normalizing bound. Controlled-kind framing closure and
decoded-kind termination also hold. A separate structural proof gives every
frozen-index native query template and normalized assignment a normalizing
path bounded only by source contexts, including controlled error-kind and free
framing contexts. It needs no compatible typed shadow, but does not prove
sort/image closure for arbitrary assignments. Exact guarded matching decoding
now joins root overlaps; structural context induction and a strictly decreasing
source-context count prove full frozen-index AST matching confluence and
termination. Bidirectional AC transport then proves guarded quotient-path
confluence, AC-invariant normality and normal-form uniqueness modulo AC,
including controlled-kind/free framing. This is not a proof of the full
imported NAT/kind-variable carrier or native algorithms.
Sort-respecting native assignments now have a proved complete representation
by the existing typed substitution. They preserve proper-message guards,
guarded rewrites and counted matching/quotient paths. Kind abstraction preserves
proper values and produces a sorted abstract assignment, so a compatible typed
shadow exists rather than being assumed. Controlled-kind/free framing is
therefore closed under every modeled sort-respecting assignment. This is not
normality preservation or a kernel proof of runtime validation/importing.
Sorted assignments now compose, with checked simultaneous substitution laws
and pointwise AC congruence. AC-unifier solutions are closed under sorted
composition and preserve/reflect proper message/natural typed solutions.
Kind solutions transfer only through compatible shadows: unrestricted natural
shadows can solve a Fresh/natural equality that has no sorted original solution.
Kernel and actual Maude controls retain this separation and distinguish AC
unification from equality modulo rewrite equations.
AC factorization now compares assignments only on input-query variables.
Sorted factors give a preorder and preserve sorted solutions; independently
defined typed composition and all-five-sort pointwise equality/AC preserve
and reflect that relation. On proper message/natural inputs, a given finite
family is sound and complete exactly when its typed counterpart is, and
singleton completeness characterizes most-generality. Kernel cases distinguish
the variable-pair MGU from a sound but incomplete ground singleton, and show
that adding an unrelated variable would reject a valid scoped MGU.
These are conditional completeness/most-generality transports, not a finite
complete native generator. Every sorted solution
now has a finite binding-list representative agreeing exactly on the input
variables. Scoped postfactors also have finite representatives, supported on
variables in candidate values, including residual variables absent from the
input. Completeness and most-generality can quantify over input-supported
finite solutions without loss. Restricting a given family's candidates
preserves/reflects completeness only with their original sortedness retained;
it does not repair invalid bindings or generate a family. Kind assignment
abstraction now has an explicit expansion inverse, with exact composition and
input-support transport. Admissible shadows must expand to sorted original
assignments and reabstract exactly. Requiring this of both solutions and
postfactors preserves/reflects scoped factorization, family completeness and
most-generality across the frozen-index AST, including controlled-kind/framing.
Unrestricted shadow factoring is unsound even between two sorted original
candidates: it can instantiate a Fresh residual to natural `one`. This is a
mathematical constraint, not native result filtering or an executable
admissibility decision procedure. The owner explicitly selected
`resume-proof-only` despite the unresolved native budget diagnosis.
Generic finite-AST occurs rejection now constructs complete empty AC families.
An occurs-free sort-compatible one-binding substitution is finite, supported,
idempotent and most general in either orientation. A proof-carrying
variable-equation solver generates complete explicit binding-list families
for identity, proper cycles and occurs-free targets. An incompatible
orientation is outside its domain, not an unsatisfiability verdict; pure AC
rejection does not reject equality modulo the six rewrite equations.
This is constructive variable elimination, not a general sorted AC generator.
Native algorithm,
runtime finite-support/occurs-check/fresh-namespace correspondence, narrowing/FVP and
importer correctness remain open. The blocked error-kind
projection and permitted inner rewrite agree with actual Maude controls.
The existing kernel/CLI seams reject missing new audits after intended reds;
the current gates run 28 native CLI/180 model/50 lifecycle tests plus native
clock unit tests, 43 projections and all 187 audits. The [PR #9 checks](https://github.com/trancee/cairn/pull/9/checks)
record authoritative current-head hosted results. These equation proofs change no native guard source-ID input,
equation, protocol, API, wire, runtime dependency or resource ceiling.

## Native budget diagnosis (2026-10-16)

The approved phase-accounting follow-up reuses the existing failure-only pair
for numeric native-phase CPU/wall, driver-thread CPU, Linux guard observations
and final Tamarin RTS statistics. No new full-export pair is added to the
existing CLI test or failure capture. Native profiling is opt-in and Linux-only,
requires owned bounded reports before shutdown evidence and a source-identified
rebuild, and rejects at acceptance even when relabelled. All ordinary validation,
19 jobs, deadlines and budgets remain unchanged. Actual current-head Linux
execution and a causal fix require evidence; instrumentation does not establish
either or activate SDK/formal acceptance.
See [ADR 0010](docs/adr/0010-compositional-lifecycle-verification.md#same-pair-native-phase-and-driver-cpu-accounting-2026-10-17).

The preceding increment adds
[failure-only RTS/CPU capture](docs/spec/models/equations/native-proxy/README.md#failure-only-ci-capture)
to the existing lifecycle core cell. The unprofiled budget step remains
authoritative and failing; a separate one-pair diagnostic requires five minutes
remaining plus a one-minute retention reserve within the existing 15-minute
ceiling. Original reports and separately marked numeric evidence have a
failure-only seven-day artifact. No job, native source-ID input, equation,
validation, export deadline, budget, acceptance retry or PMU dependency changes.
Local parser/process/control-flow tests and real macOS RTS execution are not
hosted Linux failure-trigger proof or a fix for the intermittent native budget.
`LEAN=<pinned Lean> scripts/check.sh` passes 24 native, 166 model and 50
lifecycle tests plus both kernel/source gates. Separate unprofiled local
three-pair budgets pass at `+6.419572%` full export and `+43.645208` ms startup;
the new RTS pair retains both false budget flags and rejects at the public
acceptance checker. These are local results, not current-head hosted acceptance.
See [ADR 0010](docs/adr/0010-compositional-lifecycle-verification.md#failure-triggered-tamarin-runtime-accounting-2026-10-17).

The published kind-family head `8c54f2b` passes its actual 169-audit kernel,
18 caller cells, all 11 Rust jobs and six required CodeQL jobs, but its
lifecycle core cell rejects full-export medians of `24.513057061`/
`28.576567731` seconds (`+16.576923%`, above `10%`). Its final rollup is
36 successes, one failure and one intentional simulator skip. No startup
measurement follows that failure; the head is not accepted.

The owner selected `diagnose-and-fix-native-performance`, extending the
proof-only scope to bounded diagnosis and a justified fix without changing
the equations, grammar, validation, strict gates/deadlines or budgets.
An unchanged local baseline passes at `+6.403659%`, not reproducing Linux.
Active-worker sampling shows mainly pipe/poll waits; the final Python journal
audit takes `0.151` profiled seconds. Neither establishes the Linux cause.
The first diagnostic increment adds per-sample waited-child CPU/context-switch
resources outside wall timing. Legacy reports remain compatible; malformed
present diagnostics reject, and diagnostics never replace the wall budget.
All 17 report cases and 20 real native CLI/process/proof cases pass.
Current local three-pair reports pass at `+6.154029%` full export and
`+36.256333` ms startup, with fixed-identical exports. These unchanged-binary
observations are not a native performance fix or new-head hosted acceptance.
See the [reference](docs/spec/models/equations/native-proxy/README.md#child-resource-diagnostics)
and [decision](docs/adr/0010-compositional-lifecycle-verification.md#native-budget-diagnostics-2026-10-16).

Diagnostic head `c270c73` also fails actual Linux full export:
`43.772741808`/`48.885125646` seconds (`+11.679378%`). All 18 callers,
11 Rust jobs and six required CodeQL jobs pass, with independently audited
strict execution/result delivery. Partial waited-child CPU increases by
about `1.43` median seconds, versus about `5.11` median wall seconds; these
aggregates do not identify individual guards or establish a cause.
Separate borrowed-provenance and thin-LTO trials preserve native tests and
exports but show no worthwhile wall improvement; both are removed.
The next diagnostic adds opt-in, one-pair native-Linux process sampling to
the existing benchmark CLI. The existing native CLI suite exercises it on
Linux and rejects unsupported profiling on macOS. It records observed guard
CPU/runqueue counters and sampler CPU, not complete accounting or performance
acceptance. Normal three-pair measurements remain unprofiled and unchanged.
Published profiling head `fb1abf4` passes all 19 lifecycle cells, 11 Rust
jobs and six required CodeQL jobs, with one intentional simulator skip.
Independently validated Linux budgets are `+9.038921%` full export and
`+26.309800` ms startup. The active guard observation has `1.07` user/
`2.08` system CPU seconds, unlike the partial waited-child aggregates.
This unchanged-native checkpoint is diagnosis, not a performance fix.
See the [reference](docs/spec/models/equations/native-proxy/README.md#native-linux-process-profiles)
and [decision](docs/adr/0010-compositional-lifecycle-verification.md#native-linux-process-profiling-2026-10-16).

Published readiness trial `d4bbeac` passes actual Linux 25 native/141 model/
50 lifecycle cases, 43 projections, 169 audits and both budgets. Six loader
faults check setup/wait/tag/removal/close failures. Full export is
`31.742090`/`34.539671` seconds (`+8.813474%`), startup `+15.745673` ms.
Observed guard CPU drops from `3.15` to `2.44` seconds, but direct export
also becomes `22.1%` faster across hosted runs; normalized overhead improves
only `2.49%`. This does not demonstrate a worthwhile native improvement.
CodeQL preparation also fails its bounded frozen-tool-startup probe with
exit `124`; compiled Kotlin analysis is skipped. This head is not accepted.
Remove the additional `epoll` code and its now-obsolete fault injector.
The original native source is restored; the two general CLI controls for
closed stderr/repeated replies and diagnostic rejection remain (24 cases).
All original validation, grammar/events, equations, dependencies, jobs,
deadlines and budgets remain unchanged. No performance fix is established.
See the [decision](docs/adr/0010-compositional-lifecycle-verification.md#native-linux-readiness-trial-2026-10-16).

Removal `84d6267` restores the exact original Linux source/binary but again
rejects actual full export: `43.565964908`/`48.308937965` seconds
(`+10.886877%`); startup does not run. Actual 24/141/50 cases, 43 projections,
169 audits/25 axiom-free, all 18 callers, 11 Rust and six required CodeQL jobs
pass. Strict compilation/five Kotlin units, cleanup, integrity and processed
delivery are independently verified. Final rollup is 36 successes/one failure/
one intentional skip, not a native fix or acceptance.
The owner-selected same-run Linux comparison at `bbf115c` validates frozen
`fb1abf4`/`d4bbeac` through their own source-identified builds/CLIs, shared
inputs/environment and owned-worktree cleanup. Original/candidate observed
CPU is `2.44`/`2.43` seconds, while profiled overhead is `+8.964051%`/
`+9.022732%`: only `0.4098%` lower CPU and `0.6546%` worse normalized overhead,
with direct rate differing `0.4132%`. No worthwhile gain is established.
All 19 lifecycle/11 Rust/six required CodeQL jobs and both normal budgets
(`+9.562037%`, `+14.648994` ms) pass, with independently audited strict delivery.
Final rollup is 37 successes/one intentional skip, not a native fix.
Remove the one-shot driver/mode, scheduled step and extra history fetch;
keep the diagnostic-report rejection/regression. Original native source/binary,
19 jobs, deadlines and budgets remain unchanged; cleanup needs its own gates.
See the [reference](docs/spec/models/equations/native-proxy/README.md#same-run-native-linux-comparison)
and [decision](docs/adr/0010-compositional-lifecycle-verification.md#same-run-native-linux-comparison-2026-10-16).

Published AC-unifier checkpoint `bfff37f` passes all 19 lifecycle cells,
all 11 Rust jobs and both native budgets, but CodeQL `38770078501` fails
ordinary Apple scratch ejection with `Resource busy` after Kotlin queries,
before mandatory integrity/result delivery. This is not full hosted acceptance.
A native owned-file regression reproduces a separate holder-diagnostic defect:
`lsof -Fpc` also emits mandatory `f` records. The narrow parser fix accepts
and discards those descriptors while retaining only validated PID/command
output and the original ejection failure. All 67 local Apple tooling tests
pass, with six existing hosted-only supervisor skips. Updated-source hosted
gates remain separate; no busy-eject root-cause or reliability fix is claimed.
See [the decision](docs/adr/0014-hosted-apple-isolation-probes.md#mandatory-native-holder-record-compatibility)
and [current PR #9 checks](https://github.com/trancee/cairn/pull/9/checks).

The owner-approved proof-only Maude boundary now checks the pinned native
module and every executed query/complete reply, with fail-closed lifecycle
evidence required by ratchet export, projection, equation, precompute, replay,
mutation and attack callers. Returned sort/index provenance and importer
variable-namespace restrictions are checked; no solutions are filtered.
Real native operations and guarded Tamarin parsing pass. The initial complete
ratchet export measured `+46.3%` overhead, unlike the unrepresentative `+2.7%`
parse-only result. Owner-approved bounded operation-journal batching,
selector reuse and conservative parser/audit fast paths reduce final-source
medians to `24.303`/`29.761` seconds direct/guarded (`+22.5%`), with identical
exports and unchanged deadlines. Every operation record is retained; the
journal closes before successful shutdown evidence. This is approximately
16% faster than the initial whole guard, but failed Constitution P4.
That Python validator is now removed; no representative-workload exception
was approved. Native recognition, tool implementations and injective variable renaming/
importer correspondence are not kernel-verified.

The owner then selected a bounded
[compiled proxy prototype](docs/spec/models/equations/native-proxy/README.md),
not a default cutover. Its standalone, dependency-free Rust host tool preserves
the stream/evidence checks and shares the reviewed generated inventory.
Eighteen opt-in CLI/process/proof checks pass. Three paired full-export runs
measure `24.281`/`25.931` seconds direct/prototype (`+6.80%`), with identical
bytes. A separate tiny derivation fixture adds `39.93` ms (`+33.76%`).
The owner subsequently approved maintained promotion with a startup-only
`50` ms additive allowance, retaining the full-export `10%` limit.
Native [run `38721189200`](https://github.com/trancee/cairn/actions/runs/38721189200)
at `71168a1` meets those staging criteria: all 19 cells pass, including all
replay/mutation callers and both actual three-pair budgets. Linux full export
is `32.023234`/`35.116483` seconds (`+9.6594%`); startup is
`0.103667`/`0.119538` seconds (`+15.871115` ms, `+15.3097%`).
Both workloads retain fixed per-host digests and six identical exports, without
normalization, filtering, budget changes or larger deadlines. Earlier genuine
Linux/startup failures and their measured stdout/teardown fixes remain recorded
in the reference and issue. Companion Rust `38721189142` and four-language
CodeQL `38721189358` also pass, including the Apple preflight.

The owner-authorized conditional cutover now makes `cairn-maude-proxy` the
shared ratchet acceptance default. It resolves from `CARGO_TARGET_DIR/release`,
or root `target/native-proxy/release` when unset. Empty targets and missing/
non-executable/stale builds reject; every version requires current source
identity. No automatic build or fallback occurs inside proof commands.
The temporary selector and obsolete Python validator/evidence/parser are
deleted. All nine duplicate parser-test cases remain covered by the native CLI;
the standalone framing and unsorted-Pub cases are explicitly retained.
The cutover's local fast gate passed 19 native checks, 131 model tests,
50 lifecycle tests, 43 projections and 67 audits. The intended default-selection
red precedes implementation; malformed lifecycle fixtures reach their intended
failure rather than an earlier missing-identity check.
Current-source macOS three-pair medians are `24.324896`/`25.820824` seconds
for full export (`+6.1498%`) and `0.112296`/`0.154256` seconds for startup
(`+41.960417` ms, `+37.3660%`), both within the separate limits.
At cutover `2fa6d16`, native run `38724991914` passes both actual budgets:
full export `44.715197`/`48.455601` seconds (`+8.3650%`), startup
`0.124042`/`0.149827` seconds (`+25.785370` ms, `+20.7876%`).
The lifecycle cell and 17 of 18 callers pass. `replay-initial_ck_secret`
fails during assembled export because the unchanged strict `60`-second
derivation check times out, before its selected proof. The exact local
caller passes (11-step claim plus five origin helpers); this is not a native
reproduction or a fix. The hosted cause remains unestablished and the failed
run is retained, without a raised limit or manual rerun.
Companion Rust `38724991821` and four-language CodeQL `38724992020` pass.
All current-head hosted gates remain a merge prerequisite; the
[PR #9 checks](https://github.com/trancee/cairn/pull/9/checks) are authoritative
for subsequent documentation-only checkpoints.
Promotion commits/pushes and PR-description updates in PR #9 are authorized;
merge and SDK/profile activation remain unapproved. Full-proof/memory overhead
remains unmeasured.
Native FVP and full assembled acceptance are unchanged.

The 53-audit boundary checkpoint was published at `3d5dd7c`.
Its [formal run](https://github.com/trancee/cairn/actions/runs/38622779805)
passed the lifecycle cell but failed all 18 replay/mutation cells: Tamarin's
derivation checker changes natural variables to Fresh inside natural sums.
The owner selected `extend-derivation-kind-image`. A disjoint Fresh/natural
shadow encoding now proves injectivity, raw AC/rewrite transfer, image closure
and decoded-kind termination. Substitution commutation is unconditional;
framed closure still has an explicit typed-shadow compatibility premise.
The guard admits these controlled kind queries, not arbitrary sum operands,
kind variables or kind-valued returned bindings/results. Raw rules omit
native message-sort guards, so these kind results do not transfer
controlled-kind confluence, normalization-path existence or narrowing/FVP completeness.

At the preceding local extension checkpoint, the fresh fast gate passed
117 model tests, 50 lifecycle tests, 43 projections and all 67 equation audits.
The guarded default recovery witness and 56 refined safety certificates replay
successfully with unchanged 43 rules/13 restrictions and deadlines.
Both actual mutation regressions also preserve their verified defaults and
expected 504-/526-step counterexamples.
Selected contexts do not establish full assembled acceptance; full native acceptance is still incomplete as recorded above.

The earlier termination-only checkpoint passed final-source formal/Rust/
four-language CodeQL acceptance in PR #9 at `70c1c19`. Native bookkeeping
hypotheses, universal query-builder/importer correspondence, narrowing/
unification closure, sorted AC-unification/FVP acceptance and full assembled replay remain
open. The owner selected the actual protocol-query image, extended to required
derivation-kind terms, not the entire arithmetic/error-kind carrier.
No merge, profile activation or SDK/ratchet
implementation approval is implied. Earlier sections below are snapshots.

## Current equation termination evidence (2026-10-14)

The [equation termination checker](docs/spec/models/equations/README.md) now
kernel-checks all six expanded source equations in every typed message context
modulo sorted natural AC, with mandatory theorem axiom audits and generated
source correspondences. It shares the exact equation inventory/audit helpers
with the lifecycle gate and runs in the existing fast/CI lifecycle cell.
At authoring, local proof/source-boundary checks pass; hosted validation of
this snapshot is pending. Published revision status is recorded by its PR/CI.
Native flat-pattern exhaustion and sorted CRC checks are supporting
evidence, not a combined FVP certificate: source/signature transfer and
admissibility/coherence hypotheses remain unverified. Full assembled replay
also remains incomplete. No profile activation, SDK/ratchet implementation,
protocol, public API, wire, primitive or constant-time claim change is authorized.

## Current ratchet evidence (2026-10-13)

The opt-in `DISCLOSURE_SOURCES` profile now reports complete refined
deconstructions (43 groups, zero residual chains), using a Tamarin-generated
joint KEM/CT-tail source certificate verified against raw sources in 60 steps.
All 56 completed safety certificates replay together, and all four
honest/recovery witnesses replay independently against the same 43 rules and
13 restrictions. The fresh-secret origin certificate is migrated with unchanged
formula/attributes. The runner fails closed on incomplete source evidence;
local/CI gate definitions cover the joint source, complete safety and witnesses.

The three serialization claims use the accepted Lean compositional gate.
Full assembled replay was system-killed with exit 137 before a summary.
All 19 formal jobs passed at `85aa105` in
[run 38442377893](https://github.com/trancee/cairn/actions/runs/38442377893).
A separate full-context hint-hiding experiment timed out and was discarded.
Independent mixed-equation/FVP acceptance remains outstanding.
Default activation and ratchet implementation
are not authorized by these partial-context results. Earlier source counts
and replay results elsewhere in this profile are historical; the
[current source evidence](docs/spec/models/ratchet-source-evidence.md#current-result-2026-10-13)
is authoritative for this increment. No protocol, API, wire, primitive,
runtime dependency or constant-time claim changes.

## Standalone binding proof

The [Linux/Android fixture](proofs/bindings/linux-android/README.md) preserves
the exact owner-tested standalone Ubique source and Cargo lockfile. It is
separate from `core/`, exports only arithmetic/Greeter test APIs and does not
implement protocol or SDK behavior. Its README records the
`{module,target,host,prerequisites,task,proof,limitations}` matrix and the
interop-specific Rust 1.97.1/Kotlin 2.4.20/Gradle 9.7.0/AGP 9.3.1 tuple.
Owner-reported offline JVM calls and Android debug APK execution on an API 26
x86_64 emulator passed. Repository scripts from commit `8deda79` also passed
an owner-authorized SSH replay: 69 actionable tasks executed, followed by
Android instrumentation, with matching AAR/APK/transcript hashes. Retained
dependency/Cargo caches were used; this is not a fresh disposable image. No default CI
gate, accepted final sandbox, Compose, ARM64 hardware,
release/R8 or iOS binding proof is implied. The foundation-specific platform
claims below are unchanged.
The [bounded allocator evidence](proofs/bindings/linux-android/ALLOCATOR-AUDIT.md)
covers the fixture and delivered Linux/Android runtime ELFs, not Apple or
future dependency graphs.
The standalone build script now self-checks read-only actual source,
configuration and downloaded dependency mounts; its forced 69-task build
passed with unchanged artifacts. Writable Gradle project shells/metadata and
retained outputs remain explicit limitations, not final runner acceptance.
Android instrumentation also passes in a private runtime network namespace
with explicit route-denial assertions and verified emulator cleanup. A
disposable 16 GiB loop-backed runtime volume bounds fresh AVD/artifact/temp writes;
over-capacity allocation fails with `ENOSPC`, and cleanup is verified.
The unbooted root-owned AVD seed passes checksum checks before/after runtime;
the smoke package is absent before installation. Owner-supplied console output
also records a cold networkless clone replay: all 69 build tasks executed,
JVM assertions and fresh Android instrumentation passed, and the AAR hash
matched. The APK hash differed from the historical artifact; byte-identical
APK reproduction is not established. Owner-supplied host checks verify unchanged
base bytes and a sole overlay disk backed by the independent base, with no
NIC/shares/passthrough/guest-agent channel in live XML. A base-specific DAC
override passed live QEMU-account write denial and start/stop ownership/hash
checks. Read-only journal extraction and explicitly authorized proof-domain/
overlay disposal passed, retaining base and evidence. Full namespace
immutability and final runner acceptance remain open.
The separated canonical-input layout also passed a new networkless clone:
69 forced tasks, read-only/same-object source and dependency mapping assertions,
unchanged canonical manifest and fresh Android instrumentation. Its base
write denial, shutdown, read-only journal preservation and explicitly
authorized overlay disposal passed. Canonical inputs are immutable in the
build namespace; project shells and cache coordination metadata remain
writable disposable state. This does not close full runner or Apple acceptance.
The bounded supervisor also passed cold and resumed replay with live cgroup/
rlimit assertions and checksum-verified captured output below 64 MiB. The
resumed run's live base write denial and shutdown/extraction metadata checks
passed. Direct-backend extraction avoids the reproduced libvirt appliance
ownership change. The stopped bounded overlay is retained by owner choice.
Emulator diagnostics and instrumentation now stream into the shared 64 MiB
collector. A real preparation-guest red/green routing proof passed, with
7,307 bytes captured after the change; saved current script/manifest are
updated. No new cold-clone routing proof is claimed. Earlier emulator
timeout/segfault and aggregate journal/evidence retention remain limitations;
successful replay is not a deterministic reliability claim.
New host extraction now uses the owner-approved 1 GiB ext4 evidence-image
boundary with explicit failure and preserved incomplete output.
Real synthetic CLI tests pass on the preparation guest and Fedora direct
guestfish synthetic integration passes. Owner-run stopped bounded-VM journal
extraction in the new format also passes, preserving image bytes/ownership
and both boot logs with complete status and unmount cleanup.
Existing evidence stays unchanged. See
[ADR 0013](docs/adr/0013-bounded-host-proof-evidence.md) for access-format
migration and the excluded guest/appliance/aggregate storage surfaces.
The owner subsequently approved 8 GiB NEW host aggregate storage, 4 GiB
appliance scratch and 1 GiB guest logging, without eviction, plus a separate
new clone. Host scripts now reserve full images inside the aggregate store;
profile/composition tests pass on Ubuntu and Fedora. Fedora direct guestfish
synthetic extraction with bounded scratch also passes with unchanged source
bytes/ownership. V4 subsequently verified new-clone extraction and guest
logging controls as recorded below. Apple stays paused. The retention clone has a separate 1 GiB
raw log disk; its supervisor reserves replay output before execution and
disables duplicate persistent logging only inside that networkless clone.
Linux collector reservation and no-command-on-ENOSPC tests pass.
Supervisors are installed on preparation; its boot condition correctly skips.
Earlier retention boots failed before target work as recorded below.
The first retention boot failed before target work because kernel disk
enumeration reversed proof/root devices. It is stopped and preserved.
The corrected supervisor resolves the unique `CAIRN_PROOF_LOGS` ext4 label,
validating 1 GiB capacity; real Linux identity/failure tests pass.
The `retention-v2` boot resolved the log disk but failed before target work:
active `syslog.socket` reactivated rsyslog during cutover. Both failed clones
are preserved. Trigger-first stopping/masking and runtime-mask identity
checks pass a shared-helper real synthetic systemd test.
V3 failed before replay on retained `logrotate.timer` failed state after
masking; disks/evidence are preserved. Explicit prior-failure reporting and
post-disable state normalization pass real synthetic failed-unit tests.
The timer's original boot failure remains unverified.
The owner approved a separate V4 clone, preserving V1/V2/V3. Startup cutover
now uses the existing reserved 64 MiB collector on the 1 GiB proof disk,
before journald changes; replay retains its separate unchanged 64 MiB limit.
Real synthetic systemd output-capture red/green passed, including retained
failure diagnostics and child exit. Owner-run V4 passed all 69 cold-build tasks,
JVM assertions and fresh Android instrumentation (20.565s, 4.6G peak, zero swap).
Live topology/base write denial and graceful shutdown passed. Read-only
extraction verified matching startup/replay records for boot
`67e02a91-1f25-4721-b9a9-31cae6343de2`, resource/logging markers and unchanged
base/overlay/log-disk bytes and metadata. Complete root-only 1 GiB evidence is
`bounded-store/retention-v4-replay-volume.ext4`; bounded appliance scratch was
removed and all clones retained. This closes the retention-control integration,
not earlier emulator instability or full Linux runner acceptance.

## Verified profile

Post-merge CodeQL's automatic Kotlin trial failed `none`-mode extraction in
run `38249821951`; default Actions/Python/Rust scanning initially remained configured.
The owner approved a build-backed advanced-setup migration preserving strict
offline build controls. Run `38263225443` at `799d758` verifies actual Kotlin
database finalization inside the Apple cell with the approved exact
CodeQL-only `/opt` parent read; downloaded metadata and archive agree.
Run `38268914707` verifies Actions/Python/Rust analyses and actual Kotlin
compilation-unit coverage for all three tracked and both generated binding
sources, plus bundled query execution. Kotlin SARIF mapping subsequently
fails on an implicit URI base; the standard `%SRCROOT%` interpretation is
corrected and failed-report retention added.
Run `38274027100`, attempt 2, at `6618ecb` verifies the complete four-language
upload-free replacement, including mapped Kotlin export, input integrity,
UID cleanup and scratch teardown. Downloaded actual raw/mapped SARIF replay
and compiled-source manifest checks agree; Kotlin reports zero results.
Attempt 1 fails preflight scratch-device lookup before target work; unchanged failed
jobs are replayed, not automatically retried or given larger limits.
The staged advanced workflow preserves all existing languages
and supports upload-free feature-branch/dispatch validation. CodeQL mode
omits native-only framework/executable proof, payload export and unrelated
functional simulator runtime; ordinary binding mode retains them with
unchanged controls. The owner subsequently approved PR #6 merge and the
coordinated setting transition. Default setup is now disabled; PR
run `38279234281` passed and GitHub processed all four language analyses
at merge revision `f36da6130053e89070c3ec6ec785daf2bfacfb5c`.
Branch run `38279051559` completed Kotlin analysis but failed scratch
teardown; its failed jobs are replayed with unchanged controls.
Deployment and processed scans on `main` remain pending.
See [ADR 0015](docs/adr/0015-build-backed-kotlin-codeql.md).

The owner now permits a separate normal-user functional CoreSimulator job on
the supplied fresh GitHub `macos-26` VM. The owning workflow retains strict
offline build controls and transfers only the canonical simulator smoke
executable, checksum and source revision to that fresh runtime VM.
[Run 38228998011, attempt 2](https://github.com/trancee/cairn/actions/runs/38228998011/attempts/2)
at `19c35ba` passed delivered ARM64 simulator generated calls, typed overflow,
string/object-lifetime assertions and exact-device cleanup. Preflight and strict
build passed in attempt 1; only its failed runtime job was replayed with the
same checksum/revision-verified payload and unchanged limits on a fresh VM.
Attempt 1 timed out during simulator creation/cleanup inventory, so reliable
first-attempt execution is not established. Functional success does not close
strict helper containment, issue-45 acceptance or physical-device proof.
See the current lane contract
in the [Apple proof README](proofs/bindings/apple/README.md).

Apple isolation assessment has resumed using benign
[hosted probes](proofs/bindings/apple/README.md) under
[ADR 0014](docs/adr/0014-hosted-apple-isolation-probes.md). The unprotected
local CLI failed intended input denial; sandboxed probes passed locally.
Hosted [run 38088954525](https://github.com/trancee/cairn/actions/runs/38088954525)
at `608dee0` passed the same benign probes on ARM64 macOS 26.6.2/Xcode 26.6;
downloaded log/environment checksums passed. Full isolation/resource
enforcement and binding builds remain unverified. Subsequent
[run 38090454490](https://github.com/trancee/cairn/actions/runs/38090454490)
at `3db7ee7` verified unprivileged sandbox/fixed-scratch composition,
real disk/process/CPU enforcement, and a 7 GiB whole-VM RAM envelope
with dynamic pager disabled/unloaded and zero swap. Shared collector
deadline regressions passed; downloaded artifact checksums passed.
Build-tool compatibility and whole-process-tree containment remain open.
Trusted preparation subsequently passed in
[run 38090961772](https://github.com/trancee/cairn/actions/runs/38090961772)
at `3ffd8cf`: pinned Rust/iOS targets, checksum-verified Gradle and exact
Temurin 25.0.4.1+1, plus locked fixture/Ubique Cargo downloads. No fixture
compiled; frozen inputs, offline completeness and build-scale controls
remain unverified.
The dedicated hosted supervisor subsequently passed
[run 38093375336](https://github.com/trancee/cairn/actions/runs/38093375336)
at `3e19313`: deadline cleanup removes a deliberately detached descendant,
retains partial output and confirms the UID is empty. A child observed hard/
soft CPU 900s, NPROC 128, per-file 64 MiB, zero core limits, only primary GID
20 and an explicit environment. Subsequent
[run 38095349642](https://github.com/trancee/cairn/actions/runs/38095349642)
at `cee5a9d` composed the sandbox, fully backed 8 GiB scratch and trusted
Rust/Cargo/JDK/Gradle version commands; frozen tool hashes remained unchanged.
The named read policy also rejected accessible unrelated host data.
Fixture/Maven/Native input freezing, Gradle initialization/IPC, actual
compilation and generated runtime calls remain unverified.
Trusted empty-project initialization in
[run 38095639900](https://github.com/trancee/cairn/actions/runs/38095639900)
failed on Gradle's required wildcard UDP lock-service socket; `--offline`
does not remove this IPC requirement. A proven external/cross-UID network
boundary and owner approval are required before permitting those sockets.
The owner subsequently approved benign PF probes. Private-loopback
UID isolation and trusted offline empty Gradle `help` pass in
[run 38124841659](https://github.com/trancee/cairn/actions/runs/38124841659)
at `89fbb05`, with unchanged copied tool hashes and named PF cleanup.
TCP cross-UID/external denials and same-UID TCP/UDP roundtrip pass;
UDP negative/adversarial coverage and frozen fixture/Maven/Native inputs
remain open before any binding build.
UDP negatives exposed a reverse cross-UID state gap and passed after an
outbound private-alias origin rule in
[run 38125239632](https://github.com/trancee/cairn/actions/runs/38125239632)
at `c6204b0`. Frozen fixture/Maven/Native inputs and binding compilation/
runtime remain unverified; no fixture build ran.
Shared fixture settings are verified in
[run 38127148746](https://github.com/trancee/cairn/actions/runs/38127148746)
at `5016e70`: unsupported selections fail before project plugins; default
and explicit Linux/Android retain all three module/build-file selections,
and explicit Apple selects SDK/consumer with `sdk/apple.gradle.kts`.
These are actual Gradle settings checks with empty project scripts, not
effective Kotlin target configuration or binding compilation. Tool hashes,
resource/socket controls and ordinary cleanup passed. An earlier scratch
detach `Resource busy` failure remains unexplained, not fixed by later greens.
No production Apple
acceptance is implied.
Trusted scratch-device creation passed `38165989640`. Boot attempts
`38167434234`/`38168165135` expired the 60-second limit; shutdown/UID cleanup
did not complete and scratch detach failed busy. Launchd-parented simulator
services were observed. Simulator lifecycle/containment remains incomplete;
no generated app or simulator calls ran.
Exact user-domain teardown/empty UID are now verified, including
`38220908711`; ordinary detach passed in that run. Actual selected bootstrap
UID 59000 passes its supervisor regression, but boot still times out at the
separately approved 300-second ceiling in LaunchServices migration.
A prior 120-second snapshot showed 166 dedicated-UID processes, so caller
128-process limits do not bound launchd helpers. Failed profiler code was
removed; no runtime acceptance or generated simulator calls are implied.

Offline effective Apple plugin configuration passed in
[run 38130344648](https://github.com/trancee/cairn/actions/runs/38130344648)
at `2472082` with JVM/iOS-device ARM64/simulator ARM64 targets. Pinned-plugin
preparation seeds read-only Gradle dependencies; tool/dependency hashes remain
unchanged after replay. The owner-approved child per-file ceiling is now
128 MiB (actual boundary/next-byte rejection pass); the separate streamed
output remains 64 MiB. The instrumented Kotlin plugin is 67,326,033 bytes,
exceeding the old 64 MiB file limit. No-swap setup now precedes provisioning.
Kotlin/Native compiler/cinterop caches, Cargo input freezing, allocator review,
binding generation and generated runtime calls remain unverified.

External Apple configuration artifacts and native cinterop metadata extraction
passed offline in run `38131639643`. Immutable Cargo vendor metadata passed
fixture/bindgen/runtime across Darwin/device/simulator ARM64 in run
`38132518944`. The official checksum-verified Kotlin/Native distribution
starts offline, and script-owned arithmetic KLIBs compile for device and
simulator ARM64 in
[run 38133904604](https://github.com/trancee/cairn/actions/runs/38133904604)
at `adc22c5`. All seed/tool hashes and cleanup passed. These are input and
trusted compiler probes, not FFI, native linkage, fixture or runtime proof.
Native SDK/cinterop/linker access, Apple allocator evidence and binding
generation/generated calls remain open.

Trusted header cinterop subsequently passed offline for both ARM64 targets
in [run 38136851477](https://github.com/trancee/cairn/actions/runs/38136851477)
at `74673d1`. LLVM/libffi inputs are frozen read-only; airplane mode and
blanket socket denial remain active. All tool/Gradle/Cargo/Native hash checks
and cleanup pass. Linkage/deployment-floor inspection, allocator evidence,
fixture generation/compilation and runtime remain open.

Trusted arithmetic framework linkage and actual `IOS`/`IOSSIMULATOR`
Mach-O minimum OS `15.0` inspection passed offline in
[run 38137529578](https://github.com/trancee/cairn/actions/runs/38137529578)
at `f7f4eca`, without extra downloads. Frozen hashes and cleanup pass.
These script-owned frameworks do not establish fixture packaging, allocator
compatibility, generated calls or device runtime.

[Apple allocator evidence](proofs/bindings/apple/ALLOCATOR-AUDIT.md) records
bounded source closures and actual default-allocator thunk forwarding in
delivered Darwin/device/simulator ARM64 runtimes (`38143105757`).
Actual shared-fixture Rust compilation passed all three targets in run
`38143726072`; fixture default-allocator thunks/generated-Rust scans then
passed in runs `38144367463` and `38145166981`. No generated FFI calls ran.
Both bindgen compilation attempts expired the unchanged 60-second command
deadline during `uniffi_bindgen`; sharing fingerprinted Cargo scratch did
not close it. Binding generation/compilation/runtime remain incomplete.

The owner subsequently approved 300-second actual build/generation cells,
keeping trusted probes at 60 seconds and other budgets unchanged.
Run `38146169370` compiled the diagnostic debug generator in 3m09s,
then the owning Gradle optimized `installBindgen` hit its 300-second ceiling.
Bindings and generated calls remain incomplete; no unsupported prebuilt
generator injection or validation bypass is used.

The owner then approved 600 seconds for optimized `installBindgen` only,
with the redundant diagnostic debug build removed. Runs `38147417409` and
`38149099333` still expired installation. The latter passed one-shot
owned-process diagnostic regressions: at 540 seconds `rustc` was runnable
with 6m56s CPU, not an observed lock/network wait. Exact checksum-verified
compile JDK is now Temurin `21.0.12.1+1`, matching the actual prior JVM
rather than its misleading hosted-cache directory name. UID cleanup passed;
ordinary scratch detach again failed `Resource busy`. No generated bindings
or FFI calls, optimizer change, complete reliability or runner acceptance
is claimed.

Subsequent owner-approved generator-only debug installation passed the
plugin's owning install/fingerprint path; binding generation passed in
`38150603530`. Actual immutable JVM consumer calls passed in `38151849548`,
and generated device/simulator/common Native compilation in `38154100996`
after moving commonizer outputs/locks to a scratch distribution shell whose
inputs still point to the immutable seed. Actual fixture frameworks passed
device/simulator Mach-O minimum OS `15.0` checks in
[run 38155697269](https://github.com/trancee/cairn/actions/runs/38155697269)
at `ef2302e`. All seed hashes and ordinary cleanup passed in those green runs.
Generator-only debug is an explicitly approved build-tool profile difference;
SDK Rust profiles/default Linux behavior remain unchanged.
Simulator generated-call runtime, physical iPhone proof, earlier busy-detach
reliability and final runner acceptance remain open.

The trusted scratch-device-set simulator inventory failed under unchanged
socket/Mach denial in
[run 38157170214](https://github.com/trancee/cairn/actions/runs/38157170214)
at `f62938f`: CoreSimulator connection/subscription refused. Earlier JVM
calls and both framework links passed; UID cleanup and ordinary detach passed.
Final workflow input-hash checks were not reached. Targeted denial collection
now runs before expensive fixture work; no service allowance or simulator
boot/generated call is authorized by this diagnostic.
Narrowed replay `38158407544` at `98e52e6` confirms denied Mach lookup of
CoreSimulatorService and simdiskimaged, with UID cleanup/ordinary detach.
Service-helper containment is unverified; no service allowance was added.
The owner subsequently approved a separate trusted inventory-only profile
with exactly those two lookups and helper identity/resource observations.
Generated/build commands remain unchanged; no boot or runtime is permitted.
Run `38159023923` reached JSON inventory but failed available-iOS validation;
root-owned simdiskimaged was observed after caller-UID cleanup. Additional
service/device denials remain unchanged. Scratch capacity/ordinary detach
passed; helper containment and simulator runtime remain open.
The owner approved one further inventory-only SimLaunchHost-arm64 lookup
experiment, with unchanged other denials/deadline and no boot/generated calls.
Hosted ARM64 nested virtualization is officially unsupported; helper
containment remains a separate prerequisite.
The three-lookup trusted inventory passed in run `38162040714` at `cd7f2ae`:
12 records, available iOS `26.2`/`26.4.1`/`26.5`. Actual JVM/Native/framework
gates, all input hashes and ordinary cleanup passed again. Root simdiskimaged
remained observable; no simulator boot/generated calls or containment
acceptance is implied.

- **Public documentation:** [README.md](README.md) introduces the current
  scope; [the documentation entry point](docs/README.md) links the runnable
  wire tutorial, contributor validation guide, foundation API reference and
  compact-PQ/BLE design explanation. Local Markdown links are checked with
  the activated Diataxis skill's `scripts/check-links.py`; no repository
  Markdown formatter or spelling gate is configured. All three Mermaid
  diagrams render with `@mermaid-js/mermaid-cli` 12.0.0 and the installed
  Chrome browser. This is a local documentation check, not a new CI gate.
- **Purpose:** specify and verify `cairn-r1` before implementing the SDK.
- **Languages/toolchains:** Markdown specification and Tamarin `.spthy` models;
  model commands use Tamarin 1.12.0 and Maude 3.5.1.
  The `core/` Cargo workspace pins Rust 1.99.0 for the public wire codecs and
  partial SHA-384/HMAC/HKDF backend seam (AWS-LC and RustCrypto).
  [Core documentation](core/README.md) lists the feature selection, vectors,
  dependencies, commands and remaining gates; [ADR 0012](docs/adr/0012-rust-foundation-increment.md)
  bounds this increment. No protocol state machines or FFI exist yet.
- **Platforms:** formal checks have run on macOS/Apple silicon. Android/iOS
  are intended application targets, not implemented or runtime-tested here.
  Both foundation crates/all backends now cross-compile as release libraries
  for iOS device/simulator ARM64 with Xcode 27 SDKs; this is not linked-app,
  packaged-binding, deployment-floor or device proof. Both crates/all backends
  also cross-compile as release libraries for Android API 26 arm64-v8a,
  armeabi-v7a and x86_64 with cargo-ndk 4.1.2 and NDK r30
  (`30.0.16248370`). No APK, linked shared-library or Android runtime proof
  exists.
  Rust foundation gates pass locally on macOS ARM64 and in all 11 jobs of
  [hosted run 37963154963](https://github.com/trancee/cairn/actions/runs/37963154963)
  at `4ba4955`, including Linux x86-64/ARM64, macOS and mobile cross-builds.
- **Prerequisites/setup:** tool installation is documented in
  [`docs/spec/models/README.md`](docs/spec/models/README.md#tooling).
- **Environment:** before running Tamarin, replay or `act`, read
  [`docs/spec/models/ENVIRONMENT.md`](docs/spec/models/ENVIRONMENT.md);
  `scripts/check.sh` runs the fast gates (also the pre-commit hook and CI).
  `bash scripts/check-rust.sh` runs Rust format/clippy/tests and cargo-deny;
  the pre-commit hook additionally calls it. Miri/careful use the pinned
  nightly in the Rust workflow. Local source line/branch coverage is now
  100% for both crates; error-propagation regions remain uncovered.
  Other ADR 0007
  gates remain incomplete ([issue 46](.scratch/cairn-r1/issues/46-rust-foundation-gates.md)).
  The standalone `core/ct` Memcheck driver (`bash scripts/check-ct.sh`)
  passes both primitive adapters in Linux x86-64/Rosetta and native ARM64
  containers, with required branch/address controls and output-taint checks.
  Hosted native taint jobs also pass with Valgrind 3.22.0.
  Mobile constant-time behavior and unimplemented protocol glue remain
  outside that result.
- **Targeted validation:** from the repository root,
  `tamarin-prover docs/spec/models/ratchet.spthy --open-chains=0 --saturation=0 --derivcheck-timeout=30`
  checks model loading/wellformedness, not lemma verification.
  `--prove=lemma_name` selects a proof obligation.
- **Full validation:** the model README gives full Resume/SAS profiles and
  regression commands. A prior reduced-model diagnosis incorrectly removed
  the `LockStage` marker from release because its `Finish` rule omitted the
  stage increment present in the assembled theory. The marker has been
  restored. The last completed assembled replay verified 55/59 obligations on
  the same marker behavior; a fresh strict replay timed out at 360 seconds.
  The isolated `lock_stage_order` search also timed out at 300 seconds, so
  current full-theory completion remains unverified. A proof-search-only
  relocation of `LockStage` to finish actions timed out on both stage-order
  targets and was reverted. Alternative lifecycle/initial-lock tactics and
  no-reuse induction also timed out; the interactive overview stalled.
  See the model README for exact bounds and limitations.
  These three lifecycle claims now also have compositional evidence:
  Lean 4.34.1 induction and token simulation, arbitrary-key interleavings,
  and source-derived certificates for all 43 rules. Run
  `python3 docs/spec/models/lifecycle/check.py --lean /path/to/lean`.
  The source bridge trusts Tamarin's canonical export and the tested Python
  extractor; it is not native Tamarin replay or a verified Tamarin importer.
  The pin, setup and full trust boundary are in the
  [lifecycle reference](docs/spec/models/lifecycle/README.md).
  `lost_data_recovery` has a verified 826-step witness against a theory with
  the same signature, equations, 43 rules and 13 restrictions; its
  assembled-layout strict replay was system-killed with exit 137 after about
  48 minutes. Repository-owned exact-source replay now verifies that witness
  in 826 steps and its sole source lemma in 9 steps:
  `python3 docs/spec/models/replay.py --timeout 180`.
  It preserves every non-lemma declaration and retained certificate through
  a native MSR roundtrip, removes unrelated lemmas and does not start new
  searches with `--prove`. Full-context certificate-only replay still timed
  out at 300 seconds; assembled completion remains unverified (re-run: both profiles exhaust the 5 GiB heap, no lemma result).
  The [source inventory](docs/spec/models/ratchet-source-evidence.md)
  accounts for 43 goal groups/179 branches; the raw inventory has 30
  residual CK/SS disclosure chains, while the current refined profile has
  16 `Reveal_SS` residual chains. The
  [equation review](docs/spec/models/ratchet-equation-evidence.md) supplies
  an internal termination/confluence/FVP rationale. Separate
  [checker research](docs/research/2026-10-09-tamarin-equational-theory-independent-checkers.md)
  records Tamarin's subterm-convergence check and an external CRC
  local-confluence check on the reduced message equations; CRC assumes
  termination. Neither closes independent combined-theory/FVP acceptance.
  Both gates remain open.
  The opt-in proof-only `DISCLOSURE_SOURCES` profile proves CK/SS
  disclosure origins in 12/8 steps. Before the KEM-origin `[sources]`
  promotion it had 15 refined residual chains; the current profile has 16,
  all `Reveal_SS`. Run
  `python3 docs/spec/models/replay.py --disclosure-sources`. It replays the
  unchanged lost-data certificate in 802 steps and all three source
  certificates. Default proof contexts are unchanged:
  all eight existing safety certificates are migrated in the refined profile.
  No application or SDK build/compatibility gate is available.
- **CI gates/code generation:** no application pipeline or generated SDK
  artifacts exist. Future implementation gates are in the local
  [map](.scratch/cairn-r1/map.md); symbolic verification is not a
  constant-time, byte-parser, persistence or hardware proof.
  The lifecycle runner regenerates proof certificates into a temporary
  directory. The [lifecycle workflow](.github/workflows/lifecycle.yml)
  configures Ubuntu 24.04 matrix jobs with Python 3.13.16, Lean 4.34.1,
  Tamarin 1.12.0 and Maude 3.5.1; official tool archives have pinned hashes
  and actions have immutable revisions. Local actionlint validation and the
  macOS lifecycle runner pass. The first hosted run passed the lifecycle
  gate, both witnesses, KEM origin and fresh-DK origin, then hit the shared
  15-minute job timeout. Each of the eleven replays now has its own 15-minute
  matrix job, separate from the lifecycle gate, with fail-fast disabled.
  The merged matrix run
  [37952930237](https://github.com/trancee/cairn/actions/runs/37952930237)
  is successful; required-check enforcement remains unverified. The same
  workflow also runs default and opt-in disclosure-profile exact-source
  witness replay, refined-certificate replays and its 42 regressions.
  `python3 docs/spec/models/replay.py --disclosure-sources --target kem_ciphertext_origin`
  verifies the KEM origin `[sources]` certificate in 31 steps with all
  three source certificates. Default KEM replay remains 31 steps.
  All eight refined certificates are migrated (`--target`
  `kem_ciphertext_origin`, `fresh_dk_origin`, `encrypted_origin`,
  `extract_origin`,   `ratchet_key_origin`, `session_key_origin`,
  `initial_ck_secret`, `fresh_ss_origin`). After the KEM-origin `[sources]`
  promotion, the exact-prefix safety-only context built from the current
  native export verified 55/55 complete all-traces certificates. It excludes
  the three incomplete serialization lemmas and four existential witnesses;
  it does not establish assembled/full-profile completion. Exact commands,
  hashes, and exclusions are recorded in the
  [source evidence](docs/spec/models/ratchet-source-evidence.md#combined-safety-only-context).
  The focused `encrypted_ct_tail_encapsulated` certificate also verifies in
  four steps in default and disclosure-source contexts. It ties an honest
  outgoing CT tail to an earlier encapsulation; it does not establish the
  origin of arbitrary incoming ciphertext or close the 16 residual refined
  SS chains. Promoting the KEM origin lemma to `[sources]` preserved all
  43 rules and 13 restrictions but increased refined precomputation residuals
  from 15 to 16; source closure remains open.
  A local `gh act` 0.2.89 Linux/amd64 run on Colima/Rosetta passed
  checksum installation, lifecycle proofs and replay regressions, but
  default witness replay hit guest OOM; a bounded-runtime retry timed
  out at 300 seconds. The full local job did not pass and did not reach
  disclosure-profile replay.   Hosted formal matrix checks have passed; the
  full assembled-context replay remains inconclusive.
  `python3 docs/spec/models/mutation.py --timeout 180` now establishes native
  mandatory-mix sensitivity: the unchanged default target verifies in 2 steps,
  and `CLASSIC_FALLBACK` falsifies it in 504 steps. The runner checks exact
  transition correspondence apart from the removed guard and uses no helper
  lemmas. `--mutation NO_PREFIX_GUARD` establishes stored-prefix sensitivity:
  the default `no_partial_mix` verifies in 4 steps and the mutation falsifies
  it in 526 steps. Correspondence requires only two added unguarded tail
  rules, with no other default declaration changes. Separate lifecycle
  matrix jobs are configured but have not yet run on a hosted runner.
  The broader ratchet gate remains open; see the
  [mutation reference](docs/spec/models/README.md#native-mandatory-mix-mutation-regression).

Policy authority: [`CONSTITUTION.md`](CONSTITUTION.md)/[`AGENTS.md`](AGENTS.md).

### CI scheduling and setup

Rust and lifecycle workflows run on pull requests, pushes to `main`, merge
groups and manual dispatch. Feature branches without a PR use manual dispatch;
this avoids duplicate push/PR matrices. Superseded PR runs are cancelled, but
main/merge-group/manual runs are not cancelled. All proof, build, test,
coverage and fuzz gates still execute; results and compiled project targets
are not cached.

CodeQL likewise runs on main pushes, PRs targeting main, weekly scans and
manual dispatch; feature branches without a PR use manual validation.
Only superseded PR CodeQL runs are cancelled. Its original all-branch push
trigger duplicated the full strict Kotlin build on PR updates. Observed
baseline at `85aa105`: CodeQL PR 24m16s, Kotlin preparation 20m14s,
formal workflow 6m45s, Rust foundation 2m. Removing duplicate triggers reduces
work, not the duration of one cold analysis; strict build/analysis and upload
gates are unchanged. See [ADR 0015](docs/adr/0015-build-backed-kotlin-codeql.md#post-deployment-scheduling-refinement).
Publication was initially kept local; the owner approved this scheduling
change and bounded same-VM Cargo reuse validation on 2026-10-14.

Setup caches contain version-keyed host tool binaries, lockfile-keyed Cargo
registry downloads and pinned proof archives. Proof archives are checksum
verified after every restore. Cache misses install the same pinned tools.
The Memcheck apt install omits recommended packages, not its requested
prerequisites. New cache actions are pinned to official `v6.1.0`.

Baseline: PR Rust run `37963979548` took 13m32s; its x86-64 taint job spent
9m26s installing prerequisites (55.8 MB at 103 kB/s), then about 63s checking
and executing the harness. The same commit's push Rust run `37963974833`
took 4m22s and its taint job 1m18s. This establishes setup/network variability,
not slow taint execution. Optimization changes require hosted cold/warm
comparison before claiming a measured speedup; queue and mirror latency
remain outside the repository's control.

Hosted comparison at `aa470f2` (2026-10-09):
[Rust run 37966263807](https://github.com/trancee/cairn/actions/runs/37966263807)
passed all 11 jobs in 3m39s cold and 2m11s warm (attempt 2);
[lifecycle run 37966263691](https://github.com/trancee/cairn/actions/runs/37966263691)
passed all 11 jobs in 4m56s cold and 4m55s warm.
Logs confirm warm binary/registry/archive cache hits. Same-PR reruns preserve
cache scope; manual dispatch cannot read PR-merge-ref caches.
The warm Rust reduction was 40% in this sample; lifecycle wall time did not
materially improve because proof replay/queueing still dominates. These are
single-run observations, not a guaranteed latency budget or attribution of
the anomalous baseline's full 13m32s to repository-controlled work.

Pre-merge scan (2026-10-09): Gitleaks 8.30.1 scanned all 11 proposed commits.
Its 204 generic-key findings were confined to the pinned public Wycheproof
and NIST HMAC fixtures; both file checksums matched recorded upstream
provenance. A temporary exact-findings baseline excluded those known vector
matches, and the remaining history scan passed. No blanket file exclusion
or repository scan suppression was added. This is a point-in-time scan,
not an independent cryptographic/security audit.

Final-head lifecycle run
[37967905307](https://github.com/trancee/cairn/actions/runs/37967905307)
at `83e2edb` failed in `replay-fresh_dk_origin` with
`tamarin-prover: <<loop>>`, exit 1, after theory closure.
Both canonical hashes match the successful warm run above, and both jobs
used the same runner image version and checksum-verified tool archives.
Ten local replays with the exact Linux archives and matching canonical hashes
verified all five retained certificates, but used Rosetta rather than a
native x86-64 runner. The cause remains unresolved; these passes do not
establish that the intermittent crash is fixed. No retry, runtime workaround
or proof change was added.

The bounded native x86-64 diagnostic
[37970902175](https://github.com/trancee/cairn/actions/runs/37970902175)
at `00a3f0c` verified all five certificates on all 20 unchanged-input
replays (43.77–46.08 seconds each). Canonical hashes matched the failed
run. The job used the same Ubuntu image version, Python 3.13.16,
GHC 9.6.7 and four CPUs, with `GHCRTS` unset and the binary's default
`-N`. The temporary diagnostic workflow and driver were removed after
capturing its seven-day hosted artifact. The ordinary Rust/lifecycle
runs `37970902100`/`37970902125` also passed at `00a3f0c`.
No native crash was reproduced, so its cause remains unresolved.
Passing repetitions do not establish a fix or justify a retry policy.

PR #2 was merged at `65fc089` on 2026-10-09 after every check passed on
final head `ce54305`: [Rust run 37972979064](https://github.com/trancee/cairn/actions/runs/37972979064)
and [lifecycle run 37972978282](https://github.com/trancee/cairn/actions/runs/37972978282)
each passed all 11 jobs, and CodeQL passed. The feature branch was deleted.
This accepts only ADR 0012's bounded foundation, not S0 or the full protocol.
Post-merge results are separate from this final-PR-head evidence.

Post-merge Rust run
[37973820517](https://github.com/trancee/cairn/actions/runs/37973820517)
passed at `65fc089`. Lifecycle run
[37973820415](https://github.com/trancee/cairn/actions/runs/37973820415)
failed in `replay-encrypted_origin` during tool installation: `curl` exit 56,
`Recv failure: Connection reset by peer`. Its proof step did not run.
This is a download failure, not the earlier Tamarin `<<loop>>` symptom
or a reported counterexample. No successful post-merge formal run is claimed.

### Frozen-input manifest generation

Apple tool/Gradle/Cargo/Native preparation now shares a streaming SHA-256
manifest generator, preserving byte-sorted `shasum` records and the independent
post-cell `shasum --check` gates. Copies, root/read-only setup, pinned inputs,
fresh compilation and limits are unchanged; empty or unreadable inventories
fail explicitly. The retained component benchmark compares the real CLI
against the committed `a6b0767` pipeline with identical manifests, source/
environment/workload hashes and a 10% improvement threshold. On the local
1.21 GB Rust `1.99.0` tool tree, the median changed from `3.79s` to `0.68s`;
full hosted preparation/CodeQL improvement remains unverified.
Initial hosted freeze steps took `162s`/`242s` versus `139s`; both strict cells
failed (unexpected UID processes or startup deadline). The later same-VM
full-tree A/B at `a8fff9e` verifies identical manifests for 80,635 files/
5,860,115,366 bytes: median `76.27s` to `46.17s` (39.5% lower).
The supplied three-CPU ARM64 VM reports macOS `26.6.2`, Xcode Python `3.9.6`
and LibreSSL `2.8.3`. Profiling overhead exhausted that manual job's unchanged
30-minute ceiling; ordinary PR/push CodeQL and Rust/formal gates pass at the
same revision. Tagged timing/manual profiling are removed; normal CI has no
benchmark overhead. No end-to-end speedup or reliability fix is established.
Unexpected processes are reported, never trusted or pre-cleaned.
Commands and scope are in the
[Apple reference](proofs/bindings/apple/README.md#frozen-input-manifest-generation).
No protocol, public API, compiler profile or constant-time claim changes.
Final cleanup head `db68586` fails Kotlin acceptance on scratch detach,
one-shot snapshot or offline effective-target expiry; final non-Kotlin scans,
Rust and formal gates pass. The target script now streams partial Gradle
diagnostics into the existing bounded collector with unchanged exit/budget
semantics, verified by real-script timeout/error tests. Hosted manual probe
`38514098575` passes; PR `38513991094` passes offline targets then rejects
UID-59000 `distnoted`, with unestablished helper origin/lifetime. Formal
`38513991093` separately fails unchanged Tamarin mutation replay (`<<loop>>`).
Push `38513985911` completes Kotlin extraction/coverage/queries but fails
ordinary scratch detach before mandatory input-integrity/delivery gates.
Temporary startup/snapshot tracing is removed. Cleanup-head `8b4c2d6` PR
CodeQL/Rust/formal gates pass; all four PR scans process at
`47a9c5207514ea28f5ab7393233148ced60dc5b5` without errors. Duplicate push
`38515598161` fails both attempts. Deterministic reliability is not established.

### Same-VM generator reuse evaluation

The approved experiment at `75c5623` aligned the owning bindgen directory
and explicit host target with preceding fixture compilation, preserving
all plugin/Cargo fingerprints, SDK profiles, bounds and security gates.
Three complete independent same-VM comparisons at unchanged-source attempt 2
(`38525913102`, `38529286247`, `38529289684`) verify all input checksums and
both execution orders. Median paired ratio is `1.06195`: about 6.2% slower,
despite 36 reused artifact records and fewer compiled records (103 to 72).
The ordinary Native/runtime case and CodeQL/Rust/formal/processed scan gates
pass at experiment revision `75c5623`. First attempts fail existing helper refusal or disk-query
timeout; their one explicit replay each does not establish reliability.
The experiment is not adopted; its code/tests/dispatch paths are removed,
restoring `8b4c2d6` compiler/task behavior exactly while keeping the
duplicate-scheduling fix. Reproducible experiment source remains in
committed `75c5623`; results and limitations are in the
[Apple reference](proofs/bindings/apple/README.md#generator-reuse-evaluation)
and [PR #8](https://github.com/trancee/cairn/pull/8).

The schema below is retained for the future implementation profile.

```text
profile={purpose,languages/toolchains,supported_platforms/version_constraints,prerequisites,setup/bootstrap,
targeted/full_validation,CI_gates,code_generation}
KMP_add={
version/config_owners:{wrapper,catalog,conventions,included_builds,daemon_JDK,compile_toolchains/bytecode},
target_host_proof_matrix:[{module,target,host,prerequisites,task,proof,limitations}],
proof:compilation|ABI|generated-consumer|runtime|coverage,
checks:{fast_local,clean/forced_CI,host_gaps/owning_jobs},
ABI:{validator,baseline/update/check,final_artifact_scope,unsupported_target_inference},
coverage:{engine,modules/source_sets/test_tasks,thresholds,exclusions,unmeasured_targets},
generated_docs/code:{owning_tasks,outputs,committed_artifact_drift_gates},
processors/plugins:{supported_consumer_toolchains,integration_matrix}}
```
