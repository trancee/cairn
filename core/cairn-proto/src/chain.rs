//! Message-key chains, skipped keys and QUEUED bodies (spec §8, ADR 0034).

use crate::data::{Malformed, TooLong, leb128, padding_is_zero, read_leb128};
use crate::kdf::kdf;
use alloc::string::String;
use alloc::vec::Vec;
use cairn_crypto::{CryptoBackend, CryptoError};
use zeroize::Zeroizing;

pub(crate) const INNER_BUCKETS: [usize; 8] = [32, 64, 128, 256, 512, 1024, 2048, 4048];
const ZERO_NONCE: [u8; 12] = [0; 12];
pub(crate) const TAG_LEN: usize = 16;
/// Skipped keys a receiver holds per contact (spec §8).
pub(crate) const MAX_SKIPPED: usize = 500;
/// How long a skipped key or a superseded receive chain is kept (spec §8, OI-38).
pub(crate) const RETENTION_S: u64 = 7 * 24 * 60 * 60;

/// The direction of a message chain, named after the sender's Resume role.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub(crate) enum Dir {
    I,
    R,
}

impl Dir {
    /// The other side's direction in the same Resume.
    pub(crate) fn peer(self) -> Self {
        match self {
            Self::I => Self::R,
            Self::R => Self::I,
        }
    }

    /// The label byte used in route tags and in persisted rows: `I` or `R`.
    pub(crate) fn label(self) -> u8 {
        match self {
            Self::I => b'I',
            Self::R => b'R',
        }
    }
}

/// `MC_dir,0 = KDF(MS_{n+1}, "", "chain " ‖ dir, "", 32)`.
pub(crate) fn seed<B: CryptoBackend>(
    msg_seed: &[u8; 32],
    dir: Dir,
) -> Result<Zeroizing<[u8; 32]>, CryptoError> {
    let label: &[u8] = match dir {
        Dir::I => b"chain I",
        Dir::R => b"chain R",
    };
    kdf::<B, 32>(msg_seed, &[], label, &[])
}

/// `inner = LEB128(msgno) ‖ LEB128(len(text)) ‖ text`, zero-padded to the
/// smallest inner bucket (spec §8, OI-37).
pub(crate) fn inner(msgno: u32, text: &str) -> Result<Zeroizing<Vec<u8>>, TooLong> {
    let length = u32::try_from(text.len()).map_err(|_| TooLong)?;
    let mut plaintext = Zeroizing::new(Vec::with_capacity(INNER_BUCKETS[7]));
    leb128(msgno, &mut plaintext);
    leb128(length, &mut plaintext);
    plaintext.extend_from_slice(text.as_bytes());
    let bucket = INNER_BUCKETS
        .into_iter()
        .find(|bucket| *bucket >= plaintext.len())
        .ok_or(TooLong)?;
    plaintext.resize(bucket, 0);
    Ok(plaintext)
}

/// The `msgno` and text of an opened inner plaintext. The padding is checked
/// in constant time over its length.
pub(crate) fn parse_inner(inner: &[u8]) -> Result<(u32, String), Malformed> {
    if !INNER_BUCKETS.contains(&inner.len()) {
        return Err(Malformed);
    }
    let (msgno, size) = read_leb128(inner).ok_or(Malformed)?;
    if msgno == 0 {
        return Err(Malformed);
    }
    let rest = &inner[size..];
    let (length, size) = read_leb128(rest).ok_or(Malformed)?;
    let rest = &rest[size..];
    let text = rest.get(..length as usize).ok_or(Malformed)?;
    if !bool::from(padding_is_zero(&rest[text.len()..])) {
        return Err(Malformed);
    }
    let text = core::str::from_utf8(text).map_err(|_| Malformed)?;
    Ok((msgno, text.into()))
}

/// The AAD of a queued message: `u8(gen) ‖ LEB128(idx)`.
fn aad(gen_: u8, idx: u32) -> Vec<u8> {
    let mut aad = Vec::with_capacity(6);
    aad.push(gen_);
    leb128(idx, &mut aad);
    aad
}

type Key = Zeroizing<[u8; 32]>;

/// `mk_i` and `MC_{i+1}` from `MC_i`.
fn step<B: CryptoBackend>(chain: &[u8; 32]) -> Result<(Key, Key), CryptoError> {
    Ok((
        kdf::<B, 32>(chain, &[], b"mk", &[])?,
        kdf::<B, 32>(chain, &[], b"next", &[])?,
    ))
}

