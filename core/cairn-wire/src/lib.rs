#![no_std]

//! Canonical public-field encodings from Cairn R1 §2.2.
//! These variable-length operations are not suitable for secret integers.

/// A malformed input or insufficient output capacity.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WireError {
    Truncated,
    NonMinimal,
    Overflow,
    BufferTooSmall,
    LengthOverflow,
}

/// Encode a public u32 as minimal unsigned LEB128 without partial writes.
pub fn encode_leb128(value: u32, output: &mut [u8]) -> Result<usize, WireError> {
    let length = ((32 - value.leading_zeros()).max(1) as usize).div_ceil(7);
    if output.len() < length {
        return Err(WireError::BufferTooSmall);
    }
    let mut remaining = value;
    for (index, byte) in output[..length].iter_mut().enumerate() {
        *byte = (remaining & 0x7f) as u8;
        remaining >>= 7;
        if index + 1 < length {
            *byte |= 0x80;
        }
    }
    Ok(length)
}

/// Decode one canonical public u32, returning its value and consumed bytes.
pub fn decode_leb128(input: &[u8]) -> Result<(u32, usize), WireError> {
    let mut value = 0;
    for (index, &byte) in input.iter().take(5).enumerate() {
        if index == 4 && byte > 0x0f {
            return Err(WireError::Overflow);
        }
        value |= u32::from(byte & 0x7f) << (index * 7);
        if byte & 0x80 == 0 {
            if index > 0 && byte == 0 {
                return Err(WireError::NonMinimal);
            }
            return Ok((value, index + 1));
        }
    }
    Err(WireError::Truncated)
}

/// Encode `u16(len(value)) || value` without partial writes.
pub fn encode_length_prefixed(value: &[u8], output: &mut [u8]) -> Result<usize, WireError> {
    let length = u16::try_from(value.len()).map_err(|_| WireError::LengthOverflow)?;
    let written = value.len() + 2;
    if output.len() < written {
        return Err(WireError::BufferTooSmall);
    }
    output[..2].copy_from_slice(&length.to_be_bytes());
    output[2..written].copy_from_slice(value);
    Ok(written)
}

/// Borrow one length-prefixed field and return its consumed byte count.
pub fn decode_length_prefixed(input: &[u8]) -> Result<(&[u8], usize), WireError> {
    let prefix = input.get(..2).ok_or(WireError::Truncated)?;
    let end = usize::from(u16::from_be_bytes([prefix[0], prefix[1]])) + 2;
    let value = input.get(2..end).ok_or(WireError::Truncated)?;
    Ok((value, end))
}
