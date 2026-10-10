---
status: accepted
date: 2026-10-10
version: cairn-r1
---

# 0014: Benign hosted Apple isolation probes

## Context

The only local Apple-silicon Mac has 8 GiB RAM and about 6.8 GiB free disk.
A disposable Xcode VM has not been established. Standard
[GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
are free for public repositories, including Cairn. A fresh hosted VM does not
alone establish offline target execution or immutable inputs.

## Decision

The owner authorized a free standard hosted macOS probe workflow, feature-branch
commit/push and execution. Use `macos-26`, not paid larger runners. Only benign
Python/shell probes run; no binding build, dependency download or signing.
The workflow accepts manual dispatch. Its feature-branch push trigger permits
the initial authorized run before the new workflow exists on the default branch.

Invoke a native sandbox with an empty environment and explicit scratch/input
paths. Check denied input writes, a designated benign host sentinel read,
network bind/outbound TCP, Unix IPC, scratch symlink escapes, inherited
child write denial, permitted scratch writes and a
1 MiB per-file limit. System reads are allowed; reads of other `/Users` data
are denied. This is not a complete filesystem-read allowlist or proof of all
network operations. TCP/Unix listeners are benign supervisor-owned fixtures;
unsandboxed controls connect first so missing listeners cannot explain denial.
Narrow system-read allowlisting aborted even `/bin/echo`
locally; widening system reads permits these initial probes but does not
authorize target-controlled work.

The benign probe job has a 10-minute wall-clock ceiling. Its log is checked
against 1 MiB after execution, not enforced by a streaming collector. Artifacts
are retained for seven days. Aggregate output/scratch, memory, process-count,
CPU and trusted-supervisor boundaries remain unverified and must be established
before any binding build. The workflow is internal tooling, not production
coverage or platform/SDK acceptance.

## Alternatives and risks

Local VM provisioning is currently capacity-constrained. Bare-host target builds
would expose a shared workstation. Hosted VM disposability avoids that exposure,
but the native sandbox must still be empirically validated. Broad system reads
and sentinel-only denial outside `/Users` are explicit probe limitations.
No credentials or secrets are supplied; checkout does not persist its token.
Physical iPhone execution is separate from hosted simulator execution.

## Migration

No production/API or existing Linux runner contract changes. Linux retention
is committed separately; its earlier intermittent emulator failures remain open.
The probes do not waive issue 45 or authorize a binding build on success.

## Observed evidence

The unprotected local CLI failed on allowed input mutation; the protected CLI
passed. Hosted
[run 38088954525](https://github.com/trancee/cairn/actions/runs/38088954525)
at `608dee0` passed all six benign checks in an eight-second job.
Downloaded artifact log/environment SHA-256 checksums passed. Observed
environment: ARM64 macOS 26.6.2, Xcode 26.6; `df` reported 95 GiB available,
not a guaranteed scratch allocation. This differs from research's 14 GB
runner specification and must not be promoted to an enforced budget.
Full runner acceptance and target-controlled builds remain gated.

The owner authorized hosted-only benign resource probes with an ephemeral
unprivileged account and fixed scratch. First test the memory boundary before
implementing that wider setup: request a 32 MiB `RLIMIT_AS`, then attempt a
bounded 64 MiB allocation. Failure to enforce the limit fails the job and
retains `memory.log`; it must not become an accepted memory control.
Darwin exposes `RLIMIT_AS` with the same constant as `RLIMIT_RSS` locally,
and its `setrlimit` manual describes RSS as memory-pressure preference.
Hosted enforcement therefore remains an empirical question, not a guarantee.
Hosted [run 38089266646](https://github.com/trancee/cairn/actions/runs/38089266646)
at `d85bc60` failed while setting the candidate limit (`ValueError`), before
allocation. Downloaded diagnostic checksums passed. This is an unsupported
setup result, not proof that an allocation exceeded a successfully applied
limit. The probe now records initial limits and reports this failure explicitly.
No process-level hard-memory control or full Apple runner is accepted.

Continue independent hosted-only resource probes even while memory fails:
create a fresh disabled-login UID with no administrator membership, mount a
fixed 256 MiB HFS+ image with ownership enabled, and run bounded scratch
exhaustion plus a 16-process UID ceiling and two-second child CPU ceiling.
An ordinary local filesystem failed the capacity assertion before writes.
The account is removed and the volume detached after execution; fixture files
remain only in the disposable hosted VM. This is not yet a generic build
supervisor, aggregate memory bound or validated whole-process-tree deadline.

Hosted [run 38089701128](https://github.com/trancee/cairn/actions/runs/38089701128)
at `721828f` passed actual scratch `ENOSPC` at filesystem capacity 268,394,496
bytes, per-UID process rejection and child CPU termination. Downloaded setup/
resource logs passed checksums; the account cleanup command succeeded and disk
detach was observed. Prior setup failures were preserved: sudo sanitized the
hosted guard, then invalid blank-image options failed. Explicit environment
passing and documented `hdiutil -type UDIF` resolved those setup errors.
The memory test still fails setting `RLIMIT_AS`; the overall job remains failed.

The owner subsequently selected whole disposable VM memory enforcement rather
than a separate process-memory cap. The current probe checks actual VM RAM
against a candidate 7 GiB ceiling and requires zero configured swap. The
candidate uses the documented standard ARM64 runner resource table, but any
observed mismatch fails setup rather than silently raising the budget.
No process-level cap, OOM failure test or swap reconfiguration is implied.
The initial whole-VM observation at `2958705` matched 7,516,192,768 bytes
of RAM and zero configured swap. To prevent later dynamic swap growth in a
build cell, the current hosted-only root step disables/unloads
`com.apple.dynamic_pager`, verifies disabled/not-loaded state and then checks
zero swap. Existing nonzero swap fails rather than being deleted. Only the
disposable hosted VM is affected; local swap remains unchanged.
The first swap-control run's empty log exposed a workflow-shell bug:
implicit `bash -e` did not propagate pipeline failure. Explicit `shell: bash`
enables GitHub's `-o pipefail` invocation. Do not accept that run's green job
as swap-control proof. Current service checks accept the native disabled-state
display (`disabled` or `true`) and require the final explicit success marker.

Reuse the Linux collector for Apple output/deadline enforcement: optional
`--seconds` uses a monotonic deadline, retains partial output and terminates
the owned command process group on expiry. The default Linux invocation has
no new deadline. The CLI deadline regression first rejected the missing option,
then passed with partial output and exit 124. Hosted benign sandbox execution
uses a 30-second collector deadline and unchanged 64 MiB streamed-output cap.
This does not yet prove containment of deliberate process-group escape.

The next composition runs the same network/IPC/input/symlink probes under
the dedicated non-administrator UID with its writable paths on the fixed
scratch disk. Fixtures and inputs remain root-owned; an empty environment
enters the sandbox after UID drop. Resource exhaustion is still a separate
benign invocation, not an accepted compiler/build supervisor.

Hosted [run 38090454490](https://github.com/trancee/cairn/actions/runs/38090454490)
at `3db7ee7` passed that unprivileged fixed-scratch composition along with
the independent resource probes, three shared-collector deadline tests,
disabled/unloaded pager and 7 GiB/zero-swap observations. All eight downloaded
artifact log checksums passed. Whole-process-tree escape containment and
compiler/build compatibility are not established by these benign results.

## Authorized preparation phase

The owner approved a separate trusted preparation/compatibility phase and
build-scale ceilings: 7 GiB whole-VM RAM/zero swap, 8 GiB reserved scratch,
64 MiB output, 128 processes, 900 CPU seconds per process and a 30-minute job
deadline. These are not yet composed or accepted build controls.
Only permit a fixture build after remaining isolation gates pass.

`apple-toolchain-preparation.yml` first requires the reusable benign preflight
and then starts a separate fresh hosted preparation VM. It selects the
existing fixture's Rust 1.97.1, Gradle 9.7.0 and daemon JDK 25.0.4.1+1, plus
compile JDK 21. The Gradle ZIP has an official fixed SHA-256; Ubique source
uses the existing immutable 1.3.1 revision. Cargo downloads use locked
manifests. Preparation has network access and does not compile the fixture.
Its output is not a frozen seed or build-isolation proof. Kotlin/Native and
Maven preparation, compiler compatibility and input freezing remain pending.

Preparation [run 38090825696](https://github.com/trancee/cairn/actions/runs/38090825696)
passed benign preflight but failed before downloads: the workflow incorrectly
encoded the existing daemon version as `25.0.4+1`, which the vendor resolver
could not find. The official release is `jdk-25.0.4.1+1`. Use its exact ARM64
macOS archive with the published SHA-256, preserving the Linux fixture's
version rather than substituting another JDK. This setup failure is not a
behavior-test red or compiler compatibility result.

Corrected [run 38090961772](https://github.com/trancee/cairn/actions/runs/38090961772)
at `3ffd8cf` passed benign preflight and trusted preparation. Retained versions
show Rust 1.97.1 with ARM64 Darwin/iOS device/iOS simulator targets,
Temurin 25.0.4.1+1, Gradle 9.7.0 and Xcode 26.6 on macOS 26.6.2.
The Gradle archive matched the published checksum; locked fixture and Ubique
Cargo downloads completed. The artifact retains logs and input hashes, not
the downloaded seed itself. No offline completeness, Kotlin/Native build,
Apple allocator audit or runtime result is established.

## Dedicated-UID supervisor seam

The owner approved a hosted root-owned supervisor CLI seam for deadline,
detached-descendant cleanup and output retention. Its tests require the
existing fresh disabled-login account; local non-root execution skips them.
The first hosted regression deliberately checks the current process-group-only
baseline and must fail if a detached child survives. Test teardown kills only
the specific owned child PID. Fixture builds remain unauthorized until these
and the remaining isolation gates pass.

Hosted [run 38091251447](https://github.com/trancee/cairn/actions/runs/38091251447)
at `fae9175` failed for the intended reason: the collector returned 124 and
retained the child PID, but that detached descendant was still alive.
The fixture's PID-specific teardown ran and disk detach succeeded.
The corrected CLI enumerates only the dedicated UID, signals individual PIDs
after rechecking ownership, and requires an empty UID process set within ten
seconds before returning. It also rejects pre-existing UID processes and
requires a root-owned private proof-output directory. Signal interruption
cleans the owned collector group and UID; uncatchable root `SIGKILL` and
whole-VM termination remain outside this in-process cleanup guarantee.

The detached-child correction passed
[run 38093092451](https://github.com/trancee/cairn/actions/runs/38093092451)
at `afdb188`. The next composed-limit regression failed as intended in
[run 38093180086](https://github.com/trancee/cairn/actions/runs/38093180086):
the sudo-launched child inherited unlimited CPU/file limits, a larger process
ceiling and supplementary groups. Replace sudo child launch with a trusted
root setup that fixes hard/soft CPU 900s, NPROC 128, per-file 64 MiB and
zero core-file limits before dropping all supplementary groups and UID/GID.
Exec receives only PATH/HOME/TMPDIR and a fixed UTF-8 LANG. Apple runtime's
automatically inserted `__CF_USER_TEXT_ENCODING` is distinct from inherited
workflow environment; the child-environment assertion excludes that key.
Whole-VM RAM/swap and aggregate scratch remain separate gates.

The first composed-limit replay
[run 38093275298](https://github.com/trancee/cairn/actions/runs/38093275298)
verified the requested rlimits and explicit environment but failed the Python
group-list assertion. Darwin's `getgroups(2)` documentation states that its
unlimited variant returns directory membership, not the access list modified
by `setgroups`. The corrected consumer uses libc's POSIX access-list interface:
require only primary GID 20 and no supplementary groups. This replaces an
invalid measurement, not the identity-isolation requirement.

Hosted [run 38093375336](https://github.com/trancee/cairn/actions/runs/38093375336)
at `3e19313` passed both dedicated supervisor regressions and all existing
benign sandbox/resource checks. All eight downloaded artifact checksums passed.
This closes the tested detached-deadline and child-limit slices only; a real
build still requires sandbox composition, scratch reservation, immutable
inputs and offline compiler/runtime compatibility.

The approved build-scratch assertion failed for the intended reason in
[run 38093539208](https://github.com/trancee/cairn/actions/runs/38093539208):
the existing benign resource disk was 256 MiB, not 8 GiB.
Keep that independent ENOSPC probe, detach it, and create a separate 8 GiB
HFS+ image. Before mounting, rewrite its existing bytes in bounded 32 MiB
chunks and fsync; require allocated blocks to cover the complete logical
image. This is an explicit full-backing check, not reliance on image creation
or apparent host free space. Allocation failure prevents target execution.
The mounted scratch remains private to the dedicated UID and the image stays
root-owned. The owner-approved job ceiling is now 30 minutes.

The first reservation replay
[run 38093628086](https://github.com/trancee/cairn/actions/runs/38093628086)
proved an exactly 8 GiB fully allocated image, but the test's invented
16 MiB metadata allowance rejected HFS+'s EFI/partition overhead: usable
filesystem capacity was 8,245,960,704 bytes. The approved budget is a ceiling,
not a guarantee of 8 GiB usable payload storage. Require exactly 8 GiB image
size, full backing and positive filesystem capacity no greater than that
ceiling; record actual usable bytes. No budget is increased.

The corrected full-reservation probe passed
[run 38093725410](https://github.com/trancee/cairn/actions/runs/38093725410)
at `0a9f6ee`. Composition then failed as intended in
[run 38093862154](https://github.com/trancee/cairn/actions/runs/38093862154):
the sudo-only sandbox child still had unlimited CPU.
Route the sandbox command through the dedicated-UID supervisor, with its
private root proof-output directory, after mounting verified 8 GiB scratch.
Require the sandbox child to observe all approved rlimits before the existing
input/network/IPC/symlink checks. Recheck scratch backing/capacity after those
probes and require UID cleanup. This still uses the initial broad-system-read
policy; compiler compatibility and complete read-boundary acceptance remain open.

The composed broad-read policy failed the accessible unlisted-file denial
assertion in
[run 38094051180](https://github.com/trancee/cairn/actions/runs/38094051180).
The new build policy allows global file metadata, named system/Xcode data
roots, assigned inputs/scratch and designated entropy devices, not arbitrary
host data. Root-directory enumeration is explicitly allowed without granting
data reads of its descendants. A minimized local `echo` probe initially
aborted with signal 6. Targeted kernel denials identified `file-read-data /`;
adding only that literal fixed `echo` and Xcode Python startup. Granting
additional dyld-cache paths or read suboperations had not fixed it.
Local CLI regressions cover startup and readable data outside named roots.
Hosted composition must still pass; compiler-required IPC is not authorized
by this read-policy change.

Named read-policy composition passed
[run 38094262857](https://github.com/trancee/cairn/actions/runs/38094262857)
at `9eeba17`; all eight retained checksums passed.
The authorized preparation workflow next copies only the selected Rust,
Gradle and JDK tools into root-owned read-only `/opt/cairn-apple-tools` and
hashes their regular files. It probes version commands inside the bounded
UID/sandbox/scratch cell, then requires unchanged tool hashes. This does not
configure a Gradle project, compile the fixture, freeze Maven/Native caches
or establish daemon IPC compatibility. The initial read policy must reject
the new unlisted tool root; admit only that assigned root once the negative
startup result is observed, not all of `/opt`.

Trusted startup
[run 38094445085](https://github.com/trancee/cairn/actions/runs/38094445085)
failed as intended on denied `/opt/cairn-apple-tools/rust/bin/rustc`
execution. The shell also reported an inherited working directory outside
the allowed data roots. Permit only the fixed root-owned tool seed subtree
and change to the dedicated account's scratch before exec; do not widen
reads to the workflow checkout or all of `/opt`.

The assigned-root replay
[run 38094699822](https://github.com/trancee/cairn/actions/runs/38094699822)
still rejected Rust startup after the cwd correction. The copied Rustup
tool permissions must not retain owner-only readability after root ownership
transfer. Normalize tool copies to readable/traversable but non-writable
permissions, preserving existing execute bits, and require a dedicated-UID
DAC executable-access control before entering the sandbox. Record the tool
path modes; do not silently relax the read policy further.

After correcting the native `/bin/test` path, startup
[run 38095140743](https://github.com/trancee/cairn/actions/runs/38095140743)
passed the DAC control and Rust 1.97.1 startup. Cargo's linked system
LibreSSL then failed reading `/private/etc/ssl/openssl.cnf`. Permit that
specific system configuration file, not the parent configuration tree;
network operations remain denied. Java/Gradle startup remains unverified
until the original version-command sequence completes.

Trusted version startup passed in
[run 38095349642](https://github.com/trancee/cairn/actions/runs/38095349642)
at `cee5a9d`: pinned Rust/Cargo, daemon/compiler JDKs and Gradle version
commands completed with the sandbox/network/resource controls composed.
All frozen tool-file hashes verified unchanged afterwards.
Next probe `help` on a script-owned empty Groovy Gradle project, offline,
inside the same cell. This checks Gradle initialization/daemon IPC without
loading fixture or third-party plugin build logic. It does not waive the
remaining gates or permit a target fixture build.

Empty Gradle initialization failed in
[run 38095639900](https://github.com/trancee/cairn/actions/runs/38095639900)
at `f83ec6e`: `FileLockContentionHandler` construction raised
`SocketException: Operation not permitted`. Pinned Gradle 9.7.0 source
[creates a wildcard UDP socket unconditionally](https://github.com/gradle/gradle/blob/v9.7.0/platforms/core-execution/persistent-cache/src/main/java/org/gradle/cache/internal/locklistener/DefaultFileLockCommunicator.java);
this is not fixed by `--offline` or `--no-daemon`.
Its [address factory](https://github.com/gradle/gradle/blob/v9.7.0/platforms/core-runtime/messaging/src/main/java/org/gradle/internal/remote/internal/inet/InetAddressFactory.java)
normally selects loopback for peer communication, but the daemon bind-address
environment setting does not change this wildcard UDP bind.

A socket-policy change therefore requires a separate owner decision. Blanket
loopback access alone could expose other runner services and is not accepted.
One candidate is a hosted-only, separately releasable PF anchor that denies
external traffic and cross-UID local communication, with native sandbox
permissions limited to the required socket classes. PF documentation describes
socket-owner UID matching and enable-reference release, but the complete
composition is unproven. Require live positive controls and external/cross-UID
negative controls before any fixture work. Do not replace global PF rules,
flush global states, weaken isolation or modify local Mac networking.
