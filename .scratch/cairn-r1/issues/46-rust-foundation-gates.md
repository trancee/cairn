# Rust foundation gate completion

Type: task
Status: open
Blocked by: 44

## Scope

The user approved a host-only workspace/wire/symmetric-crypto increment on
2026-10-09, with public wire encoding and crypto backend seams. No state
machines or bindings are authorized by this increment. S0 is not complete.

## Evidence and outstanding gates

Local Rust 1.99.0 tests, clippy, cargo-deny 0.20.2, wire Miri and crypto
careful 0.4.10 (nightly-2026-10-08) pass on macOS ARM64. Both adapters pass
83 HKDF and 174 HMAC Wycheproof cases. CI is configured for three host
platforms and passes in hosted run 37963154963 (linked below).

Nightly branch coverage measured by cargo-llvm-cov 0.9.1 is 100% for wire
lines/branches and 100% of recorded crypto branches, but only 86.36% of
crypto lines in the first measurement; after diagnostic tests, coverage is
93.94%. The four uncovered lines translate provider errors. An independent failure-capable seam is needed before claiming
full line coverage; do not suppress production code or inject fixture-only
failures.

Follow-up (user approved the typed provider-error conversion seam):
`From` implementations map genuine provider HKDF length failures and the
documented defensive HMAC length error to `CryptoError::BackendFailure`.
Tests cover that public contract. Both crates now have 100% measured source
line and recorded branch coverage. Four error-propagation regions remain
uncovered (crypto region coverage 94.81%); line coverage does not establish
that errors occurred inside valid adapter calls. No suppression was added.

The wire fuzz smoke completed 57,843,345 executions in 61 seconds on macOS
ARM64 (cargo-fuzz 0.13.2, nightly-2026-10-08, seed 20261009, max_len 65540)
without a crash. Corpus and fuzz lockfile are retained; Linux x86-64/ARM64
smokes also pass in the hosted run linked below.

Provider source investigation: RustCrypto HMAC `new_from_slice` accepts any
key length; RustCrypto HKDF rejects only output longer than 255 digest
blocks. The wrapper already validates that bound. AWS-LC expansion rejects
the same bound and fill rejects output/key length mismatch, neither of
which valid wrapper calls permit. Native fill errors must still fail closed.
These paths must not be fabricated or suppressed for a coverage number.

Outstanding ADR 0007 gates: secret-taint checks for protocol-labelled glue,
binding/device proofs and required-check enforcement configuration.
CI enforces 100% source line/branch coverage, which now passes locally.
Binding deployment
floors/device proofs remain issue 44 and S0 obligations. Independent protocol
review and the composed-ratchet gate also remain open.

Done when the applicable ADR 0007 and Constitution gates are green, the
CI results are recorded, and PROJECT/core documentation agrees with them.

HMAC ACVP follow-up: both adapters pass all 150 AFT cases from the official
NIST ACVP-Server HMAC-SHA2-384-2.0 corpus at commit
`975de31eb83d87039ec88934fdc47d8c312b892d`. Prompt/results and NIST notice
are retained unchanged with checksums in core/README.

HKDF KDA follow-up: the owning extraction script validates both upstream
checksums and retains all 100 SHA2-384 single-expansion cases (50 AFT/50 VAL)
from KDA-HKDF-Sp800-56Cr2 at the same NIST commit. Both adapters pass,
including accepted/rejected VAL cases. Fixed info follows upstream
`FixedInfo.cs` (U party info || V party info || u32 output-bit length);
shared input is Z || T. Selected group contents are unchanged and the
subset notice records the modification.

Multi-expansion follow-up: the same checksum-validated owning script now
extracts the remaining 100 SHA2-384 cases (50 AFT/50 VAL). Both adapters pass
every expansion, including accepted/rejected VAL output-key lists.
The existing raw HKDF interface recomputes extract per iteration; no
reusable-PRK API is added or tested. All 200 SHA2-384 cases in the pinned
corpus are now covered; no all-algorithm corpus or certification claim is made.
The foundation adapter taint and mobile compilation follow-ups below
provide local and hosted evidence.

Foundation secret-taint follow-up: the separate locked `core/ct` workspace
uses `crabgrind` 0.4.0 safe Memcheck requests around the existing primitive
seams. `bash scripts/check-ct.sh` passed both adapters under Rust 1.99.0 /
Valgrind 3.19.0 on Linux x86-64 (Rosetta) and native Linux ARM64 containers.
Required branch/address controls produced diagnostics and exit code 42;
output shadow-bit checks confirmed secret propagation. Backend runs
reported zero errors; no harness suppressions or declassification were used.
The initial compiler-folded control was detected as insensitive and replaced
with post-taint memory reads. Storage exhaustion interrupted testing, but
the final corrected runs completed after space was freed and the VM restarted.
The hosted Linux matrix passes with Valgrind 3.22.0. This is not mobile or
full protocol-glue constant-time evidence.

