# Research findings: can Docker containers satisfy the required isolated-build-runner sandbox?

Scope: primary sources only (Docker Engine/Desktop official docs, Apple's own
Xcode distribution page, GitHub Actions runner docs), bounded to the question
raised by
[issue 45, "Provision isolated build runner"](../../.scratch/pqcble-r1/issues/45-provision-isolated-build-runner.md)
for the Ubique UniFFI Gradle/Cargo prototype gated by
[issue 44](../../.scratch/pqcble-r1/issues/44-ubique-binding-smoke-test.md).
No build/test execution was performed; this is a feasibility assessment only.

## 1. Docker availability on this host

**Verified.** This host (Darwin 27.0.0, arm64, Mac mini M1) has no `docker`,
`podman`, or `container` binary on `PATH` (`which`/`--version` checks all
failed with "command not found", checked 2026-10-08). This matches issue 45's
2026-10-08 comment recording "no container runtime" on this machine. Using
Docker here would first require installing Docker Desktop (or another
runtime), which is an infrastructure change outside this note's read-only
scope and would still need explicit authorization per issue 45's own framing
("creating or modifying a hosted runner is an external-service action and
needs the owner's infrastructure choice and authorization").

## 2. What Docker Desktop on macOS actually runs, and whether Apple builds fit

**Verified: Docker Desktop on Mac does not run containers natively on macOS.**
It runs a **Linux virtual machine** and containers execute inside that Linux
VM's kernel, not the host macOS kernel. Docker's own "Virtual Machine Manager"
page states Docker Desktop on Mac is backed by either "Docker VMM" (Docker's
own VMM, replacing `libkrun` as of Desktop 4.86) or the "Apple Virtualization
framework," both of which "power the Linux VM that runs containers"
(`docs.docker.com/desktop/features/vmm/`, fetched 2026-10-08). There is no
option to run a macOS-kernel container on Docker Desktop for Mac; every
container is a Linux container regardless of host architecture.

**Verified: Xcode (and therefore the iOS/iPadOS/tvOS/watchOS/visionOS SDKs
and `xcodebuild`/simulator toolchain) requires macOS and does not run on
Linux.** Apple's own Mac App Store listing for Xcode states plainly:
"Requires macOS 26.6 or later and a Mac with Apple M1 chip or later"
(`apps.apple.com/us/app/xcode/id497799835`, fetched 2026-10-08, confirmed via
raw page text: `Requires macOS 26.6 or later and a Mac with Apple M1 chip or
later.`). Xcode has never shipped a Linux build, and there is no supported
path to install or run Xcode, the iOS SDK, `xcodebuild`, or the iOS
Simulator inside a Linux container — Docker Desktop's Linux VM included.

**Conclusion for this question:** a **standard Docker container cannot run
the macOS/Xcode/iOS-SDK leg of the proof**, on this host or any other Docker
Desktop-for-Mac host, because Docker containers on macOS are Linux
containers and Xcode is macOS-only software. This is a hard platform
constraint, not a configuration gap. (Consistent with GitHub's own
hosted-runner design: GitHub's "GitHub-hosted runners" doc states macOS
runners are "a new virtual machine (VM) hosted by GitHub" — GitHub does not
offer macOS as a *container* image either; macOS workloads are always run in
a full macOS VM, never a container
(`docs.github.com/en/actions/concepts/runners/github-hosted-runners`, fetched
2026-10-08).)

## 3. Can Docker controls enforce the issue 45 acceptance criteria?

Checked against Docker Engine's own CLI/reference docs (Linux containers,
since that is what Docker Desktop for Mac actually runs):

