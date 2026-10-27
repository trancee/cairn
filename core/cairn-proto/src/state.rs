//! Durable device state and its version-2 rows (ADR 0034 §1).

use crate::PairingRole;
use crate::card::Card;
use crate::chain::{MAX_SKIPPED, Queued, ReceiveChain, Receiver, SendChain, Skipped};
use crate::core::{ContactId, Verification};
use crate::pairing::Paired;
use alloc::collections::BTreeMap;
use alloc::vec::Vec;
use zeroize::Zeroizing;

pub(crate) const BLOB_VERSION: u32 = 2;
const MODE_TOFU: u8 = 0x03;

/// The sealed-by-the-platform state of a core; it contains secrets.
#[derive(Clone, PartialEq, Eq)]
pub struct Persisted {
    pub blob: Vec<u8>,
    pub version: u32,
}

impl core::fmt::Debug for Persisted {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        formatter
            .debug_struct("Persisted")
            .field("version", &self.version)
            .finish_non_exhaustive()
    }
}

/// One stored contact row (ADR 0034 §1).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContactRow {
    pub contact: ContactId,
    pub state: Persisted,
}

/// One stored queued message (ADR 0034 §1).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QueuedRow {
    pub contact: ContactId,
    pub msgno: u32,
    pub state: Persisted,
}

/// `CK_{n+1}` and `MS_{n+1}` while R awaits I's key confirmation.
#[derive(Clone)]
pub(crate) struct Pending {
    pub(crate) chain_key: Zeroizing<[u8; 32]>,
    pub(crate) msg_seed: Zeroizing<[u8; 32]>,
}

/// A sealed message waiting for the peer's ACK.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Outgoing {
    pub(crate) created_s: u64,
    pub(crate) queued: Queued,
}

/// The message numbers received from, or expired by, the peer.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(crate) struct Received {
    /// The highest number up to which every number is covered; the ACK value.
    pub(crate) contiguous: u32,
    /// Disjoint, non-adjacent inclusive ranges above `contiguous + 1`, ascending.
    pub(crate) above: Vec<(u32, u32)>,
}

impl Received {
    pub(crate) fn contains(&self, msgno: u32) -> bool {
        msgno != 0
            && (msgno <= self.contiguous
                || self
                    .above
                    .iter()
                    .any(|&(from, to)| from <= msgno && msgno <= to))
    }

    /// Whether every number in `from..=to` is covered. Canonical ranges
    /// never touch, so a covered range lies within one of them.
    pub(crate) fn covers(&self, from: u32, to: u32) -> bool {
        to <= self.contiguous
            || self
                .above
                .iter()
                .any(|&(start, end)| start <= from && to <= end)
    }

    /// Covers `from..=to`; returns whether the ACK value moved.
    pub(crate) fn insert(&mut self, from: u32, to: u32) -> bool {
        let (mut from, mut to) = (u64::from(from), u64::from(to));
        let mut kept = Vec::with_capacity(self.above.len() + 1);
        for &(start, end) in &self.above {
            let (start, end) = (u64::from(start), u64::from(end));
            if end + 1 < from || to + 1 < start {
                kept.push((start, end));
            } else {
                from = from.min(start);
                to = to.max(end);
            }
        }
        let before = self.contiguous;
        if from <= u64::from(self.contiguous) + 1 {
            self.contiguous = self.contiguous.max(to as u32);
        } else {
            kept.push((from, to));
        }
        kept.sort_unstable();
        self.above = kept
            .into_iter()
            .map(|(start, end)| (start as u32, end as u32))
            .collect();
        self.contiguous != before
    }
}

