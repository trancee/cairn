# ADR 0015: Build-backed Kotlin CodeQL extraction

Status: accepted direction; extraction and scan migration unverified

## Context

After PR #5 merged, GitHub's automatic language trial in
[run 38249821951](https://github.com/trancee/cairn/actions/runs/38249821951)
selected Java/Kotlin `build-mode: none` and failed database finalization with
no extracted source. Kotlin requires compilation under CodeQL tracing.
Existing default setup remains configured for Actions, Python and Rust.
The pinned CodeQL `2.27.2` supports the fixture's Kotlin `2.4.20` and JDKs;
no toolchain downgrade is justified.

## Decision and approval

The owner approved advanced-setup migration with strict offline build controls,
feature-branch commits/pushes and free hosted diagnostic runs on 2026-10-12.
First prove direct tracing inside the existing Apple dedicated-UID sandbox.
Prepare checksum-pinned CodeQL and Android API inputs outside target work,
freeze them with the existing tool manifest, and initialize/trace/finalize a
database entirely inside bounded scratch under the existing 300-second build
command limit. Export only a successfully finalized database before teardown.
Default scanning stays enabled until a complete replacement is verified.

The analysis-only init script adds the unchanged Android consumer Kotlin
sources to the existing JVM consumer compilation, using the genuine pinned
Android API `37.0` platform JAR as a compile-only dependency. This permits
extraction of all current handwritten Kotlin, alongside generated JVM
bindings, without an Android runtime or a duplicate handwritten API.
The canonical JVM entry point still executes. Ordinary binding builds do not
load this script. This is security-analysis compilation, not an Android
packaging, release, platform-equivalence or hardware proof.

## Alternatives

- Keep `none`: cannot analyze Kotlin, reproduces the observed failure.
- Compile on an unrestricted runner: owner selected strict-cell integration.
- Trace the inherited runner environment through the supervisor: violates the
  explicit environment boundary. Start tracing after entering the sandbox.
- Downgrade the compiler or exclude Kotlin: unnecessary and weakens coverage.

## Risks and migration

CodeQL native tracing may be incompatible with the sandbox, platform or
sanitized environment. Its database also consumes existing bounded scratch.
Do not add permissions, inherited environment, resources or fallback modes
without a separately justified decision. Database finalization alone does not
prove complete source coverage or successful queries/upload.

Before disabling default setup, verify actual Kotlin extraction for every
tracked `.kt` source, successful queries and repository-path mapping, and
preserve Actions/Python/Rust lanes in the replacement workflow. No alert
dismissal, merge, publication or issue-44/45 acceptance waiver is authorized.

## First strict-cell observation

[Run 38252012714](https://github.com/trancee/cairn/actions/runs/38252012714)
passes checksum-verified preparation, CodeQL startup, database initialization,
forced owning JVM compilation with the Android analysis source mapping and
both canonical generated-call assertions. Finalization fails in native TRAP
import: `Could not create real path`, caused by
`FileSystemException "/opt: Operation not permitted"`. UID cleanup and ordinary
scratch teardown pass. No Kotlin database/query/coverage success is established.
Next capture only kernel sandbox denials for `/opt`, bounded to 15 seconds
and the last two minutes; determine the actual denied operation before changing
any permission. Existing limits and default scanning remain unchanged.
