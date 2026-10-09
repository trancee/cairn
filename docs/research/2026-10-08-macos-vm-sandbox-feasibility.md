# Research findings: can this Mac mini host a compliant macOS VM sandbox for the Ubique iOS proof?

Scope: primary sources only (Apple's Virtualization framework reference docs,
Apple's own sample code, the macOS Software License Agreement, and Apple's
public Mac mini/Xcode product pages), bounded to the question of whether a
**macOS guest virtual machine** on this host can satisfy the sandbox
acceptance criteria in
[issue 45, "Provision isolated build runner"](../../.scratch/pqcble-r1/issues/45-provision-isolated-build-runner.md),
specifically for the leg of the proof that needs Xcode/the iOS SDK (which
[the companion Docker note](2026-10-08-docker-sandbox-feasibility.md)
established cannot run in a Linux container). No VM was created, installed,
started, or modified; no code was built or run. This is a documentation-based
feasibility assessment only.

Host facts taken as given per issue 45's own 2026-10-08 comment: Mac mini M1,
8 GB RAM, 15.6 GB free disk, Xcode 27 / iOS SDK 27 installed, Android SDK
present, no container runtime.

## 1. What Apple's Virtualization framework supports on Apple silicon

**Verified.** Apple's `Virtualization` framework lets a macOS app create and
run virtual machines, and on **Apple silicon only**, the guest can itself be
macOS: "This sample code project demonstrates how to install and run macOS
virtual machines (VMs) on Apple silicon," using `InstallationTool` to install
a macOS restore image (`.ipsw`) into a VM bundle and
`macOSVirtualMachineSampleApp` to run it
(`developer.apple.com/documentation/virtualization/running-macos-in-a-virtual-machine-on-apple-silicon`,
fetched 2026-10-08). A macOS guest is configured with `VZMacPlatformConfiguration`
(hardware model, auxiliary storage, machine identifier) and booted with
`VZMacOSBootLoader`; the restore image's compatibility with the current host is
queried via `VZMacOSRestoreImage.mostFeaturefulSupportedConfiguration`, which
"represents the most fully featured configuration that's supported by both the
current host and by this restore image" and is `nil` if the host supports none
of the image's hardware models
(`developer.apple.com/documentation/virtualization/installing-macos-on-a-virtual-machine`,
fetched 2026-10-08). Creating any `VZVirtualMachine` requires the app to hold
the `com.apple.security.virtualization` entitlement
(`developer.apple.com/documentation/virtualization/vzvirtualmachine`, fetched
2026-10-08), i.e. a code-signed, entitled app — not an ad-hoc shell command.
Since this Mac mini M1 is Apple silicon, it is architecturally eligible to run
a macOS guest (Intel Macs cannot run macOS guests at all via this framework;
only Linux guests are documented for Intel hosts in the same framework
overview).

## 2. Hardware/resource minimums: no fixed numbers are published by Apple

**Verified as "not documented."** The framework exposes minimums
**programmatically, per restore image and per host**, not as fixed numbers in
the API reference text:

- `VZMacOSConfigurationRequirements.minimumSupportedCPUCount` and
  `.minimumSupportedMemorySize` — "the minimum supported number of CPUs/memory
  size for this configuration" — are read off a specific `VZMacOSRestoreImage`'s
  resolved requirements object at runtime; no numeric value is given in the
  class reference itself
  (`developer.apple.com/documentation/virtualization/vzmacosconfigurationrequirements`,
  fetched 2026-10-08).
- `VZVirtualMachineConfiguration.minimumAllowedCPUCount` /
  `.minimumAllowedMemorySize` / `.maximumAllowedMemorySize` are declared as
  `class var` (computed, host-dependent) properties with no documented
  constant value in their reference pages — only "the value ... must be
  greater than or equal to [or less than or equal to] the value in this
  property"
  (`developer.apple.com/documentation/virtualization/vzvirtualmachineconfiguration/minimumallowedmemorysize`,
  `.../minimumallowedcpucount`, fetched 2026-10-08).

