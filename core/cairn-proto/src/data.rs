//! DATA frames, padding and CHAT records (spec §7).

use crate::resume::Keys;
use alloc::string::String;
use alloc::vec::Vec;
use cairn_crypto::{CryptoBackend, CryptoError};
use subtle::ConstantTimeEq;
use zeroize::Zeroizing;

const BUCKETS: [usize; 8] = [32, 64, 128, 256, 512, 1024, 2048, 4079];
const DATA_HEADER: u8 = 0x30;
const END: u8 = 0x00;
const CHAT: u8 = 0x01;
/// An all-padding plaintext: I's key confirmation right after S2 (ADR 0022).
pub(crate) const EMPTY: [u8; 32] = [0; 32];
/// A sender closes the session before `ctr` reaches 2^32 (spec §7.1).
pub(crate) const COUNTER_LIMIT: u64 = 1 << 32;

/// The message does not fit one CHAT record in the largest bucket.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct TooLong;

/// Authenticated plaintext the receiver must close the link on.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct Malformed;

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Chat {
    pub(crate) msgno: u32,
    pub(crate) text: String,
}

/// Appends the minimal unsigned LEB128 encoding of `value`.
pub(crate) fn leb128(mut value: u32, output: &mut Vec<u8>) {
    while value >= 0x80 {
        output.push(value as u8 | 0x80);
        value >>= 7;
    }
    output.push(value as u8);
}

/// Decodes a minimal LEB128 value of at most 2^32 − 1 and its length.
pub(crate) fn read_leb128(input: &[u8]) -> Option<(u32, usize)> {
    let mut value = 0u32;
    for (index, byte) in input.iter().take(5).enumerate() {
        if index == 4 && *byte > 0x0f {
            return None;
        }
        value |= u32::from(byte & 0x7f) << (7 * index);
        if byte & 0x80 == 0 {
            return (index == 0 || *byte != 0).then_some((value, index + 1));
        }
    }
    None
}

/// The CHAT plaintext, padded to the smallest bucket that fits (spec §7.2).
pub(crate) fn chat_plaintext(msgno: u32, text: &str) -> Result<Zeroizing<Vec<u8>>, TooLong> {
    if text.len() > BUCKETS[7] {
        return Err(TooLong);
    }
    let mut body = Zeroizing::new(Vec::new());
    leb128(msgno, &mut body);
    body.extend_from_slice(text.as_bytes());
    let length = body.len() as u32;
    let mut plaintext = Zeroizing::new(Vec::with_capacity(BUCKETS[7]));
    plaintext.push(CHAT);
    leb128(length, &mut plaintext);
    plaintext.extend_from_slice(&body);
    let bucket = BUCKETS
        .into_iter()
        .find(|bucket| *bucket >= plaintext.len())
        .ok_or(TooLong)?;
    plaintext.resize(bucket, END);
    Ok(plaintext)
}

/// The CHAT records of an authenticated plaintext. The zero padding after
/// the end marker is checked in constant time over its length.
pub(crate) fn parse(plaintext: &[u8]) -> Result<Vec<Chat>, Malformed> {
    let mut chats = Vec::new();
    let mut rest = plaintext;
    while let Some((&kind, after)) = rest.split_first() {
        if kind == END {
            return if bool::from(padding_is_zero(after)) {
                Ok(chats)
            } else {
                Err(Malformed)
            };
        }
        if kind != CHAT {
            return Err(Malformed);
        }
        let (length, size) = read_leb128(after).ok_or(Malformed)?;
        let after = &after[size..];
        let body = after.get(..length as usize).ok_or(Malformed)?;
        let (msgno, size) = read_leb128(body).ok_or(Malformed)?;
        if msgno == 0 {
            return Err(Malformed);
        }
        let text = core::str::from_utf8(&body[size..]).map_err(|_| Malformed)?;
        chats.push(Chat {
            msgno,
            text: text.into(),
        });
        rest = &after[body.len()..];
    }
    Ok(chats)
}

/// Whether `padding` is all zero, in constant time over its length.
pub(crate) fn padding_is_zero(padding: &[u8]) -> subtle::Choice {
    padding.iter().fold(0u8, |acc, byte| acc | byte).ct_eq(&0)
}

/// The keys and counters of one established session (spec §7.1).
pub(crate) struct Session {
    send_key: Zeroizing<[u8; 32]>,
    receive_key: Zeroizing<[u8; 32]>,
    /// `dir` of frames this side sends: 0 for I→R, 1 for R→I.
    send_dir: u8,
    send_ctr: u64,
    receive_ctr: u64,
}

impl Session {
    pub(crate) fn new(keys: &Keys, initiator: bool) -> Self {
        let (send_key, receive_key, send_dir) = if initiator {
            (&keys.i_to_r, &keys.r_to_i, 0)
        } else {
            (&keys.r_to_i, &keys.i_to_r, 1)
        };
        Self {
            send_key: send_key.clone(),
            receive_key: receive_key.clone(),
            send_dir,
            send_ctr: 0,
            receive_ctr: 0,
        }
    }

