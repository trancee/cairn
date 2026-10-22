# ADR 0015: Build-backed Kotlin CodeQL extraction

Status: accepted; four-language PR processing verified; main deployment pending

## Context

After PR #5 merged, GitHub's automatic language trial in
[run 38249821951](https://github.com/trancee/cairn/actions/runs/38249821951)
selected Java/Kotlin `build-mode: none` and failed database finalization with
no extracted source. Kotlin requires compilation under CodeQL tracing.
Existing default setup was configured for Actions, Python and Rust.
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
preserve Actions/Python/Rust lanes in the replacement workflow. The initial
diagnostic approval did not authorize merge or publication; the subsequent
cutover approval is recorded below. No alert dismissal or issue-44/45
acceptance waiver is authorized.

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

Run `38267253216` fails during trusted query-pack preparation before freezing
or target work; no coverage/query evidence is produced. Select the sole
bundled Java query-pack version directory and verify its actual standard suite
instead of assuming a source-checkout metadata filename in a published pack.
Missing or ambiguous pack inputs fail with an explicit diagnostic.

The SARIF boundary maps frozen fixture and disposable generated-source
locations to `proofs/bindings/linux-android/`, preserving URI escaping and
regions. Generated findings retain their real `sdk/build/uniffi/` paths; these
are untracked build files, not falsely attributed to handwritten source.
They therefore do not establish GitHub source annotations for generated code.
Malformed, unknown-base or out-of-scope locations fail before upload.

The staged `codeql.yml` replacement retains Actions/Python/Rust `none`-mode
analysis, default query suites and the remote threat model, and calls the
owning strict Kotlin lane. Only mapped Kotlin SARIF is eligible for upload.
The official `v4.38.3` annotated release tag resolves to commit
`24c54180a607b1449ed407dd24f251e4e9147c8d`; use that immutable commit, not
the annotated tag object. Dispatch with `upload=false` for validation while
default setup remains enabled. No database publication is requested.
Feature-branch pushes also perform upload-free validation, allowing the new
workflow to register and run before deployment to the default branch.
That initial registration behavior is superseded by the scheduling refinement
below after the workflow is deployed to `main`.
Only default-branch/PR/scheduled runs and explicit `upload=true` dispatches
publish after cutover; branch validation does not change scanning settings.
The unrelated functional simulator runtime is skipped only in CodeQL mode;
ordinary binding-proof dispatch retains it. Strict build gates are unchanged.

Cutover requires all four analyses and mapping to pass, then explicit
deployment approval for the repair PR and setting transition. GitHub rejects
advanced CodeQL uploads while default setup is enabled. Keep existing scanning
until replacement validation, verify the approved uploaded branch analyses,
and deploy the replacement to `main` without an intervening unscanned source
change. Verify actual processed results for all four languages; revert the
setting if deployment fails. No SDK API, cryptography, runtime dependency or
release-version change is introduced.

## Four-language observation

Upload-free [run 38268914707](https://github.com/trancee/cairn/actions/runs/38268914707)
at `1ecd7659079542961c99520ae572cd98e92b3edf` passes Actions, Python and Rust
analysis. The Kotlin cell passes actual extraction and the inventory query:
all three tracked Kotlin compilation units and both generated common/JVM
units have positive compiled LOC. The bundled Java/Kotlin suite evaluates
and produces SARIF inside the unchanged analysis ceiling.
Its built-in summary reports `3 out of 9` Java/Kotlin files; this is not a
claim that every archived or generated file has a GitHub source annotation.
The explicit compilation-unit gate supplies the tracked-source evidence.

Mapping then fails `unknown-uri-base`; no successful Kotlin analysis artifact
or replacement deployment is claimed. CodeQL's official valid-SARIF fixture
uses `%SRCROOT%` without an `originalUriBaseIds` definition. Interpret only
that standard implicit ID as the explicitly frozen database source root;
unknown IDs and malformed explicit definitions still fail. A focused test
reproduces the exact failure before the fix. Preserve failed analysis files
with an explicit failed status for subsequent diagnostics, never under the
successful-analysis artifact name.

CodeQL mode now stops target work after the forced JVM consumer and required
analysis gates: native-only framework/executable proof and simulator payload
export belong to the ordinary binding-proof lane, not security analysis.
Ordinary mode retains all those gates. Frozen inputs, Rust/allocator checks,
PF controls, private UID, command/file/memory/scratch ceilings, integrity
verification and cleanup remain required in both modes.

## Verified replacement before cutover

[Run 38274027100, attempt 2](https://github.com/trancee/cairn/actions/runs/38274027100/attempts/2)
at `6618ecb9f60426a3064bb03d716ec43323c13e2a` passes the complete upload-free
replacement. Existing Actions/Python/Rust analyses pass, along with strict
Kotlin extraction, all three tracked and both generated compilation units,
the unchanged bundled suite, mapped SARIF export, immutable-input checks,
empty-UID cleanup and scratch teardown. The result-delivery job downloads
the same-run artifact; publication is intentionally skipped.

Downloaded Kotlin artifacts verify CLI `2.27.2`, a successful query invocation,
76 rule metadata entries and zero Kotlin results. Replaying the owning mapper
on the actual raw SARIF reproduces the exported mapped document exactly;
the raw artifact uses the standard implicit `%SRCROOT%`. Replaying the source
guard against the current tracked manifest confirms all five compilation
units. These are observed extraction/analysis/mapping results, not processed
GitHub code-scanning evidence or an absence-of-vulnerabilities guarantee.

Attempt 1 fails preflight scratch-device lookup: `diskutil info -plist`
expires its existing five-second deadline before target work, leaving teardown
incomplete. Only failed/skipped jobs are replayed on fresh hosted VMs
with the same revision and unchanged controls; successful existing-language
results are retained. No retry implementation, timeout increase or reliability
claim is introduced. The known scratch-eject limitation remains open.

## Approved cutover and PR processing

The owner subsequently approved coordinated scanning cutover, verified merge
of PR #6 and branch cleanup. Default setup was disabled after replacement
validation. [PR run 38279234281](https://github.com/trancee/cairn/actions/runs/38279234281)
passed, including strict Kotlin analysis, cleanup and uploaded-result
processing. GitHub records successful Actions, Python, Rust and Kotlin
analyses at PR merge revision `f36da6130053e89070c3ec6ec785daf2bfacfb5c`.
Kotlin analysis `1937876304` has no processing error and zero results.

The concurrent upload-free branch run `38279051559` completed extraction,
coverage, queries and mapping, but failed scratch teardown. Its failed jobs
are replayed on fresh hosted VMs with unchanged revision and controls.
This does not establish teardown reliability or permit a failed-gate bypass.
Deployment and successful processed scans on `main` remain required before
declaring the persistent scanning fix complete. Restore default setup if
deployment fails; no existing alert is dismissed.

## Post-deployment scheduling refinement

The owner requested faster CI on 2026-10-13. At revision `85aa105`, CodeQL
ran on both branch push (`38442371579`) and pull request (`38442378458`),
repeating the strict Kotlin cell for the same revision. The PR run took
24m16s; the Kotlin preparation job took 20m14s, with 13m46s inside the bounded
cell. Rust foundation took 2m and formal checks 6m45s. These are observed
baselines, not guaranteed durations.

The initial scheduling patch stayed local by owner choice. On 2026-10-14
the owner explicitly approved publishing it together with implementation
and bounded hosted validation of same-VM Cargo dependency reuse. Merge is
not authorized by that approval.

Now that advanced setup is deployed, trigger pushes only on `main`, retaining
PRs targeting `main`, weekly scans and explicit manual dispatch. A branch
without a PR uses manual validation, matching the other maintained workflows.
Use event/ref-scoped concurrency and cancel superseded PR runs only.
Main, scheduled and manual runs are not cancelled by newer PR work.

This removes duplicate same-revision push/PR work and stale PR work; it does
not reduce one cold Kotlin build's duration. Every language, default security
suite, upload/processing gate, forced compilation, strict-cell boundary and
resource ceiling remains unchanged. No database, query result, compiled
artifact or proof result is restored across runs.
The separately approved same-VM Cargo experiment did not demonstrate a
speedup and was removed after measurement; see
[ADR 0014](0014-hosted-apple-isolation-probes.md#same-vm-generator-compilation-reuse-evaluation).
Checksum-verified download reuse and
avoiding repeated export/precomputation are separate potential optimizations,
not implemented or measured improvements here.

### Runner-slot scheduling (2026-10-18)

The public user-owned repository runs at most 20 hosted jobs at once. At
`09274a1` the three workflows requested about 37 jobs together, peaking at
exactly 20; the 19-cell lifecycle matrix occupied the slots that the strict
Kotlin preparation and Rust macOS jobs needed once they became ready.
Kotlin preparation waited `141s` after its benign preflight and the macOS
Rust jobs waited `220s` to `241s`. A lifecycle `max-parallel: 10` cap was
tried first. Hosted runs at `1cee495` passed without retries: CodeQL
`39154660841` in `17m28s` (Kotlin preparation waited `8s`), Rust
`39154660762` in `2m09s` and lifecycle `39154660809` in about `11m`.
That is one sample, not a cold/warm comparison.

The owner then asked for every PR to finish within 10 minutes and selected
path-scoped strict Kotlin scans. No preparation, preflight or in-cell
compilation change can meet that budget: the frozen preparation, fresh
generator build, tracing and analysis alone exceed it. Therefore:

- Move the strict lane and its result upload unchanged into
  [`codeql-kotlin.yml`](../../.github/workflows/codeql-kotlin.yml). It keeps
  the `/language:java-kotlin` category, upload policy, `main` pushes, weekly
  scans and manual dispatch without filters. Pull requests run it only when
  they change `proofs/bindings/**`, the three owning workflows,
  `rust-toolchain.toml` or `.gitattributes`. The fixture is self-contained
  and reads no other repository path. `test_codeql_kotlin_triggers.py` fails
  if a reachable workflow references an uncovered path or if pushes or
  scheduled scans become filtered. Changes to the hosted runner image or
  pinned downloads are still caught by the unfiltered `main` and weekly runs.
- Run the Actions, Python and Rust analyses with the action's default
  threads and RAM instead of the strict cell's `2`-thread/`2 GiB` bound,
  which had been copied without a hosted rationale. Rust query evaluation
  took `377s` on 2 of the runner's 4 CPUs. Suites, languages, build mode,
  threat model and upload/processing gates are unchanged.
- Remove the lifecycle cap again and run the native budgets in their own
  `native-budgets` cell; see
  [ADR 0010](0010-compositional-lifecycle-verification.md#separate-native-budget-cell-2026-10-18).

A FIFO simulation over measured durations predicts about 8.6 to 8.9
minutes for a PR that does not touch strict-lane inputs. PRs that do touch
them remain bounded by the unchanged strict lane, about 17 to 20 minutes.
Hosted runs at `8b20be6` passed without retries, with the strict lane also
running and competing for slots: `CodeQL advanced` `39157701948` in `4m45s`
(Rust analysis `281s`), Rust `39157701925` in `1m52s`, lifecycle
`39157701904` in `8m49s` and `CodeQL strict Kotlin` `39157702087` in
`19m00s` (preparation `932s`). One sample, not a cold/warm comparison.

### Strict-lane preparation speedup (2026-10-18)

The owner then asked for the strict lane itself to finish within 10 minutes
without weakening any gate. In run `39157702087`, preparation spent `111s` freezing
(`83s` of `ditto` copies and a `28.6s` serial manifest), `44s` downloading and
`55s` preparing Gradle while Cargo and Native waited. The approved changes are:

- **Clone freeze.** Freeze copies use `ditto --clone`, so the source and
  `/opt` on the same APFS volume share blocks copy-on-write.
  `tool-input-manifest.py --jobs` hashes on `hw.ncpu` workers. Tests check
  that its output is byte-identical to the serial manifest. Later edits to
  the source do not affect the frozen copy, and the post-cell `shasum`
  gates are unchanged.
- **Checksum-verified download cache.** `fetch-pinned.sh` keeps pinned
  JDK, Gradle, Kotlin/Native, CodeQL bundle and Android API archives in an
  `actions/cache` directory keyed by their SHA-256. Every use, including a
  cache hit, runs `shasum -a 256 --check` against the pin in the
  workflow or script, and a mismatch fails. Compiled targets, Cargo inputs,
  Gradle dependencies and the generator are not cached.
- **Overlap.** JDK, toolchain and CodeQL downloads run concurrently, and
  Gradle preparation runs concurrently with Cargo and Native preparation.
  This is scheduling only; each step keeps its own manifest and integrity
  log.
- Preflight ordering, the split cells and the generator debuginfo are
  recorded in
  [ADR 0014](0014-hosted-apple-isolation-probes.md#concurrent-preflight-and-split-strict-cells-2026-10-18).

## Action release refresh (2026-10-16)

The owner requested updating all GitHub Actions to their latest versions.
Official stable-release metadata and release-tag commits were checked for
all six upstream repositories used by the five maintained workflows.
Only the CodeQL Action requires an update:
[`v4.39.0`](https://github.com/github/codeql-action/releases/tag/v4.39.0),
published on 2026-10-15, resolves to immutable commit
`6f2ac81f5cd81fe351a197ba0b00d91d03cd2aee`. Replace all three `init`,
`analyze` and `upload-sarif` references together, with matching version comments.
This supersedes the initial `v4.38.3` action pin above, not its historical evidence.

`actions/checkout` `v7.0.1`, `actions/cache` `v6.1.0`,
`actions/setup-python` `v7.0.0`, `actions/upload-artifact` `v7.0.2` and
`actions/download-artifact` `v8.0.2` already match their latest stable releases
and exact release commits; retain those pins. Same-repository reusable
workflows continue to follow the checked-out revision.

The new CodeQL release raises its minimum CLI version to `2.20.7`; the
strict Kotlin lane's checksum-pinned CLI `2.27.2` remains compatible.
All configured inputs remain supported, including `tools: linked` and
the default workspace-root checkout. No workflow trigger, permission,
language, query suite, upload policy, resource limit or Kotlin isolation
setting changes. This is a CI dependency refresh, not a runtime/API/wire
change or new hosted extraction/processed-scan evidence.

## Root Gradle build extraction (ADR 0020)

The owner chose to extend this lane to the root Gradle build in PR #33 rather
than leave the root Kotlin unscanned. The same database (source root still
`/opt/cairn-apple-tools/fixture`) now traces two builds before one finalize:

1. `jvm`: the fixture build, unchanged except that finalization moves out.
2. `repository-bindings` (build sandbox, private IPC, 900 seconds):
   `check-repository-build.sh bindings` assembles `repository-build` in
   bounded scratch from frozen inputs and runs `:sdk:buildBindings` offline.
3. `repository-codeql` (CodeQL sandbox, private IPC, 900 seconds):
   `check-codeql-repository.sh` traces the five compile tasks
   (`:sdk:compileKotlinJvm`, `:sdk:compileTestKotlinJvm`,
   `:sdk:compileAndroidMain`, `:app:compileAndroidMain`,
   `:androidApp:compileDebugKotlin`), then finalizes.

The frozen root inputs are prepared only in the `codeql` cell under
`/opt/cairn-apple-tools/repository-inputs`, covered by the separate
`repository-inputs.sha256` manifest:

- the tracked root sources;
- Rust `1.99.0`;
- Ubique `1.3.2` source pinned by commit;
- a Cargo vendor tree;
- the resolved Gradle `modules-2` cache, including macOS AAPT2;
- an Android SDK built from checksum-pinned platform `37.0` and build-tools
  `36.0.0` archives plus license-free `package.xml` metadata;
- a generator adapter derived from the fixture's.

The coverage gate and SARIF mapper accept the root build as a second owning
root. Root sources map to repository paths and generated bindings of either
build are required. Every other path still fails.

Limit changes, each justified by the added work rather than relaxed gates:

| Limit | Before | After | Reason |
|---|---|---|---|
| `repository-bindings`, `repository-codeql` | none | 900 s each | the root build compiles generator, Rust core and five Kotlin compilations; an offline Linux guest needed 6 min 15 s at one worker |
| `codeql-analysis` | 300 s | 600 s | the suite now evaluates the root sources as well |
| `prepare` job | 30 min | 45 min | the added preparation and both traced builds run in the `codeql` cell |

The sandbox, network, integrity, scratch-size and cleanup boundaries are
unchanged. The isolation cell does not prepare or verify root inputs.

Observed in run
[`39830482224`](https://github.com/trancee/cairn/actions/runs/39830482224)
at `f871a15`. The first attempt lost the completed preflight job state
(GitHub kept reporting it as in progress), so both cells failed closed at
the preflight wait. The full rerun then passed with unchanged revision and
limits:

- `repository-bindings` took 3 min 5 s, and the root trace with finalize
  took 1 min 39 s. Analysis took 1 min 13 s, and the `codeql` cell 22 min 38 s.
- Compiled coverage contains all five tracked root `.kt` files plus the root
  `commonMain`, `jvmMain` and `androidMain` generated bindings, alongside the
  fixture sources.
- The bundled suite reports zero results across 76 rules.

The SARIF artifact list still enumerates only files under the fixture source
root. Root findings are mapped by the tested normalizer, but no actual root
result has been observed yet.
