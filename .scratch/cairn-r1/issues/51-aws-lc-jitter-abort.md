# AWS-LC jitter entropy aborts the app at startup

Type: bug
Status: resolved
Blocked by: none

## Observation

During the S2 fleet trace run ([issue 32](32-slice-s2.md)), the Huawei P10 lite
(Kirin 659, Android 8.0, API 26) aborted with SIGABRT about 0.7 s after
`onCreate`, on five out of five launches. The same build had run on that
phone earlier the same night. Symbolized against the unstripped
`libcairn_ffi.so`, the trace is:

`CairnCore.handle(Restore)` → `Core::restore` (`core.rs:354`) →
`AwsLc::fill_random` → `RAND_bytes` → `get_entropy_source` →
`tree_jitter_initialize_once` → `tree_jitter_get_root_seed` → `abort()`.

`aws-lc-sys` 0.45 builds the CPU jitter entropy source by default. When the
jitter collector fails its health tests three times in a row, AWS-LC aborts
the process.

## Resolution

[ADR 0024](../../../docs/adr/0024-aws-lc-os-entropy.md): the repository-root
`.cargo/config.toml` sets `AWS_LC_SYS_NO_JITTER_ENTROPY=1` for every target,
so AWS-LC seeds its DRBG from the OS CSPRNG. The new test
`core/cairn-crypto/tests/entropy.rs` was red before the change and is green
after it. With the rebuilt APK, the P10 lite started on five out of five
launches.

Upstream: a report to aws/aws-lc is drafted but not filed. It needs approval
and a minimal Cairn-free reproducer.