/// The opened plaintext, or `None` if `ct` does not authenticate.
fn open_with<B: CryptoBackend>(
    key: &[u8; 32],
    aad: &[u8],
    ct: &[u8],
) -> Result<Option<Zeroizing<Vec<u8>>>, CryptoError> {
    match B::aes256gcm_open(key, &ZERO_NONCE, aad, ct) {
        Ok(plaintext) => Ok(Some(plaintext)),
        Err(error) => crate::data::peer_fault(error).map(|()| None),
    }
}

/// A sealed queued message: the QUEUED body is `gen ‖ LEB128(idx) ‖ ct`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Queued {
    pub(crate) gen_: u8,
    pub(crate) idx: u32,
    pub(crate) ct: Vec<u8>,
}

impl Queued {
    pub(crate) fn encode(&self) -> Vec<u8> {
        let mut body = aad(self.gen_, self.idx);
        body.extend_from_slice(&self.ct);
        body
    }

    pub(crate) fn decode(body: &[u8]) -> Result<Self, Malformed> {
        let (&gen_, rest) = body.split_first().ok_or(Malformed)?;
        let (idx, size) = read_leb128(rest).ok_or(Malformed)?;
        let ct = &rest[size..];
        let sealed = ct
            .len()
            .checked_sub(TAG_LEN)
            .is_some_and(|inner| INNER_BUCKETS.contains(&inner));
        if !sealed {
            return Err(Malformed);
        }
        Ok(Self {
            gen_,
            idx,
            ct: ct.into(),
        })
    }
}

/// The sending half of a contact's message layer.
#[derive(Clone)]
pub(crate) struct SendChain {
    pub(crate) gen_: u8,
    pub(crate) dir: Dir,
    pub(crate) idx: u32,
    pub(crate) key: Zeroizing<[u8; 32]>,
}

/// The courier delivery secret `s` of one message (spec §8.1).
pub(crate) type Delivered = Zeroizing<[u8; 16]>;

impl SendChain {
    /// Seals `inner` under `mk_idx` and advances the chain, erasing `mk_idx`
    /// and `MC_idx` once `s` is derived. `None` once the index space is exhausted.
    pub(crate) fn seal<B: CryptoBackend>(
        &mut self,
        inner: &[u8],
    ) -> Result<Option<(Queued, Delivered)>, CryptoError> {
        if self.idx == u32::MAX {
            return Ok(None);
        }
        let (mk, next) = step::<B>(&self.key)?;
        let ct = B::aes256gcm_seal(&mk, &ZERO_NONCE, &aad(self.gen_, self.idx), inner)?;
        let delivered = crate::courier::delivered::<B>(&mk)?;
        let queued = Queued {
            gen_: self.gen_,
            idx: self.idx,
            ct,
        };
        self.key = next;
        self.idx += 1;
        Ok(Some((queued, delivered)))
    }
}

/// One generation's receive chain: `key` is `MC_next`.
#[derive(Clone)]
pub(crate) struct ReceiveChain {
    pub(crate) gen_: u8,
    pub(crate) dir: Dir,
    pub(crate) next: u64,
    pub(crate) key: Zeroizing<[u8; 32]>,
    /// When a newer Resume superseded it, in Unix seconds.
    pub(crate) superseded_s: Option<u64>,
}

#[derive(Clone)]
pub(crate) struct Skipped {
    pub(crate) gen_: u8,
    pub(crate) dir: Dir,
    pub(crate) idx: u32,
    pub(crate) key: Zeroizing<[u8; 32]>,
    pub(crate) created_s: u64,
}

/// What became of a QUEUED body.
#[derive(Debug, PartialEq, Eq)]
pub(crate) enum Opened {
    Message(Zeroizing<Vec<u8>>),
    /// Its key is gone: consumed, expired or never derivable. A duplicate.
    Unknown,
}

/// The receiving half of a contact's message layer.
#[derive(Clone, Default)]
pub(crate) struct Receiver {
    pub(crate) chains: Vec<ReceiveChain>,
    pub(crate) skipped: Vec<Skipped>,
}

