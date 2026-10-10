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
standard `macos-26` runner, with a 10-minute job timeout and seven-day artifacts.
No secrets, signing, dependencies or target-controlled build are involved.
Hosted results must be observed before claiming any hosted probe passed.
