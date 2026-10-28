//! Courier envelopes, route tags and tombstones (spec §8.1, ADR 0033).

use crate::chain::{Dir, INNER_BUCKETS, TAG_LEN};
use crate::data::leb128;
use crate::kdf::{hash, kdf, labelled, mac};
use alloc::vec::Vec;
use cairn_crypto::{CryptoBackend, CryptoError};
use subtle::{Choice, ConstantTimeEq};
use zeroize::Zeroizing;

/// The largest `inner` a courier carries (spec §8.1).
pub(crate) const COURIER_INNER_MAX: usize = 2048;

/// `MAC(K_route, "route", dir ‖ u8(gen) ‖ LEB128(idx))`.
pub(crate) fn route_tag<B: CryptoBackend>(
    route_key: &[u8; 32],
    dir: Dir,
    gen_: u8,
    idx: u32,
) -> Result<[u8; 16], CryptoError> {
    let mut index = Vec::with_capacity(5);
    leb128(idx, &mut index);
    mac::<B>(route_key, b"route", &[&[dir.label()], &[gen_], &index])
}

/// `s = KDF(mk_idx, "", "delivered", "", 16)`.
pub(crate) fn delivered<B: CryptoBackend>(
    mk: &[u8; 32],
) -> Result<Zeroizing<[u8; 16]>, CryptoError> {
    kdf::<B, 16>(mk, &[], b"delivered", &[])
}

/// `c = Trunc16(H(lp("cairn-r1 delivered") ‖ s))`.
pub(crate) fn commitment<B: CryptoBackend>(s: &[u8; 16]) -> [u8; 16] {
    let digest = hash::<B>(&[&labelled(b"delivered"), s]);
    *digest.first_chunk::<16>().expect("48 > 16")
}

/// Whether `s` opens the commitment `c`, in constant time.
pub(crate) fn tombstone_matches<B: CryptoBackend>(c: &[u8; 16], s: &[u8; 16]) -> Choice {
    commitment::<B>(s).ct_eq(c)
}

/// `ENV = tag ‖ c ‖ u32(expiry) ‖ u8(copies) ‖ ct`. `expiry` and `copies`
/// are not authenticated; `ct` is checked by [`Envelope::valid`], not by parsing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Envelope {
    pub(crate) tag: [u8; 16],
    pub(crate) c: [u8; 16],
    /// Unix minutes.
    pub(crate) expiry_min: u32,
    pub(crate) copies: u8,
    pub(crate) ct: Vec<u8>,
}

/// The fixed part of `ENV` before `ct`.
pub(crate) const ENVELOPE_HEADER: usize = 16 + 16 + 4 + 1;

impl Envelope {
    /// A courier accepts it: `ct` seals a courier-sized `inner`, `copies > 0`
    /// and it has not expired at `now_min`.
    pub(crate) fn valid(&self, now_min: u32) -> bool {
        let sized = self
            .ct
            .len()
            .checked_sub(TAG_LEN)
            .is_some_and(|inner| inner <= COURIER_INNER_MAX && INNER_BUCKETS.contains(&inner));
        sized && self.copies > 0 && self.expiry_min > now_min
    }

    pub(crate) fn encode(&self, output: &mut Vec<u8>) {
        output.extend_from_slice(&self.tag);
        output.extend_from_slice(&self.c);
        output.extend_from_slice(&self.expiry_min.to_be_bytes());
        output.push(self.copies);
        output.extend_from_slice(&self.ct);
    }

    /// `None` if `body` is shorter than the fixed fields.
    pub(crate) fn decode(body: &[u8]) -> Option<Self> {
        let (header, ct) = body.split_at_checked(ENVELOPE_HEADER)?;
        let (tag, rest) = header.split_first_chunk::<16>()?;
        let (c, rest) = rest.split_first_chunk::<16>()?;
        let (expiry, copies) = rest.split_first_chunk::<4>()?;
        Some(Self {
            tag: *tag,
            c: *c,
            expiry_min: u32::from_be_bytes(*expiry),
            copies: copies[0],
            ct: ct.into(),
        })
    }
}