pub(crate) struct Contact {
    pub(crate) id: ContactId,
    pub(crate) role: PairingRole,
    pub(crate) verification: Verification,
    pub(crate) pair_id: [u8; 16],
    pub(crate) th: [u8; 48],
    pub(crate) nonce_b: [u8; 16],
    pub(crate) peer: Card,
    pub(crate) door_a_to_b: Zeroizing<[u8; 32]>,
    pub(crate) door_b_to_a: Zeroizing<[u8; 32]>,
    /// Resume index `n` of `chain_key` (spec §6).
    pub(crate) resume_index: u64,
    pub(crate) chain_key: Zeroizing<[u8; 32]>,
    /// The last `msgno` sent to this contact; 0 before the first.
    pub(crate) sent_msgno: u32,
    pub(crate) pending: Option<Pending>,
    /// `None` until the first Resume (ADR 0034 §2).
    pub(crate) send: Option<SendChain>,
    pub(crate) receiver: Receiver,
    /// The peer's highest ACK.
    pub(crate) peer_acked: u32,
    /// The peer's highest READ.
    pub(crate) peer_read: u32,
    /// The highest number the user marked read.
    pub(crate) read_marked: u32,
    pub(crate) received: Received,
    /// Real-time CHATs sent but not acked or re-sealed, ascending.
    pub(crate) unacked: Vec<u32>,
    /// Ranges this side expired, announced until the peer's ACK passes them.
    pub(crate) expired: Vec<(u32, u32)>,
    /// Queued rows, keyed by `msgno`.
    pub(crate) queued: BTreeMap<u32, Outgoing>,
}

impl Contact {
    pub(crate) fn new(id: ContactId, paired: Paired) -> Self {
        let Paired {
            role,
            th,
            nonce_b,
            peer,
            pair_id,
            chain_key,
            door_a_to_b,
            door_b_to_a,
        } = paired;
        Self {
            id,
            role,
            verification: Verification::Unverified,
            pair_id,
            th,
            nonce_b,
            peer,
            door_a_to_b,
            door_b_to_a,
            resume_index: 0,
            chain_key,
            sent_msgno: 0,
            pending: None,
            send: None,
            receiver: Receiver::default(),
            peer_acked: 0,
            peer_read: 0,
            read_marked: 0,
            received: Received::default(),
            unacked: Vec::new(),
            expired: Vec::new(),
            queued: BTreeMap::new(),
        }
    }

    /// The next message number; `None` once 2^32 − 1 has been sent (spec §8).
    pub(crate) fn next_msgno(&self) -> Option<u32> {
        self.sent_msgno.checked_add(1)
    }

    /// The contact row; queued messages are separate rows.
    pub(crate) fn row(&self) -> ContactRow {
        let mut blob = Zeroizing::new(Vec::new());
        blob.push(match self.role {
            PairingRole::A => 0,
            PairingRole::B => 1,
        });
        blob.push(MODE_TOFU);
        blob.push(match self.verification {
            Verification::Unverified => 0,
            Verification::Verified => 1,
            Verification::Compromised => 2,
        });
        blob.extend_from_slice(&self.pair_id);
        blob.extend_from_slice(&self.th);
        blob.extend_from_slice(&self.nonce_b);
        let card = self.peer.encode();
        let card_len = u16::try_from(card.len()).expect("cards are below 64 KiB");
        blob.extend_from_slice(&card_len.to_be_bytes());
        blob.extend_from_slice(&card);
        blob.extend_from_slice(&self.door_a_to_b[..]);
        blob.extend_from_slice(&self.door_b_to_a[..]);
        blob.extend_from_slice(&self.resume_index.to_be_bytes());
        blob.extend_from_slice(&self.chain_key[..]);
        blob.extend_from_slice(&self.sent_msgno.to_be_bytes());
        match &self.pending {
            None => blob.push(0),
            Some(pending) => {
                blob.push(1);
                blob.extend_from_slice(&pending.chain_key[..]);
                blob.extend_from_slice(&pending.msg_seed[..]);
            }
        }
        match &self.send {
            None => blob.push(0),
            Some(chain) => {
                blob.push(1);
                blob.push(chain.gen_);
                blob.extend_from_slice(&chain.idx.to_be_bytes());
                blob.extend_from_slice(&chain.key[..]);
            }
        }
        put_count(self.receiver.chains.len(), &mut blob);
        for chain in &self.receiver.chains {
            blob.push(chain.gen_);
            blob.extend_from_slice(&chain.next.to_be_bytes());
            blob.extend_from_slice(&chain.key[..]);
            match chain.superseded_s {
                None => blob.push(0),
                Some(superseded) => {
                    blob.push(1);
                    blob.extend_from_slice(&superseded.to_be_bytes());
                }
            }
        }
        put_count(self.receiver.skipped.len(), &mut blob);
        for skipped in &self.receiver.skipped {
            blob.push(skipped.gen_);
            blob.extend_from_slice(&skipped.idx.to_be_bytes());
            blob.extend_from_slice(&skipped.key[..]);
            blob.extend_from_slice(&skipped.created_s.to_be_bytes());
        }
        for counter in [
            self.peer_acked,
            self.peer_read,
            self.read_marked,
            self.received.contiguous,
        ] {
            blob.extend_from_slice(&counter.to_be_bytes());
        }
        put_ranges(&self.received.above, &mut blob);
        put_count(self.unacked.len(), &mut blob);
        for msgno in &self.unacked {
            blob.extend_from_slice(&msgno.to_be_bytes());
        }
        put_ranges(&self.expired, &mut blob);
        ContactRow {
            contact: self.id,
            state: persisted(&blob),
        }
    }