**Conclusion: any specific "macOS needs at least N GB RAM / M CPUs in a VM"
figure is UNVERIFIED from Apple's own API docs** — Apple deliberately ties the
floor to the restore image and host hardware model rather than publishing a
static number. The one concrete, Apple-authored sizing data point found is
qualitative, not a documented minimum: Apple's own sample code comments
`// Create a 128 GB disk image.` when sizing the guest's `Disk.img` in the
reference `macOSVirtualMachineSampleApp`
(`developer.apple.com/documentation/virtualization/running-macos-in-a-virtual-machine-on-apple-silicon`,
fetched 2026-10-08) — Apple's own reference implementation assumes on the
order of 128 GB of addressable disk for one guest's virtual disk (a sparse
image; actual bytes consumed depend on what's installed, but this is the
scale Apple itself designs around, not a worst-case minimum).

## 3. macOS Software License Agreement: is virtualizing macOS for this purpose permitted?

**Verified.** The macOS Software License Agreement text (fetched from Apple's
own `apple.com/legal/sla/docs/macOSSequoia.pdf`; this specific clause has been
stable across recent macOS SLA revisions and is the relevant primary source
for the license terms governing virtualized macOS copies) states, in the
section on permitted uses (2B(iii)):

> "to install, use and run up to two (2) additional copies or instances of the
> Apple Software, or any prior macOS or OS X operating system software or
> subsequent release of the Apple Software, within virtual operating system
> environments on each Apple-branded computer you own or control that is
> already running the Apple Software, for purposes of: (a) software
> development; (b) testing during software development; (c) using macOS
> Server; or (d) personal, non-commercial use."

and immediately following:

> "Except as expressly permitted in Section 3, the grant set forth in Section
> 2B(iii) above does not permit you to use the virtualized copies or instances
> of the Apple Software in connection with service bureau, time-sharing,
> terminal sharing, relay service or other similar types of services. ...
> you may not use the Apple Software to run any Apple operating system
> software, including iOS, iPadOS, watchOS or tvOS, in virtual operating
> system environments on Mac Computer(s)."

and separately (2D):

> "the Apple Software is supported on only Apple-branded hardware that meets
> specified system requirements as indicated by Apple."

**Interpretation for this task (fits the license):** running up to two
virtualized macOS instances on this Apple-branded Mac mini, for the purpose of
software development/testing (building and proving the Ubique
Gradle/Cargo/Xcode toolchain), is squarely within the 2B(iii) "software
development; testing during software development" grant. The clause's ban on
virtualizing **iOS/iPadOS/watchOS/tvOS** on a Mac is not implicated here: the
proof needs Xcode and the iOS **SDK/simulator** running inside a **macOS**
guest, not an iOS guest OS — the iOS Simulator is a macOS userspace component,
not a virtualized iOS operating system instance, so it is unaffected by that
restriction. The "service bureau/time-sharing" exclusion would matter only if
the VM were offered to third parties as a shared remote service, not for an
internal disposable build sandbox. No Apple Developer Program or notarization
requirement is stated in the SLA for private, local use of the
`com.apple.security.virtualization` entitlement itself, though code-signing
the host app requires a signing identity to exercise the entitlement
(§1), which is a separate macOS code-signing mechanism from SLA licensing.

## 4. Isolation and resource-control primitives available from the framework

