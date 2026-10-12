# ADR 0015: Build-backed Kotlin CodeQL extraction

Status: accepted direction; hosted extraction verified, analysis and migration unverified

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

Run `38254923786` instead expires the existing 600-second generator-install
deadline before reaching CodeQL; it adds no importer-operation evidence.
Move a trusted, minimal Java compiler/import probe ahead of generator work
to tighten this diagnostic loop, using the same frozen JDK/CodeQL paths,
database source root, sandbox and 300-second cell limit. Its constant source
is created only inside disposable scratch. It cannot satisfy Kotlin extraction
or coverage acceptance; the full forced Kotlin consumer remains mandatory.
Run `38258239184` instead expires the pre-existing 60-second fixture-target
configuration before the minimal probe. Its captured `/opt` denials are Gradle
attempts to write frozen cache metadata, not the CodeQL importer operation.
Move the independent minimal probe before fixture configuration; do not relax
that deadline or permit cache writes to make the diagnostic reachable.

The early minimal probe in run `38259872217` reproduces the same importer
failure within 20 seconds. Kernel evidence identifies `java` denied
`file-read-data /opt`; it is not an attempted out-of-scratch write.
The original profile still denies this parent-directory read. Any allowance
must be separately approved and exact-directory-only, retaining child-content,
write, network and resource denials.
Diagnostic artifact upload also failed because copied UID-owned logs remained
private to that UID. Normalize exported diagnostic/database ownership to root
and read-only runner-readable permissions, like the existing payload export;
do not claim the failed artifact was preserved. Narrow kernel output further
to `java` so unrelated hosted-agent denials are excluded.

The owner approved an exact parent-directory read only for CodeQL cells.
Append `file-read-data (literal "/opt")` to the unchanged build policy only
for the minimal importer and traced Kotlin command. This exposes directory
entry names at `/opt`, not unrelated child contents. Network, input-write,
scratch and resource controls are unchanged; ordinary build commands retain
the original profile. A real native sandbox test fails on the intended
parent-read denial before the allowance, then must pass with negative child
read/input-write and ordinary-profile assertions.

## Extraction and analysis gates

[Run 38263225443](https://github.com/trancee/cairn/actions/runs/38263225443)
at `799d758523ea6834560cf4cb8b889439ae6f8c63` passes the minimal importer,
forced real Kotlin compilation, canonical JVM calls, native TRAP import and
database finalization under unchanged limits. The downloaded database records
CodeQL `2.27.2`, manual mode and `finalised: true`; its archive contains all
three tracked Kotlin files and both generated common/JVM binding files.
Archive presence is not compiled-source coverage or successful security
analysis. Existing default scanning is still enabled.

The next mandatory gate queries actual `CompilationUnit` values satisfying
`fromSource()` and `isKotlinSourceFile()`. It compares positive compiled LOC
against a frozen manifest of every tracked `.kt` file and requires generated
binding evidence. Missing or malformed evidence fails explicitly. The owned
inventory query is copied into the checksum-verified bundled Java query pack
before freezing, reusing its real dependency context without changing package
metadata, locks or libraries. Its non-summary metric metadata keeps it separate
from the unchanged standard security suite; it is explicitly executed as a
required coverage gate, not omitted from analysis.

Execute the bundled `java-code-scanning.qls` suite offline inside the same
dedicated-UID sandbox, with a separate existing 300-second command ceiling,
two evaluator threads and 2 GiB requested evaluator RAM. Compilation/evaluator
caches and output stay inside the existing bounded scratch. No permission,
network, whole-VM memory, scratch, file or job limit is increased. Export
coverage and SARIF only after successful execution. Repository-path mapping
and persistent advanced-setup replacement remain unverified.
