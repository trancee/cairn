//! UniFFI exports for public, non-secret Cairn core operations.
//!
//! Secret keys, shared secrets and plaintext never cross this boundary.

use std::sync::{Mutex, PoisonError};

pub use cairn_proto::{ChunkOutcome, ObjectKind};
use cairn_proto::{Epoch, TransferInvalid};
pub use cairn_wire::WireError;

uniffi::setup_scaffolding!();

#[uniffi::remote(Error)]
pub enum WireError {
    Truncated,
    NonMinimal,
    Overflow,
    BufferTooSmall,
    LengthOverflow,
}

#[uniffi::remote(Enum)]
pub enum ObjectKind {
    EncapsulationKey,
    Ciphertext,
}

#[uniffi::remote(Enum)]
pub enum ChunkOutcome {
    Appended,
    Duplicate,
}

/// A rejected KEM_EK or KEM_CT chunk; local reason `pq_transfer_invalid`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Error)]
pub enum TransferError {
    Invalid,
}

impl std::fmt::Display for TransferError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        TransferInvalid.fmt(formatter)
    }
}

impl std::error::Error for TransferError {}

impl From<TransferInvalid> for TransferError {
    fn from(_: TransferInvalid) -> Self {
        Self::Invalid
    }
}

/// One decoded length-prefixed field and the bytes it consumed.
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct DecodedField {
    pub value: Vec<u8>,
    pub consumed: u32,
}

/// One decoded LEB128 value and the bytes it consumed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct DecodedLeb128 {
    pub value: u32,
    pub consumed: u32,
}

/// Encode a public u32 as minimal unsigned LEB128.
#[uniffi::export]
pub fn encode_leb128(value: u32) -> Vec<u8> {
    let mut output = [0; 5];
    let length = cairn_wire::encode_leb128(value, &mut output).expect("five bytes hold any u32");
    output[..length].to_vec()
}

/// Decode one canonical public u32 from the start of `input`.
#[uniffi::export]
pub fn decode_leb128(input: Vec<u8>) -> Result<DecodedLeb128, WireError> {
    let (value, consumed) = cairn_wire::decode_leb128(&input)?;
    Ok(DecodedLeb128 {
        value,
        consumed: wire_count(consumed),
    })
}

/// Encode `u16(len(value)) || value`.
#[uniffi::export]
pub fn encode_length_prefixed(value: Vec<u8>) -> Result<Vec<u8>, WireError> {
    let mut output = vec![0; value.len().saturating_add(2)];
    cairn_wire::encode_length_prefixed(&value, &mut output)?;
    Ok(output)
}

/// Decode one length-prefixed field from the start of `input`.
#[uniffi::export]
pub fn decode_length_prefixed(input: Vec<u8>) -> Result<DecodedField, WireError> {
    let (value, consumed) = cairn_wire::decode_length_prefixed(&input)?;
    Ok(DecodedField {
        value: value.to_vec(),
        consumed: wire_count(consumed),
    })
}

/// The receiver's contiguous prefix of one public epoch KEM object.
#[derive(Debug, uniffi::Object)]
pub struct IncomingObject {
    inner: Mutex<cairn_proto::IncomingObject>,
}

#[uniffi::export]
impl IncomingObject {
    #[uniffi::constructor]
    pub fn new(epoch: u32, kind: ObjectKind) -> Self {
        Self {
            inner: Mutex::new(cairn_proto::IncomingObject::new(Epoch::new(epoch), kind)),
        }
    }

    pub fn epoch(&self) -> u32 {
        self.locked().epoch().value()
    }

    pub fn kind(&self) -> ObjectKind {
        self.locked().kind()
    }

    /// Cumulative offset to report in KEM_PROGRESS.
    pub fn next_offset(&self) -> u32 {
        self.locked().next_offset()
    }

    /// Validate a chunk completely before mutating the stored prefix.
    pub fn accept_chunk(
        &self,
        epoch: u32,
        kind: ObjectKind,
        offset: u32,
        chunk: Vec<u8>,
    ) -> Result<ChunkOutcome, TransferError> {
        Ok(self
            .locked()
            .accept_chunk(Epoch::new(epoch), kind, offset, &chunk)?)
    }

    /// The whole object, only once every byte has been received.
    pub fn completed(&self) -> Option<Vec<u8>> {
        self.locked().completed().map(<[u8]>::to_vec)
    }
}

impl IncomingObject {
    // `accept_chunk` validates before mutating, so a poisoned guard still holds a valid prefix.
    fn locked(&self) -> std::sync::MutexGuard<'_, cairn_proto::IncomingObject> {
        self.inner.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

// Consumed counts come from u16-prefixed fields or five-byte LEB128 values.
fn wire_count(consumed: usize) -> u32 {
    consumed as u32
}
