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

The owner approved hosted-only PF isolation probes. First run live owned
TCP/UDP controls without PF to demonstrate same-UID local communication and
the expected cross-UID failure of the unrestricted baseline. Root establishes
external TCP reachability to GitHub without sending application data, and
owns a live loopback listener. Dedicated-UID cleanup still applies. This
experiment is not fixture-build authorization.

Hosted [run 38123483299](https://github.com/trancee/cairn/actions/runs/38123483299)
failed as intended: same-UID TCP/UDP worked, but cross-UID TCP was allowed.
Remove the unnecessary listener thread (its Python 3.9 timeout type caused
unrelated diagnostics); the root socket remains listening throughout the test.
The candidate anchor tags dedicated-UID loopback traffic, permits only tagged
inbound traffic to the same UID, and rejects external/cross-UID TCP/UDP.
Load only a fresh `com.apple/cairn-UUID` anchor after verifying the existing
Apple wildcard attachment, retain before/after main rules, and release only
the PF enable reference acquired by the probe. This candidate is not accepted
until live controls pass.

## Private-loopback IPC evidence

The tag candidate failed same-UID TCP in runs
[38123581731](https://github.com/trancee/cairn/actions/runs/38123581731) and
[38123662243](https://github.com/trancee/cairn/actions/runs/38123662243).
Counters showed outgoing tag matches but no corresponding incoming tagged
match. Reversing tag direction also failed
[38123750172](https://github.com/trancee/cairn/actions/runs/38123750172).
The current candidate instead uses a fresh `127.0.0.2` loopback alias and
direct packet sender/receiver UID rules. It removes that specific alias,
clears only its named anchor rules and releases its own enable reference.
Main PF rules are compared before/after. PF stays active around the entire
resource/tool cell, not merely the preliminary socket probe.

The native compiler socket profile permits TCP/UDP socket operations while
PF supplies the precise address/UID restriction. `PRIVATE_IPC=false` retains
the original blanket socket denial for the separate benign sandbox probes.
This profile must not be used alone as a network isolation control.
Native filters require `local` endpoints for inbound/listening operations;
the previous `remote` filter caused a reproduced `listen()` EPERM. A local
CLI regression now covers listener startup.

Hosted [run 38124841659](https://github.com/trancee/cairn/actions/runs/38124841659)
at `89fbb05` passed unsandboxed and sandboxed private TCP/UDP roundtrip
controls, live cross-UID TCP denial in both directions, external TCP denial,
the composed resource/read probes, and trusted offline empty Gradle `help`.
Gradle reported `BUILD SUCCESSFUL in 3s`; copied tool-file hashes verified
unchanged and named PF cleanup returned zero. The trusted Gradle probe uses
`GRADLE_DAEMON_BIND_ADDRESS=127.0.0.2` and IPv4 launcher preference.
External/cross-UID UDP negative controls, broader socket adversarial cases,
fixture/Maven/Native cache freezing and actual binding compilation/runtime
remain unverified. This is not full Apple runner acceptance.

Live UDP negatives then failed as intended in
[run 38125155369](https://github.com/trancee/cairn/actions/runs/38125155369):
a root-origin UDP packet reached the dedicated private listener despite the
inbound rules. Reject other UID traffic to the private alias at the outbound
hook before default PF state creation. The original reverse UDP test and
cross-UID/non-loopback delivery checks passed in
[run 38125239632](https://github.com/trancee/cairn/actions/runs/38125239632)
at `c6204b0`, both outside and inside the compiler socket profile.
Root-owned UDP receivers have before/after delivery controls; dedicated
same-UID UDP roundtrip remains green. Trusted empty Gradle `help` and copied
tool integrity also remain green. No fixture build occurred.

The owner approved extending the existing fixture with an explicit Apple
selection, preserving its default Linux/Android behavior and source/version
owners. The approved test seam is the Gradle CLI using
`-PcairnProofPlatform=apple`, with visible invalid-selection rejection.
First test only the actual fixture settings file and empty project shells:
an init-script assertion detects unsupported selection accepted by settings
before any project plugin/build logic executes. This is not binding generation
or permission to run unfrozen target builds.

The invalid-selection CLI regression failed for the intended reason in
[run 38125792934](https://github.com/trancee/cairn/actions/runs/38125792934):
actual settings accepted the unsupported property. Settings now validate the
closed `linux-android|apple` choice before project plugins. Default selection
keeps existing modules/build scripts; explicit Apple requires macOS, omits
Android consumer and selects the SDK's scoped Apple adapter. Kotlin/Ubique
versions remain owned by the existing root build, and Rust source/lock/package
are unchanged. The Apple adapter declares JVM/iOS device/simulator ARM64,
uses the frozen Ubique source path and requires assigned CARGO_TARGET_DIR.
Native commonization is enabled. Effective target configuration and binding
generation remain unverified until their separate hosted CLI gates run.

Selection verification at `9004764` in
[run 38126082975](https://github.com/trancee/cairn/actions/runs/38126082975)
never reached preparation: every benign boundary/resource assertion passed,
but final HFS+ scratch detachment failed with `Resource busy` after dedicated
UID cleanup. This is not a fixture-selection result. On detach failure,
collect only open-file holder PIDs and command names with a 15-second deadline;
retain the original failure. No retry, forced detach, unrelated process kill
or budget change is authorized by this diagnostic.

The invalid-selection gate passed in
[run 38126287911](https://github.com/trancee/cairn/actions/runs/38126287911)
at `41446e7`: actual Gradle settings report
`Unsupported cairnProofPlatform: invalid` before project plugins. Tool hashes
remained unchanged and ordinary detach/UID/PF cleanup passed. The earlier
busy mount did not recur; its holder/cause remains unverified.
Next assert default, explicit Linux/Android and explicit Apple module/build-file
selection through Gradle's settings-evaluated hook with empty project shells.
This characterizes the settings contract, not the declared/effective Kotlin
targets or Native build behavior.

The positive settings harness failed in
[run 38126889867](https://github.com/trancee/cairn/actions/runs/38126889867):
empty module directories lacked the actual fixture's Kotlin build filenames,
so Gradle chose its default Groovy filename. Create empty project scripts at
the existing canonical filenames, checking each original exists. This repairs
the settings-only seam without copying/executing plugin build logic, changing
the Linux configuration, or weakening the selection assertions.

Corrected settings checks passed in
[run 38127148746](https://github.com/trancee/cairn/actions/runs/38127148746)
at `5016e70`: default and explicit Linux/Android select SDK/consumer/Android
consumer with original build filenames; Apple selects SDK/consumer and
`apple.gradle.kts`. Invalid selection still fails before plugins. The unchanged
60-second tool-cell deadline, resource/socket checks, copied-tool integrity
and ordinary scratch/UID/PF cleanup passed. No fixture plugins, binding
generation, Native compilation or generated calls ran.

The owner approved extending the separate disposable network-enabled
preparation phase to execute the pinned Gradle/Kotlin/Ubique plugins against
a preparation-only project for dependency resolution, then freeze inputs
before offline replay. No fixture Rust compilation, binding generation,
signing, publication or local-Mac execution is authorized. Download-only
reconstruction of Gradle variants/Native caches was considered and rejected
as substantially more complex. Preparation execution is not build-isolation
evidence.
First run the approved actual Gradle CLI target seam offline: load the
existing root pins and Apple adapter, request only `help`, and require SDK
targets `metadata`, `jvm`, `iosArm64`, `iosSimulatorArm64`. Missing plugin/
Native inputs must fail before any accepted target-configuration result.

The offline target gate failed as intended in
[run 38127554356](https://github.com/trancee/cairn/actions/runs/38127554356)
at `0905dfa`: the unchanged root AGP `apply false` request could not resolve
from an empty offline plugin cache. The approved networked preparation now
requests only `help` with the same root/SDK/consumer scripts and pinned tools;
it checks that no Cargo compilation-output directory appears. Copy the
resolved `modules-2` cache without lock/gc files into a root-owned read-only
seed and recheck its hashes after offline execution.
Use Gradle 9.7.0's documented incubating `GRADLE_RO_DEP_CACHE` interface:
the seed supplies immutable dependency files/metadata while transforms,
Kotlin DSL output and lock coordination remain disposable scratch.
Missing inputs still fail offline under PF; Native compiler/cache completeness
and binding builds are not established by this initial plugin seed.

First networked configuration in
[run 38127894684](https://github.com/trancee/cairn/actions/runs/38127894684)
resolved the pinned plugins but failed SDK configuration because the
preparation shell omitted the authoritative `gradle.properties`, including
required Native commonization. Copy that file unchanged into the shell;
override only the platform-specific JDK path through the existing CLI.
No plugin version, commonization validation or Linux default is relaxed.

Corrected networked preparation passed in
[run 38128161002](https://github.com/trancee/cairn/actions/runs/38128161002)
at `78dc7b7`, reporting the expected effective Apple targets and no Cargo
compilation-output directory. Read-only Gradle seed copying passed. Offline
replay resolved plugin inputs but failed creating Gradle's instrumented
Kotlin-plugin JAR in scratch. Add only the Gradle CLI stacktrace to expose the
nested cause before changing a budget or transform/cache strategy. No offline
target green, seed-integrity completion or binding result is claimed.

The diagnostic replay
[run 38128556994](https://github.com/trancee/cairn/actions/runs/38128556994)
expired the unchanged 60-second collector deadline after the version/empty/
selection probes, before target diagnostics completed. Keep each command's
60-second ceiling and run effective-target configuration as its own supervised
invocation; the 30-minute whole-job ceiling remains unchanged. Another busy
detach exposed an invalid `lsof +f` mount-path diagnostic; use bounded `+D`
directory enumeration and still print only PID/command fields. Neither
failure is treated as a successful offline target proof.

Separately bounded offline configuration in
[run 38128968818](https://github.com/trancee/cairn/actions/runs/38128968818)
at `3381a4c` confirms the transform's nested cause:
`java.io.IOException: File too large` while finishing the instrumented
Kotlin Gradle plugin JAR. The approved 64 MiB child per-file ceiling blocks
this required scratch artifact. Networked preparation/expected targets still
pass; offline configuration remains failed, with no binding build.
Changing the per-file budget or introducing precomputed transform inputs is
a material owner decision. Keep the limit unchanged pending that decision;
the shared 64 MiB streamed-output cap is a separate invariant.

The owner approved raising only the dedicated child per-file ceiling to
128 MiB. The collector retains its separate 64 MiB streamed-output cap;
8 GiB scratch, 7 GiB VM RAM, CPU/process limits and deadlines are unchanged.
First require the real supervised child to observe the new hard/soft limit,
then verify actual file-boundary enforcement and instrumented artifact size.
Precomputed transform inputs were not selected because they add Gradle/cache
coupling and may not cover later Native compiler files.

The new child-limit expectation failed as intended in
[run 38129355841](https://github.com/trancee/cairn/actions/runs/38129355841):
the actual child still observed `[67108864, 67108864]`, not
`[134217728, 134217728]`. Apply the approved ceiling in trusted child setup
and require the sandbox composition to observe the same value.

Hosted [run 38129425533](https://github.com/trancee/cairn/actions/runs/38129425533)
at `ace66ef` passed offline effective-target configuration with the revised
child ceiling, unchanged dependency/tool hashes and successful cleanup.
The next run `38129790626` passed actual 128 MiB file-boundary preflight but
stopped preparation on existing 1 GiB swap after tool provisioning.
Move the unchanged pager-disable/zero-swap gate immediately after checkout
before downloads/tool preparation. Never delete existing swap or accept
nonzero swap; its exact creation source in the failed run is unverified.

Final configuration replay passed in
[run 38130344648](https://github.com/trancee/cairn/actions/runs/38130344648)
at `2472082`: actual 128 MiB child file-boundary/next-byte rejection,
effective offline Apple targets, unchanged tool/dependency seed hashes and
scratch/UID/PF cleanup. Instrumented Kotlin plugin size is 67,326,033 bytes.
An intervening artifact-size check failed because child-side `xcrun` could
not perform its license lookup inside the named read policy; pass the already
selected trusted Python path from the root supervisor instead of widening
reads or changing Xcode license state. Native compiler/cinterop and Cargo
cache freezing/completeness, allocator audit, binding builds and runtime
proof remain pending. Earlier busy-detach failures remain unexplained.

Next extend the approved Gradle CLI preparation seam to resolve external
artifacts of all resolvable Apple project configurations, filtering project
components out of artifact views. Request only this dependency-resolution
task, not compilation/generation or project-output tasks. First run offline
against the existing seed to expose missing inputs, then seed those artifacts
through the separately approved networked preparation. This still does not
prove Native compiler distribution or Cargo source completeness.

Offline [run 38130908209](https://github.com/trancee/cairn/actions/runs/38130908209)
failed as intended on uncached stdlib, Ubique runtime, Okio, atomicfu and
coroutines dependencies. Use the same external-artifact resolver during
approved networked preparation before freezing the dependency seed.

Networked run `38131273835` exposed a harness overreach: directly resolving
the synthetic `kotlin-commonized-cinterop` usage requests a runtime variant
that is not published. Pinned Ubique source instead feeds extracted runtime
cinterop metadata through `transformNativeMainCInteropDependenciesMetadata`.
Exclude that synthetic usage from direct artifact resolution and invoke the
owning metadata extraction task explicitly in preparation/offline replay.
No compiler/commonizer validation is disabled; this changes the preparation
seam to match the plugin's actual consumer path.

The external-artifact/metadata path passed networked preparation and offline
replay in [run 38131639643](https://github.com/trancee/cairn/actions/runs/38131639643)
at `455ad8f`, with unchanged seed/tool hashes. This is dependency/metadata
extraction, not Kotlin/Native compiler or binding runtime evidence.
Next test the Cargo CLI seam with locked offline metadata for fixture,
bindgen and runtime across Darwin/iOS-device/iOS-simulator ARM64 using a
dedicated immutable vendor seed. The initial seed is absent and must fail
before any compilation. No fixture compiler task is requested.

Run `38132020833` passed Gradle artifact replay then failed the absent Cargo
seed check. Prepare with locked `cargo vendor` across fixture/bindgen/runtime
manifests, copy root-owned read-only source/configuration into the trusted
tool subtree and verify hashes after metadata replay. Missing vendor config
now has an explicit fail-closed diagnostic. No compilation or Rustup fallback
is introduced.

Vendored Cargo metadata passed all nine manifest/target combinations in
run `38132518944`, with unchanged vendor/tool/Gradle hashes. Native startup
then failed as intended on a missing compiler in run `38132887676`.
Prepare official `kotlin-native-prebuilt-macos-aarch64-2.4.20.tar.gz`,
verified against release SHA-256
`b70d4fd2855fdb054fc9604beaa7de83c18d786454ae948de72a226e81f07dc8`,
and freeze it with the tools. Probe only `konanc -version`; SDK/linker/
platform-library completeness and fixture compilation remain unverified.

Official Native startup passed in run `38133286890` at `20fb718`, along
with Gradle external/cinterop inputs and all nine vendored Cargo metadata
combinations; input hashes and cleanup passed. The owner approved a trusted
CLI compile seam: a script-owned arithmetic function compiled as a KLIB for
iOS device/simulator ARM64 inside the existing isolated cell. This tests
compiler input availability, not fixture bindings, FFI or runtime. First
run offline; missing inputs must fail before networked preparation changes.

The trusted minimal KLIB probes passed offline without extra downloads in
[run 38133904604](https://github.com/trancee/cairn/actions/runs/38133904604)
at `adc22c5`, for both device and simulator ARM64. Frozen Native/tool,
Gradle and vendor-source hashes remained unchanged; UID/disk/PF cleanup
passed. This is a green characterization of compiler KLIB availability,
not an intended-failure/red claim or SDK cinterop/linker/FFI/runtime proof.

The owner approved the remaining gated phase: trusted C-header cinterop/
linker probes, participating-source/delivered-runtime allocator inspection,
then offline shared-fixture generation/compilation and generated-call hosted
simulator execution only after those gates pass. No signing, publication,
paid runner, local privileged work or resource-budget increase is included.
Physical iPhone proof remains unavailable and separate. First exercise Native
cinterop against a script-owned arithmetic header for device/simulator ARM64
with unchanged blanket network denial and resource limits.

Trusted cinterop run `38134505206` failed inside the named read profile:
`xcrun --sdk iphoneos --show-sdk-path` reports license acceptance unavailable.
The same VM's preparation Xcode version command passed outside the profile.
Collect recent sandbox kernel denials on the failed probe, without accepting
licenses, widening directories or treating this as a real license-state
diagnosis until the denied input is identified.

Run `38135181386` identified denied data reads of the exact system Xcode
preferences file, alongside unrelated denied services/configuration. Permit
only `/Library/Preferences/com.apple.dt.Xcode.plist` to test whether existing
license-state visibility fixes SDK lookup. Do not permit all preferences,
account databases, Mach services or diagnostic devices; do not modify license
state. The original cinterop command remains the verification boundary.

Run `38135833123` passed SDK/license lookup after that exact input allowance
and failed on absent LLVM downloads under network denial. Prepare dependencies
through the trusted header probe in network-enabled preparation, freeze
extracted directories read-only, and symlink them into scratch's dependency
layout. Only extraction coordination metadata remains writable. Offline
replay sets Native `airplaneMode=true`; missing input must fail immediately,
not attempt network/retries. Hash the frozen dependencies after replay.

Preparation header probes and dependency freezing passed in run `38136413700`.
Offline replay rejected compiler-style `-Xoverride-konan-properties=value`
syntax; cinterop's actual help requires separate option/value arguments.
Correct that invocation without disabling airplane mode. Narrow kernel
diagnostics to named compiler/SDK processes rather than unrelated system
sandbox events.

Offline device/simulator header cinterop passed in
[run 38136851477](https://github.com/trancee/cairn/actions/runs/38136851477)
at `74673d1`, with airplane mode, blanket socket denial, immutable LLVM/libffi
inputs and unchanged tool/Gradle/Cargo/Native hashes. UID, scratch and PF cleanup
passed. This closes header-probe input availability, not fixture FFI/runtime.
Next exercise the already-approved trusted linker seam: link script-owned
arithmetic frameworks for each target in separate unchanged 60-second cells
and inspect actual Mach-O build-version platform and minimum OS `15.0`.
Missing dependencies fail offline before changing preparation.

Trusted arithmetic framework linkage passed offline in
[run 38137529578](https://github.com/trancee/cairn/actions/runs/38137529578)
at `f7f4eca`. Actual Mach-O build versions identify `IOS`/`IOSSIMULATOR`,
minimum OS `15.0` and SDK `26.4`. No extra downloads were required.
All seed/tool hashes and ordinary cleanup passed. This is a characterization
green, not a red/green or fixture ABI/runtime claim.
Next collect package-scoped normal/build feature trees and allocator-pattern
source candidates for fixture/runtime/bindgen across the three Apple targets,
plus delivered runtime archive identities/native entry names. This read-only
diagnostic is not an allocator-acceptance test: candidate classification,
generated-source limits and delivered allocator thunks remain separate gates.

Initial collection in run `38138281856` failed before source inspection:
the explicit diagnostic environment omitted the pinned Rust `bin` from PATH,
so Cargo could not execute `rustc -vV`. Supply that existing immutable tool
directory, matching the earlier metadata gate; do not add Rustup or downloads.

Run `38138817213` reached Cargo tree output but rejected a package identity
before inspection. Retain the exact non-sensitive feature-tree row in the
failure diagnostic before adjusting the parser; do not skip unmatched rows.

Run `38139304928` first expired an earlier tool cell and did not reach the
diagnostic. Its unchanged failed-job replay reached the exact rejection:
`thiserror v2.0.20|default,std`. The parser consumed the feature delimiter as
part of the version when no source-path suffix separated it. Stop identity
matching at `|`; keep unique metadata-identity validation and every feature
row. No source candidate was accepted by the failed collection.

Run `38140398174` collected all nine feature closures: fixture/runtime each
50 packages and bindgen 81 on each target. Candidate hits are bytes test-only
allocator fixtures and autocfg/hashbrown example/documentation references,
matching earlier Linux source observations; delivered Apple evidence is still
required. Artifact discovery then failed because it assumed `uniffi-runtime-`
filenames. The frozen manifest instead records `runtime-*` under the exact
`ch.ubique.uniffi` group. Search that scoped group using its actual filenames,
not arbitrary runtime-named dependencies.

Collection passed in run `38140965124` at `536f690`, with all input hashes
and cleanup. It identified device/simulator `libuniffi_runtime.a` inside the
published cinterop KLIBs and Darwin ARM64 runtime dylib in the JVM JAR.
Next extract only those entries to bounded scratch, record their hashes,
discover actual allocator symbols and collect targeted disassembly using
Xcode's inspection tools. This is evidence collection, not automatic allocator
acceptance or source-to-binary provenance.

Run `38141613896` first failed benign scratch detach (`Resource busy`);
the unchanged replay reached inspection. Xcode `nm` rejects LLVM 22
compiler-builtins bitcode inside the delivered archive (reader LLVM 21).
Use its documented `--no-llvm-bc` mode for the scoped machine-code allocator
thunk diagnostic and state that excluded bitcode is not inspected. Do not
ignore a tool error or claim complete archive analysis; actual allocator
symbols must still be found and their machine-code targets inspected.

Run `38142418613` collected all three delivered ARM64 hashes/symbol sets
with unchanged inputs and cleanup, but disassembly emitted missing-symbol
warnings rather than thunk bodies. This diagnostic green is not allocator
evidence. Derive exact disassembly names from objdump's own symbol table and
do not demangle while selecting symbols; include relocations for archive
branch-target identity. Require actual thunk bodies before acceptance.

Actual runtime thunk bodies and matching default `__rdl_*` branch/relocation
targets passed inspection in run `38143105757` at `90a31be` for Darwin,
device and simulator ARM64; all immutable inputs and cleanup passed.
The bounded findings/bitcode limitation are recorded in
[Apple allocator evidence](../../proofs/bindings/apple/ALLOCATOR-AUDIT.md).
Now compile the actual shared Rust fixture, locked/offline, separately for
each target under the unchanged 60-second/128 MiB file ceilings. No fixture
FFI calls are permitted until its resulting allocator thunks are inspected.

Actual fixture Rust compilation passed offline on all three Apple targets
in run `38143726072` at `51525af`, within existing per-command/resource
ceilings. All immutable hashes and cleanup passed. No FFI calls ran.
Next require each actual fixture allocator thunk to forward to its matching
default allocator and scan generated Rust output, then compile the pinned
Ubique bindgen offline in its own unchanged bounded cell. Missing/thunk
mismatches and compilation failures retain diagnostics and gate progression.

Run `38144367463` passed all three fixture default-allocator forwarding and
generated-Rust scans, then expired the 60-second bindgen cell during
`uniffi_bindgen` compilation. Reuse the existing scratch Cargo target directory
and explicit Darwin target for compatible already-built dependency artifacts;
Cargo fingerprints still own reuse across the two locked manifests. No
deadline/budget increase, immutable binary seed or network fallback is added.

Run `38145166981` also expired the unchanged 60-second bindgen deadline
during `uniffi_bindgen`, despite fingerprinted scratch reuse. All fixture
compile/default-allocator scans had passed before it; UID/scratch/PF cleanup
passed after failure. Generator compilation is incomplete. A larger build
invocation ceiling versus separately preparing an immutable generator is a
material owner decision; do not raise limits or weaken validation implicitly.

The owner selected 300-second actual build/generation cells, retaining
60-second trusted probes and all other budgets, including the 30-minute job
ceiling. Apply it first to generator compilation, then the owning Gradle
`:sdk:buildBindings` task. Gradle Cargo subprocesses consume a scratch
configuration symlink to the immutable vendor config, explicit offline mode
and pinned Rust PATH; Native home is the immutable compiler seed.
Do not bypass the plugin's installation/source-fingerprint contract by
copying the separately built diagnostic generator into its install directory.

Run `38146169370` compiled the diagnostic debug generator offline in
3m09s, inside the newly approved ceiling. The actual owning Gradle task
then expired 300 seconds while `installBindgen` ran Cargo's optimized
`install --locked --force --path` contract. No binding generation completed.
UID/scratch/PF cleanup passed. Pinned plugin source offers path/Git/registry
installation, not a supported prebuilt-binary seam; do not fake its source
fingerprint or suppress the task. The optimized installation ceiling remains
a separate unresolved owner choice.

The owner approved 600 seconds for owning `:sdk:installBindgen` only and
removal of the redundant debug-generator build. Other build/generation cells
remain 300 seconds, trusted probes 60 seconds, whole job 30 minutes, all
other resource/isolation controls unchanged. Installation and `buildBindings`
now run separately. The immutable Cargo-config symlink is verified on each
invocation; no plugin fingerprint fabrication, profile change or task skip.

The compile-JDK cache directory name was not its actual release identity:
the hosted JVM reports Temurin `21.0.12.1+1`. Official release metadata and
ARM64 macOS SHA-256 were verified, along with current stable official action
releases. Replace floating setup-java `"21"` selection with the exact archive
and published hash `3623232f33a9c3baadf304480b2535f9a3cba8a58d42ecbb438ba267315d9998`,
using the same verified-download pattern as the daemon JDK. This preserves
the observed compiler release rather than upgrading it; hosted replay still
must verify the extraction path and actual version.

Run `38147417409` also expired the explicitly approved 600-second owning
installation cell. CargoRunner buffers compiler output until return, so no
live compilation stage or blocked-wait cause was retained. Do not raise the
deadline again without diagnosis. Extend the approved supervisor CLI seam
with a one-shot, owner-UID-only process snapshot before its unchanged
deadline; fields are PID/parent/state/CPU time/executable basename, never
arguments, environment or unrelated UID records. First require a short
sleeping-child regression to report that snapshot and retain deadline cleanup.

The diagnostic regression failed as intended in run `38148973462`:
the CLI rejected absent `--diagnose-after`. Implement one-shot root-side
observation only when requested, before the existing collector's original
deadline, and retain cleanup/exit semantics. Optimized installation requests
its snapshot at 540 seconds inside the unchanged 600-second ceiling.

Run `38149099333` passed the supervisor diagnostic/invalid-time regressions
and exact compile-JDK archive/version checks. At 540 seconds, the real
installation snapshot showed `rustc` runnable with `6:56.02` accumulated CPU,
while Cargo/Gradle waited. Installation then expired 600 seconds. This is
active compiler work, not evidence of a network or lock deadlock; the exact
compiler crate/phase is not captured by the identity-only diagnostic.
UID cleanup passed but ordinary scratch detach again failed `Resource busy`;
bounded holder collection found no retained holder identity.
Do not change the optimizer/profile or raise the deadline silently.
Generation, runtime and final isolation/reliability acceptance remain open.

The owner selected debug profile for the generator only, retaining the
600-second installation ceiling. The pinned plugin lacks a profile DSL;
an immutable PATH Cargo adapter adds `--debug` only to installation from the
exact pinned generator path and rejects competing profile arguments/other
installation sources. All other Cargo calls forward unchanged to pinned
Cargo. The plugin still performs its owning install, fingerprint and ready
record checks; no prebuilt injection or task suppression. SDK profiles,
300-second generation, 60-second probes and all other limits are unchanged.

Owning debug-profile installation and actual `buildBindings` passed offline
in run `38150603530` at `3e52471`, with all input hashes and cleanup.
No FFI calls ran. Next execute the existing immutable shared JVM smoke
consumer through its owning `interopSmoke` task, then discover effective
Native compilation tasks rather than assume names. The consumer source is a
symlink to the frozen canonical source; writable outputs remain scratch.

Run `38151849548` at `38029f6` passed actual generated JVM calls on Apple:
integer value/boundary, typed overflow, string transfer and deterministic
object close/post-close rejection. All seed hashes and ordinary cleanup pass.
This proves JVM generated consumers only. Effective task discovery identifies
`compileKotlinIosArm64`, `compileKotlinIosSimulatorArm64` and
`compileNativeMainKotlinMetadata`; run each offline under the approved
300-second compilation ceiling with the frozen Native home/dependencies.

Run `38152967600` passed generated device/simulator target compilation and
JVM calls, then common metadata failed creating the commonizer `.lock` under
the immutable Native distribution. Pinned KGP source fixes commonizer output
under `<nativeHome>/klib/commonized/<version>`. Provide a scratch distribution
shell whose compiler/platform inputs are symlinks to the immutable seed and
only `klib/commonized` is writable generated/coordination state. Do not make
the original compiler writable, disable commonization or fabricate its cache.

Run `38154100996` at `f0c1d44` passed generated device/simulator/common
Native compilation, actual JVM calls, all seed hashes and ordinary cleanup.
Next link actual fixture frameworks for each target through the Apple-only
adapter and inspect real Mach-O platform/minimum OS `15.0`; default Linux
configuration is unchanged. Framework linkage is not simulator/device runtime.

Actual generated fixture frameworks linked offline for device/simulator
ARM64 and passed Mach-O platform/minimum OS `15.0` inspection in
[run 38155697269](https://github.com/trancee/cairn/actions/runs/38155697269)
at `ef2302e`. JVM calls, Native/common compilation, all seed hashes and
ordinary cleanup passed. No simulator or physical-device runtime is implied.
Next test a trusted `simctl` runtime-inventory command with a dedicated
scratch device set under unchanged blanket socket/Mach denial. No device
is booted; this tests the access prerequisite before approving any service
allowance or executing generated simulator calls.

The unchanged-denial inventory failed in
[run 38157170214](https://github.com/trancee/cairn/actions/runs/38157170214)
at `f62938f`: `CoreSimulatorService` connection invalid, runtime-image service
unavailable and scratch device-set notification subscription refused. Prior
JVM calls and both framework links passed; UID cleanup and ordinary scratch
detach passed. Final workflow input-hash checks were not reached.
This is an access-prerequisite failure, not evidence that an available
runtime is absent or that generated calls fail.
Move the trusted inventory ahead of expensive fixture work and collect only
recent `simctl` sandbox kernel denials with a 15-second diagnostic deadline.
Retain unchanged blanket socket/Mach denial, resource limits and no boot.
Candidate causes are denied service lookup, fresh-UID service availability
or denied runtime/device-set paths; exact denial evidence is needed before
any material service-boundary decision.

The narrowed replay
[38158407544](https://github.com/trancee/cairn/actions/runs/38158407544)
at `98e52e6` reproduced the access failure before fixture work. Kernel
diagnostics explicitly report denied Mach lookup of
`com.apple.CoreSimulator.CoreSimulatorService` and
`com.apple.CoreSimulator.simdiskimaged`. Other denied services include
Open Directory, Core Services and Disk Arbitration; their necessity is not
established. UID cleanup and ordinary scratch detach passed.
No allowance has been added. Granting service lookup is a material boundary
change: service helpers are not proven to inherit the caller's UID limits,
sandbox, disk or network policy. A trusted inventory-only diagnostic profile
versus an alternative simulator runtime boundary requires owner selection.

The owner selected the trusted inventory-only probe. Compose the existing
read/write/network policy with exactly the two named CoreSimulator Mach
lookups for this script-owned invocation only. No other denied service is
allowed automatically; failure is retained. Keep the 60-second command
deadline, no boot, private scratch device set and no generated calls.
Root-side observation records only exact helper executable names and
UID/PID/parent/RSS/virtual-memory/CPU fields, with a five-second snapshot
deadline, and rechecks scratch capacity. These observations do not prove
helper containment or authorize simulator boot. Generated fixture/build
commands retain the unchanged blanket Mach denial.

The two-lookup probe in
[38159023923](https://github.com/trancee/cairn/actions/runs/38159023923)
at `239b8f4` reached JSON inventory but failed the available-iOS assertion.
No available runtime is established; the returned record count and
availability reasons were not captured by that version of the script.
Add those structured inventory diagnostics before the unchanged assertion.
Kernel diagnostics now include denied `com.apple.CoreSimulator.SimLaunchHost-arm64`
lookup, Disk Arbitration and IOKit clients; necessity is not established.
The helper snapshot found root-owned `simdiskimaged` (PID 12346, parent 1,
RSS 21,840 KiB), after dedicated-UID cleanup. This demonstrates that the
caller-UID cleanup/resource policy does not cover every simulator helper;
no root-helper containment is claimed. Whole-VM memory remains bounded.
Scratch capacity recheck and ordinary detach passed. No further service
allowance or runtime boot is authorized; retain the inventory failure.

The unchanged two-lookup diagnostic replay
[38159746830](https://github.com/trancee/cairn/actions/runs/38159746830)
at `2624f0c` expired its 60-second inventory deadline before JSON diagnostics.
Dedicated UID cleanup, scratch capacity and ordinary detach passed.
Root-owned simdiskimaged remained observable (RSS 25,344 KiB, CPU 30.24s).
Availability reasons remain unverified; the two-lookups-only profile is
neither sufficient nor deterministic on this evidence. No implicit retry,
deadline increase or further service allowance is applied. Simulator runtime
requires a separately approved service/helper containment design.

The owner selected a further inventory-only experiment: add exactly the
observed `com.apple.CoreSimulator.SimLaunchHost-arm64` lookup to the separate
trusted profile. The prediction is that permitting this lookup exposes iOS
availability records; all other denials, the 60-second deadline, scratch
device set and no-boot/no-generated-call boundary remain unchanged.
This does not establish or waive helper containment.
[GitHub's runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners#limitations-for-arm64-macos-runners)
explicitly excludes nested virtualization on ARM64 macOS runners; a nested
VM is not a supported replacement boundary here. A separately controlled
Apple environment remains an alternative external prerequisite.