impl Receiver {
    /// Installs a new generation. The live chain becomes superseded at
    /// `now_s`; a chain with the same `gen` is deleted with its skipped keys
    /// (OI-5).
    pub(crate) fn reseed(&mut self, gen_: u8, dir: Dir, key: Zeroizing<[u8; 32]>, now_s: u64) {
        self.chains.retain(|chain| chain.gen_ != gen_);
        self.skipped.retain(|skipped| skipped.gen_ != gen_);
        for chain in &mut self.chains {
            chain.superseded_s.get_or_insert(now_s);
        }
        self.chains.push(ReceiveChain {
            gen_,
            dir,
            next: 0,
            key,
            superseded_s: None,
        });
    }

    /// Deletes superseded chains and skipped keys older than 7 days.
    pub(crate) fn prune(&mut self, now_s: u64) {
        self.chains.retain(|chain| {
            chain
                .superseded_s
                .is_none_or(|superseded| now_s < superseded.saturating_add(RETENTION_S))
        });
        self.skipped
            .retain(|skipped| now_s < skipped.created_s.saturating_add(RETENTION_S));
    }

    /// Opens a QUEUED body. Its key is consumed only if it opens; a body
    /// that fails to open, or that would skip past the bound, is malformed.
    pub(crate) fn open<B: CryptoBackend>(
        &mut self,
        queued: &Queued,
        now_s: u64,
    ) -> Result<Result<Opened, Malformed>, CryptoError> {
        Ok(self.open_delivered::<B>(queued, now_s)?.map(|opened| {
            opened.map_or(Opened::Unknown, |(plaintext, _)| Opened::Message(plaintext))
        }))
    }

    /// As [`Self::open`], with the sender's delivery secret `s` of an opened
    /// message; `None` is [`Opened::Unknown`].
    #[allow(clippy::type_complexity)]
    pub(crate) fn open_delivered<B: CryptoBackend>(
        &mut self,
        queued: &Queued,
        now_s: u64,
    ) -> Result<Result<Option<(Zeroizing<Vec<u8>>, Delivered)>, Malformed>, CryptoError> {
        let aad = aad(queued.gen_, queued.idx);
        let held = self
            .skipped
            .iter()
            .position(|skipped| skipped.gen_ == queued.gen_ && skipped.idx == queued.idx);
        if let Some(index) = held {
            let key = &self.skipped[index].key;
            return Ok(match open_with::<B>(key, &aad, &queued.ct)? {
                Some(plaintext) => {
                    let delivered = crate::courier::delivered::<B>(key)?;
                    self.skipped.swap_remove(index);
                    Ok(Some((plaintext, delivered)))
                }
                None => Err(Malformed),
            });
        }
        let idx = u64::from(queued.idx);
        let Some(chain) = self
            .chains
            .iter_mut()
            .find(|chain| chain.gen_ == queued.gen_ && idx >= chain.next)
        else {
            return Ok(Ok(None));
        };
        let gap = (idx - chain.next) as usize;
        if self.skipped.len() + gap > MAX_SKIPPED {
            return Ok(Err(Malformed));
        }
        let mut key = chain.key.clone();
        let mut skipped = Vec::with_capacity(gap);
        for skipped_idx in chain.next..idx {
            let (mk, next) = step::<B>(&key)?;
            skipped.push(Skipped {
                gen_: queued.gen_,
                dir: chain.dir,
                idx: skipped_idx as u32,
                key: mk,
                created_s: now_s,
            });
            key = next;
        }
        let (mk, next) = step::<B>(&key)?;
        let Some(plaintext) = open_with::<B>(&mk, &aad, &queued.ct)? else {
            return Ok(Err(Malformed));
        };
        let delivered = crate::courier::delivered::<B>(&mk)?;
        chain.key = next;
        chain.next = idx + 1;
        self.skipped.extend(skipped);
        Ok(Ok(Some((plaintext, delivered))))
    }