| Required control (issue 45) | Virtualization.framework primitive | Verified? | Source |
|---|---|---|---|
| No external network | Simply omit any entry from `VZVirtualMachineConfiguration.networkDevices` (an array you populate; nothing is added automatically) — the guest is given no network device at all. | Yes, by construction/absence | `developer.apple.com/documentation/virtualization/vzvirtualmachineconfiguration` (`networkDevices` property description), fetched 2026-10-08 |
| (If network were needed, scoped) | `VZNATNetworkDeviceAttachment` "works with the host computer to perform network address translation (NAT) on the guest system's network packets... route[s] those packets to outside networks" — explicitly routes to external networks, so it is the wrong primitive for a no-network requirement; only its *absence* gives isolation. | Yes | `developer.apple.com/documentation/virtualization/vznatnetworkdeviceattachment`, fetched 2026-10-08 |
| CPU/memory caps | `VZVirtualMachineConfiguration.cpuCount` and `.memorySize` are set once at configuration time and bounded by the framework's `minimumAllowedCPUCount`/`maximumAllowedCPUCount` and `minimumAllowedMemorySize`/`maximumAllowedMemorySize`; the guest cannot exceed the partitioned allocation (memory can additionally be adjusted live only via an explicit `VZMemoryBalloonDeviceConfiguration`, which the host controls). | Yes (mechanism); exact numeric bounds undocumented (§2) | `developer.apple.com/documentation/virtualization/vzvirtualmachineconfiguration`, fetched 2026-10-08 |
| Read-only toolchain / scratch-only writes | Apple's own `sharedBaseImageSampleApp` pattern uses `DiskImageKit` to open the base install image `.open(url: diskImageURL, mode: .readOnly)` and layers a writable **overlay** (`.asifLayer(url: overlay, type: .overlay)`) on top via `StackedImage`/`DiskImage.appending` — i.e. a read-only base + a disposable writable overlay is an Apple-documented pattern, and the sample explicitly supports **discarding the overlay** to reset to pristine state (`discardOverlay(vmIndex:)` in the app-delegate flow). | Yes | `developer.apple.com/documentation/virtualization/running-macos-in-a-virtual-machine-on-apple-silicon`, fetched 2026-10-08 |
| Disposable / reset between runs | `VZVirtualMachine.saveMachineStateTo(url:completionHandler:)` / `.restoreMachineStateFrom(url:completionHandler:)` snapshot and restore in-memory VM execution state; combined with discarding a disk overlay (above), this gives a repeatable pristine-state-per-build reset pattern. | Yes (API exists); disk-snapshot-level repeatable reset is the overlay-discard pattern above, not a single "snapshot" API call | `developer.apple.com/documentation/virtualization/vzvirtualmachine`, fetched 2026-10-08 |
| Process count / per-file size / wall-clock limits | **Not exposed by Virtualization.framework at all.** The framework's documented surface (configuration, boot, devices, save/restore) has no API for guest-side process-count ceilings, per-file size caps, or wall-clock execution deadlines; the framework reference pages fetched for this note contain no such properties or methods. | **Gap — unverified/not offered by this framework** | Absence confirmed across `VZVirtualMachine`, `VZVirtualMachineConfiguration` reference pages fetched 2026-10-08; no contradicting primary source found |

**Conclusion:** the framework gives strong, Apple-documented primitives for
network isolation (by omission), CPU/memory partitioning, and a read-only
toolchain + scratch-overlay + discard-to-reset pattern. It does **not** give a
built-in process-count, per-file-size, or wall-clock enforcement boundary —
those would have to be enforced **inside the guest OS** (e.g. the guest's own
`launchd`/`ulimit`/a supervisory process with a timeout) or by the **host app**
that is driving `VZVirtualMachine` (e.g. the host calling `stop(completionHandler:)`
after an external timer), neither of which is a Virtualization.framework
feature per se. This mirrors the same wall-clock gap already identified for
Docker in the companion note — it is a cross-cutting gap, not something a
macOS VM automatically fixes.

## 5. Is an 8 GB RAM / 15.6 GB free disk Mac mini feasible for this, conservatively?

No official Apple document fetched in this pass states a fixed minimum
RAM/disk figure for a macOS guest (§2), so the following is a **conservative,
labeled-unverified** engineering judgment from the available primary-source
sizing signals, not an Apple-stated pass/fail:

- **Disk is very likely a hard blocker.** Apple's own sample code sizes a
  single guest's disk image at **128 GB** (`running-macos-in-a-virtual-machine-on-apple-silicon`,
  §2 above) — a sparse allocation, so actual bytes written is lower, but it is
  the scale Apple's reference implementation designs around for one VM. A
  current macOS restore image (`.ipsw`) downloaded via
  `VZMacOSRestoreImage.fetchLatestSupported` is itself commonly on the order
  of low-teens-of-GB (not independently re-verified in this pass against a
  live download, so treat as directionally indicative, not a cited Apple
  figure), and installing it into a guest disk plus holding Gradle/Cargo
  offline caches inside the guest needs materially more free space than the
  restore image alone. **15.6 GB total free disk on the host is below the
  restore-image size alone in the common case, before any guest disk,
  overlay, or toolchain cache exists** — this is the dominant, conservative
  reason to treat this host as infeasible for a macOS-guest approach as
  currently provisioned, consistent with issue 45's own 2026-10-08 conclusion
  that "free disk is also insufficient evidence for installing and caching
  Xcode/Android/Rust cross-target toolchains."
- **RAM is marginal-to-insufficient and unverified.** No Apple doc fetched
  states a minimum guest memory size; `minimumSupportedMemorySize` is only
  resolved from a specific restore image at runtime (§2). Qualitatively, a
  macOS guest runs its own WindowServer/Dock/background daemons in addition
  to Xcode/build tooling, and must share an 8 GB host that simultaneously
  runs the host's own macOS, Xcode, and this task's other processes. Treating
  "a macOS guest plus host overhead both fit comfortably in 8 GB" as
  **unverified and conservatively unlikely**, pending an actual
  `VZMacOSRestoreImage.mostFeaturefulSupportedConfiguration` query on this
  host (not performed — this note makes no VM/API calls per its no-execution
  bound).
- **Entitlement/build step itself** (code-signing a host app with
  `com.apple.security.virtualization`, per §1) is an additional setup
  prerequisite not currently present on this host (no evidence of an existing
  entitled VM host app was found or assumed).

**Overall, conservative conclusion: this specific Mac mini (8 GB RAM, 15.6 GB
free disk) is not a feasible host for a macOS-guest Virtualization.framework
sandbox today**, primarily because of disk space (a near-certain blocker
given Apple's own ~128 GB reference sizing and realistic restore-image/cache
sizes against 15.6 GB free) and secondarily because of RAM headroom
(plausible but unverified-from-primary-source risk). This is consistent with,
and reinforces, issue 45's own 2026-10-08 assessment and recommendation to
provision a separate, adequately-resourced disposable runner rather than use
this machine as-is.

## 6. Exact, plausible setup options (not executed)

1. **Native Virtualization.framework host app (Apple-first-party path).**
   Build (or reuse) a small, entitled Swift host app modeled directly on
   Apple's own sample —`InstallationTool` to fetch/install a macOS restore
   image into a `VM.bundle`, and a driver app equivalent to
   `macOSVirtualMachineSampleApp`/`sharedBaseImageSampleApp` — configured with:
   `VZMacPlatformConfiguration` + `VZMacOSBootLoader`; **no** entries in
   `networkDevices` (full network isolation, §4); a `DiskImageKit`
   read-only base image + writable overlay per guest build, discarded
   (`discardOverlay`) between builds for a pristine scratch state (§4); fixed
   `cpuCount`/`memorySize` set at configuration time as the resource ceiling
   (§4); wall-clock/process/file-count limits layered on top via the host
   app's own supervisory logic or guest-side `launchd`/`ulimit`
   configuration, since the framework does not provide these natively (§4
   gap). Requires provisioning adequate disk/RAM first (§5) and a valid code
   signing identity for the `com.apple.security.virtualization` entitlement
   (§1), and fits within the SLA's "software development/testing" grant on
   this Apple-branded Mac (§3). This is the most directly Apple-documented,
   first-party option, and the only one evaluated here against primary
   Apple sources end-to-end.

