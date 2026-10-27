//! Entry points into secret-dependent checks for the `core/ct` Memcheck
//! harness and the `core/fuzz` targets (ADR 0022). Behind the hidden,
//! non-default `probes` feature; not part of the stable API.
//!
//! Every verdict is the branch-free `Choice` the protocol declassifies, as
//! `0` or `1`, so a harness can check it still carries the taint of a secret
//! input.

#![allow(clippy::missing_errors_doc, clippy::missing_panics_doc)]

use crate::beacon::{self, DayKey};
use crate::epoch::PairingRole;
use crate::resume::{self, Chain};
use alloc::string::String;
use alloc::vec::Vec;
use cairn_crypto::{CryptoBackend, CryptoError};
use zeroize::Zeroizing;

/// A Resume chain key candidate `CK_n` and I's pairing role.
#[derive(Clone, Copy, Debug)]
pub struct Candidate {
    pub pair_id: [u8; 16],
    pub n: u64,
    pub ck: [u8; 32],
    pub initiator: PairingRole,
}

impl Candidate {
    fn chain(&self) -> Chain<'_> {
        Chain {
            pair_id: &self.pair_id,
            n: self.n,
            ck: &self.ck,
        }
    }
}

fn day_key(day: u32, key: &[u8; 32]) -> DayKey {
    DayKey {
        day,
        key: Zeroizing::new(*key),
    }
}

/// The beacon of the key `BK_day` in `window`.
pub fn beacon<B: CryptoBackend>(
    day: u32,
    key: &[u8; 32],
    window: u64,
) -> Result<[u8; 8], CryptoError> {
    day_key(day, key).beacon::<B>(window)
}

/// The verdict and index of the first `(day, BK_day)` key whose beacon in a
/// window around `unix_s` equals `read`.
pub fn beacon_match<B: CryptoBackend>(
    keys: &[(u32, [u8; 32])],
    unix_s: u64,
    read: &[u8; 8],
) -> Result<(u8, u64), CryptoError> {
    let keys: Vec<DayKey> = keys.iter().map(|(day, key)| day_key(*day, key)).collect();
    let (hit, found) = beacon::matching::<B>(&keys, unix_s, read)?;
    Ok((hit.unwrap_u8(), found))
}

/// I's Resume pseudonym for `attempt`.
pub fn pseudonym<B: CryptoBackend>(
    candidate: &Candidate,
    attempt: u8,
) -> Result<[u8; 8], CryptoError> {
    resume::pseudonym::<B>(&candidate.chain(), candidate.initiator, attempt)
}

/// The verdict and index of the first candidate whose pseudonym for any
/// attempt equals `read`.
pub fn pseudonym_match<B: CryptoBackend>(
    candidates: &[Candidate],
    read: &[u8; 8],
) -> Result<(u8, u64), CryptoError> {
    let chains = candidates
        .iter()
        .map(|candidate| (candidate.chain(), candidate.initiator));
    let (hit, found) = resume::matching::<B>(chains, read)?;
    Ok((hit.unwrap_u8(), found))
}

/// A genuine S1 and R's S2 for it on `candidate`.
pub fn resume<B: CryptoBackend>(candidate: &Candidate, attempt: u8) -> ([u8; 57], [u8; 49]) {
    let chain = candidate.chain();
    let (_, s1) = resume::Initiator::start::<B>(&chain, candidate.initiator, attempt)
        .expect("the backend builds S1");
    let (_, s2) =
        resume::respond::<B>(&chain, candidate.initiator, &s1).expect("R answers a genuine S1");
    (s1, s2)
}

/// Whether the MAC of `s1` verifies under `candidate`.
pub fn s1_authentic<B: CryptoBackend>(
    candidate: &Candidate,
    s1: &[u8; 57],
) -> Result<u8, CryptoError> {
    Ok(resume::s1_confirmed::<B>(&candidate.chain(), candidate.initiator, s1)?.unwrap_u8())
}

/// Whether the confirmation of `s2` answers `s1` under `candidate`.
pub fn s2_authentic<B: CryptoBackend>(
    candidate: &Candidate,
    s1: &[u8; 57],
    s2: &[u8; 49],
) -> Result<u8, CryptoError> {
    let chain = candidate.chain();
    let (confirmed, _) = resume::s2_confirmed::<B>(chain.ck, &resume::ctx(&chain), s1, s2)?;
    Ok(confirmed.unwrap_u8())
}

/// Whether a P3/P4 confirmation equals the expected one.
pub fn card_confirmed(confirm: &[u8; 16], expected: &[u8; 16]) -> u8 {
    crate::pairing::confirmed(confirm, expected).unwrap_u8()
}

/// Whether the padding after a DATA end marker is all zero.
pub fn padding_is_zero(padding: &[u8]) -> u8 {
    crate::data::padding_is_zero(padding).unwrap_u8()
}

/// The padded CHAT plaintext, or `None` for a message too long.
pub fn chat_plaintext(msgno: u32, text: &str) -> Option<Vec<u8>> {
    let chat = crate::data::Record::Chat(crate::data::Chat {
        msgno,
        text: text.into(),
    });
    let plaintext = crate::data::plaintext(&[chat]).ok()?;
    Some(plaintext.to_vec())
}

