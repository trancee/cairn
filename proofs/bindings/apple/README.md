# Apple isolation probes

Internal benign probes for [issue 45](../../../.scratch/cairn-r1/issues/45-provision-isolated-build-runner.md),
not a binding build or accepted Apple runner. See
[ADR 0014](../../../docs/adr/0014-hosted-apple-isolation-probes.md).

On macOS with Xcode Python available:

```bash
bash proofs/bindings/apple/run-probes.sh /absolute/unused/probe-output
```

The output directory must not exist. Logs, environment observations and SHA-256
checksums remain there after success or failure. The workload checks input
write denial, a designated host sentinel read, network bind/outbound TCP,
Unix-socket IPC, scratch symlink escape denial, child inheritance,
writable scratch and a 1 MiB per-file ceiling. TCP/Unix fixtures first
connect outside the sandbox; the supervisor owns/closes them.
Use a short output path so the Unix socket pathname remains below 104 bytes.

The unprotected CLI went red on allowed input mutation. The protected local
CLI passed. An initial narrow read profile aborted process startup; the current
profile permits system reads and denies other `/Users` data plus the sentinel.
This does not prove a complete filesystem/network boundary, total disk,
memory/CPU/process limits or Xcode/Kotlin compatibility.

`.github/workflows/apple-isolation-probe.yml` runs only these probes on the free
standard `macos-26` runner, with the approved 30-minute job timeout and seven-day artifacts.
No secrets, signing, dependencies or target-controlled build are involved.
Hosted results must be observed before claiming any hosted probe passed.

The initial process-memory probe failed while setting the limit. The owner
selected a whole-VM boundary instead: `probe-memory.py` checks observed RAM
against a candidate 7 GiB ceiling and requires zero configured swap.
Any mismatch fails with checksummed `memory.log`; this is not a process cap.
Wider dedicated-user/
disk/process probes run separately even when memory fails; no target build
is authorized.

`run-resource-probes.sh` requires root and `GITHUB_ACTIONS=true`; it creates
a disabled-login UID only in the disposable hosted VM, enables ownership on
a fixed 256 MiB scratch image and runs real capacity/process/CPU exhaustion.
The user/volume are removed/detached afterwards; diagnostics remain retained.
These are benign test thresholds, not build budgets or memory acceptance.

The shared Linux collector now supports optional `--seconds` deadlines.
`python3 -B -m unittest discover -s proofs/bindings/apple -p 'test_*.py'`
checks partial output retention, closed-output waiting and invalid deadlines.
The hosted sandbox command uses a 30-second deadline and 64 MiB output cap;
the collector log is included in the checksummed artifact. Whole-VM memory
requires 7 GiB RAM and disabled/unloaded dynamic pager with zero swap.
The bounded supervisor now composes these controls for benign probes, not an
accepted binding build.

The separately authorized `apple-toolchain-preparation.yml` requires benign
preflight before downloading the existing Rust/Gradle/JDK/Ubique pins and
locked Cargo inputs on a fresh hosted VM. It does not compile the fixture.
Fixture/dependency caches are not yet frozen or replayed offline. The selected
Kotlin/Gradle/Ubique versions are unchanged; Xcode 26.6 is a separately
recorded hosted environment. Further compiler/Maven/Native preparation and
binding-build acceptance remain pending.
Trusted preparation
[run 38090961772](https://github.com/trancee/cairn/actions/runs/38090961772)
passed with the exact daemon JDK `25.0.4.1+1` after correcting an erroneous
version selector. Its artifacts contain versions, logs and input hashes,
not a reusable frozen cache.

`uid-supervisor.py` is a hosted-root-only CLI seam for the fresh
`cairnbenignprobe` account. It rejects existing UID processes and non-private
proof-output directories, applies approved CPU/process/file/core limits,
drops supplementary groups and executes with an explicit environment.
Completion, deadline and catchable interruption perform PID-specific UID
cleanup. It does not itself apply the sandbox or provision build scratch.
Hosted [run 38093375336](https://github.com/trancee/cairn/actions/runs/38093375336)
passed actual child-limit/access-group assertions and detached-descendant
deadline cleanup; all eight retained log checksums passed.

The hosted resource script next provisions an exactly 8 GiB root-owned image,
fully backs every logical byte and verifies private HFS+ scratch. Its usable
capacity is `8,245,960,704` bytes after filesystem/partition overhead. It runs
the existing sandbox probes through the dedicated supervisor and rechecks
backing/capacity afterwards. `build.sb` uses named data-read roots, unlike the
initial broad-read `probe.sb`; global metadata and root-directory enumeration
are allowed, but unrelated host file data is denied.

Trusted tool preparation
[run 38095349642](https://github.com/trancee/cairn/actions/runs/38095349642)
passed pinned Rust/Cargo, both JDKs and Gradle version startup in that cell,
then verified all frozen tool-file hashes unchanged. Tool copies are read-only
under `/opt/cairn-apple-tools`; this does not freeze fixture/Maven/Native caches.
The next compatibility probe runs `help` on a script-owned empty Groovy Gradle
project, still offline. No Ubique/Kotlin plugin or fixture is compiled.
