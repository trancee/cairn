# Rust foundation API

Scope: unreleased `cairn-wire` and `cairn-crypto` at crate version `0.1.0`.
There is no protocol state-machine, transport or FFI API.

## `cairn-wire`

This allocation-free `no_std` crate encodes public fields. Variable-length
integer operations are not suitable for secret integers.

| Function | Input and output | Errors |
|---|---|---|
| `encode_leb128(value: u32, output: &mut [u8]) -> Result<usize, WireError>` | Writes minimal unsigned LEB128. Returns bytes written, from 1 to 5 | `BufferTooSmall` |
| `decode_leb128(input: &[u8]) -> Result<(u32, usize), WireError>` | Reads one canonical integer. Returns the value and bytes consumed | `Truncated`, `NonMinimal`, `Overflow` |
| `encode_length_prefixed(value: &[u8], output: &mut [u8]) -> Result<usize, WireError>` | Writes the `u16` big-endian byte length followed by the value. Returns bytes written | `LengthOverflow`, `BufferTooSmall` |
| `decode_length_prefixed(input: &[u8]) -> Result<(&[u8], usize), WireError>` | Borrows one field. Returns its contents and total bytes consumed | `Truncated` |

Encoders leave the output unchanged on failure. Length-prefixed values may
contain at most 65,535 bytes and require two additional output bytes.
Decoders accept trailing input after the first field. A complete-frame
caller must enforce full consumption.

`WireError::Truncated` means an integer or field is incomplete.
`NonMinimal` rejects redundant integer bytes. `Overflow` rejects an
integer exceeding `u32`. `BufferTooSmall` means output capacity is
insufficient. `LengthOverflow` means the field length does not fit `u16`.

For a runnable example, use the
[wire roundtrip tutorial](../tutorials/first-wire-roundtrip.md).

## `cairn-crypto`

`CryptoBackend` has three static operations:

| Operation | Contract |
|---|---|
| `sha384(input: &[u8]) -> [u8; 48]` | Returns the full SHA-384 digest |
| `hmac_sha384(key: &[u8], input: &[u8]) -> Result<Zeroizing<[u8; 48]>, CryptoError>` | Returns the full HMAC-SHA-384 tag |
| `hkdf_sha384(input: &[u8], salt: &[u8], info: &[u8], length: usize) -> Result<Zeroizing<Vec<u8>>, CryptoError>` | RFC 5869 extract and expand. Returns exactly `length` bytes |

HKDF permits zero-length output and at most 12,240 bytes (`255 * 48`).
An empty salt is equivalent to 48 zero bytes. `info` is passed unchanged:
the operation does not add Cairn protocol labels.

`CryptoError::InvalidOutputLength` rejects excessive HKDF output.
`BackendFailure` represents a translated provider error. Its displayed
diagnostic is `cryptographic backend failure`. Error translation does not
expose provider-specific errors through the trait.

Returned HMAC and HKDF buffers use `zeroize::Zeroizing` and wipe on drop.
SHA-384 returns an ordinary array. Callers manage that value's lifetime.
These types do not prove erasure of every provider temporary or caller copy.
There is no production tag-verification operation.

## Backend features

| Feature | Adapter | Default |
|---|---|---|
| `aws-lc` | `AwsLc`, non-FIPS `aws-lc-rs` | Enabled |
| `reference` | `Reference`, RustCrypto | Enabled |

The adapter is selected through the type implementing `CryptoBackend`,
not a runtime fallback. A consumer can disable default features and select
one adapter. Both are enabled in the default workspace for differential
tests. The [core reference](../../core/README.md) records exact dependencies,
vectors, commands and validation limitations.
