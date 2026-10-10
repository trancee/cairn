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