    fn nonce(dir: u8, ctr: u64) -> [u8; 12] {
        let mut nonce = [0; 12];
        nonce[0] = dir << 7;
        nonce[4..].copy_from_slice(&ctr.to_be_bytes());
        nonce
    }

    /// `DATA = hdr ‖ Seal(SK_dir, nonce, hdr, plaintext)`, or `None` once the
    /// send counter reached 2^32 and the session must close.
    pub(crate) fn seal<B: CryptoBackend>(
        &mut self,
        plaintext: &[u8],
    ) -> Result<Option<Vec<u8>>, CryptoError> {
        if self.send_ctr >= COUNTER_LIMIT {
            return Ok(None);
        }
        let nonce = Self::nonce(self.send_dir, self.send_ctr);
        let sealed = B::aes256gcm_seal(&self.send_key, &nonce, &[DATA_HEADER], plaintext)?;
        self.send_ctr += 1;
        let mut frame = Vec::with_capacity(1 + sealed.len());
        frame.push(DATA_HEADER);
        frame.extend_from_slice(&sealed);
        Ok(Some(frame))
    }

    #[cfg(test)]
    pub(crate) fn exhaust(&mut self) {
        self.send_ctr = COUNTER_LIMIT;
    }

    /// Opens the next DATA frame from the peer, or `None` if it is not a
    /// DATA frame or does not authenticate: the peer's fault.
    pub(crate) fn open<B: CryptoBackend>(
        &mut self,
        frame: &[u8],
    ) -> Result<Option<Zeroizing<Vec<u8>>>, CryptoError> {
        let Some((&DATA_HEADER, sealed)) = frame.split_first() else {
            return Ok(None);
        };
        let nonce = Self::nonce(self.send_dir ^ 1, self.receive_ctr);
        match B::aes256gcm_open(&self.receive_key, &nonce, &[DATA_HEADER], sealed) {
            Ok(plaintext) => {
                self.receive_ctr += 1;
                Ok(Some(plaintext))
            }
            Err(error) => peer_fault(error).map(|()| None),
        }
    }
}

