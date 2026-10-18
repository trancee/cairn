#![no_std]

//! Sans-IO state machines for Cairn R1.
//!
//! This increment covers only post-quantum epoch identifiers and the durable
//! chunk transfer of spec §9 (OI-21, OI-25, OI-26). It is not wired into any
//! session, FFI or wire path; see ADR 0016.
//!
//! ```
//! use cairn_proto::{ChunkOutcome, Epoch, IncomingObject, OutgoingObject, PairingRole};
//!
//! let epoch = Epoch::FIRST;
//! let kind = epoch.incoming_kind(PairingRole::B);
//! let mut sender = OutgoingObject::new(epoch, kind, vec![7; kind.length()])?;
//! let mut receiver = IncomingObject::new(epoch, kind);
//! while let Some(chunk) = sender.next_chunk(500) {
//!     let outcome = receiver.accept_chunk(epoch, kind, chunk.offset, chunk.bytes)?;
//!     assert_eq!(outcome, ChunkOutcome::Appended);
//! }
//! sender.accept_progress(epoch, kind, receiver.next_offset())?;
//! assert!(sender.is_fully_acknowledged());
//! assert_eq!(receiver.completed(), Some(&[7; 1184][..]));
//! # Ok::<(), Box<dyn core::error::Error>>(())
//! ```

extern crate alloc;

mod epoch;
mod transfer;

pub use epoch::{Epoch, EpochExhausted, ObjectKind, PairingRole};
pub use transfer::{
    ChunkOutcome, IncomingObject, ObjectLengthInvalid, OutgoingChunk, OutgoingObject,
    ProgressRejected, TransferInvalid,
};
