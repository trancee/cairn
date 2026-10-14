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

PR #7's preparation failed the same aggregate tool-cell deadline after the
expected invalid-selection rejection. The settings probe buffered subsequent
Gradle output until return, obscuring partial progress when the collector
expired. A real-script/collector regression fails on that missing output;
streaming through the existing `tee` pattern preserves progress and the
original child status under `pipefail`. This is diagnostic hardening only:
no command, assertion, budget, permission, cache policy or retry changes.
Current-source hosted acceptance remains required; no latency or reliability
improvement is inferred from the regression.

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
The preparation push filter now includes all Apple `.sb` profiles so changing
the separate inventory policy schedules its owning hosted proof; previously
only `build.sb` changes matched. Official checkout/upload release identities
were reverified as `v7.0.1`/`v7.0.2`; their existing immutable pins remain.

The three-lookup inventory passed in
[38162040714](https://github.com/trancee/cairn/actions/runs/38162040714)
at `cd7f2ae`: 12 runtime records, with available iOS `26.2`, `26.4.1` and
`26.5`. This supports the narrow SimLaunchHost access prediction, not
necessity of any other denied service. Root-owned simdiskimaged remained
observable (RSS 21,904 KiB, parent 1). Subsequent actual JVM calls,
device/simulator/common compilation, both framework links/deployment floor
`15.0`, all workflow input-hash checks and ordinary cleanup passed.
No simulator was booted and no generated simulator calls ran. Inventory
access is now characterized; runtime/helper containment is still open.

The owner approved a trusted one-device create/boot/shutdown diagnostic in
the private scratch set, with unchanged 60-second cells and no generated
app installation/calls. No automatic service widening is included.
Trusted helper writes outside scratch remain an explicit diagnostic risk,
not accepted runtime containment. First collect actual `simctl` lifecycle
help and iPhone device-type identifiers in the existing inventory seam;
this prerequisite does not create or boot a device.

Run `38163868922` passed inventory but the first lifecycle help command
omitted `--set` and attempted the default device set. It failed before
returning help; do not interpret its allocation diagnostic as proven RAM
exhaustion. Supply the same explicit scratch device set to every simctl
invocation, including help. No default host device state is intended.

Private-set help and device-type discovery passed in `38164460672` at
`41ba912`, followed by all fixture/hash/cleanup gates. Actual help confirms
explicit type/runtime create arguments and boot/bootstatus/shutdown/delete
commands. First exercise the approved lifecycle creation slice only:
create one `iPhone-17`/iOS `26.4.1` device in the private set and assert its
unique UUID and `Shutdown` state. Keep its metadata in disposable scratch;
do not boot or install an app in this slice. The unchanged 60-second
supervisor cleans caller-UID processes after the invocation.

Trusted private creation passed in `38165989640` at `9e405d3`: exactly one
new device in `Shutdown` state, then all fixture/hash/ordinary cleanup gates.
Next exercise approved ARM64 boot/bootstatus/shutdown in one 60-second cell,
with explicit nested command deadlines totaling at most 55 seconds.
Always request exact-device shutdown before returning, including boot errors;
shutdown failures remain failures. No app installation/generated call or
additional service allowance is included.

Boot run `38167434234` at `ae21ed6` failed the 60-second collector deadline
without boot/shutdown completion output. The dedicated-UID cleanup then
failed its own ten-second deadline, and ordinary scratch detach failed
`Resource busy`; no holder identity was collected. Nested subprocess
deadlines did not establish effective completion/cleanup in this run.
Do not claim a booted simulator, successful shutdown or cleanup.
Use the existing one-shot identity-only supervisor diagnostic at ten seconds
and targeted failed-boot kernel/remaining-UID observations before interpreting
the cause. Budgets, services and generated-code denial remain unchanged.

Diagnostic replay `38168165135` at `1b03bc6` again expired boot's 60-second
deadline. At ten seconds it observed launchd-parented simulator services,
including CoreSimulatorService, SimLaunchHost, SimulatorTrampoline,
SimRenderServer and SimAudioProcessorService; the audio process was in `U`
state. Post-failure observation found a launchd-parented `distnoted` process
still under the dedicated UID. This supports a service-lifecycle containment
gap, not a confirmed single denied-service cause. No boot/shutdown completion
or successful cleanup was observed. Repeated unchanged boot probes are not
a solution: controlling launchd services and their restarts requires a new
explicitly approved trusted boundary, or independently controlled Apple
infrastructure. Do not increase deadlines or signal unrelated services.

The owner approved removing only the disposable account's `user/59000`
launchd domain after the workload. The actual boot/cleanup failures in
`38167434234`/`38168165135` are the red regression at the supervised lifecycle
seam. Add opt-in `--bootout-user-domain` to that boot invocation only.
Validate hosted-root/dedicated UID identity, use exact `launchctl bootout`
with a five-second deadline inside the existing ten-second cleanup window,
then verify the UID is empty. Do not touch system/runner/GUI domains, disable
services persistently, raise limits or accept failed bootout.
The [launchctl manual](https://keith.github.io/xcode-man-pages/launchctl.1.html)
documents user-domain removal; its printed domain structure is not a stable
API and will not be parsed as an enforcement mechanism.

Run `38168984924` failed the earlier inventory deadline before reaching
the domain-cleanup regression; ordinary detach passed. Remove now-completed
lifecycle help/device-type discovery from the inventory cell: exact command
contracts and pinned type identities were already characterized in
`38164460672`. This narrows the prerequisite without changing its available
iOS assertion or 60-second ceiling; it is not a reliability fix.

Run `38169654181` at `f209f14` failed ordinary disk detach in benign preflight
(`Resource busy`), so preparation and the domain-cleanup regression did not
run. The opt-in implementation remains unverified at its intended seam.
Two distinct preceding prerequisite failures are retained; do not infer a
cleanup green from local tests or rerun unchanged jobs until one happens
to pass. Benign scratch cleanup reliability must be diagnosed alongside
the simulator domain boundary before final acceptance.

The benign preflight failure `38169654181` reports "couldn't eject" after
all UID/workload checks pass; recursive scratch lsof returned no retained
holder identity. Distinguish volume unmount from whole-image eject before
assuming a caller holder. Make ordinary detach verbose and collect only
device/mount/ejectability fields from exact-volume `diskutil info` after
failure, with a five-second diagnostic deadline. No retry, force, service
mutation or relaxed success check is added.

Run `38204550881` at `638c278` reached boot data migration but expired
60 seconds. The approved `user/59000` domain removal then passed and the UID
became empty: the observed lifecycle cleanup regression is green.
Scratch unmount still failed busy, with its mountpoint retained; caller
cleanup is not complete storage/helper cleanup.
The owner approved 300 seconds for this trusted boot/migration/shutdown cell
only, retaining other limits, service permissions and no generated app.
Nested command ceilings total at most 290 seconds. Replace recursive-directory
lsof selection with exact-filesystem selection (`+f -- <scratch>`) so deleted
or unenumerated open files on the volume are eligible for identity-only
diagnostics. This does not force/retry detach or claim a holder was found.

Run `38212924042` at `c03d07d` expired the earlier cold inventory's unchanged
60-second ceiling, never reaching boot. UID cleanup/ordinary detach passed.
The owner separately approved 300 seconds for trusted inventory startup,
with a ten-second identity-only process snapshot and all other controls
unchanged. This is a measured cold-start diagnostic budget change, not proof
of reliability or permission for generated runtime calls.

Run `38215350684` at `8d5071e` passed cold inventory and private creation,
then expired the approved 300-second boot cell. Bootstatus remained on
`00LaunchServicesMigrator` for over four minutes. Exact-domain removal,
empty UID verification and ordinary scratch detach passed; no holder was
needed in this run. This closes the observed domain cleanup integration,
not intermittent detach reliability or successful boot.
Move the boot's existing one-shot process snapshot from ten to 120 seconds
to observe the stalled migration phase rather than early simulator launch.
No second snapshot, new permission, timeout increase or migration bypass is
added. Earlier nested command timeouts did not stop bootstatus before the
outer deadline; outer supervision remains the observed hard boundary.

Run `38216685239` at `8108bb8` again stalled in LaunchServices migration.
The 120-second snapshot contained 166 UID-59000 processes, exceeding the
caller's 128-process ceiling: launchd services do not inherit that proven
caller limit. Domain removal, empty UID and ordinary detach passed again;
full runtime resource containment remains unverified.
The owner approved one bounded stack-only sample of host-side `lsd` owned
by UID 59000, excluding unrelated processes/arguments/environment/file
contents. First require the supervisor CLI to reject sampling without a
scheduled diagnostic; unknown-option rejection is not the expected contract.

The intended red passed its setup and failed the expected contract in
`38218142377`: `--sample-host-lsd` was unknown rather than rejecting missing
diagnostic scheduling. Implement opt-in sampling only for the first observed
host `lsd` with dedicated UID and parent 1, rechecking identity immediately
before sampling. One-second sample, five-second command deadline, 1 MiB
sample-file ceiling and zero core; emit at most 180 call-graph lines only,
not headers, binary paths or arguments. Temporary sample bytes are removed.
The original outer lifecycle deadline and domain cleanup remain unchanged.

Run `38218295326` at `acea57d` passed the scheduling regression but the
actual sample exceeded its five-second diagnostic deadline before a call
graph was returned. Domain removal and UID cleanup passed; no stack cause
is established. The owner separately approved 20 seconds for profiler
setup/symbolication only, retaining the one-second sample window, 1 MiB
file ceiling, stack-only output and unchanged outer lifecycle deadline.

Run `38219474925` also timed out profiling before a stack was returned;
do not increase that ceiling again or infer a stack cause.
The owner approved a separate trusted lifecycle-context experiment:
`launchctl asuser 59000` before the existing child privilege drop.
The launchctl manual documents adopting Mach bootstrap/audit context without
changing credentials/environment. Current `setuid`/`setgid`/HOME setup does
not explicitly select that context. First require the supervised child to
observe `manageruid` 59000, with exact-domain cleanup; missing CLI support
must fail the test before implementation. Generated/build commands remain
unchanged and launchd-helper resource inheritance is still unproven.

The bootstrap observation test failed as intended in `38220750953` because
`--user-bootstrap` was unknown. Implement exact-UID `launchctl asuser` around
the existing root child launcher, before its limits/credential/environment
setup, inside the same bounded collector. Use it only for the trusted boot
experiment; stop requesting the unsupported stack sample there. Original
build/fixture commands and service permissions remain unchanged.

Run `38220908711` at `aab5640` passed all seven hosted supervisor regressions,
including actual child bootstrap UID 59000. Trusted boot still stalled in
the same LaunchServices migration and expired 300 seconds. Domain removal,
empty UID and ordinary scratch detach passed. This falsifies bootstrap
selection alone as a fix; it does not prove the cause or complete boot.
Remove the failed bounded stack-sampling experiment and its scheduling-only
test rather than retain an unverified profiler path; preserve its failed
evidence above. Keep the verified bootstrap/domain controls and their real
CLI regression. No further deadline increase, migration bypass or generated
simulator execution is justified by these results.

Final source replay `38222383057` at `f2c73ed` again expired trusted boot
at 300 seconds; exact-domain teardown, empty UID and ordinary detach passed.
The owner selected strict infrastructure rather than a weaker functional-only
hosted simulator lane. No independently controlled Apple host/VM, capacity
or access/provisioning route was supplied in the infrastructure elicitation.
Strict runtime acceptance therefore has an external infrastructure blocker.
Do not repeat unchanged hosted boot probes, relax the acceptance contract,
or provision/build on the excluded shared local Mac. Preserve compilation/
JVM/linkage/inventory evidence separately from incomplete simulator/hardware
execution and whole-runtime containment.

## Separate hosted functional runtime lane

The owner subsequently selected a separate fresh hosted functional-runtime
job using the normal runner user and CoreSimulator context. Strict offline
build controls stay unchanged; strict issue-45 acceptance and physical-device
proof remain blocked. Runtime helper filesystem/resource/network guarantees
are weaker and must not be relabeled as strict containment.
Remove the failed custom-account inventory/boot path from the owning build
sequence. Compile the canonical Kotlin smoke consumer as an iOS-simulator
ARM64 executable, transfer only checksum-verified fixture bytes to the fresh
job, and run bounded generated calls with exact-device cleanup. No signing
or project secrets. First request the owning executable-link task before
declaring that binary: it must fail for the absent task, not setup.

The owning-task red is observed in
[run 38224421218](https://github.com/trancee/cairn/actions/runs/38224421218)
at `f45780f`: prior JVM/Native/framework tasks pass and Gradle rejects absent
`linkDebugExecutableIosSimulatorArm64`. An earlier run `38224109195` failed
benign scratch eject, not the intended seam; exact whole-disk identity is now
retained before detach so post-unmount failures remain diagnosable.

Declare the executable and map only `iosSimulatorArm64Main` to the immutable
canonical smoke source. Root exports compared bytes after supervised linkage;
the fresh functional job validates the closed three-file payload, SHA-256,
same-run source revision, ARM64/Mach-O simulator identity and minimum OS
`15.0`. Real payload-validation tests go red on the absent validator, then
green for valid input and corrupt/missing/symlink/oversized/extra/path-traversal/
revision-mismatched input. Runtime uses a private device set and recorded UUID,
with 300-second bootstatus, 60-second calls and separate bounded cleanup.
The obsolete disabled-account simulator scripts/profile and freeze consumers
are removed; historical evidence remains in this ADR and Git history.
This is an explicit functional lane, not a fallback inside the strict cell.
No API/version/SDK/signing change or whole-helper containment claim is made.

Run `38226464134` at `4346431` passes strict owning executable linkage,
simulator ARM64/minimum OS `15.0`, all frozen-input checks, scratch cleanup
and same-run delivery. Fresh normal-user bootstatus reports Finished in
two minutes; the redundant post-boot whole-set list command exceeds its
15-second ceiling before generated calls. Exact recorded-device shutdown/
deletion passes. Remove that redundant inventory operation: successful
bootstatus is already tied to the recorded UUID, and actual generated calls
are the runtime acceptance seam. Keep creation, boot, call and cleanup bounds.
Use the documented standalone executable launch contract from Kotlin's
[XcodeSimulatorExecutor](https://github.com/JetBrains/kotlin/blob/master/native/executors/src/main/kotlin/org/jetbrains/kotlin/native/executors/XcodeSimulatorExecutor.kt):
`simctl spawn --standalone <UUID> <executable>`. No changed runtime limit,
default-set mutation or successful generated-call claim is implied yet.

### Observed functional execution

[Run 38228998011, attempt 2](https://github.com/trancee/cairn/actions/runs/38228998011/attempts/2)
at `19c35ba000a17f734ce04b1685d28d0c40d64e74` passes actual delivered
simulator execution. Attempt 1 passed benign preflight and strict offline
build, executable platform/floor inspection, immutable-input hashes, scratch
teardown and payload delivery, then exceeded the 30-second create deadline
and 15-second cleanup inventory deadline. Replay only the failed functional
job on a fresh supplied VM; retain the same source/payload and every limit.
No retry, additional service permission or deadline expansion is implemented.

The replay reports completed exact ARM64 bootstatus, typed overflow across
FFI, value/boundary/string/object-lifetime assertions, successful delivered
consumer exit and verified exact-device shutdown/deletion. Downloaded payload
checksum and revision match: executable SHA-256
`1c1f429e9c7bb47814070f871ff24e6a896dfdeac7ff9a84c8a175cce8cdb229`,
ARM64 `IOSSIMULATOR`, minimum OS `15.0`. The source-backed standalone launch
contract now has real generated-call evidence. The initial creation-timeout
cause is not established or fixed, and first-attempt reliability is not proven.
This closes the approved functional-runtime implementation only: strict
helper containment, final issue-45 acceptance, Compose/app integration,
release behavior and physical iPhone execution remain open.

## Manifest-generation optimization

On 2026-10-13 the owner requested lower CI latency while retaining the supplied
GitHub macOS VM and existing strict gates. The observed CodeQL preparation
baseline spent 139 seconds freezing tools. A bounded local comparison of a
real 1.21 GB Rust tool tree found copying negligible (`0.09s`) but serial
`shasum` generation slower than Python's SHA-256 implementation. The actual
CLI component benchmark first failed its 10% improvement target, then passed
with identical manifests: median `3.79s` versus `0.68s`, about 82% lower.
This is local component evidence, not an end-to-end or hosted speedup.

Use one standard-library streaming generator for the four existing manifests,
after their unchanged ownership/read-only setup. Preserve byte sorting,
regular-file selection, escaped filenames, SHA-256 and manifest prefixes.
Keep the independent native `shasum --check` gates after the full strict cell.
Reject empty inventories, invalid/root-escaping scopes and I/O failures
explicitly without emitting a partial stdout manifest. This is tooling-input
integrity, not a protocol cryptographic-provider or constant-time change.

Changing copy strategy was rejected because `ditto` already copied this
workload quickly. Caching compiled results, removing integrity/probe gates,
prebuilding the generator outside its owning task, widening permissions or
raising budgets are not selected. No cached manifest/result is trusted.

The risk is a generator/format mismatch or platform-dependent performance.
Exact comparisons against the previous pipeline, independent `shasum` replay
and adversarial scope/name/error tests bound the format change. The retained
benchmark records the committed baseline, source hashes, workload, environment
and all samples; it cannot substitute for full hosted preparation/analysis.
Migration changes only the four manifest producers. Existing manifest names,
consumers, copies, compiler tasks, all security/resource controls and immutable
pins remain unchanged. Hosted comparison requires separate publication/
execution approval; no issue-45 or scratch-reliability acceptance is implied.

### Initial hosted acceptance and bounded diagnosis

At `d17aded`, both generated tool manifests preserve the same 80,635 input
paths as the verified baseline. The five digest differences are confined to
Rust component metadata/Ubique Git metadata. However, whole-step freezing
takes `162s`/`242s` rather than the earlier `139s`; the observed comparison
does not pass the performance gate or isolate the cause. The PR cell then
rejects unexpected dedicated-UID processes before Native cinterop; the branch
cell expires the existing 60-second startup/selection deadline. No final
Kotlin extraction/query/integrity acceptance or failure fix is established.

Use temporary tagged copy/ownership/manifest phase timing and a manual-only
full pinned-tree A/B measurement in the existing fresh preparation VM.
Each existing benchmark command stays capped at 120 seconds; the job remains
30 minutes. Remove this temporary workflow/timing instrumentation after
collection. Add the already-existing redacted process-identity report before
the unchanged existing-UID rejection: diagnostics only, never preflight
cleanup, delayed trust acceptance or a resource/permission increase.
This diagnostic regression was observed red before that report and green
after it; local simulation does not prove the hosted helper's identity/cause.

### Same-VM result and diagnostic cleanup

[Manual run 38460658960](https://github.com/trancee/cairn/actions/runs/38460658960)
at `a8fff9e` compares the full 80,635-file, 5,860,115,366-byte pinned tree
on one supplied `macos-26` VM. The three-CPU ARM64 environment reports
macOS `26.6.2`, Xcode Python `3.9.6` and LibreSSL `2.8.3`.
Three alternating baseline/candidate samples retain identical manifests:
baseline `76.27s`/`59.31s`/`78.51s`, candidate `50.15s`/`38.27s`/`46.17s`.
The median ratio is `0.6054` (39.5% lower), below the unchanged `0.9`
acceptance threshold. The manifest SHA-256 is
`5f5759844b54cc702180eed95cd29167098004ba7514e39cad9d5af65cb99b6a`.
Phase timing records copy `77s`, ownership/permissions `19s` and initial
generation `39s`; whole-step variation cannot be attributed to hashing alone.

The earlier manual request `38454793910` acquired no hosted runner.
Run `38459283620` failed before target work because the shallow checkout
lacked the baseline Git object; fetching only the exact public commit fixed
that diagnostic setup. No compiler/build failure was bypassed.
The successful A/B adds about six minutes of measurement and the full
diagnostic later exhausts the unchanged 30-minute job ceiling.
Do not treat that partial diagnostic as a complete build or latency proof.
Ordinary PR/push CodeQL runs `38460667964`/`38460659594` at `a8fff9e`
pass strict Kotlin extraction, coverage, queries, post-cell integrity,
cleanup and result delivery/processing; ordinary Rust/formal checks also pass.
Full CodeQL wall-clock improvement and deterministic runner reliability remain
unestablished. The unexpected UID condition did not recur, so no helper
identity/root-cause or reliability fix is claimed.

Remove the tagged timing, temporary manual step and exact-object fetch.
Retain only the opt-in representative benchmark, faster manifest producers
and tested redacted preflight report. Normal CI performs no A/B workload.
Final cleanup-head hosted gates remain required before merge.

### Partial target diagnostics and final-head failure observation

At cleanup head `db68586`, final Rust/formal and non-Kotlin CodeQL gates pass.
PR run `38465374925` first fails ordinary scratch detach, then its unchanged
failed-job replay fails the existing one-shot UID snapshot assertion.
Push run `38465367937` expires the separate offline effective-target/
dependency-metadata cell after the tool/selection probes pass. The target
script buffers Gradle output until return, so expiry loses that partial
stage evidence. These failures do not establish a manifest regression or
their own root causes.

The owner approved a scoped diagnostic/fix/publication follow-up without
relaxed gates. Stream both Gradle channels through `tee` into the existing
bounded collector, keeping the existing scratch log and `pipefail` failure
propagation. A real-script/collector regression is red on missing partial
output before this change and green after it; nonzero child status also
propagates unchanged. The test uses controlled subprocesses, not an accepted
Gradle build.

Increasing timeouts, repeated automatic runs and accepting an empty snapshot
instead of the existing assertion are not selected. Manual hosted probe
`38514098575` passes all supervisor/resource/boundary cases at `6ad4bb9`;
its eight artifact checksums verify. PR run `38513991094` passes offline
effective targets/metadata and later rejects a UID-59000 `distnoted` process
parented by PID 1. This identifies that observed helper, not its origin,
lifetime or the helper in earlier failures. No pre-cleanup or trust exception
is added. The missing-snapshot failure does not recur, so its cause remains
unestablished. Separate formal run `38513991093` fails unchanged mutation
certificate replay with Tamarin `<<loop>>`.
Push run `38513985911` completes Kotlin extraction, coverage and queries but
fails ordinary scratch detach before post-cell input integrity and delivery.
Those missing gates are not waived by the earlier completed extraction.

Remove temporary tagged child-bootstrap/snapshot tracing after collection;
retain controlled test-child log context on assertion failure. The migration
changes diagnostic delivery only, not tools, targets, compiler tasks, public
API, ownership, network policy or any resource/deadline budget.
At cleanup head `8b4c2d6`, PR CodeQL `38515603675`, Rust `38515603697`
and formal `38515603660` pass. GitHub processed all four PR language scans
at merge revision `47a9c5207514ea28f5ab7393233148ced60dc5b5` without errors.
Duplicate push `38515598161` fails its first attempt on another pre-existing
UID-59000 `distnoted`; its one unchanged failed-job replay also fails.
This closes final PR-head acceptance, not deterministic runner reliability
or successful duplicate-push acceptance.

## Same-VM generator compilation reuse evaluation

The owner approved implementation, publication and bounded hosted comparison
on 2026-10-14. Successful PR run `38515603675` took 23m38s versus the original
24m16s, but preparation still took 20m59s and owning `installBindgen` about
4m10s. These different-VM observations do not establish a causal speedup.

Pinned Ubique `b819fb4` sets the install task's `CARGO_TARGET_DIR` from its
own `bindgenBuildPath`, overriding the shell's shared directory. Its installer
also uses an implicit host target, unlike explicit-target fixture compilation.
The evaluated implementation at `75c5623` configured that public task property
to the fixture's `cargo.targetDirectory` and supplied explicit
`--target aarch64-apple-darwin` for generator installation. Competing target/
directory arguments failed before Cargo. Default Linux/Android configuration
and SDK Rust profiles/targets were unchanged.

Cargo alone decided which freshly compiled same-VM dependencies were compatible
by its normal source, version, feature, profile, target and compiler fingerprints.
The experiment retained the plugin's real installation, source fingerprint,
target lock and ready record, without binary injection, fabricated fingerprints,
cross-run compiled restores or skipped gates. An effective-configuration probe
checked both task directories; real adapter assertions were red before the
target-ownership implementation and green afterward.

The archived opt-in paired benchmark replayed the committed `8b4c2d6` Cargo
installation policy with an empty baseline target directory versus the
experimental adapter using fixture dependencies compiled earlier on that VM.
Both installed the same locked, immutable generator source freshly into
separate empty roots. Cargo JSON established fresh generator compilation
in both cases, zero baseline reuse and positive candidate reuse; both real
ARM64 binaries were inspected.
The result included source/lock/adapter/benchmark hashes, Rust/host/Python/CPU
metadata, artifact counts, binary hashes and elapsed times. It measured Cargo
installation, not Gradle startup or whole-workflow latency.

Each explicitly selected comparison retained the existing 600-second command,
30-minute job and all memory/disk/file/process/CPU/network/isolation bounds.
Normal CI never ran it. Three complete independent paired reports, both orders
and matching input/environment hashes passed their checksum and all four
post-cell immutable-input gates:
`38525913102`, `38529286247` and `38529289684`, each attempt 2.
Their first attempts failed pre-existing UID-helper refusal or a five-second
`diskutil info` timeout; each failed job was explicitly replayed once, unchanged.
These are not reliability fixes or automatic retries.

Paired candidate/baseline ratios were `1.06195`, `1.08933`, `0.92474`;
median `1.06195`, about **6.2% slower**, despite reusing 36 artifact records
and reducing compiled records from 103 to 72. The 10% regression ceiling
passed, but the requested speedup did not. Ordinary Native/framework/executable
compilation and functional simulator calls also passed in `38529289684`,
attempt 2; CodeQL/Rust/formal and all four processed PR scans passed at
`75c5623`.

Do not adopt this optimization: restore the original generator adapter,
SDK/task directory configuration and owning workflows byte-for-byte from
`8b4c2d6`; remove the experiment-only test, dispatch and benchmark paths.
The implementation and reproducible report summarizer remain in committed
`75c5623`, and verified results are recorded in
[PR #8](https://github.com/trancee/cairn/pull/8).
Retain the separately approved duplicate-scheduling fix. No elapsed-time
improvement is claimed from fewer Cargo artifact records.
Checksum-verified archive reuse and change-aware gate applicability are not
part of this decision.

## Failure-only scratch-detach diagnostics

PR #9 CodeQL run `38573866366` at branch head `53de10f` completed actual
Kotlin tracing, coverage, bundled security queries and export, then failed
the resource fixture's exit trap. Its eager five-second `diskutil info`
lookup timed out even though subsequent ordinary `hdiutil detach -verbose`
successfully ejected `disk7`. The earlier diagnostic error retained result
one. Post-cell immutable-input checks and successful-result upload were
skipped, so this is not accepted Kotlin CI. The outer PF cleanup's result
one propagates the child failure; it does not establish a PF cleanup failure.

The owner approved a failure-only diagnostic fix, OS-command/teardown tests
and updated-source CI. Extract ordinary scratch teardown into the stable
internal `detach-scratch.py` boundary. Validate the caller's canonical owned
volume path before native mutation. Eject first and return zero only after
actual ejection success. On failure, retain failure and collect the existing
selected disk-state and holder-identity diagnostics within their unchanged
five-/15-second ceilings. Invalid or unavailable diagnostics report a
redacted error category without hiding the independent holder collection.
The caller still preserves earlier workload/account-cleanup failures.

The approved OS-boundary regression first returned one for successful
ejection plus a timed-out metadata lookup, then passed after the lookup
became failure-only. Failed ejection remains nonzero with state/holder
reports; unavailable commands, malformed/truncated metadata, invalid volume
paths and diagnostic timeout/error cases are covered. The initial fix's Python
`3.9` local execution passes the complete Apple tooling suite (58 tests, six hosted-only
supervisor skips). Hosted native teardown and final-source four-language
analysis remain separate authoritative requirements.

Keeping the eager lookup was rejected because optional diagnostics must not
create an independent success-path failure. Ignoring real detach failures,
retrying, forcing ejection or increasing deadlines was not selected.
Moving lookup after failed ejection can lose mount-path metadata when unmount
already succeeded; report that unavailability rather than invent disk state.
The selected fields still include `ParentWholeDisk` when available.
Earlier busy detach/helper failures and first-attempt reliability remain open.

Migration replaces only the final trap's inline teardown with the helper;
existing benign-preflight discovery owns its tests. No protocol, API, wire,
production dependency, sandbox/PF permission, resource budget, compilation
task, integrity gate or result-acceptance change is authorized. Final-head
hosted evidence must be recorded by the PR; successful Kotlin analysis alone
cannot substitute for cleanup, post-cell integrity and processed scans.

### Owned-image diagnostic follow-up

At published `8e6d82d`, final formal `38580683833` (19 jobs) and Rust
`38580683851` (11 jobs) pass, attempt one. CodeQL `38580684474` instead fails
benign preflight on real `hdiutil` ejection failure: `Resource busy`.
All 58 tooling tests, all six actual dedicated-UID supervisor regressions,
resource/sandbox assertions and empty-UID checks pass. The new helper correctly
retains nonzero. Mount-path metadata and holder collection both return
`CalledProcessError`; that is unavailable evidence, not proof of no holders
or completed unmount. The eight retained artifact checksums verify.
Kotlin preparation and its final integrity/delivery gates are skipped.

The owner approved bounded owned-image diagnostics, their tests, commit/push
and updated-source CI. Pass the current owned image path from the protected
hosted caller; require the same canonical fixture directory and one of its
two existing image filenames. After failed ejection, use the native
[machine-readable image inventory](https://keith.github.io/xcode-man-pages/hdiutil.1.html#info)
to select only an exact image-path match. Validate unique device entries,
one whole-disk namespace and assigned mount points before printing or using
device targets. Never print the full inventory or unrelated image metadata.
Reported mount-point presence is evidence at that observation, not inferred
whole-disk state or a successful-unmount assertion.

The original mount-state query and image inventory share the existing
five-second monotonic metadata window. Filesystem-holder and exact
image/device-holder queries share the existing 15-second window; exhausted
windows prohibit follow-on commands. Only PID/command fields are accepted.
Keep valid partial holder output on nonzero query status and report that
status explicitly. All errors retain the original ejection failure.
Discovery failure still permits independent read-only collection for the
known owned image file, never guessed or foreign devices.

The approved regression is red on missing owned-device/holder identity after
failed ejection plus unavailable mount-path information, then green after
this change. Sixteen focused tests cover unrelated-image exclusion, malformed/
ambiguous inventory, invalid image paths, reported mounts, partial/invalid
holder fields and virtual-clock shared-deadline exhaustion. Python `3.9`
passes the complete 66-test tooling suite with six hosted-only supervisor
skips. Simulation is not native busy-ejection root-cause or reliability proof;
final-source hosted execution remains required.

Parsing human-readable verbose output was rejected in favor of the documented
plist interface. Suppressing real ejection failure, retry/force, guessing disk
identity, signaling holders or granting each new command a fresh deadline
are not selected. This follow-up changes diagnostics only, not detach strategy,
permission, budget, resource/integrity gates or the unresolved acceptance scope.
Migration updates the sole owning shell invocation and every test consumer
to the two-path internal CLI; no released SDK/API or protocol change.