/// `Ok` for a tag failure, which is the peer's; any other error is local.
fn peer_fault(error: CryptoError) -> Result<(), CryptoError> {
    match error {
        CryptoError::AuthenticationFailed => Ok(()),
        local => Err(local),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use cairn_crypto::Reference;

    fn encoded(value: u32) -> std::vec::Vec<u8> {
        let mut output = std::vec::Vec::new();
        leb128(value, &mut output);
        output
    }

    fn keys() -> Keys {
        Keys {
            i_to_r: Zeroizing::new([1; 32]),
            r_to_i: Zeroizing::new([2; 32]),
            next_ck: Zeroizing::new([3; 32]),
        }
    }

    fn nonce(dir: u8, ctr: u64) -> [u8; 12] {
        let mut nonce = [0; 12];
        nonce[0] = dir << 7;
        nonce[4..].copy_from_slice(&ctr.to_be_bytes());
        nonce
    }

    #[test]
    fn leb128_round_trips_minimal_encodings() {
        let values = [0, 127, 128, 300, u32::MAX];

        let encodings = values.map(encoded);

        assert_eq!(
            encodings,
            [
                std::vec![0x00],
                std::vec![0x7f],
                std::vec![0x80, 0x01],
                std::vec![0xac, 0x02],
                std::vec![0xff, 0xff, 0xff, 0xff, 0x0f],
            ]
        );
        for (value, encoding) in values.iter().zip(&encodings) {
            assert_eq!(read_leb128(encoding), Some((*value, encoding.len())));
        }
    }

    #[test]
    fn leb128_rejects_non_minimal_oversized_and_truncated_input() {
        let inputs: [&[u8]; 5] = [
            &[0x80, 0x00],
            &[0xff, 0xff, 0xff, 0xff, 0x10],
            &[0xff, 0xff, 0xff, 0xff, 0x8f, 0x00],
            &[0x80],
            &[],
        ];

        let decoded = inputs.map(read_leb128);

        assert_eq!(decoded, [None; 5]);
    }

    #[test]
    fn a_chat_is_padded_to_the_smallest_bucket() {
        let plaintext = chat_plaintext(1, "hi").unwrap();

        assert_eq!(plaintext.len(), 32);
        assert_eq!(plaintext[..5], [0x01, 0x03, 0x01, b'h', b'i']);
        assert!(plaintext[5..].iter().all(|byte| *byte == 0));
    }

    #[test]
    fn a_record_that_fills_a_bucket_needs_no_end_marker() {
        let exact = "x".repeat(29);

        let sizes = [&exact[..], &std::format!("{exact}x")]
            .map(|text| chat_plaintext(1, text).unwrap().len());

        assert_eq!(sizes, [32, 64]);
    }

    #[test]
    fn the_largest_chat_fills_the_4079_byte_bucket() {
        let largest = "x".repeat(4075);

        let results = (
            chat_plaintext(1, &largest).unwrap().len(),
            chat_plaintext(1, &std::format!("{largest}x")).err(),
            chat_plaintext(1, &"x".repeat(5000)).err(),
        );

        assert_eq!(results, (4079, Some(TooLong), Some(TooLong)));
    }

    #[test]
    fn chats_round_trip_through_parse() {
        let mut plaintext = chat_plaintext(300, "héllo").unwrap().to_vec();
        plaintext.truncate(10);
        plaintext.extend_from_slice(&[0x01, 0x02, 0x05, b'!', 0x00, 0x00]);

        let chats = parse(&plaintext).unwrap();

        assert_eq!(
            chats,
            [
                Chat {
                    msgno: 300,
                    text: "héllo".into()
                },
                Chat {
                    msgno: 5,
                    text: "!".into()
                },
            ]
        );
    }

    #[test]
    fn bad_plaintexts_are_malformed() {
        let plaintexts: [&[u8]; 8] = [
            &[0x02, 0x01, 0x01],
            &[0x0e, 0x00],
            &[0x01, 0x05, 0x01, b'a'],
            &[0x01, 0x02, 0x01, b'a', 0x00, 0x00, 0x01],
            &[0x01, 0x02, 0x00, b'a'],
            &[0x01, 0x02, 0x01, 0xff],
            &[0x01, 0x81, 0x00],
            &[0x01, 0x01, 0x80],
        ];

        let results = plaintexts.map(|plaintext| parse(plaintext).err());

        assert_eq!(results, [Some(Malformed); 8]);
    }

    #[test]
    fn an_all_zero_or_empty_plaintext_holds_no_chats() {
        let parsed = [parse(&[0; 32]), parse(&[])];

        assert_eq!(parsed, [Ok(std::vec![]), Ok(std::vec![])]);
    }

    #[test]
    fn data_frames_use_the_direction_and_counter_nonce() {
        let mut initiator = Session::new(&keys(), true);
        let mut responder = Session::new(&keys(), false);

        let frames = [
            initiator.seal::<Reference>(b"one").unwrap().unwrap(),
            initiator.seal::<Reference>(b"two").unwrap().unwrap(),
            responder.seal::<Reference>(b"back").unwrap().unwrap(),
        ];

        let expected = [
            (&[1; 32], nonce(0, 0), b"one".as_slice()),
            (&[1; 32], nonce(0, 1), b"two"),
            (&[2; 32], nonce(1, 0), b"back"),
        ]
        .map(|(key, nonce, plaintext)| {
            let mut frame = std::vec![0x30];
            frame.extend(Reference::aes256gcm_seal(key, &nonce, &[0x30], plaintext).unwrap());
            frame
        });
        assert_eq!(frames, expected);
        assert_eq!(
            &responder.open::<Reference>(&frames[0]).unwrap().unwrap()[..],
            b"one"
        );
        assert_eq!(
            &responder.open::<Reference>(&frames[1]).unwrap().unwrap()[..],
            b"two"
        );
        assert_eq!(
            &initiator.open::<Reference>(&frames[2]).unwrap().unwrap()[..],
            b"back"
        );
    }

    #[test]
    fn replayed_reflected_or_foreign_frames_are_rejected() {
        let mut initiator = Session::new(&keys(), true);
        let mut responder = Session::new(&keys(), false);
        let frame = initiator.seal::<Reference>(b"one").unwrap().unwrap();
        responder.open::<Reference>(&frame).unwrap().unwrap();
        let mut renamed = frame.clone();
        renamed[0] = 0x31;

        let results = [
            responder.open::<Reference>(&frame),
            initiator.open::<Reference>(&frame),
            Session::new(&keys(), false).open::<Reference>(&renamed),
            Session::new(&keys(), false).open::<Reference>(&[]),
        ];

        assert_eq!(results.map(Result::unwrap), [None, None, None, None]);
    }

    #[test]
    fn only_an_authentication_failure_is_the_peers_fault() {
        let errors = [
            CryptoError::AuthenticationFailed,
            CryptoError::BackendFailure,
        ];

        let classified = errors.map(peer_fault);

        assert_eq!(classified, [Ok(()), Err(CryptoError::BackendFailure)]);
    }

    #[test]
    fn a_session_stops_sealing_at_the_counter_limit() {
        let mut session = Session::new(&keys(), true);
        session.send_ctr = COUNTER_LIMIT - 1;

        let results = [
            session
                .seal::<Reference>(b"last")
                .map(|frame| frame.is_some()),
            session
                .seal::<Reference>(b"over")
                .map(|frame| frame.is_some()),
        ];

        assert_eq!(results, [Ok(true), Ok(false)]);
    }
}