    /// The contact of `row`, without its queued messages.
    fn decode(row: &ContactRow) -> Result<Self, InvalidBlob> {
        let mut reader = reader(&row.state)?;
        let role = match reader.byte()? {
            0 => PairingRole::A,
            1 => PairingRole::B,
            _ => return Err(InvalidBlob),
        };
        if reader.byte()? != MODE_TOFU {
            return Err(InvalidBlob);
        }
        let verification = match reader.byte()? {
            0 => Verification::Unverified,
            1 => Verification::Verified,
            2 => Verification::Compromised,
            _ => return Err(InvalidBlob),
        };
        let pair_id = reader.array()?;
        let th = reader.array()?;
        let nonce_b = reader.array()?;
        let card_len = usize::from(u16::from_be_bytes(reader.array()?));
        let peer = Card::decode(reader.take(card_len)?).map_err(|_| InvalidBlob)?;
        let door_a_to_b = reader.key()?;
        let door_b_to_a = reader.key()?;
        let resume_index = reader.u64()?;
        let chain_key = reader.key()?;
        let sent_msgno = reader.u32()?;
        let pending = match reader.flag()? {
            false => None,
            true => Some(Pending {
                chain_key: reader.key()?,
                msg_seed: reader.key()?,
            }),
        };
        let send = match reader.flag()? {
            false => None,
            true => Some(SendChain {
                gen_: reader.byte()?,
                idx: reader.u32()?,
                key: reader.key()?,
            }),
        };
        let mut receiver = Receiver::default();
        for _ in 0..reader.count()? {
            receiver.chains.push(ReceiveChain {
                gen_: reader.byte()?,
                next: reader.u64()?,
                key: reader.key()?,
                superseded_s: match reader.flag()? {
                    false => None,
                    true => Some(reader.u64()?),
                },
            });
        }
        for _ in 0..reader.count()? {
            receiver.skipped.push(Skipped {
                gen_: reader.byte()?,
                idx: reader.u32()?,
                key: reader.key()?,
                created_s: reader.u64()?,
            });
        }
        let peer_acked = reader.u32()?;
        let peer_read = reader.u32()?;
        let read_marked = reader.u32()?;
        let received = Received {
            contiguous: reader.u32()?,
            above: reader.ranges()?,
        };
        let unacked = (0..reader.count()?)
            .map(|_| reader.u32())
            .collect::<Result<Vec<_>, _>>()?;
        let expired = reader.ranges()?;
        reader.end()?;
        let contact = Self {
            id: row.contact,
            role,
            verification,
            pair_id,
            th,
            nonce_b,
            peer,
            door_a_to_b,
            door_b_to_a,
            resume_index,
            chain_key,
            sent_msgno,
            pending,
            send,
            receiver,
            peer_acked,
            peer_read,
            read_marked,
            received,
            unacked,
            expired,
            queued: BTreeMap::new(),
        };
        contact.consistent().then_some(contact).ok_or(InvalidBlob)
    }