/// The `(msgno, text)` CHAT records of a plaintext, or `None` if malformed.
/// Other record types are skipped.
pub fn parse_records(plaintext: &[u8]) -> Option<Vec<(u32, String)>> {
    let records = crate::data::parse(plaintext).ok()?;
    Some(
        records
            .into_iter()
            .filter_map(|record| match record {
                crate::data::Record::Chat(chat) => Some((chat.msgno, chat.text)),
                _ => None,
            })
            .collect(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use cairn_crypto::Reference;

    const NOW: u64 = 1_800_000_000;

    fn candidate(byte: u8, initiator: PairingRole) -> Candidate {
        Candidate {
            pair_id: [byte; 16],
            n: u64::from(byte),
            ck: [byte ^ 0x5a; 32],
            initiator,
        }
    }

    #[test]
    fn a_beacon_match_reports_the_first_key_beaconing_in_the_next_window() {
        let today = crate::beacon::day(NOW);
        let keys = [(today, [1; 32]), (today - 3, [2; 32]), (today - 3, [2; 32])];
        let read = beacon::<Reference>(today - 3, &[2; 32], NOW / 300 + 1).unwrap();

        let found = beacon_match::<Reference>(&keys, NOW, &read).unwrap();

        assert_eq!(found, (1, 1));
    }

    #[test]
    fn a_beacon_from_no_key_is_no_match() {
        let today = crate::beacon::day(NOW);
        let keys = [(today, [1; 32])];
        let read = beacon::<Reference>(today, &[1; 32], NOW / 300 + 2).unwrap();

        let found = beacon_match::<Reference>(&keys, NOW, &read).unwrap();

        assert_eq!(found.0, 0);
    }

    #[test]
    fn a_pseudonym_match_reports_the_candidate_of_any_attempt() {
        let candidates = [candidate(1, PairingRole::A), candidate(2, PairingRole::B)];
        let read = pseudonym::<Reference>(&candidates[1], 3).unwrap();

        let found = pseudonym_match::<Reference>(&candidates, &read).unwrap();

        assert_eq!(found, (1, 1));
    }

    #[test]
    fn a_pseudonym_from_no_candidate_is_no_match() {
        let candidates = [candidate(1, PairingRole::A)];
        let read = pseudonym::<Reference>(&candidate(1, PairingRole::B), 0).unwrap();

        let found = pseudonym_match::<Reference>(&candidates, &read).unwrap();

        assert_eq!(found.0, 0);
    }

    #[test]
    fn a_genuine_resume_authenticates_both_ways() {
        let candidate = candidate(7, PairingRole::B);
        let (s1, s2) = resume::<Reference>(&candidate, 1);

        let verdicts = (
            s1_authentic::<Reference>(&candidate, &s1).unwrap(),
            s2_authentic::<Reference>(&candidate, &s1, &s2).unwrap(),
        );

        assert_eq!(verdicts, (1, 1));
    }

    #[test]
    fn a_flipped_mac_bit_fails_either_resume_message() {
        let candidate = candidate(7, PairingRole::B);
        let (mut s1, mut s2) = resume::<Reference>(&candidate, 0);
        let (genuine_s1, _) = (s1, s2);
        s1[56] ^= 1;
        s2[48] ^= 1;

        let verdicts = (
            s1_authentic::<Reference>(&candidate, &s1).unwrap(),
            s2_authentic::<Reference>(&candidate, &genuine_s1, &s2).unwrap(),
        );

        assert_eq!(verdicts, (0, 0));
    }

    #[test]
    fn a_card_confirmation_must_equal_the_expected_one() {
        let verdicts = (
            card_confirmed(&[9; 16], &[9; 16]),
            card_confirmed(&[9; 16], &[8; 16]),
        );

        assert_eq!(verdicts, (1, 0));
    }

    #[test]
    fn padding_must_be_all_zero() {
        let verdicts = (
            padding_is_zero(&[0; 31]),
            padding_is_zero(&[0, 0, 0x80, 0]),
            padding_is_zero(&[]),
        );

        assert_eq!(verdicts, (1, 0, 1));
    }

    #[test]
    fn a_chat_plaintext_parses_back_to_its_record() {
        let plaintext = chat_plaintext(300, "héllo").unwrap();

        let records = parse_records(&plaintext);

        assert_eq!(
            (plaintext.len(), records),
            (32, Some(vec![(300, "héllo".into())]))
        );
    }

    #[test]
    fn only_chat_records_are_returned() {
        let plaintext = crate::data::plaintext(&[
            crate::data::Record::Ack(4),
            crate::data::Record::Chat(crate::data::Chat {
                msgno: 5,
                text: "hi".into(),
            }),
        ])
        .unwrap();

        let records = parse_records(&plaintext);

        assert_eq!(records, Some(vec![(5, "hi".into())]));
    }

    #[test]
    fn an_oversized_message_or_malformed_plaintext_is_none() {
        let outcomes = (chat_plaintext(1, &"x".repeat(4080)), parse_records(&[0x02]));

        assert_eq!(outcomes, (None, None));
    }
}
