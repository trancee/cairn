# Research Note: macOS VM on a Linux Host for the iOS Sandbox/Proof

Date: 2026-10-08
Scope: Whether a macOS guest virtualized on a Linux (non-Apple) host can serve as
a valid environment for the Ubique iOS sandbox/proof (Xcode build + iOS
Simulator). Primary sources only; no tools installed or executed.

## 1. Does Apple permit virtualized macOS on non-Apple hardware?

**No.** The macOS Software License Agreement (SLA) grants virtualization
rights only on top of Apple-branded hardware, and separately prohibits
running the Apple Software on non-Apple-branded hardware at all.

Source: Apple, *macOS Sequoia Software License Agreement*
(https://www.apple.com/legal/sla/docs/macOSSequoia.pdf), extracted via
`pdftotext`:

- Section 2B(iii) (virtualization grant), lines 72–77:
  > "(iii) to install, use and run up to two (2) additional copies or
  > instances of the Apple Software, or any prior macOS or OS X operating
  > system software or subsequent release of the Apple Software, within
  > virtual operating system environments **on each Apple-branded computer
  > you own or control** that is already running the Apple Software, for
  > purposes of: (a) software development; (b) testing during software
  > development; (c) using macOS Server; or (d) personal, non-commercial
  > use."

- Section 2J ("Other Use Restrictions"), line 192:
  > "The grants set forth in this License do not permit you to, and you
  > agree not to, **install, use or run the Apple Software on any
  > non-Apple-branded computer**, or to enable others to do so."

- Section 2D ("System Requirements"), lines 90–92: "the Apple Software is
  supported on only Apple-branded hardware that meets specified system
  requirements as indicated by Apple."

Together these clauses mean the virtualization allowance in 2B(iii) is
layered *on top of* the baseline restriction in 2J — it only legitimizes
running extra copies of macOS in VMs when the **physical host** is itself
Apple-branded hardware already licensed to run the Apple Software. There is
no license grant anywhere in the SLA for running macOS (virtualized or not)
on a Linux/x86 PC, a generic cloud VM, or any other non-Apple-branded
system. This has been Apple's consistent SLA position across recent
releases (Sonoma/Ventura text preceding the Sequoia clause reiterates
"directly on each Apple-branded computer running macOS Sonoma, macOS
Ventura…", line 62).

Apple's own `Virtualization` framework (the supported API for building
macOS-VM tooling such as UTM/Tart/Apple's `tart`-style tools) is consistent
with this: it is a macOS framework (`import Virtualization`, available
macOS 11+/12+ for the installer APIs) that runs *on* a Mac host to create
guest VMs — it has no Linux host counterpart and is not offered as a way to
run macOS virtualized on non-Apple hardware.

Source: Apple Developer Documentation, *Virtualization* framework overview
(https://developer.apple.com/documentation/virtualization.md):
> "The Virtualization framework provides high-level APIs for creating and
> managing virtual machines (VM) on Apple silicon and Intel-based Mac
> computers."

and `VZMacOSInstaller` (https://developer.apple.com/documentation/virtualization/vzmacosinstaller.md),
whose only documented purpose is installing a macOS guest from a host that
is itself a Mac. No non-Apple host is supported or documented.

## 2. Does KVM/QEMU officially support macOS guests on Linux?

**No.** QEMU's own documentation (the System Emulation manual, e.g.
https://www.qemu.org/docs/master/system/index.html and the x86 target page
https://www.qemu.org/docs/master/system/target-i386.html) documents generic
PC/x86 peripheral emulation (i440FX/PIIX3, Q35, device models, etc.) but
contains no macOS-guest-specific support, no OSK key handling, and no
reference to Apple's `AppleSMC`/`AppleHDA` device requirements as an
officially supported configuration. Booting macOS under QEMU/KVM is only
possible via third-party, community ("Hackintosh"-style) tooling that
patches in Apple's proprietary SMC emulation and an unofficial OpenCore
bootloader — it is not part of upstream QEMU/KVM and is not documented on
qemu.org.

The most prominent community project, OSX-KVM
(https://github.com/kholia/OSX-KVM), confirms this framing explicitly in
its README:
- Its "Is This Legal?" section (lines 253–268) says: "I am not a lawyer…",
  points to third-party commentary (Dortania's OpenCore guide "Legality of
  Hackintoshing," and a CMU researcher's notes) rather than any QEMU or
  Apple statement of support, and explicitly states: "Note: It is your
  responsibility to understand, and accept (or not accept) the Apple EULA."
- The setup instructions rely on an extracted Apple "OSK" string and a
  hand-built OpenCore boot chain — i.e., a reverse-engineered/unofficial
  boot path, not an upstream QEMU feature.

Conclusion: KVM/QEMU can *technically* boot a macOS guest via this
unofficial community tooling on compatible Intel/AMD hardware (VT-x/AMD-SVM,
SSE4.1/AVX2 depending on macOS version, per the OSX-KVM README), but this is
neither an officially supported QEMU/KVM feature nor an Apple-sanctioned
configuration.

## 3. Can a Linux-hosted macOS guest offer reliable Xcode/iOS SDK/simulator proof?

Even setting licensing aside, this path is technically fragile for the
specific proof needed (Xcode build + iOS Simulator run):

- The iOS Simulator and much of Xcode's tooling depend on Apple hardware
  features and entitlements (Hypervisor.framework / Apple Silicon-specific
  acceleration for Simulator devices, code-signing/notarization services
  tied to an Apple Account, and the Metal/Rosetta stack for Apple
  Silicon-only SDKs). None of this is exercised or validated by the
  community QEMU/KVM Hackintosh path, which targets generic Intel/AMD PC
  emulation, not Apple Silicon.
- Apple's supported virtualization story for CI/dev purposes (the
  `Virtualization` framework, and its documented guides such as "Running
  macOS in a virtual machine on Apple silicon" and "Virtualize macOS on a
  Mac") explicitly requires an Apple Silicon or Intel **Mac host** —
  reinforcing that Apple does not provide, test, or support a path where
  Xcode/Simulator functionality is validated on non-Apple-hardware virtual
  macOS.
- Because the Linux/QEMU macOS-guest path is unofficial and undocumented
  upstream, there is no Apple or QEMU guarantee of fidelity for Xcode
  toolchain behavior, simulator runtime behavior, or future compatibility
  (each new macOS/Xcode release can silently break the unofficial
  SMC/OpenCore emulation layer, as evidenced by OSX-KVM's per-release
  update cadence).

**Conclusion: a Linux-hosted macOS VM is not a reliable or supported basis
for an Xcode/iOS SDK/Simulator proof** — it is both against Apple's license
terms (Section 2J/2B(iii) above) and technically unsupported/unverified by
QEMU/KVM upstream.

## 4. Compliant alternatives

1. **Linux-only proof for the non-Apple-specific parts**: keep JVM/Kotlin
   Multiplatform common code and the Android target's build/test/proof
   fully on Linux CI (no macOS dependency), since Android and pure-JVM
   targets have no Apple hardware requirement.
2. **Apple-branded runner for the iOS-specific proof**: run the Xcode
   build, iOS SDK compilation, and iOS Simulator proof on genuine
   Apple-branded hardware — either:
   - A physical Mac (on-prem or in a Mac-hosting colo), which satisfies SLA
     2D/2J directly without any virtualization question; or
   - A cloud "Mac" instance built on genuine Apple hardware, e.g. AWS EC2
     Mac instances, which AWS documents as running on dedicated Apple Mac
     mini / Mac Studio hardware (https://aws.amazon.com/ec2/instance-types/mac/:
     "Our x86-based EC2 Mac instances are built on Apple Mac mini
     computers… EC2 M1 Mac instances are built on Apple M1 Mac mini
     computers… EC2 M2 Pro Mac instances are built upon Apple M2 Pro Mac
     Mini computers…"). Because the physical host is genuine Apple
     hardware, this is consistent with SLA Section 2D/2J, unlike a Linux
     host virtualizing macOS. (Other reputable Mac-hosting providers, e.g.
     MacStadium, make the same "dedicated Apple hardware" claim; verify the
     specific provider's hardware-sourcing claims before relying on them.)
   - On a genuine Mac host, Apple's own `Virtualization` framework can
     additionally be used to run short-lived, ephemeral macOS VMs for
     build isolation (per Apple's documented "Running macOS in a virtual
     machine on Apple silicon" guide) — this is the one macOS-on-VM
     configuration Apple actually documents and supports, precisely because
     the physical host remains Apple-branded.
3. **Net architecture**: Linux CI/dev machines handle everything that does
   not require Apple's OS (JVM tests, Android build/instrumented tests,
   static analysis, packaging); a small pool of genuine Apple hardware
   (physical or AWS EC2 Mac/equivalent) is reserved specifically for the
   Xcode/iOS SDK/Simulator proof step, invoked from the same CI pipeline.

## Sources consulted

- Apple, macOS Sequoia Software License Agreement (PDF), Sections 2B(iii),
  2D, 2J: https://www.apple.com/legal/sla/docs/macOSSequoia.pdf
- Apple Developer Documentation, Virtualization framework overview:
  https://developer.apple.com/documentation/virtualization
  (markdown source: https://developer.apple.com/documentation/virtualization.md)
- Apple Developer Documentation, `VZMacOSInstaller`:
  https://developer.apple.com/documentation/virtualization/vzmacosinstaller.md
- QEMU Project, System Emulation documentation (master):
  https://www.qemu.org/docs/master/system/index.html,
  https://www.qemu.org/docs/master/system/target-i386.html,
  https://www.qemu.org/docs/master/system/i386/pc.html
  (no macOS-guest-specific support documented)
- OSX-KVM community project README (unofficial/community, not Apple- or
  QEMU-endorsed), incl. "Is This Legal?" section:
  https://github.com/kholia/OSX-KVM
- AWS, EC2 Mac instance types (genuine Apple hardware hosting):
  https://aws.amazon.com/ec2/instance-types/mac/

## Gaps / notes

- Did not verify the physical-hardware claims of non-AWS Mac-hosting
  providers (e.g., MacStadium) from their own primary documentation in this
  pass — flagged as a follow-up if a specific provider is chosen.
- Apple's Developer Program License Agreement (separate from the macOS
  SLA) may contain additional terms relevant to CI/build-service usage of
  Xcode; not reviewed here since the question centered on the macOS guest
  OS license, not the Xcode/developer program terms.
- This note is factual/legal-text research, not legal advice; a final
  compliance decision should be confirmed with counsel if there is any
  ambiguity about the chosen hosting provider's hardware sourcing.