    /// Whether the decoded fields are canonical and fit together.
    fn consistent(&self) -> bool {
        let sent = self.sent_msgno;
        let chains = &self.receiver.chains;
        let skipped = &self.receiver.skipped;
        let live = chains
            .iter()
            .filter(|chain| chain.superseded_s.is_none())
            .count();
        let unique_gens = chains
            .iter()
            .enumerate()
            .all(|(index, chain)| chains[..index].iter().all(|other| other.gen_ != chain.gen_));
        let unique_skipped = skipped.iter().enumerate().all(|(index, key)| {
            skipped[..index]
                .iter()
                .all(|other| (other.gen_, other.idx) != (key.gen_, key.idx))
        });
        let above_start = u64::from(self.received.contiguous) + 2;
        live <= 1
            && unique_gens
            && unique_skipped
            && skipped.len() <= MAX_SKIPPED
            && self.peer_acked <= sent
            && self.unacked.first().is_none_or(|first| *first > 0)
            && self.unacked.windows(2).all(|pair| pair[0] < pair[1])
            && self.unacked.last().is_none_or(|last| *last <= sent)
            && canonical(&self.received.above, above_start)
            && canonical(&self.expired, 1)
            && self.expired.last().is_none_or(|&(_, to)| to <= sent)
    }
}

/// Whether `ranges` are ascending, non-adjacent, non-empty and start at `first` or later.
fn canonical(ranges: &[(u32, u32)], first: u64) -> bool {
    let mut next = first;
    ranges.iter().all(|&(from, to)| {
        let fits = u64::from(from) >= next && from <= to;
        next = u64::from(to) + 2;
        fits
    })
}

impl Outgoing {
    pub(crate) fn row(&self, contact: ContactId, msgno: u32) -> QueuedRow {
        let mut blob = Vec::with_capacity(8 + 6 + self.queued.ct.len());
        blob.extend_from_slice(&self.created_s.to_be_bytes());
        blob.extend_from_slice(&self.queued.encode());
        QueuedRow {
            contact,
            msgno,
            state: persisted(&blob),
        }
    }

    fn decode(row: &QueuedRow) -> Result<Self, InvalidBlob> {
        let mut reader = reader(&row.state)?;
        let created_s = reader.u64()?;
        let queued = Queued::decode(reader.0).map_err(|_| InvalidBlob)?;
        Ok(Self { created_s, queued })
    }
}

fn persisted(blob: &[u8]) -> Persisted {
    Persisted {
        blob: blob.to_vec(),
        version: BLOB_VERSION,
    }
}

fn reader(state: &Persisted) -> Result<Reader<'_>, InvalidBlob> {
    if state.version != BLOB_VERSION {
        return Err(InvalidBlob);
    }
    Ok(Reader(&state.blob))
}

fn put_count(count: usize, blob: &mut Vec<u8>) {
    let count = u16::try_from(count).expect("lists are bounded below 64 Ki");
    blob.extend_from_slice(&count.to_be_bytes());
}

fn put_ranges(ranges: &[(u32, u32)], blob: &mut Vec<u8>) {
    put_count(ranges.len(), blob);
    for (from, to) in ranges {
        blob.extend_from_slice(&from.to_be_bytes());
        blob.extend_from_slice(&to.to_be_bytes());
    }
}

pub(crate) struct Device {
    pub(crate) beacon_day: u32,
    pub(crate) beacon_key: Zeroizing<[u8; 32]>,
    pub(crate) next_contact: u64,
    /// The global, reciprocal read-receipt setting (ADR 0034 §4).
    pub(crate) read_receipts: bool,
    pub(crate) contacts: Vec<Contact>,
}

/// The rows do not decode as version 2 or do not fit together.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct InvalidBlob;

impl Device {
    /// The device row; contacts are separate rows.
    pub(crate) fn row(&self) -> Persisted {
        let mut blob = Zeroizing::new(Vec::with_capacity(45));
        blob.extend_from_slice(&self.beacon_day.to_be_bytes());
        blob.extend_from_slice(&self.beacon_key[..]);
        blob.extend_from_slice(&self.next_contact.to_be_bytes());
        blob.push(u8::from(self.read_receipts));
        persisted(&blob)
    }

