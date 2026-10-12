---
status: accepted
date: 2026-10-10
version: cairn-r1
---

# 0013: Bounded host proof-evidence extraction

## Context

The standalone binding runner's 64 MiB collector bounds streamed replay
output, including emulator diagnostics and instrumentation. It does not
bound raw guest journals or Fedora extraction storage. Existing extraction
copies the whole journal onto a shared host filesystem before filtering.
Issue 45 requires bounded logs. Guest journald also forwards to rsyslog;
bounding its storage must cover both copies.

## Decision

The owner approved 1 GiB per NEW host extraction, explicit failure on
capacity exhaustion, and preservation of incomplete output without eviction.
Retain output in a root-only ext4 image of exactly 1,073,741,824 bytes.
Filesystem metadata reduces usable capacity. Mount it only during extraction;
unmount before reporting completion. A fixed-size status message outside
the image marks complete or incomplete. Refuse reuse of any existing output,
image or status path. Preserve historical directory-format evidence.

The owner subsequently approved an 8 GiB aggregate store for NEW host
evidence and 4 GiB disposable appliance scratch, with the same fail/preserve
policy. New extraction images and appliance scratch reside inside the
aggregate image at `/var/lib/cairn-proof-evidence/bounded-store.ext4`.
Reserve the entire image allocation before starting work using `fallocate`.
This prevents loop-backed filesystems from discovering host space exhaustion
only after their advertised capacity was accepted. Usable aggregate space
is below 8 GiB; the 4 GiB scratch reservation means fewer than eight
extractions can fit. Refuse work without the reservations, never evict.
Remove only successful disposable scratch; failed scratch remains in the
aggregate store with incomplete status. Command-local `TMPDIR`,
`LIBGUESTFS_TMPDIR` and `LIBGUESTFS_CACHEDIR` point into the scratch volume.
Historical images/directories stay outside this new aggregate boundary.

The owner approved 1 GiB guest logging and a separate new proof clone, and
selected checksum-verified replay records as authoritative. The retention
clone receives a separate fully allocated 1 GiB ext4 disk labelled `CAIRN_PROOF_LOGS`,
mounted at `/var/lib/cairn-proof-logs`. Reserve each 64 MiB replay budget
before launching target work; reservation failure prevents command execution.
Instrumentation copies reside on the same disk.
For this networkless clone only, journald uses bounded volatile diagnostics,
forwarding to syslog is disabled, and rsyslog/logrotate are stopped and
runtime-masked. Volatile system diagnostics may rotate and are not proof
authority. Existing preparation logs and retained clones remain unchanged.
Owner-run V4 evidence below establishes guest boot enforcement and new-clone
extraction; the retained bounded clone must not restart.
The first retention boot exposed reversed kernel disk enumeration: proof disk
was `vda`, root was `vdb`. Its size guard failed before target work. Resolve
the unique filesystem label and validate ext4/1 GiB instead of positional
device names; ambiguous, missing or wrong-size devices fail closed. Preserve
that failed clone. The `retention-v2` boot resolved the correct disk but
revealed an active `syslog.socket` reactivating rsyslog during cutover.
Stop and runtime-mask trigger sockets before their services; validate actual
runtime mask symlinks and inactive state rather than `is-enabled` display
spelling. Synthetic socket-activation tests pass on Ubuntu using the same
helper. Preserve both failed clones. This does not diagnose earlier Android
emulator instability.
V3 confirmed trigger shutdown but rejected a masked timer's retained
`failed` state before replay. For intentionally disabled units only, emit
their prior failure state/result, then reset the historical failure after
masking/stopping and require inactive state plus the runtime mask.
Real failed-service regression tests reproduce the rejection and pass with
this normalization; they do not reproduce the timer's original boot failure.
V3 and its evidence remain preserved.
The owner selected a separate corrected V4 clone with durable startup
diagnostics. After identifying/mounting the proof disk and before changing
journald, the existing collector reserves a separate 64 MiB startup record
on that same 1 GiB disk. The replay's 64 MiB ceiling remains unchanged.
Capture logging cutover stdout/stderr and retained unit-failure diagnostics;
preserve partial startup records on failure, and checksum only successful
startup records. Disk identity/mount failures necessarily precede this
capture. Extraction of V4 requires matching successful startup and replay
records from the same boot. Real synthetic systemd capture testing failed
when output existed only on the console, then passed with the collector,
including stderr and child exit preservation. Owner-run V4 then passed the
cold build and fresh Android instrumentation. Live topology/base write denial,
graceful stop and bounded read-only extraction passed. Matching startup/replay
checksums for boot `67e02a91-1f25-4721-b9a9-31cae6343de2` verify logging/resource
markers. All VM disk bytes/metadata stayed unchanged. Evidence image
`bounded-store/retention-v4-replay-volume.ext4` is complete, root-only and 1 GiB,
with SHA-256 `e2e3291c5509726ee3ccbb9730a1ccceae82bdc4a4b9997b52c6216062274ea1`.
Successful bounded scratch was removed; all clones/historical evidence remain.

The owner also approved this access-format change and real synthetic
preparation-guest CLI tests. Inspect images through a read-only, no-journal-
replay mount. Separately authorized overlay disposal may append its XML
record using a temporary writable mount of complete evidence; it must
verify existing manifests rather than regenerate input assertions.

## Alternatives and risks

A post-copy size check can detect excess only after writing it, so it does
not enforce the requested boundary. Global journal rotation could evict
historical evidence and would not bound forwarded syslog or host copies.
A dedicated per-extraction image provides a narrow filesystem-enforced cap
without changing global logging or host filesystem configuration.

One GiB is an approved ceiling, not a promise that every journal fits.
Full extraction can fail; its retained image remains incomplete, and must
not authorize disposal. Runtime reliability and Apple isolation remain
incomplete. Root is a trusted operator.
Synthetic Ubuntu and owner-run Fedora direct guestfish tests passed,
including source byte/ownership preservation. Owner-run stopped bounded-VM
journal extraction also passed in the new format, preserving both boot logs
and VM image bytes/ownership. Those runs preceded the aggregate/scratch
cutover. New profile/composed-filesystem tests pass on Ubuntu and Fedora;
Fedora aggregate/scratch guestfish synthetic integration also passes,
including source byte/ownership preservation and successful scratch cleanup.
V4 proof-clone extraction under those controls subsequently passed as above.

## Migration

`preserve-journal.sh` now uses `-volume` destinations inside the aggregate
store, leaving all existing evidence untouched. New evidence is an `.ext4`
image plus `.status`, not an
always-accessible directory. No existing VM is restarted or re-extracted by
this change. No protocol, SDK API or published compatibility contract changes.
