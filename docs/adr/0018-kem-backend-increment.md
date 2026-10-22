---
status: accepted
date: 2026-10-22
version: cairn-r1
---

# 0018: Host-only ML-KEM-768 and X-Wing backend increment

## Context

[ADR 0012](0012-rust-foundation-increment.md) left KEM operations for a later
seam increment. [ADR 0004](0004-core-architecture.md) named `mlkem-native`
plus RustCrypto as the reference adapter, and
[ADR 0007](0007-ct-conformance-gates.md) requires ACVP, Wycheproof and
X-Wing vectors on both adapters.

Findings on 2026-10-22:

- AWS-LC imports its ML-KEM from `mlkem-native`
  (`crypto/fipsmodule/ml_kem/README.md`). A `mlkem-native` reference would
  therefore not be independent of the AWS-LC adapter.
- The `aws-lc-rs` 1.18.1 safe API offers random key generation and
  encapsulation, plus import and export of the FIPS 203 expanded decapsulation
  key. It has no seeded key generation, no derandomized encapsulation and no
  SHAKE256.
- RustCrypto `ml-kem` 0.3.3 offers seeded key generation, derandomized
  encapsulation (`hazmat`) and the expanded key encoding. That encoding is
  deprecated upstream in favour of seeds.
- RustCrypto `x-wing` 0.1.1 implements draft-06, not draft-11.
- AWS-LC accepts an encapsulation key that fails the FIPS 203 §7.2 modulus
  check, or a decapsulation key that fails the §7.3 hash check. It reports
  the failure only later, as an opaque operation error.

## Decision

The user approved on 2026-10-22:

1. Add ML-KEM-768 and X-Wing (draft-11) key generation, encapsulation and
   decapsulation to the host-only `CryptoBackend` seam.
2. Make the reference adapter RustCrypto: `ml-kem` 0.3.3, `x25519-dalek`
   3.0.0, `sha3` 0.12.0 and `shake` 0.1.0. Compose X-Wing from those parts.
   This amends ADR 0004/0007.
3. Restrict the `aws-lc-rs` adapter to the safe API, and record its
   known-answer-test (KAT) limits below.

Contract:

- Both adapters store decapsulation keys in expanded form:
  - ML-KEM-768: the FIPS 203 `dk_PKE ‖ ek ‖ H(ek) ‖ z` (2400 B);
  - X-Wing: `dk_M ‖ sk_X ‖ pk_X` (2464 B), the cached form that draft-11
    §5.5.1 permits.

  Only the expanded form imports into AWS-LC. Keys zeroize on drop and redact
  `Debug`.
- Both adapters explicitly enforce the §7.2 modulus check on encapsulation
  and the §7.3 hash check on decapsulation, returning `CryptoError::InvalidKey`.
  These checks read only public key bytes.
- An all-zero X25519 output in either direction returns
  `CryptoError::ZeroSharedSecret`, per spec §2.1. `x25519-dalek` tests for it
  in constant time. AWS-LC fails X25519 only for this reason once both inputs
  are 32 bytes.
- AWS-LC X-Wing key generation draws `dk_M` and `sk_X` independently, because
  it cannot expand a 32-byte seed with SHAKE256. Public keys, ciphertexts and
  expanded keys are interchangeable between the adapters, but AWS-LC-generated
  keys have no 32-byte seed form.
- Derandomized `Reference` functions exist only for known-answer tests.
  Production randomness comes from the OS CSPRNG (`getrandom`, AWS-LC
  `rand`).

Evidence, as pinned in `core/README.md`:

- ACVP ML-KEM-768 keyGen and encapsulation run on the reference adapter.
  ACVP decapsulation and both key checks run on both adapters.
- Wycheproof ML-KEM-768 seed key generation, encapsulation and decapsulation
  run on the reference adapter. AWS-LC decapsulates the same cases using the
  reference adapter's expanded keys, and must match its encapsulation-key
  accept/reject decisions; both adapters run the semi-expanded decapsulation
  file.
- X-Wing vectors: the three draft-11 Appendix C cases plus 29 SHAKE256-derived
  inputs. BoringSSL and CIRCL must produce identical bytes, and the SHAKE256
  `sk_X` must agree, before the generator writes them. The reference adapter
  reproduces key generation, encapsulation and decapsulation; AWS-LC
  reproduces decapsulation.
- Both adapters are tested in every generate, encapsulate and decapsulate
  role assignment, and on reproducible varied ciphertexts.
- Low-order X25519 rejection is tested on both adapters with seven
  u-coordinates. These are separate from the oracle vectors, because CIRCL
  returns zeros where BoringSSL fails.
- The `core/ct` Memcheck harness covers ML-KEM and X-Wing decapsulation on
  both adapters (valid and implicitly rejected ciphertexts), the X-Wing
  combiner glue, and reference derandomized encapsulation.

## Alternatives

- **`mlkem-native` reference.** It shares AWS-LC's ML-KEM source, so
  differential tests would not be independent.
- **The `aws-lc-sys` unsafe API for derandomized KATs.** It conflicts with the
  workspace's `unsafe_code = "forbid"` and the safe-API choice.
- **RustCrypto `x-wing`.** It targets draft-06; a draft-11 release is not
  available.
- **Seed-only key storage.** AWS-LC cannot import seeds, so the adapters would
  not interoperate.
- **Mapping AWS-LC's opaque errors to `InvalidKey`.** That would mislabel
  internal failures; explicit public-data checks keep the error precise.

## Risks and gates

- AWS-LC is not KAT-tested for key generation or encapsulation outputs. It is
  covered only through interoperability, ACVP/Wycheproof decapsulation, key
  checks, and accept/reject decisions.
- The expanded key form is deprecated upstream in `ml-kem`. The expanded
  helpers carry a scoped `#[expect(deprecated)]` that names this
  interoperability reason.
- Memcheck taint covers `dk_PKE`, `z` and the ML-KEM message, but not
  matrix-seed-dependent key generation or the X25519 scalars. The mandated
  all-zero abort is a public-by-design branch on secret-derived data, and the
  harness neither declassifies nor suppresses it. X25519 constant-time
  behaviour relies on upstream evidence.
- None of this is mobile constant-time evidence or CMVP validation. The
  standalone X25519 operation and its Wycheproof vectors are not exposed by
  this increment. All other ADR 0007 gates still apply, and the open gates
  remain in issue 46.

## Migration

No wire bytes, protocol labels or published APIs change. This does not
authorize S1, state-machine integration, bindings or a release. Adopting
seed-form storage later requires a provider that can import seeds, plus a
persistence-format decision.
