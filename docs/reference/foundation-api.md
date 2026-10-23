# Rust foundation API

Scope: unreleased `cairn-wire`, `cairn-crypto`, `cairn-proto` and `cairn-ffi`
at crate version `0.1.0`. There is no BLE transport; the FFI exports the
sans-IO `CairnCore` of slice S1.

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
`WireError` implements `Display` and `core::error::Error` with fixed,
input-free messages, for example `wire field truncated`.

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

## `cairn-proto`

This `no_std` + `alloc` crate holds the sans-IO `Core` event loop, whose
contract is [ADR 0022](../adr/0022-cairn-core-contract.md). It also implements
the epoch identifiers and durable KEM object transfer of
[spec §9](../spec/cairn-r1.md#9-post-quantum-ratchet), documented below. That
transfer moves public ML-KEM-768 objects only: it performs no KEM operation,
record encoding or persistence, and nothing calls it outside its tests
([ADR 0016](../adr/0016-unexposed-epoch-transfer-core.md)).

| Type or operation | Contract | Errors |
|---|---|---|
| `Epoch::new(value: u32)`, `Epoch::value(self) -> u32`, `Epoch::FIRST` | Wire identifier, starting at 0 | None |
| `Epoch::successor(self) -> Result<Epoch, EpochExhausted>` | Advances by exactly one; never wraps | `EpochExhausted` after `u32::MAX` |
| `Epoch::generator(self) -> PairingRole` | `A` for even epochs, `B` for odd ones | None |
| `Epoch::incoming_kind(self, local: PairingRole) -> ObjectKind` | The generator receives `Ciphertext`; the other role receives `EncapsulationKey` | None |
| `ObjectKind::length(self) -> usize` | 1184 for `EncapsulationKey`, 1088 for `Ciphertext` | None |
| `ObjectKind::progress_code(self) -> u8`, `ObjectKind::from_progress_code(code: u8)` | KEM_PROGRESS `kind`: `0x01` key, `0x02` ciphertext | `ProgressRejected` for other codes |
| `IncomingObject::new(epoch, kind)` | Empty receiver prefix for one epoch object | None |
| `IncomingObject::accept_chunk(&mut self, epoch, kind, offset: u32, chunk: &[u8]) -> Result<ChunkOutcome, TransferInvalid>` | `Appended` at the frontier; `Duplicate` for an exact copy inside the prefix | `TransferInvalid` |
| `IncomingObject::next_offset(&self) -> u32` | Cumulative progress to report | None |
| `IncomingObject::completed(&self) -> Option<&[u8]>` | The object only once every byte arrived | None |
| `OutgoingObject::new(epoch, kind, bytes: Vec<u8>) -> Result<OutgoingObject, ObjectLengthInvalid>` | Immutable object of the kind's fixed length | `ObjectLengthInvalid` |
| `OutgoingObject::next_chunk(&mut self, capacity: usize) -> Option<OutgoingChunk<'_>>` | Next unsent `offset` and at most `capacity` bytes; `None` when nothing fits or remains | None |
| `OutgoingObject::accept_progress(&mut self, epoch, kind, next_offset: u32) -> Result<(), ProgressRejected>` | Raises acknowledged progress; older progress keeps the stored value | `ProgressRejected` |
| `OutgoingObject::acknowledged(&self) -> u32`, `is_fully_acknowledged(&self) -> bool` | Acknowledged cumulative offset | None |
| `OutgoingObject::restart_session(&mut self)` | The next chunk restarts at the acknowledged offset | None |

`TransferInvalid` covers a wrong epoch or kind, an empty chunk, a gap, a
conflicting duplicate, an overlap crossing the frontier and any byte beyond
the fixed length, including offsets near `u32::MAX`. A rejected chunk leaves
the object unchanged; its diagnostic is the spec's local reason
`pq_transfer_invalid`. `ProgressRejected` (`KEM_PROGRESS rejected`) covers a
wrong epoch or kind and progress beyond bytes sent in any session; rejected
progress changes nothing. `EpochExhausted` displays `epoch_exhausted`.

Callers must persist appended bytes and their progress before sending
KEM_PROGRESS, and persist an outgoing object before its first chunk.
The duplicate check uses ordinary equality because KEM objects are public.
The crate-level documentation contains an executable transfer example.

## `cairn-ffi`

This crate is the UniFFI `0.32.0` surface for the Kotlin `:sdk` module. The
generated package is `ch.trancee.cairn.ffi`. It exports one `CairnCore` per
device, backed by `cairn-proto`'s `Core` with the `AwsLc` adapter
([ADR 0022](../adr/0022-cairn-core-contract.md)).

| Export | Contract | Errors (Kotlin) |
|---|---|---|
| `CairnCore()` | An unrestored core; the first event must be `Event.Restore` | None |
| `handle(clock: Clock, event: Event) -> List<Action>` | Runs one event; execute the actions in order (ADR 0022 §2, §3) | `CoreException.NotRestored`, `.AlreadyRestored`, `.InvalidBlob`, `.DuplicateLink`, `.InvalidMtu`, `.UnexpectedBeaconRead`, `.UnknownContact`, `.Crypto`, `.Poisoned` |
| `contacts() -> List<ContactInfo>` | Id, shared name and `Verification`; empty before `Restore` | `CoreException.Poisoned` |
| `beacon(unixS: ULong) -> ByteArray` | The 8 B local `beacon` characteristic value | `CoreException.NotRestored`, `.Crypto`, `.Poisoned` |

`Event` and `Action` are sealed classes mirroring the core. `LinkId`,
`TimerId` and `ContactId` cross as `ULong`. `Clock`, `Persisted`,
`ContactInfo`, `GattRole`, `Verification` and `ChatRejection` mirror the core
types. `Event.BeaconRead` carries the bytes read; a value that is not 8 B long
closes the link and backs off the address.

Keys, `pairID` and session state stay in Rust. The `Persist` blob and chat text
cross by design: Kotlin seals the blob with the platform keystore.

A panic inside the core surfaces as UniFFI's `InternalException` and poisons
the core: every later call throws `CoreException.Poisoned`. Kotlin must
`close()` a `CairnCore`; calls after `close()` throw `IllegalStateException`.