/// A courier's answer to an ENVELOPE (record `11`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub(crate) enum Custody {
    Accepted = 0,
    Full = 1,
    Duplicate = 2,
    Off = 3,
    Invalid = 4,
}

impl Custody {
    pub(crate) fn from_code(code: u8) -> Option<Self> {
        Some(match code {
            0 => Self::Accepted,
            1 => Self::Full,
            2 => Self::Duplicate,
            3 => Self::Off,
            4 => Self::Invalid,
            _ => return None,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use cairn_crypto::Reference;

    const KEY: [u8; 32] = [0x42; 32];
    const NOW_MIN: u32 = 29_000_000;

    fn envelope(ct_len: usize, copies: u8, expiry_min: u32) -> Envelope {
        Envelope {
            tag: [1; 16],
            c: [2; 16],
            expiry_min,
            copies,
            ct: std::vec![3; ct_len],
        }
    }

    #[test]
    fn a_route_tag_macs_the_direction_generation_and_index() {
        let tag = route_tag::<Reference>(&KEY, Dir::R, 3, 300).unwrap();

        let expected = mac::<Reference>(&KEY, b"route", &[b"R", &[3], &[0xac, 0x02]]).unwrap();
        assert_eq!(tag, expected);
        assert_ne!(tag, route_tag::<Reference>(&KEY, Dir::I, 3, 300).unwrap());
    }

    #[test]
    fn the_delivery_secret_and_its_commitment_follow_the_spec() {
        let mk = [7; 32];

        let s = delivered::<Reference>(&mk).unwrap();

        assert_eq!(
            s,
            kdf::<Reference, 16>(&mk, &[], b"delivered", &[]).unwrap()
        );
        let mut input = std::vec![0, 18];
        input.extend_from_slice(b"cairn-r1 delivered");
        input.extend_from_slice(&s[..]);
        assert_eq!(commitment::<Reference>(&s), Reference::sha384(&input)[..16]);
    }

    #[test]
    fn a_tombstone_matches_only_its_commitment() {
        let s = [9; 16];
        let c = commitment::<Reference>(&s);

        let matches = [
            bool::from(tombstone_matches::<Reference>(&c, &s)),
            bool::from(tombstone_matches::<Reference>(&c, &[8; 16])),
        ];

        assert_eq!(matches, [true, false]);
    }

    #[test]
    fn an_envelope_is_valid_only_with_a_courier_bucket_copies_and_a_future_expiry() {
        let valid = [
            envelope(32 + 16, 1, NOW_MIN + 1),
            envelope(2048 + 16, 16, NOW_MIN + 1),
            envelope(4048 + 16, 1, NOW_MIN + 1),
            envelope(33 + 16, 1, NOW_MIN + 1),
            envelope(32, 1, NOW_MIN + 1),
            envelope(32 + 16, 0, NOW_MIN + 1),
            envelope(32 + 16, 1, NOW_MIN),
        ]
        .map(|envelope| envelope.valid(NOW_MIN));

        assert_eq!(valid, [true, true, false, false, false, false, false]);
    }

    #[test]
    fn an_envelope_encodes_its_fields_in_order() {
        let mut bytes = std::vec![];

        envelope(48, 5, 0x0a0b_0c0d).encode(&mut bytes);

        assert_eq!(bytes.len(), ENVELOPE_HEADER + 48);
        assert_eq!(bytes[32..38], [0x0a, 0x0b, 0x0c, 0x0d, 5, 3]);
        assert_eq!(Envelope::decode(&bytes), Some(envelope(48, 5, 0x0a0b_0c0d)));
        assert_eq!(Envelope::decode(&bytes[..36]), None);
    }
}
