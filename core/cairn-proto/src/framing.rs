//! GATT fragmentation, fragment checks and reassembly (spec §4.3, §4.4, ADR 0042).

use alloc::vec::Vec;
use cairn_wire::{Header, HeaderError};

/// Largest reassembled frame before authentication (spec §4.4).
pub const PRE_AUTH_FRAME_LIMIT: usize = 2560;
/// Largest reassembled frame after Resume (spec §4.4).
pub const SESSION_FRAME_LIMIT: usize = 4096;

pub(crate) const MIN_ATT_MTU: u16 = 23;
/// ATT write/notify overhead, the repeated header byte and the check.
const FRAGMENT_OVERHEAD: usize = 6;
/// The header byte and the check that every fragment carries.
const HEADER_AND_CHECK: usize = 3;
/// Longest attribute value ATT allows (Core Vol 3 Part F §3.2.9), whatever the MTU.
const MAX_ATT_VALUE: usize = 512;

/// The ATT MTU is below the Bluetooth minimum of 23.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MtuTooSmall;

/// Splits a complete frame (header with MORE clear, then body) into ATT values.
pub fn fragment(frame: &[u8], mtu: u16) -> Result<Vec<Vec<u8>>, MtuTooSmall> {
    if mtu < MIN_ATT_MTU {
        return Err(MtuTooSmall);
    }
    let Some((&header, body)) = frame.split_first() else {
        return Ok(Vec::new());
    };
    let capacity = (usize::from(mtu) - FRAGMENT_OVERHEAD).min(MAX_ATT_VALUE - HEADER_AND_CHECK);
    let count = body.len().div_ceil(capacity).max(1);
    Ok((0..count)
        .map(|index| {
            let chunk =
                &body[(index * capacity).min(body.len())..((index + 1) * capacity).min(body.len())];
            let mut fragment = Vec::with_capacity(HEADER_AND_CHECK + chunk.len());
            let more = if index + 1 < count { 0x80 } else { 0 };
            fragment.push(header | more);
            fragment.extend_from_slice(chunk);
            let check = crc16(&fragment);
            fragment.extend_from_slice(&check.to_be_bytes());
            fragment
        })
        .collect())
}

/// Whether an ATT value is long enough for a header and check, and its check matches (ADR 0042).
///
/// The GATT server runs this before it answers a write, so the central can resend a corrupted one.
pub fn fragment_intact(value: &[u8]) -> bool {
    value.len() >= HEADER_AND_CHECK && {
        let (fragment, check) = value.split_at(value.len() - 2);
        check == crc16(fragment).to_be_bytes()
    }
}

/// CRC-16/CCITT-FALSE: polynomial 0x1021, initial value 0xFFFF, no reflection, no final XOR.
fn crc16(bytes: &[u8]) -> u16 {
    let mut crc = 0xffff_u16;
    for &byte in bytes {
        crc ^= u16::from(byte) << 8;
        for _ in 0..8 {
            crc = if crc & 0x8000 == 0 {
                crc << 1
            } else {
                (crc << 1) ^ 0x1021
            };
        }
    }
    crc
}

/// A fragment the receiver must close the link on.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReassemblyError {
    /// Too short to hold a header and the check.
    Short,
    /// The check doesn't match: the fragment changed in transit (ADR 0042).
    Check,
    Header(HeaderError),
    /// The header differs from the frame's first fragment in more than MORE.
    HeaderMismatch,
    /// The reassembled frame would exceed the current limit.
    TooLarge,
}

/// Reassembles one frame at a time for one link direction.
#[derive(Debug)]
pub struct Reassembler {
    limit: usize,
    partial: Option<(Header, Vec<u8>)>,
}

impl Reassembler {
    pub fn new(limit: usize) -> Self {
        Self {
            limit,
            partial: None,
        }
    }

    pub fn in_progress(&self) -> bool {
        self.partial.is_some()
    }

    /// Changes the limit that later fragments are checked against (spec §4.4).
    pub fn set_limit(&mut self, limit: usize) {
        self.limit = limit;
    }

    /// Discards any partial frame.
    pub fn reset(&mut self) {
        self.partial = None;
    }

    /// Accepts one ATT value and returns the frame it completes, if any.
    pub fn accept(&mut self, value: &[u8]) -> Result<Option<Vec<u8>>, ReassemblyError> {
        if value.len() < HEADER_AND_CHECK {
            return Err(ReassemblyError::Short);
        }
        if !fragment_intact(value) {
            return Err(ReassemblyError::Check);
        }
        let (&byte, body) = value[..value.len() - 2]
            .split_first()
            .expect("the length was checked");
        let header = Header::parse(byte).map_err(ReassemblyError::Header)?;
        let complete = header.with_more(false);
        let (expected, mut frame) = self.partial.take().unwrap_or_else(|| {
            let mut frame = Vec::with_capacity(1 + body.len());
            frame.push(complete.to_byte());
            (complete, frame)
        });
        if expected != complete {
            return Err(ReassemblyError::HeaderMismatch);
        }
        if frame.len() + body.len() > self.limit {
            return Err(ReassemblyError::TooLarge);
        }
        frame.extend_from_slice(body);
        if header.more() {
            self.partial = Some((expected, frame));
            Ok(None)
        } else {
            Ok(Some(frame))
        }
    }
}
