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