    pub(crate) fn restore(
        device: &Persisted,
        contacts: &[ContactRow],
        queued: &[QueuedRow],
    ) -> Result<Self, InvalidBlob> {
        let mut reader = reader(device)?;
        let beacon_day = reader.u32()?;
        let beacon_key = reader.key()?;
        let next_contact = reader.u64()?;
        let read_receipts = reader.flag()?;
        reader.end()?;
        let mut restored: Vec<Contact> = Vec::with_capacity(contacts.len());
        for row in contacts {
            let contact = Contact::decode(row)?;
            if contact.id.0 >= next_contact || restored.iter().any(|other| other.id == contact.id) {
                return Err(InvalidBlob);
            }
            restored.push(contact);
        }
        for row in queued {
            let outgoing = Outgoing::decode(row)?;
            let contact = restored
                .iter_mut()
                .find(|contact| contact.id == row.contact)
                .ok_or(InvalidBlob)?;
            let fits = row.msgno != 0
                && row.msgno <= contact.sent_msgno
                && contact.unacked.binary_search(&row.msgno).is_err();
            if !fits || contact.queued.insert(row.msgno, outgoing).is_some() {
                return Err(InvalidBlob);
            }
        }
        Ok(Self {
            beacon_day,
            beacon_key,
            next_contact,
            read_receipts,
            contacts: restored,
        })
    }
}

struct Reader<'a>(&'a [u8]);