    /// The `(dir, gen, idx)` of every message key this receiver could still
    /// derive: skipped keys, then the next indices of the newest chains, at
    /// most [`MAX_SKIPPED`] in total (spec §8.1).
    pub(crate) fn window(&self) -> Vec<(Dir, u8, u32)> {
        let mut window: Vec<(Dir, u8, u32)> = self
            .skipped
            .iter()
            .map(|skipped| (skipped.dir, skipped.gen_, skipped.idx))
            .collect();
        let reach = (MAX_SKIPPED - self.skipped.len()) as u64;
        for chain in self.chains.iter().rev() {
            let last = (chain.next + reach).min(u64::from(u32::MAX));
            for idx in chain.next..=last {
                if window.len() == MAX_SKIPPED {
                    return window;
                }
                window.push((chain.dir, chain.gen_, idx as u32));
            }
        }
        window
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use cairn_crypto::Reference;

    const NOW: u64 = 1_761_177_600;

    fn chain_key(byte: u8) -> Zeroizing<[u8; 32]> {
        Zeroizing::new([byte; 32])
    }

    fn sender(gen_: u8) -> SendChain {
        SendChain {
            gen_,
            dir: Dir::R,
            idx: 0,
            key: chain_key(gen_),
        }
    }

    fn advanced(gen_: u8, idx: u32) -> SendChain {
        let mut chain = sender(gen_);
        for _ in 0..idx {
            chain.seal::<Reference>(&[0; 32]).unwrap();
        }
        chain
    }

    fn receiver(gen_: u8) -> Receiver {
        let mut receiver = Receiver::default();
        receiver.reseed(gen_, Dir::R, chain_key(gen_), NOW);
        receiver
    }

    fn sealed(chain: &mut SendChain, msgno: u32) -> Queued {
        chain
            .seal::<Reference>(&inner(msgno, "hi").unwrap())
            .unwrap()
            .unwrap()
            .0
    }

    fn opened(receiver: &mut Receiver, queued: &Queued, now_s: u64) -> Result<Opened, Malformed> {
        receiver.open::<Reference>(queued, now_s).unwrap()
    }

    fn message(msgno: u32) -> Result<Opened, Malformed> {
        Ok(Opened::Message(inner(msgno, "hi").unwrap()))
    }

    #[test]
    fn chain_seeds_use_the_direction_label() {
        let seed_bytes = [5; 32];

        let seeds = [Dir::I, Dir::R].map(|dir| *seed::<Reference>(&seed_bytes, dir).unwrap());

        assert_eq!(
            seeds,
            [
                *kdf::<Reference, 32>(&seed_bytes, &[], b"chain I", &[]).unwrap(),
                *kdf::<Reference, 32>(&seed_bytes, &[], b"chain R", &[]).unwrap(),
            ]
        );
    }

    #[test]
    fn inner_carries_the_text_length_and_pads_to_a_bucket() {
        let plaintext = inner(300, "hi").unwrap();

        assert_eq!(plaintext.len(), 32);
        assert_eq!(plaintext[..5], [0xac, 0x02, 0x02, b'h', b'i']);
        assert!(plaintext[5..].iter().all(|byte| *byte == 0));
    }

    #[test]
    fn the_largest_inner_fills_the_4048_byte_bucket() {
        let largest = "x".repeat(4048 - 5 - 2);

        let results = (
            inner(u32::MAX, &largest).unwrap().len(),
            inner(u32::MAX, &std::format!("{largest}x")).err(),
            inner(1, &"x".repeat(17_000)).err(),
        );

        assert_eq!(results, (4048, Some(TooLong), Some(TooLong)));
    }

    #[test]
    fn inner_round_trips() {
        let plaintext = inner(7, "héllo").unwrap();

        let parsed = parse_inner(&plaintext);

        assert_eq!(parsed, Ok((7, "héllo".into())));
    }

    #[test]
    fn bad_inner_plaintexts_are_malformed() {
        let mut nonzero = inner(1, "hi").unwrap().to_vec();
        nonzero[31] = 1;
        let mut wrong_bucket = inner(1, "hi").unwrap().to_vec();
        wrong_bucket.push(0);
        let mut long_text = std::vec![0x01, 0x40];
        long_text.resize(32, 0);
        let mut not_utf8 = std::vec![0x01, 0x01, 0xff];
        not_utf8.resize(32, 0);
        let mut zero_msgno = std::vec![0x00, 0x01, b'a'];
        zero_msgno.resize(32, 0);
        let mut bad_msgno = std::vec![0x80; 31];
        bad_msgno.push(0x80);
        let mut bad_length = std::vec![0x01, 0x80];
        bad_length.resize(2, 0x80);
        bad_length.resize(32, 0x80);
        let inputs = [
            nonzero,
            wrong_bucket,
            long_text,
            not_utf8,
            zero_msgno,
            bad_msgno,
            bad_length,
        ];

        let results = inputs.map(|input| parse_inner(&input).err());

        assert_eq!(results, [Some(Malformed); 7]);
    }

    #[test]
    fn a_queued_body_round_trips_and_rejects_bad_framing() {
        let queued = Queued {
            gen_: 3,
            idx: 200,
            ct: std::vec![9; 48],
        };

        let encoded = queued.encode();

        assert_eq!(encoded[..3], [3, 0xc8, 0x01]);
        assert_eq!(Queued::decode(&encoded), Ok(queued));
        let short = [&[3u8, 0][..], &[9u8; 47][..]].concat();
        let off_bucket = [&[3u8, 0][..], &[9u8; 49][..]].concat();
        let bodies: [&[u8]; 5] = [&[], &[3], &[3, 0x80], &short, &off_bucket];
        assert_eq!(
            bodies.map(|body| Queued::decode(body).err()),
            [Some(Malformed); 5]
        );
    }

    #[test]
    fn sealing_uses_mk_idx_with_the_generation_and_index_as_aad() {
        let mut chain = sender(4);
        let mc_0 = chain_key(4);
        let mk_0 = kdf::<Reference, 32>(&mc_0[..], &[], b"mk", &[]).unwrap();
        let mc_1 = kdf::<Reference, 32>(&mc_0[..], &[], b"next", &[]).unwrap();
        let plaintext = inner(1, "hi").unwrap();

        let (queued, delivered) = chain.seal::<Reference>(&plaintext).unwrap().unwrap();

        assert_eq!((queued.gen_, queued.idx, chain.idx), (4, 0, 1));
        assert_eq!(
            *delivered,
            *crate::courier::delivered::<Reference>(&mk_0).unwrap()
        );
        assert_eq!(
            queued.ct,
            Reference::aes256gcm_seal(&mk_0, &[0; 12], &[4, 0], &plaintext).unwrap()
        );
        assert_eq!(*chain.key, *mc_1);
    }

    #[test]
    fn a_send_chain_stops_at_the_last_index() {
        let mut chain = sender(1);
        chain.idx = u32::MAX;

        let sealed = chain.seal::<Reference>(&[0; 32]).unwrap();

        assert!(sealed.is_none());
    }

    #[test]
    fn messages_open_in_any_order_once() {
        let mut chain = sender(1);
        let queued = [1, 2, 3].map(|msgno| sealed(&mut chain, msgno));
        let mut receiver = receiver(1);

        let results = [2, 0, 1, 0].map(|index| opened(&mut receiver, &queued[index], NOW));

        assert_eq!(
            results,
            [message(3), message(1), message(2), Ok(Opened::Unknown)]
        );
        assert!(receiver.skipped.is_empty());
        assert_eq!(receiver.chains[0].next, 3);
    }

    #[test]
    fn a_body_that_does_not_open_consumes_no_key() {
        let mut chain = sender(1);
        let first = sealed(&mut chain, 1);
        let second = sealed(&mut chain, 2);
        let mut forged = second.clone();
        forged.ct[0] ^= 1;
        let mut receiver = receiver(1);

        let results = [
            opened(&mut receiver, &forged, NOW),
            opened(&mut receiver, &second, NOW),
            opened(&mut receiver, &first, NOW),
        ];

        assert_eq!(results, [Err(Malformed), message(2), message(1)]);
    }

    #[test]
    fn a_tampered_skipped_key_body_is_malformed_and_kept() {
        let mut chain = sender(1);
        let first = sealed(&mut chain, 1);
        let second = sealed(&mut chain, 2);
        let mut receiver = receiver(1);
        opened(&mut receiver, &second, NOW).unwrap();
        let mut forged = first.clone();
        forged.ct[0] ^= 1;

        let results = [
            opened(&mut receiver, &forged, NOW),
            opened(&mut receiver, &first, NOW),
        ];

        assert_eq!(results, [Err(Malformed), message(1)]);
    }

    #[test]
    fn skipping_past_the_bound_is_malformed() {
        let mut chain = sender(1);
        chain.idx = MAX_SKIPPED as u32 + 1;
        let far = sealed(&mut chain, 1);
        let mut receiver = receiver(1);

        let result = opened(&mut receiver, &far, NOW);

        assert_eq!(result, Err(Malformed));
        assert!(receiver.skipped.is_empty());
    }

    #[test]
    fn the_skip_bound_counts_keys_already_held() {
        let mut chain = advanced(1, MAX_SKIPPED as u32 - 1);
        let edge = sealed(&mut chain, 1);
        let next = sealed(&mut chain, 2);
        let mut receiver = receiver(1);

        let results = [
            opened(&mut receiver, &edge, NOW),
            opened(&mut receiver, &next, NOW),
        ];

        assert_eq!(results, [message(1), message(2)]);
        assert_eq!(receiver.skipped.len(), MAX_SKIPPED - 1);
        let mut over = advanced(2, 2);
        let beyond = sealed(&mut over, 3);
        receiver.reseed(2, Dir::R, chain_key(2), NOW);
        assert_eq!(opened(&mut receiver, &beyond, NOW), Err(Malformed));
    }

    #[test]
    fn superseded_generations_stay_open_for_seven_days() {
        let mut old = sender(1);
        let late = sealed(&mut old, 1);
        let later = sealed(&mut old, 2);
        let mut fresh = sender(2);
        let current = sealed(&mut fresh, 3);
        let mut receiver = receiver(1);
        receiver.reseed(2, Dir::R, chain_key(2), NOW + 10);

        let results = [
            opened(&mut receiver, &current, NOW + 10),
            opened(&mut receiver, &late, NOW + 10 + RETENTION_S - 1),
        ];
        receiver.prune(NOW + 10 + RETENTION_S);

        assert_eq!(results, [message(3), message(1)]);
        assert_eq!(opened(&mut receiver, &later, NOW), Ok(Opened::Unknown));
        assert_eq!(receiver.chains.len(), 1);
    }

    #[test]
    fn skipped_keys_age_out_after_seven_days() {
        let mut chain = sender(1);
        let first = sealed(&mut chain, 1);
        let second = sealed(&mut chain, 2);
        let mut receiver = receiver(1);
        opened(&mut receiver, &second, NOW).unwrap();

        receiver.prune(NOW + RETENTION_S - 1);
        let kept = receiver.skipped.len();
        receiver.prune(NOW + RETENTION_S);

        assert_eq!((kept, receiver.skipped.len()), (1, 0));
        assert_eq!(opened(&mut receiver, &first, NOW), Ok(Opened::Unknown));
    }

    #[test]
    fn a_generation_collision_deletes_the_old_chain_and_its_skipped_keys() {
        let mut old = sender(1);
        let first = sealed(&mut old, 1);
        let second = sealed(&mut old, 2);
        let mut receiver = receiver(1);
        opened(&mut receiver, &second, NOW).unwrap();

        receiver.reseed(1, Dir::R, chain_key(9), NOW);

        assert!(receiver.skipped.is_empty());
        assert_eq!(receiver.chains.len(), 1);
        assert_eq!(opened(&mut receiver, &first, NOW), Err(Malformed));
    }

    #[test]
    fn the_receiver_learns_the_senders_delivery_secret_when_a_message_opens() {
        let mut chain = sender(2);
        let (queued, delivered) = chain
            .seal::<Reference>(&inner(1, "hi").unwrap())
            .unwrap()
            .unwrap();
        let mut receiver = receiver(2);

        let opened = receiver.open_delivered::<Reference>(&queued, NOW).unwrap();

        let (plaintext, learned) = opened.unwrap().unwrap();
        assert_eq!(plaintext, inner(1, "hi").unwrap());
        assert_eq!(*learned, *delivered);
        assert!(matches!(
            receiver.open_delivered::<Reference>(&queued, NOW),
            Ok(Ok(None))
        ));
    }

    #[test]
    fn the_window_lists_skipped_keys_then_the_newest_chains_up_to_500() {
        let mut chain = sender(1);
        let queued = [1, 2, 3].map(|msgno| sealed(&mut chain, msgno));
        let mut receiver = receiver(1);
        opened(&mut receiver, &queued[2], NOW).unwrap();
        receiver.reseed(2, Dir::I, chain_key(2), NOW);

        let window = receiver.window();

        assert_eq!(window.len(), MAX_SKIPPED);
        assert_eq!(
            window[..3],
            [(Dir::R, 1, 0), (Dir::R, 1, 1), (Dir::I, 2, 0)]
        );
        assert_eq!(window[MAX_SKIPPED - 1], (Dir::I, 2, 497));
    }

    #[test]
    fn the_window_reaches_older_chains_and_stops_at_the_last_index() {
        let mut receiver = receiver(1);
        receiver.chains[0].next = u64::from(u32::MAX) - 1;
        receiver.reseed(2, Dir::I, chain_key(2), NOW);
        receiver.chains[1].next = u64::from(u32::MAX) + 1;

        let window = receiver.window();

        assert_eq!(window, [(Dir::R, 1, u32::MAX - 1), (Dir::R, 1, u32::MAX)]);
    }
}