| Control | Docker primitive | Verified? | Source |
|---|---|---|---|
| No network | `--network none` — "completely isolate the networking stack of a container... only the loopback device is created" | Yes | `docs.docker.com/engine/network/drivers/none/` |
| Explicit env allowlist | `-e`/`--env`, `--env-file` (containers do not inherit host env unless passed) | Yes | `docs.docker.com/reference/cli/docker/container/run/` |
| Read-only source/toolchain | `--read-only` — "Mount the container's root filesystem as read only" | Yes | `docs.docker.com/reference/cli/docker/container/run/` |
| Scratch-only writes | `--read-only` plus a single writable bind mount or `--tmpfs`/`--mount type=tmpfs` for the scratch dir | Yes | `docs.docker.com/engine/storage/tmpfs/`, `docs.docker.com/reference/cli/docker/container/run/` |
| CPU limit | `--cpus`, `--cpu-period`/`--cpu-quota` (cgroup CFS quota) | Yes | `docs.docker.com/engine/containers/resource_constraints/` |
| Memory limit | `-m`/`--memory`, `--memory-swap` (set equal to `--memory` to disable swap) | Yes | `docs.docker.com/engine/containers/resource_constraints/` |
| Process count limit | `--pids-limit` | Yes | `docs.docker.com/reference/cli/docker/container/run/` |
| Per-file size limit | `--ulimit fsize=<bytes>` (standard POSIX ulimit passed through) | Yes (documented as a generic `--ulimit` passthrough flag; Docker's reference lists `--ulimit` as "Ulimit options" without enumerating `fsize` explicitly in the fetched page, so treat the `fsize` sub-option as a standard Linux ulimit name, not a Docker-specific guarantee) | `docs.docker.com/reference/cli/docker/container/run/` |
| Total disk/quota | `--storage-opt size=<bytes>` | **Partially verified / conditional** — Docker's `overlay2` storage-driver doc only documents `overlay2` operating on an `xfs` (or compatible) backing filesystem with `d_type=1`; per-container size quotas via `--storage-opt size` are documented elsewhere as requiring `overlay2` with `pquota` on XFS (not confirmed in the pages fetched here). Docker Desktop's Linux VM's backing filesystem and storage driver were not independently confirmed in this pass, so disk-quota enforcement should be treated as **unresolved** until the actual Desktop VM storage driver/filesystem is checked. | `docs.docker.com/engine/storage/drivers/overlayfs-driver/` |
| Wall-clock limit | **Not a native `docker run` flag.** Docker has `--stop-timeout` (grace period for `SIGTERM`→`SIGKILL` on *stop*) and daemon-level `--default-stop-timeout`, but no built-in "kill the container after N seconds of execution" option. | **Unresolved as a Docker-native control** — must be wrapped externally, e.g. `timeout <seconds> docker run ...` or an external supervisor calling `docker stop`/`docker kill` after a deadline. | `docs.docker.com/reference/cli/dockerd/`, `docs.docker.com/reference/cli/docker/container/run/` |

**Conclusion for this question:** Docker's Linux-container primitives can
satisfy network isolation, explicit env, read-only root + scratch-only
writes, CPU/memory/pids limits, and (with a documented but unverified storage
driver/filesystem combination) a disk quota. Wall-clock enforcement requires
an external wrapper, not a native Docker flag. All of this only applies to
**Linux container** workloads; it says nothing about enforcing these same
controls around an Xcode build, because Xcode cannot run inside the
container in the first place (§2).

## 4. Practical split: JVM/Android vs. Apple targets

Given §2 and §3:

- **JVM and Android targets** (Gradle/Kotlin JVM target, Android compile via
  AGP + NDK with Linux-hosted toolchains, Rust host/Android-ABI cross
  compiles) are Linux-toolchain-compatible workloads and are the class of
  work for which Docker's Linux-container controls in §3 are a documented,
  verifiable fit — subject to resolving the disk-quota and wall-clock gaps
  noted above, and to actually installing/provisioning Docker on a runner
  (§1 shows none is available here).
- **Apple targets** (iOS device, iOS-simulator-arm64, any `xcodebuild`/iOS
  SDK/Xcode-toolchain step the prototype's own skill package requires per
  `references/gradle-targets.md` in the installed `ubique-uniffi` skill) are
  **out of scope for Docker entirely**. They require a macOS host (real
  hardware or a macOS VM under a hypervisor licensed/entitled to run macOS
  guests), not a container, per §2.
- This means no single Docker-based runner can provide "the macOS/Xcode,
  Android SDK/NDK, Rust targets, and linker tools" issue 45 asks for in one
  environment. A compliant setup — if Docker is adopted at all — would need
  **two different enforcement mechanisms**: Docker (or an equivalent Linux
  container/cgroup sandbox) for the JVM/Android leg, and a **separate
  macOS-native sandbox** (e.g. `sandbox-exec`-successor tooling, a dedicated
  disposable macOS VM, or a hardened per-build macOS user/profile) for the
  Apple leg — because Docker cannot isolate or even execute that leg.

## 5. Recommendation

Given (a) the requirement for an **end-to-end iOS 15 deployment-target proof**
(issue 44) that necessarily runs through Xcode/`xcodebuild`/the iOS SDK, and
(b) the **strict security-audit sandbox policy** in issue 45 (OS-enforced,
disposable, no-network, read-only toolchain, scratch-only writes, resource
and wall-clock limits, explicit evidence of enforcement):

- **Docker cannot be the sandbox for the Apple leg of this proof — at all —
  regardless of host provisioning.** This is a platform fact (§2), not a
  missing feature to configure around. Any sandbox design that includes the
  iOS 15 proof must provide macOS-native isolation (hypervisor-level VM
  snapshot/teardown, or an audited `sandbox-exec`-class/MDM-managed
  ephemeral-user mechanism) for that step.
- **Docker is a plausible, partially-evidenced candidate for the JVM/Android
  leg only**, but two acceptance-criteria gaps are unresolved from primary
  sources in this pass and should be closed before relying on it: (i) the
  exact disk/quota mechanism and its backing-filesystem prerequisite on
  whatever host runs Docker, and (ii) wall-clock enforcement, which needs an
  external wrapper/supervisor rather than a native flag.
- **This host is not a candidate either way right now**: no container
  runtime is installed (§1), and issue 45's own 2026-10-08 comment already
  independently concluded this Mac mini is "not currently a compliant
  runner" for disk/toolchain-caching reasons. Introducing Docker here would
  still leave the Apple leg unsandboxed by Docker.
- **Recommended path:** keep issue 45's existing recommendation (a
  disposable, pre-provisioned macOS VM/runner with enforced CPU/memory/
  process/filesystem/disk/wall-clock limits) as the mechanism for the Apple
  leg, and treat Docker (or an equivalent Linux-container runtime) only as
  an optional, separately-evaluated mechanism for the JVM/Android leg, after
  independently confirming the two unresolved controls in §3 against the
  actual runner's storage driver and chosen wrapper/supervisor. Do not
  present a Docker container as satisfying the Apple-target portion of the
  required sandbox under any configuration.

## Gaps and unresolved items

- Disk-quota enforcement (`--storage-opt size=`) prerequisites (storage
  driver + XFS `pquota`) were not cross-checked against any specific Docker
  Desktop Linux VM backing filesystem — unresolved, needs a dedicated check
  if Docker is adopted for the JVM/Android leg.
- `--ulimit fsize=` per-file-size behavior was not confirmed against a
  Docker-specific enumeration of supported ulimit names (the fetched
  reference lists `--ulimit` generically); treated as a standard Linux
  ulimit passthrough, not independently verified in Docker's own docs.
- Podman, gVisor/runsc, Firecracker, and other non-Docker container/microVM
  runtimes were out of scope for this note (the task bounded investigation
  to Docker specifically) and were not evaluated as alternatives for either
  leg.
- No build, container, or Xcode command was executed; all findings are
  documentation-based per the task's "no code/build execution" bound.