impl<'a> Reader<'a> {
    fn take(&mut self, length: usize) -> Result<&'a [u8], InvalidBlob> {
        let (head, rest) = self.0.split_at_checked(length).ok_or(InvalidBlob)?;
        self.0 = rest;
        Ok(head)
    }

    fn array<const N: usize>(&mut self) -> Result<[u8; N], InvalidBlob> {
        Ok(self.take(N)?.try_into().expect("exact length"))
    }

    fn byte(&mut self) -> Result<u8, InvalidBlob> {
        Ok(self.take(1)?[0])
    }

    fn flag(&mut self) -> Result<bool, InvalidBlob> {
        match self.byte()? {
            0 => Ok(false),
            1 => Ok(true),
            _ => Err(InvalidBlob),
        }
    }

    fn u32(&mut self) -> Result<u32, InvalidBlob> {
        Ok(u32::from_be_bytes(self.array()?))
    }

    fn u64(&mut self) -> Result<u64, InvalidBlob> {
        Ok(u64::from_be_bytes(self.array()?))
    }

    fn key(&mut self) -> Result<Zeroizing<[u8; 32]>, InvalidBlob> {
        Ok(Zeroizing::new(self.array()?))
    }

    fn count(&mut self) -> Result<u16, InvalidBlob> {
        Ok(u16::from_be_bytes(self.array()?))
    }

    fn ranges(&mut self) -> Result<Vec<(u32, u32)>, InvalidBlob> {
        (0..self.count()?)
            .map(|_| Ok((self.u32()?, self.u32()?)))
            .collect()
    }

    fn end(&self) -> Result<(), InvalidBlob> {
        self.0.is_empty().then_some(()).ok_or(InvalidBlob)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key(byte: u8) -> Zeroizing<[u8; 32]> {
        Zeroizing::new([byte; 32])
    }

    fn bare(id: u64) -> Contact {
        Contact {
            id: ContactId(id),
            role: PairingRole::B,
            verification: Verification::Verified,
            pair_id: [1; 16],
            th: [2; 48],
            nonce_b: [3; 16],
            peer: Card {
                caps: 1,
                beacon_day: 4,
                beacon_key: Zeroizing::new([5; 32]),
                name: "Bo".into(),
                static_ek: None,
            },
            door_a_to_b: key(6),
            door_b_to_a: key(7),
            resume_index: 8,
            chain_key: key(9),
            sent_msgno: 12,
            pending: None,
            send: None,
            receiver: Receiver::default(),
            peer_acked: 0,
            peer_read: 0,
            read_marked: 0,
            received: Received::default(),
            unacked: Vec::new(),
            expired: Vec::new(),
            queued: BTreeMap::new(),
        }
    }

    fn outgoing(idx: u32) -> Outgoing {
        Outgoing {
            created_s: 1_800_000_000 + u64::from(idx),
            queued: Queued {
                gen_: 3,
                idx,
                ct: std::vec![idx as u8; 48],
            },
        }
    }

    fn full(id: u64) -> Contact {
        let receiver = Receiver {
            chains: std::vec![
                ReceiveChain {
                    gen_: 2,
                    next: 4,
                    key: key(13),
                    superseded_s: Some(1_800_000_000),
                },
                ReceiveChain {
                    gen_: 3,
                    next: 0,
                    key: key(14),
                    superseded_s: None,
                },
            ],
            skipped: std::vec![Skipped {
                gen_: 2,
                idx: 1,
                key: key(15),
                created_s: 1_799_999_000,
            }],
        };
        Contact {
            role: PairingRole::A,
            verification: Verification::Compromised,
            pending: Some(Pending {
                chain_key: key(10),
                msg_seed: key(11),
            }),
            send: Some(SendChain {
                gen_: 3,
                idx: 7,
                key: key(16),
            }),
            receiver,
            peer_acked: 5,
            peer_read: 4,
            read_marked: 9,
            received: Received {
                contiguous: 9,
                above: std::vec![(11, 11), (14, 20)],
            },
            unacked: std::vec![6, 12],
            expired: std::vec![(7, 8)],
            queued: [(9, outgoing(1)), (10, outgoing(2))].into(),
            ..bare(id)
        }
    }

    fn device() -> Device {
        Device {
            beacon_day: 20_384,
            beacon_key: key(17),
            next_contact: 3,
            read_receipts: false,
            contacts: std::vec![bare(0), full(2)],
        }
    }

    struct Rows {
        device: Persisted,
        contacts: Vec<ContactRow>,
        queued: Vec<QueuedRow>,
    }

    fn rows(device: &Device) -> Rows {
        Rows {
            device: device.row(),
            contacts: device.contacts.iter().map(Contact::row).collect(),
            queued: device
                .contacts
                .iter()
                .flat_map(|contact| {
                    contact
                        .queued
                        .iter()
                        .map(|(msgno, outgoing)| outgoing.row(contact.id, *msgno))
                })
                .collect(),
        }
    }

    fn restore(rows: &Rows) -> Result<Device, InvalidBlob> {
        Device::restore(&rows.device, &rows.contacts, &rows.queued)
    }

    #[test]
    fn every_field_round_trips() {
        let rows = rows(&device());

        let restored = restore(&rows).unwrap();

        let again = self::rows(&restored);
        assert_eq!(
            (again.device, again.contacts, again.queued),
            (rows.device, rows.contacts, rows.queued)
        );
        let contact = &restored.contacts[1];
        assert_eq!(contact.id, ContactId(2));
        assert_eq!(contact.role, PairingRole::A);
        assert_eq!(contact.verification, Verification::Compromised);
        assert_eq!(contact.peer.name, "Bo");
        assert_eq!(contact.pending.as_ref().unwrap().msg_seed[..], [11; 32]);
        assert_eq!(contact.send.as_ref().unwrap().idx, 7);
        assert_eq!(contact.receiver.chains[0].superseded_s, Some(1_800_000_000));
        assert_eq!(contact.receiver.skipped[0].created_s, 1_799_999_000);
        assert_eq!(contact.received.above, [(11, 11), (14, 20)]);
        assert_eq!(contact.queued[&10], outgoing(2));
        assert!(!restored.read_receipts);
    }

    #[test]
    fn rows_are_version_2_and_queued_rows_carry_their_key() {
        let rows = rows(&device());

        let versions = (rows.device.version, rows.contacts[1].state.version);

        assert_eq!(versions, (2, 2));
        assert_eq!(
            (rows.queued[1].contact, rows.queued[1].msgno),
            (ContactId(2), 10)
        );
        assert_eq!(rows.queued[1].state.blob.len(), 8 + 2 + 48);
    }

    #[test]
    fn a_device_row_takes_45_bytes_and_a_fresh_contact_221_plus_its_card() {
        let device = device();
        let card = device.contacts[0].peer.encode().len();

        let sizes = (
            device.row().blob.len(),
            device.contacts[0].row().state.blob.len(),
        );

        assert_eq!(sizes, (4 + 32 + 8 + 1, 221 + card));
    }

    #[test]
    fn chat_numbers_start_at_one_and_stop_before_wrapping() {
        let numbers = [0, 1, u32::MAX - 1, u32::MAX].map(|sent_msgno| {
            Contact {
                sent_msgno,
                ..bare(0)
            }
            .next_msgno()
        });

        assert_eq!(numbers, [Some(1), Some(2), Some(u32::MAX), None]);
    }

    #[test]
    fn received_numbers_merge_into_the_contiguous_ack() {
        let mut received = Received::default();

        let moved = [
            received.insert(3, 3),
            received.insert(6, 8),
            received.insert(10, 10),
            received.insert(9, 9),
            received.insert(1, 2),
            received.insert(5, 5),
            received.insert(4, 4),
            received.insert(2, 3),
        ];

        assert_eq!(
            moved,
            [false, false, false, false, true, false, true, false]
        );
        assert_eq!(
            received,
            Received {
                contiguous: 10,
                above: std::vec![],
            }
        );
        received.insert(12, u32::MAX);
        assert_eq!(
            [u32::MAX, 7, 11].map(|msgno| received.contains(msgno)),
            [true, true, false]
        );
        assert!(received.insert(11, 11));
        assert_eq!(received.contiguous, u32::MAX);
        assert!(!received.contains(0));
    }

    #[test]
    fn a_range_is_covered_only_within_one_received_segment() {
        let mut received = Received::default();
        received.insert(1, 4);
        received.insert(7, 9);

        let covered = [(2, 4), (7, 9), (8, 8), (4, 7), (6, 7), (9, 10), (5, 5)]
            .map(|(from, to)| received.covers(from, to));

        assert_eq!(covered, [true, true, true, false, false, false, false]);
    }

    #[test]
    fn every_truncation_and_extension_is_rejected() {
        let rows = rows(&device());
        let mut rejected = std::vec![];
        for length in 0..=rows.device.blob.len() + 1 {
            let mut blob = rows.device.blob.clone();
            blob.resize(length, 0);
            rejected.push(
                Device::restore(
                    &Persisted { blob, version: 2 },
                    &rows.contacts,
                    &rows.queued,
                )
                .is_err(),
            );
        }
        for length in 0..=rows.contacts[1].state.blob.len() + 1 {
            let mut contacts = rows.contacts.clone();
            contacts[1].state.blob.resize(length, 0);
            rejected.push(Device::restore(&rows.device, &contacts, &rows.queued).is_err());
        }
        for length in 0..=rows.queued[0].state.blob.len() + 1 {
            let mut queued = rows.queued.clone();
            queued[0].state.blob.resize(length, 0);
            rejected.push(Device::restore(&rows.device, &rows.contacts, &queued).is_err());
        }

        let accepted = rejected.iter().filter(|rejected| !**rejected).count();

        assert_eq!(accepted, 3);
    }

    #[test]
    fn debug_output_omits_the_blob() {
        let persisted = Persisted {
            blob: std::vec![0xaa; 4],
            version: 2,
        };

        let text = std::format!("{persisted:?}");

        assert_eq!(text, "Persisted { version: 2, .. }");
    }

    fn rejected(change: impl FnOnce(&mut Device)) -> Option<InvalidBlob> {
        let mut device = device();
        change(&mut device);
        restore(&rows(&device)).err()
    }

    #[test]
    fn inconsistent_contact_state_is_rejected() {
        let results = [
            rejected(|device| device.next_contact = 2),
            rejected(|device| device.contacts[1].unacked = std::vec![12, 6]),
            rejected(|device| device.contacts[1].unacked = std::vec![6, 13]),
            rejected(|device| device.contacts[1].unacked = std::vec![0]),
            rejected(|device| device.contacts[1].expired = std::vec![(8, 7)]),
            rejected(|device| device.contacts[1].expired = std::vec![(1, 2), (2, 3)]),
            rejected(|device| device.contacts[1].expired = std::vec![(12, 13)]),
            rejected(|device| device.contacts[1].peer_acked = 13),
            rejected(|device| device.contacts[1].received.above = std::vec![(10, 10)]),
            rejected(|device| device.contacts[1].received.above = std::vec![(14, 20), (11, 11)]),
            rejected(|device| device.contacts[1].received.above = std::vec![(11, 12), (13, 14)]),
            rejected(|device| device.contacts[1].received.above = std::vec![(12, 11)]),
            rejected(|device| device.contacts[1].receiver.chains[0].superseded_s = None),
            rejected(|device| device.contacts[1].receiver.chains[0].gen_ = 3),
            rejected(|device| {
                let skipped = device.contacts[1].receiver.skipped[0].clone();
                device.contacts[1].receiver.skipped.push(skipped);
            }),
            rejected(|device| {
                let mut queued = device.contacts[1].queued.clone();
                queued.insert(13, outgoing(3));
                device.contacts[1].queued = queued;
            }),
            rejected(|device| {
                device.contacts[1].queued.insert(12, outgoing(3));
            }),
            rejected(|device| {
                let skipped = device.contacts[1].receiver.skipped[0].clone();
                device.contacts[1].receiver.skipped = (0..=MAX_SKIPPED as u32)
                    .map(|idx| Skipped {
                        idx,
                        ..skipped.clone()
                    })
                    .collect();
            }),
        ];

        assert_eq!(results, [Some(InvalidBlob); 18]);
    }

    #[test]
    fn corrupt_rows_are_rejected() {
        let rows = rows(&device());
        let corrupt = |index: usize, value: u8| {
            let mut contacts = rows.contacts.clone();
            contacts[1].state.blob[index] = value;
            Device::restore(&rows.device, &contacts, &rows.queued).err()
        };
        let extra = rows.contacts[1].state.blob.len() - rows.contacts[0].state.blob.len();
        let mut bad_flag = rows.device.blob.clone();
        bad_flag[44] = 2;
        let mut duplicate = rows.contacts.clone();
        duplicate.push(rows.contacts[1].clone());
        let mut orphan = rows.queued.clone();
        orphan[0].contact = ContactId(1);
        let mut zero = rows.queued.clone();
        zero[0].msgno = 0;
        let mut twice = rows.queued.clone();
        twice.push(rows.queued[0].clone());
        let mut wrong_version = rows.contacts.clone();
        wrong_version[0].state.version = 1;
        let mut unknown = rows.contacts.clone();
        unknown[0].contact = ContactId(3);

        let results = [
            corrupt(0, 2),
            corrupt(1, 1),
            corrupt(2, 3),
            corrupt(193 + 40, 2),
            corrupt(194 + 40 + 64, 2),
            Device::restore(
                &Persisted {
                    blob: bad_flag,
                    version: 2,
                },
                &rows.contacts,
                &rows.queued,
            )
            .err(),
            Device::restore(
                &Persisted {
                    blob: rows.device.blob.clone(),
                    version: 1,
                },
                &rows.contacts,
                &rows.queued,
            )
            .err(),
            Device::restore(&rows.device, &duplicate, &rows.queued).err(),
            Device::restore(&rows.device, &rows.contacts, &orphan).err(),
            Device::restore(&rows.device, &rows.contacts, &zero).err(),
            Device::restore(&rows.device, &rows.contacts, &twice).err(),
            Device::restore(&rows.device, &wrong_version, &rows.queued).err(),
            Device::restore(&rows.device, &unknown, &rows.queued).err(),
        ];

        assert_eq!(extra, 64 + 37 + 50 + 42 + 45 + 2 * 8 + 2 * 4 + 8);
        assert_eq!(results, [Some(InvalidBlob); 13]);
    }
}
