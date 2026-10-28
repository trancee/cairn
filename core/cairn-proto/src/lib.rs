#![cfg_attr(not(test), no_std)]

//! Sans-IO state machines for Cairn R1.
//!
//! [`Core`] is the event loop of ADR 0022: fragmentation (spec §4), neighbour
//! admission and P0–P4 pairing (spec §5, §10.4), beacons (spec §10.1), Resume
//! (spec §6), DATA with CHAT records (spec §7, §8) and the version-1
//! [`Persisted`] blob. The post-quantum epoch
//! identifiers and durable chunk transfer of spec §9 (OI-21, OI-25, OI-26) are
//! not yet wired into a session; see ADR 0016.
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

mod admission;
mod beacon;
mod card;
mod chain;
mod core;
mod courier;
mod data;
mod epoch;
mod framing;
mod kdf;
mod pairing;
#[cfg(feature = "probes")]
#[doc(hidden)]
pub mod probes;
mod resume;
mod state;
mod transfer;

pub use crate::core::{
    Action, ChatRejection, Clock, ContactId, ContactInfo, Core, CoreError, Event, GattRole, LinkId,
    TimerId, Verification,
};
pub use epoch::{Epoch, EpochExhausted, ObjectKind, PairingRole};
pub use framing::{
    MtuTooSmall, PRE_AUTH_FRAME_LIMIT, Reassembler, ReassemblyError, SESSION_FRAME_LIMIT, fragment,
};
pub use state::{ContactRow, CourierRow, Persisted, QueuedRow};
pub use transfer::{
    ChunkOutcome, IncomingObject, ObjectLengthInvalid, OutgoingChunk, OutgoingObject,
    ProgressRejected, TransferInvalid,
};