Apple foundation follow-up: release library compilation passes for
`aarch64-apple-ios` and `aarch64-apple-ios-sim`, both crates/all features,
with Rust 1.99.0, Xcode 27 SDKs, Apple clang 21.0.0 and an explicit
`IPHONEOS_DEPLOYMENT_TARGET=15.0`. The hosted job also passes.
This is not an application-link/runtime/package/binding deployment
proof and does not satisfy issue 44.

Android foundation follow-up: both crates/all features compile as release
libraries for Android API 26 arm64-v8a, armeabi-v7a and x86_64.
The command is `cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 --platform 26
build --workspace --all-features --release --locked` from `core/`, with
`ANDROID_NDK_HOME` pointing to NDK r30 (`30.0.16248370`).
Local execution used Rust 1.99.0, cargo-ndk 4.1.2 and Android clang 21.0.0
on macOS ARM64; all three targets built without cached target artifacts.
The hosted Linux job also passes. No final
shared-library link, APK/JNI/KMP call, runtime/API-floor or mobile
constant-time proof is claimed. Issue 44 remains open.

Hosted foundation evidence: all 11 jobs passed in
[run 37963154963](https://github.com/trancee/cairn/actions/runs/37963154963)
on pushed commit `4ba49550b75bdfbce55f321f3ceee84258c670cb`:
ordinary gates on three hosts, coverage, Miri/careful, two fuzz jobs,
two native secret-taint jobs and Android/Apple cross-builds.
This closes hosted execution for the approved partial foundation, not S0,
binding/device readiness, independent review or composed-model completion.
The same commit's
[lifecycle run 37963154753](https://github.com/trancee/cairn/actions/runs/37963154753)
also passed all 11 formal regression jobs. This does not close the
resource-inconclusive full assembled replay.

Merge enforcement check (2026-10-09): `gh api repos/trancee/cairn/rulesets`
returned an empty list; `gh api repos/trancee/cairn/branches/main/protection`
returned HTTP 404, "Branch not protected". Thus the current CI results are
evidence, not an enforced merge prerequisite. No repository settings were
changed; configuring enforcement requires explicit owner approval.

Final-head CI at `83e2edb`: Rust run 37967905365 passed.
Lifecycle run 37967905307 failed in `replay-fresh_dk_origin` with
`tamarin-prover: <<loop>>` and exit code 1 after derivation checks.
The source hash was
`c393e8cea8a93bef1112214dae2c22e5f750de4991cf05372ce525cf740e1b2b`;
the replay hash was
`9b6a25a568a9b3024d43263649009c2df4263d1625d7a56dccbfded489f3535d`.
This resembles the previously observed runtime crash, but its cause remains
unresolved. No automatic retry or workaround was added. PR #2 remains
unmerged pending successful final-head validation and documentation review.

Investigation (2026-10-09): successful lifecycle run 37966263691, attempt 2,
has identical source/replay hashes and verifies all five retained certificates
(12/8/18/9/46 steps). Both jobs used Ubuntu image `20261004.327.1` and
checksum-verified Tamarin/Maude archives. Failure occurs in the final replay,
after theory closure, not archive installation, canonical comparison or
the 300-second timeout. No falsified lemma result was emitted.

The official Linux archive identifies GHC 9.6.7 with threaded RTS and default
`-N`, Tamarin revision `82780bbaf3328a45f624ddb41e51bf75425f851c`
(reported with uncommitted build changes). Ten repeated final replays using
that exact archive and matching canonical hashes on Ubuntu 24.04 through
Colima/Rosetta all verified the five certificates in about 42.6 seconds.
The native macOS replay also passed, but had different canonical hashes.
Neither result reproduces the crash or establishes a root cause.
The remaining diagnostic requirement is a repeatable native x86-64 Linux
reproduction with retained process diagnostics; Rosetta is not hosted parity.

The user authorized a temporary 20-replay native hosted diagnostic.
Run [37970902175](https://github.com/trancee/cairn/actions/runs/37970902175)
at `00a3f0c` passed 20/20 exact-input final replays, verifying all five
retained certificates every time (43.77–46.08 seconds). It used the same
Ubuntu image version, Python 3.13.16, GHC 9.6.7, four CPUs, unset `GHCRTS`
and default `-N`. The source/replay hashes matched the failed job.
Its `fresh-dk-runtime` artifact retains runtime metadata, theories and
per-attempt output for seven days. Ordinary lifecycle/Rust runs
`37970902125`/`37970902100` also passed at that commit.
The temporary workflow/driver were removed as authorized after capture.
No failing native reproduction or minimized counterexample was obtained.
The investigation remains inconclusive, with no root cause or fix claimed.
Do not replace the fail-closed replay gate with automatic retries.
