# Rust foundation

This is an unreleased, host-tested subset of [ADR 0004](../docs/adr/0004-core-architecture.md).
It is not a secure channel implementation or completion of S0.

- `cairn-wire`: allocation-free `no_std` encoding/decoding of public u32
  unsigned LEB128 and u16-big-endian length-prefixed fields from
  [spec §2.2](../docs/spec/cairn-r1.md#22-conventions). Decoders consume one
  field and report its byte count; callers must enforce complete-frame
  consumption. Encoders leave the output unchanged on error.
- `cairn-crypto`: a partial `CryptoBackend` seam for SHA-384, HMAC-SHA-384
  and raw RFC 5869 HKDF-SHA-384. `aws-lc` selects non-FIPS `aws-lc-rs`;
  `reference` selects RustCrypto. Both are enabled by default for differential
  tests; consumers can select one with `--no-default-features --features aws-lc`
  or `reference`. No runtime backend fallback exists.

Protocol-labelled KDF/MAC construction, tag verification, RNG, AEAD, X25519,
ML-KEM, X-Wing, protocol state machines and FFI are not implemented.
The `ch.trancee.cairn` namespace is reserved for future Kotlin bindings.
Rust crate names use `cairn-`; Cargo does not have dotted namespaces.

## Validation

Rust is pinned in the root `rust-toolchain.toml`; `core/Cargo.lock` locks all
dependencies. From the repository root:

```sh
cargo install cargo-deny --version 0.20.2 --locked
bash scripts/check-rust.sh
rustup toolchain install nightly-2026-10-08 --profile minimal --component miri,rust-src
cargo install cargo-careful --version 0.4.10 --locked
cd core
cargo +nightly-2026-10-08 miri test -p cairn-wire --locked
cargo +nightly-2026-10-08 careful test -p cairn-crypto --all-features --locked
cargo install cargo-fuzz --version 0.13.2 --locked
cargo +nightly-2026-10-08 fuzz run wire_encoding -- -max_total_time=60 -max_len=65540 -seed=20261009
```

The Rust workflow runs the ordinary gates on Linux x86-64, Linux ARM64 and
macOS, plus Miri/careful on Linux. Hosted results are not yet available for
this increment. A separate coverage job requires 100% source line/branch
coverage; both crates currently meet that threshold locally.
Interpreter checks do not prove constant-time behavior and
Miri does not inspect the AWS-LC C implementation.

The wire fuzz target checks canonical re-encoding of accepted input,
public-integer roundtrips, truncation/overflow safety and unchanged buffers
on failed integer encoding. Its seed corpus is retained under `fuzz/corpus`;
`fuzz/Cargo.lock` pins the separate internal harness dependencies. The fuzz
job runs a 60-second smoke on both Linux architectures. A local macOS ARM64
smoke completed 57,843,345 executions in 61 seconds without a crash; this is
not exhaustive parser or platform proof.
The internal harness uses `libfuzzer-sys` (MIT/Apache-2.0 and NCSA) and its
`arbitrary` dependency; neither is a runtime dependency of the SDK.

## Dependencies and vectors

`aws-lc-rs` provides the ADR-selected non-FIPS adapter with maintained native
cryptographic primitives; `sha2`, `hmac` and `hkdf` provide the independent
RustCrypto reference adapter. They are permissively licensed and lock their
native/transitive dependencies in `Cargo.lock`. `zeroize` wipes returned
HMAC/HKDF buffers on drop and enables supported RustCrypto state wiping.
The standard library has no cryptographic primitives or guaranteed wiping
equivalent. This does not establish erasure of every provider temporary,
stack/register copy or caller-owned input. No provider is claimed to be
CMVP-validated on mobile.

`serde_json` is test-only for the pinned Wycheproof corpus:
[C2SP/wycheproof commit `12fd3aaf`](https://github.com/C2SP/wycheproof/tree/12fd3aaf33eb5fa1f52e026912ee00c054f9d984/testvectors_v1).
Vendored files retain the upstream license in `cairn-crypto/tests/vectors/LICENSE`.

| File | SHA-256 | Cases |
|---|---|---:|
| `hkdf_sha384_test.json` | `69ff6ea3657bb9c1b8cdffbbb4e7832353d08fd15c0d9997b03f7a6b180e3678` | 83 |
| `hmac_sha384_test.json` | `28b9776e979dd755d852ca471043ea6cedce8b15f7a28abdf6ea9efd982b43c0` | 174 |

HKDF invalid cases must fail. HMAC corpus tests compare full/truncated
computed tags against valid and invalid vectors; they do not exercise a
production tag-verification API. RFC 4231 case 1 supplies an additional HMAC
known answer. The SHA-384 `abc` digest supplies an independent fixed example.
Differential tests use reproducible varied inputs, not production randomness.

Both adapters also run all 150 byte-aligned AFT cases from NIST's
[`HMAC-SHA2-384-2.0` corpus](https://github.com/usnistgov/ACVP-Server/tree/975de31eb83d87039ec88934fdc47d8c312b892d/gen-val/json-files/HMAC-SHA2-384-2.0).
The prompt and expected results are copied unchanged, pinned to commit
`975de31eb83d87039ec88934fdc47d8c312b892d`, with the upstream NIST notice.
The harness matches group/case IDs, verifies bit lengths and requires every
case on both sides to be accounted for. These local vectors do not confer
ACVP certification or CMVP validation.

| ACVP file | SHA-256 |
|---|---|
| `prompt.json` | `cf1c34db3973949a2f53d9971472eba2b85fcaba43ca958ab527a4d62ef885cc` |
| `expectedResults.json` | `86e208b8c7644c55b8c14028fb1a100ae2e5711f9db680623e0f6a511758aab8` |

The HKDF KDA fixture retains **100 SHA2-384 single-expansion cases** (50 AFT
and 50 VAL) from NIST's `KDA-HKDF-Sp800-56Cr2` corpus at the same commit.
The harness builds input as `Z || T` and fixed info as U party ID/optional
ephemeral data, V party ID/optional ephemeral data, then a 32-bit big-endian
output bit length. This follows upstream `FixedInfo.cs` and is checked
against NIST's expected results, including accepted and rejected VAL cases.
These test-only KDA fields are not Cairn's protocol KDF labels.

Regenerate the subset with
`python3 core/cairn-crypto/tests/vectors/extract_hkdf.py UPSTREAM_DIRECTORY OUTPUT_DIRECTORY`.
The script validates upstream checksums and copies selected group contents;
the notice records the selection. Other algorithms and all multi-expansion
groups are excluded, so this is not a complete KDA corpus sweep.

| HKDF subset file | SHA-256 |
|---|---|
| `prompt.json` | `b0df50185c90de85dc2b762d069ce613c1dd1f9de7d2bdca054c4904af2116ac` |
| `expectedResults.json` | `af4d56f1a75dea6053399cd65b53077a726dd65ab6ce06038ee40ec5c88e1e35` |

## Remaining gates

[ADR 0007](../docs/adr/0007-ct-conformance-gates.md) remains authoritative.
HKDF multi-expansion ACVP coverage, secret-taint checks, mobile
cross-builds and binding/device proofs are not complete in this increment.
Do not merge or release it as completed S0 or validated production crypto.
Track the foundation gate completion in
[issue 46](../.scratch/cairn-r1/issues/46-rust-foundation-gates.md).

Provider errors have typed `From` conversions into `CryptoError`.
The conversion tests induce genuine provider HKDF length errors; the HMAC
length error is constructed explicitly because HMAC accepts arbitrary key
lengths. This proves the public conversion contract, not that failures
occur within valid backend calls. LLVM records 100% source lines and
branches locally, but misses four `?` error-propagation regions. Thus the
coverage result does not prove all adapter error paths executed.
