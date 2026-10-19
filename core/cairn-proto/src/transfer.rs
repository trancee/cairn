use alloc::vec::Vec;

use crate::{Epoch, ObjectKind};

// Offsets are public u32 wire values; every supported target widens them losslessly.
const _: () = assert!(usize::BITS >= u32::BITS);

/// An invalid KEM_EK or KEM_CT chunk; local reason `pq_transfer_invalid`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TransferInvalid;

impl core::fmt::Display for TransferInvalid {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        formatter.write_str("pq_transfer_invalid")
    }
}

impl core::error::Error for TransferInvalid {}

/// A KEM_PROGRESS record the sender must reject (spec §9).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ProgressRejected;

impl core::fmt::Display for ProgressRejected {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        formatter.write_str("KEM_PROGRESS rejected")
    }
}

impl core::error::Error for ProgressRejected {}

/// An outgoing object whose length differs from its kind's fixed length.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ObjectLengthInvalid;

impl core::fmt::Display for ObjectLengthInvalid {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        formatter.write_str("KEM object length invalid")
    }
}

impl core::error::Error for ObjectLengthInvalid {}

/// How an accepted chunk changed the stored prefix.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChunkOutcome {
    Appended,
    Duplicate,
}

/// The receiver's single contiguous prefix of one epoch object (OI-26).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IncomingObject {
    epoch: Epoch,
    kind: ObjectKind,
    received: Vec<u8>,
}

impl IncomingObject {
    pub fn new(epoch: Epoch, kind: ObjectKind) -> Self {
        Self {
            epoch,
            kind,
            received: Vec::with_capacity(kind.length()),
        }
    }

    pub fn epoch(&self) -> Epoch {
        self.epoch
    }

    pub fn kind(&self) -> ObjectKind {
        self.kind
    }

    /// Cumulative offset to report in KEM_PROGRESS.
    pub fn next_offset(&self) -> u32 {
        wire_offset(self.received.len())
    }

    /// Validate a chunk completely before mutating the stored prefix.
    pub fn accept_chunk(
        &mut self,
        epoch: Epoch,
        kind: ObjectKind,
        offset: u32,
        chunk: &[u8],
    ) -> Result<ChunkOutcome, TransferInvalid> {
        let start = offset as usize;
        let length = self.kind.length();
        if epoch != self.epoch
            || kind != self.kind
            || chunk.is_empty()
            || start > length
            || chunk.len() > length - start
        {
            return Err(TransferInvalid);
        }
        let frontier = self.received.len();
        if start == frontier {
            self.received.extend_from_slice(chunk);
            return Ok(ChunkOutcome::Appended);
        }
        // Chunks are public KEM objects, so this comparison needs no constant-time guarantee.
        match self.received.get(start..start + chunk.len()) {
            Some(stored) if stored == chunk => Ok(ChunkOutcome::Duplicate),
            _ => Err(TransferInvalid),
        }
    }

    /// The whole object, only once every byte has been received.
    pub fn completed(&self) -> Option<&[u8]> {
        (self.received.len() == self.kind.length()).then_some(self.received.as_slice())
    }
}

/// One chunk to place in a KEM_EK or KEM_CT record.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OutgoingChunk<'object> {
    pub offset: u32,
    pub bytes: &'object [u8],
}

/// The sender's immutable epoch object and its acknowledged progress (OI-25).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OutgoingObject {
    epoch: Epoch,
    kind: ObjectKind,
    bytes: Vec<u8>,
    acknowledged: usize,
    highest_sent: usize,
    cursor: usize,
}

impl OutgoingObject {
    pub fn new(
        epoch: Epoch,
        kind: ObjectKind,
        bytes: Vec<u8>,
    ) -> Result<Self, ObjectLengthInvalid> {
        if bytes.len() != kind.length() {
            return Err(ObjectLengthInvalid);
        }
        Ok(Self {
            epoch,
            kind,
            bytes,
            acknowledged: 0,
            highest_sent: 0,
            cursor: 0,
        })
    }

    pub fn epoch(&self) -> Epoch {
        self.epoch
    }

    pub fn kind(&self) -> ObjectKind {
        self.kind
    }

    /// The durable cumulative offset the receiver has acknowledged.
    pub fn acknowledged(&self) -> u32 {
        wire_offset(self.acknowledged)
    }

    pub fn is_fully_acknowledged(&self) -> bool {
        self.acknowledged == self.bytes.len()
    }

    /// Take the next unsent chunk of at most `capacity` bytes.
    pub fn next_chunk(&mut self, capacity: usize) -> Option<OutgoingChunk<'_>> {
        let start = self.cursor;
        let end = self.bytes.len().min(start.saturating_add(capacity));
        if end == start {
            return None;
        }
        self.cursor = end;
        self.highest_sent = self.highest_sent.max(end);
        Some(OutgoingChunk {
            offset: wire_offset(start),
            bytes: &self.bytes[start..end],
        })
    }

    /// Apply cumulative KEM_PROGRESS; stale progress never decreases it.
    pub fn accept_progress(
        &mut self,
        epoch: Epoch,
        kind: ObjectKind,
        next_offset: u32,
    ) -> Result<(), ProgressRejected> {
        let acknowledged = next_offset as usize;
        if epoch != self.epoch || kind != self.kind || acknowledged > self.highest_sent {
            return Err(ProgressRejected);
        }
        self.acknowledged = self.acknowledged.max(acknowledged);
        self.cursor = self.cursor.max(self.acknowledged);
        Ok(())
    }

    /// A new session resends from the durable acknowledged offset.
    pub fn restart_session(&mut self) {
        self.cursor = self.acknowledged;
    }
}

fn wire_offset(offset: usize) -> u32 {
    // Offsets never exceed the 1184-byte fixed object length.
    offset as u32
}