2. **Third-party Virtualization.framework wrapper (e.g. Tart).** Tart
   (`github.com/cirruslabs/tart`, now mirrored at `github.com/openai/tart`)
   is described by its own README as using "Apple's own `Virtualization.Framework`
   for near-native performance" and provides a CLI (`tart clone`/`tart run`)
   around the same APIs in option 1, with OCI-registry-distributed base
   images; its own quick-start README example notes a **25 GB** base-image
   download for a current macOS base image (`github.com/openai/tart` README,
   fetched 2026-10-08) — an independent, third-party data point that is
   directionally consistent with §5's conclusion that 15.6 GB free disk is
   insufficient. This is a non-Apple, third-party OSS tool, not a primary
   Apple source, so its own isolation/resource-limit claims were not
   independently verified here and would need separate review before relying
   on it for the sandbox's enforcement guarantees; it still sits on top of
   the same framework and SLA constraints as option 1.

3. **Hosted/managed macOS runner (no VM on this physical host at all).** A
   hosted macOS CI runner (e.g., a macOS GitHub-hosted Actions runner,
   already referenced in the companion Docker note as running "a new virtual
   machine (VM) hosted by GitHub," `docs.github.com/en/actions/concepts/runners/github-hosted-runners`)
   or an equivalent cloud Mac-rental provider sidesteps this host's RAM/disk
   limits entirely by moving the Xcode/iOS-SDK leg off this Mac mini. This
   satisfies "Xcode is required" without touching Virtualization.framework
   configuration on this machine, but it (a) is explicitly out of this note's
   bound ("Creating or modifying a hosted runner is an external-service
   action and needs the owner's infrastructure choice and authorization,"
   issue 45) and (b) requires separately verifying that the vendor's own
   isolation/resource-limit mechanism actually meets issue 45's specific
   acceptance list (network-disabled, explicit env allowlist, read-only
   toolchain, scratch-only writes, CPU/memory/process/file/disk/wall-clock
   limits) from that vendor's own primary documentation — not assumed
   equivalent to options 1–2 here.

## Gaps and uncertainties

- No numeric minimum RAM/disk/CPU figure for a macOS guest is published by
  Apple in any reference page fetched in this pass; §2 and §5 are explicit
  that this is Apple's own undocumented-by-design behavior (resolved only at
  runtime per host/restore-image), not an oversight in this research.
- The exact current size of a `VZMacOSRestoreImage.fetchLatestSupported`
  `.ipsw` for whatever macOS version corresponds to "macOS 27" in this
  environment was not independently fetched/measured (would require a live
  network download, out of this note's no-execution bound); the "low
  teens-of-GB" comparison in §5 is a directional, not Apple-cited, figure and
  should be verified against an actual `VZMacOSRestoreImage.url` fetch before
  being treated as precise.
- Whether this host's current Xcode 27 installation includes
  (or can produce) a compatible `VZMacOSRestoreImage`/hardware-model pairing
  for this exact Mac mini M1 was not checked via any API call (`isSupported`,
  `mostFeaturefulSupportedConfiguration`) — no VM/Virtualization API was
  invoked, per the task's no-execution constraint.
- Tart's (and any other third-party tool's) own isolation claims were not
  independently verified against its source/docs beyond the one README data
  point cited; treat as a pointer for further review, not a verified
  equivalent to Apple's own framework guarantees.
- Process-count, per-file-size, and wall-clock enforcement were confirmed
  absent from Virtualization.framework's documented surface, but guest-side
  OS mechanisms (macOS `launchd`/`ulimit` inside the guest) that could fill
  this gap were not independently sourced in this pass — flagged as a
  follow-up if option 1 or 2 is pursued.
- No ticket, ADR, or infrastructure state was created or modified, and no
  code/build/VM command was executed, per this task's explicit bounds.
