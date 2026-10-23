# Rust foundation

This is an unreleased, host-tested subset of [ADR 0004](../docs/adr/0004-core-architecture.md).
It is not a secure channel implementation or completion of S0.

For a first executable example, follow the
[wire roundtrip tutorial](../docs/tutorials/first-wire-roundtrip.md).
The [API reference](../docs/reference/foundation-api.md) describes the public
contracts; [the validation guide](../docs/how-to/validate-foundation.md)
selects contributor checks. This page records toolchains, test provenance
and validation evidence.

- `cairn-wire`: allocation-free `no_std` encoding/decoding of public u32
  unsigned LEB128 and u16-big-endian length-prefixed fields from
  [spec §2.2](../docs/spec/cairn-r1.md#22-conventions). Decoders consume one
  field and report its byte count; callers must enforce complete-frame
  consumption. Encoders leave the output unchanged on error. It also parses
  the spec §4.2 frame header (`FrameType`, `Header`).
- `cairn-crypto`: the `no_std` + `alloc` `CryptoBackend` seam for SHA-384,
  HMAC-SHA-384, raw RFC 5869 HKDF-SHA-384, ML-KEM-768, X-Wing, X25519,
  AES-256-GCM and RNG. `aws-lc` selects non-FIPS `aws-lc-rs`;
  `reference` selects RustCrypto. Both are enabled by default for differential
  tests; consumers can select one with `--no-default-features --features aws-lc`
  or `reference`, or none to link only the trait, as `cairn-proto` does
  ([ADR 0022](../docs/adr/0022-cairn-core-contract.md)). No runtime backend
  fallback exists.
- `cairn-proto`: the `no_std` + `alloc` sans-IO `Core<B: CryptoBackend>` of
  [ADR 0022](../docs/adr/0022-cairn-core-contract.md), built on the
  backend-free `cairn-crypto` trait, `cairn-wire`, `subtle` and `zeroize`.
  It implements fragmentation and reassembly (spec §4), automatic neighbour
  admission with rate limits and the P0 tie-break (spec §10.4), P1–P4 TOFU
  pairing (spec §5), beacons (spec §10.1), Resume (spec §6), DATA frames
  with CHAT records (spec §7, §8) and the version-1 persistence blob. It
  also holds the post-quantum epoch
  identifiers and durable KEM object transfer from
  [spec §9](../docs/spec/cairn-r1.md#9-post-quantum-ratchet), under the
  narrow gate waiver in [ADR 0016](../docs/adr/0016-unexposed-epoch-transfer-core.md),
  which are not wired into a session.
- `cairn-ffi`: the interim UniFFI `0.32.0` binding-proof surface: the wire
  codec, a typed `WireError`, and `IncomingObject` with a typed
  `TransferError` ([ADR 0020](../docs/adr/0020-root-gradle-wire-ffi.md)).
  The root Gradle `:sdk` generates Kotlin from it. No secret crosses it.

Post-quantum ratchet completion and mixing, and the `CairnCore` FFI, are not
implemented.
ADR 0022 fixes the `CairnCore` contract that slice S1 implements.
Kotlin bindings use the `ch.trancee.cairn` namespace (`ch.trancee.cairn.ffi`).
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
RUSTFLAGS='--cfg sha2_backend="soft" --cfg keccak_backend="soft"' \
  cargo +nightly-2026-10-08 miri test -p cairn-proto --locked
cargo +nightly-2026-10-08 careful test -p cairn-crypto --all-features --locked
cargo +nightly-2026-10-08 careful test -p cairn-proto --locked
cargo install cargo-fuzz --version 0.13.2 --locked
cargo +nightly-2026-10-08 fuzz run wire_encoding -- -max_total_time=60 -max_len=65540 -seed=20261009
```

The Rust workflow runs the ordinary gates on Linux x86-64, Linux ARM64 and
macOS, plus Miri/careful on Linux. All 11 jobs passed in
[hosted run 37963154963](https://github.com/trancee/cairn/actions/runs/37963154963)
at commit `4ba4955`. A separate coverage job requires 100% source line/branch
coverage; all three crates currently meet that threshold locally.
Interpreter checks do not prove constant-time behavior and
Miri does not inspect the AWS-LC C implementation. Following
[ADR 0007](../docs/adr/0007-ct-conformance-gates.md), `cairn-proto` tests that
draw randomness or generate keys are ignored under Miri and run under careful;
the soft `sha2` and `keccak` backends keep Miri off vendor SIMD intrinsics,
which it cannot execute on AArch64.

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
cryptographic primitives; `sha2`, `hmac`, `hkdf`, `ml-kem`, `x25519-dalek`,
`sha3`, `shake` and `aes-gcm` provide the independent RustCrypto reference
adapter ([ADR 0018](../docs/adr/0018-kem-backend-increment.md),
[ADR 0019](../docs/adr/0019-crypto-seam-completion.md)), and `getrandom`
supplies its OS randomness. They are permissively licensed and lock their
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
groups are excluded from that subset.

A separate subset retains the other **100 SHA2-384 multi-expansion cases**
(50 AFT/50 VAL). Every iteration is checked through the existing raw HKDF
interface with the same `Z || T` and salt, and its supplied fixed info.
This recomputes extract per iteration; it does not test a reusable-PRK API.
All supplied output keys must match for a VAL case to pass. Generate it with
the same extraction command plus the final argument `multi`. Together the
two subsets cover every SHA2-384 group in this pinned corpus, not other
algorithms or ACVP certification.

| HKDF subset file | SHA-256 |
|---|---|
| `prompt.json` | `b0df50185c90de85dc2b762d069ce613c1dd1f9de7d2bdca054c4904af2116ac` |
| `expectedResults.json` | `af4d56f1a75dea6053399cd65b53077a726dd65ab6ce06038ee40ec5c88e1e35` |

| HKDF multi-expansion file | SHA-256 |
|---|---|
| `prompt.json` | `cb6f72df9664c24679be8a6d409dc42bc0e4b1cd15d31ff0d509f46c4135cc74` |
| `expectedResults.json` | `cbb0b99eb6601f8f7f5214a512c66f0e9ca0ed41ce3c01b0fc53e977ea879b02` |

### ML-KEM-768 and X-Wing vectors

The ML-KEM-768 ACVP subset comes from the same ACVP-Server commit
(`ML-KEM-keyGen-FIPS203`, `ML-KEM-encapDecap-FIPS203`). It keeps 25 keyGen
cases, plus 25 encapsulation, 10 decapsulation, 10 decapsulation-key-check
and 10 encapsulation-key-check cases. Regenerate it with
`python3 core/cairn-crypto/tests/vectors/extract_mlkem.py UPSTREAM_DIRECTORY OUTPUT_DIRECTORY`.
The `NOTICE` file records the selection.

| ACVP ML-KEM-768 file | SHA-256 |
|---|---|
| `keyGen/prompt.json` | `edf1190a26d4f9e43a3beab38033fe0c7e6f15d6f81440ce8ffd82e5ccbd844a` |
| `keyGen/expectedResults.json` | `91f8b2b4cb63e7cb6c5fe68d3889604a2058c8f69084e6361b74654a2ebd768e` |
| `encapDecap/prompt.json` | `9953cd1df05e5103523dd33427c39cc5e8edfc33b86dc1ec0c2fef445c99587f` |
| `encapDecap/expectedResults.json` | `c214269deaab1258475caa552bc209abea8c21b4c448bf7052ca29849229b360` |

The Wycheproof ML-KEM-768 files are copied unchanged from the commit above.

| File | SHA-256 | Cases |
|---|---|---:|
| `mlkem_768_test.json` | `c59c067ae794c343df575dd90f6f7458f51881b11a22d6e9d8677c8d9ee21e90` | 201 |
| `mlkem_768_encaps_test.json` | `9d4381f94c40853bba430245b94968b7390d9175aacd9f1ae4e250a71c78b713` | 265 |
| `mlkem_768_keygen_seed_test.json` | `fde5abe284396f4cb3c4610b90d680f0b57782e94c3365c97aee59e24881ebe4` | 100 |
| `mlkem_768_semi_expanded_decaps_test.json` | `e4438ab7d4dd7b6ace7165e45aeed4403082f981f86300c8369f69d3d071060a` | 9 |

`xwing_draft11.json` (SHA-256
`988904a5a7cc28c3bd138ac7b08c10cf366b01307cd6059901f841d81eb6794a`) has 32
cases: the three draft-11 Appendix C cases and 29 SHAKE256-derived inputs.
`xwing/generate.py` checks the draft text's SHA-256
(`1353f61f0d706199d86b6802eab83cabbb5195b2d99fb35bca20f5e4f83db786`), then
runs BoringSSL `4f3b183c5d4a8f8fcaba4c0ab4435df181df6978` and CIRCL `v1.6.5`
in a digest-pinned `golang:1.25-bookworm` image. It writes the file only if
the two outputs are byte-identical and the Appendix C cases match the draft.
With Docker available, regenerate it with
`python3 core/cairn-crypto/tests/vectors/xwing/generate.py DRAFT_11_TXT core/cairn-crypto/tests/vectors/xwing_draft11.json`.
Low-order X25519 points are excluded because the two oracles disagree on
them. Seven low-order u-coordinates are tested separately and must return
`ZeroSharedSecret` on both adapters.

The reference adapter runs every case above. `aws-lc-rs` cannot seed key
generation or derandomize encapsulation through its safe API. It therefore
runs ACVP decapsulation and key checks, Wycheproof semi-expanded
decapsulation and encapsulation-key decisions, Wycheproof decapsulation using
the reference adapter's expanded keys, and X-Wing decapsulation. Both adapters
are tested in all six cross-adapter generate/encapsulate/decapsulate role
assignments. These vectors do not confer ACVP certification.

### AES-256-GCM, X25519 and randomness vectors

The pinned ACVP-Server commit has no AES-256-GCM case with a 96-bit IV and a
128-bit tag. Both adapters therefore run every such case from the NIST CAVP
GCMVS static vectors
([`gcmtestvectors.zip`](https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/mac/gcmtestvectors.zip),
SHA-256 recorded in `cavp-gcm256/NOTICE`): 375 encryption cases and 375
decryption cases, 191 of which must fail. Regenerate them with
`python3 core/cairn-crypto/tests/vectors/extract_gcm.py gcmtestvectors.zip OUTPUT_DIRECTORY`.
The script checks the archive and member digests, keeps only
`Keylen = 256`, `IVlen = 96` and `Taglen = 128` groups, and converts CRLF to
LF. The `.rsp` files keep CAVS trailing spaces (`.gitattributes`).

| CAVP file | SHA-256 |
|---|---|
| `gcmEncryptExtIV256.rsp` | `cbce90b1b4241ea7fe49baa2eadd26da3ad5715b6cc25a104dc8f704a81796a7` |
| `gcmDecrypt256.rsp` | `5670fe3fbae43110d9ecf4283616445a147d0f6b0a02aa985734028d4a5a8fb1` |

The Wycheproof files are copied unchanged from the commit above.

| File | SHA-256 | Cases |
|---|---|---:|
| `aes_gcm_test.json` | `985e5ecc172e181eaf49e89508b9470dcf478002eb7e8559c707eb42dc97dfe7` | 316 |
| `x25519_test.json` | `35c3f5231cf25cc640b524d403461deee9e49441d5d915a3a25b2c8ff5adbe7d` | 518 |

The 66 AES-GCM cases with 32-byte keys, 12-byte IVs and 16-byte tags run
(39 valid, 27 invalid); the 250 other-size cases cannot be expressed through
the fixed-size API and are counted. All 487 X25519 agreement cases, including
RFC 7748 "acceptable" inputs, must match. The 31 all-zero cases must return
`ZeroSharedSecret`. The tests also cover rejection with the wrong AAD or
nonce, truncated sealed input, cross-adapter differential sealing and
agreement, and `X25519(sk, 9)` public keys. `fill_random` has sanity tests
only, no known answer.

## Foundation secret-taint harness

`ct/` is a separate, internal workspace, excluded from maintained-library
coverage like `fuzz/`. It uses `crabgrind` 0.4.0 (MIT) for safe Valgrind
client requests. Its C/bindgen/libclang dependencies are harness-only;
`unicode-ident` additionally requires the permissive Unicode-3.0 license.
Neither the standard library nor existing dependencies expose Memcheck
shadow-memory requests. The committed lockfile currently matches the main
workspace versions for shared dependencies; changes must preserve that
agreement to keep this evidence applicable to the production dependency set.

On Linux with Valgrind, clang, libclang and pkg-config installed, run:

```sh
bash scripts/check-ct.sh
```

The driver requires intentional secret-dependent branch and address
controls to emit undefined-value diagnostics and exit code 42 before
testing either backend. It fails outside Valgrind, without detected
controls, on missing output taint, or on any reported backend memory error.
The harness does not suppress errors or declassify secrets. Inputs, HMAC
keys and HKDF salts are tainted; lengths and HKDF info remain public.
Cases cross SHA-384 block/key boundaries and HKDF output boundaries,
including empty and maximum-length output. Secret buffers stay tainted
through drop.

Both adapters passed release-build checks with Rust 1.99.0 and Valgrind
3.19.0 on Linux x86-64 (Rosetta) and native Linux ARM64 containers.
An initial compiler-folded control was missed; the retained controls force
post-taint memory reads and output shadow-bit checks confirm propagation.
The workflow runs the same driver on native Linux x86-64/ARM64 runners;
both hosted jobs pass with Valgrind 3.22.0 in the run linked above.

The harness also covers ML-KEM-768 and X-Wing decapsulation on both
adapters, including implicitly rejected ciphertexts and the X-Wing combiner
glue. It marks the ML-KEM secret key (`dk_PKE` and `z`, not the public
`ek ‖ H(ek)`), and the reference adapter's encapsulation message and
X-Wing ephemeral ML-KEM seed. Key generation and X25519 scalars are not
marked: the matrix seed drives rejection sampling, and the mandated all-zero
X25519 abort is a deliberately public branch. A mutation that also marked
`H(ek)` was flagged at the `aws-lc-rs` adapter's public hash check, so the
harness does reach the KEM code.

AES-256-GCM sealing is checked on both adapters with a tainted key and
plaintext; the `ciphertext ‖ tag` output must be tainted. Opening and
standalone X25519 are not marked. A trial run with a tainted opening key was
flagged at both providers' tag-verdict branch (`e_aes.c:1188`, `aes-gcm`
`lib.rs:311`), which is public by design
([ADR 0019](../docs/adr/0019-crypto-seam-completion.md)).

This does not check the unimplemented protocol-labelled KDF, comparisons
or protocol AEAD framing in ADR 0007.
It does not prove mobile constant-time behavior, all inputs,
variable-latency arithmetic, or exhaustive provider-path coverage.

## Remaining gates

[ADR 0007](../docs/adr/0007-ct-conformance-gates.md) remains authoritative.
Protocol-glue secret-taint checks and binding/device proofs are not complete
in this increment. As checked on 2026-10-09, the repository has no rulesets
and `main` has no branch protection; successful CI is not enforced as a
merge prerequisite.
Do not merge or release it as completed S0 or validated production crypto.
Track the foundation gate completion in
[issue 46](../.scratch/cairn-r1/issues/46-rust-foundation-gates.md).

Provider errors have typed `From` conversions into `CryptoError`.
The conversion tests induce genuine provider HKDF length errors; the HMAC
length error is constructed explicitly because HMAC accepts arbitrary key
lengths. The `getrandom` error is constructed, and AWS-LC `KeyRejected` is
induced by a 1-byte decapsulation key. The `aes-gcm` error is induced by
opening an empty buffer. This proves the public conversion
contract, not that failures occur within valid backend calls. LLVM records
100% source lines (705/705) and branches (52/52) locally, but misses 36 of
709 regions, all of them `?` error propagation through provider calls. Thus the
coverage result does not prove all adapter error paths executed.

## Apple cross-build smoke

Both foundation libraries compile in release mode with both backends for
`aarch64-apple-ios` and `aarch64-apple-ios-sim`, using Rust 1.99.0,
Xcode 27 SDKs and Apple clang 21.0.0. The workflow repeats these smoke
builds from a fresh checkout; its hosted job passed in the run linked above.

```sh
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
IPHONEOS_DEPLOYMENT_TARGET=15.0 cargo build --manifest-path core/Cargo.toml --workspace --all-features --release --locked --target aarch64-apple-ios
IPHONEOS_DEPLOYMENT_TARGET=15.0 cargo build --manifest-path core/Cargo.toml --workspace --all-features --release --locked --target aarch64-apple-ios-sim
```

This is Rust/native-provider library compilation only. Configuring iOS 15
does not establish the deployment floor of a packaged/generated binding.
No application link, simulator/device execution, KMP boundary, SDK package
or mobile constant-time check was performed. The binding smoke remains
subject to issue 44's separate isolated-runner requirements; these foundation
checks are not that prototype.

## Android cross-build smoke

Both foundation libraries compile in release mode with both backends for
`aarch64-linux-android` (`arm64-v8a`), `armv7-linux-androideabi`
(`armeabi-v7a`) and `x86_64-linux-android`, targeting API 26.
Local compilation used Rust 1.99.0, `cargo-ndk` 4.1.2 and NDK r30
(`30.0.16248370`, Android clang 21.0.0) on macOS ARM64.
The workflow pins the same tool versions for a Linux cross-build;
the hosted job passed in the run linked above.

Install NDK `30.0.16248370` with the Android SDK package manager, then run:

```sh
cargo install cargo-ndk --version 4.1.2 --locked
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cd core
ANDROID_NDK_HOME=/path/to/sdk/ndk/30.0.16248370 cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 --platform 26 build --workspace --all-features --release --locked
```

These are Rust/native-provider library compilation checks, not final
shared-library linking, JNI/KMP calls, APK packaging, API-26 device
execution or mobile constant-time evidence. No binding code was added;
issue 44's isolated integration proof remains separate.
