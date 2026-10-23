//! Durable device state and its version-1 Persist blob (ADR 0022 §7).

use crate::PairingRole;
use crate::card::Card;
use crate::core::{ContactId, Verification};
use crate::pairing::Paired;
use alloc::vec::Vec;
use zeroize::Zeroizing;

pub(crate) const BLOB_VERSION: u32 = 1;
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
    /// The last CHAT `msgno` sent to this contact; 0 before the first.
    pub(crate) sent_msgno: u32,
    /// `CK_{n+1}` while R awaits I's key confirmation.
    pub(crate) pending_chain_key: Option<Zeroizing<[u8; 32]>>,
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
            pending_chain_key: None,
        }
    }

    /// The next CHAT number; `None` once 2^32 − 1 has been sent (spec §8).
    pub(crate) fn next_msgno(&self) -> Option<u32> {
        self.sent_msgno.checked_add(1)
    }
}

pub(crate) struct Device {
    pub(crate) beacon_day: u32,
    pub(crate) beacon_key: Zeroizing<[u8; 32]>,
    pub(crate) next_contact: u64,
    pub(crate) contacts: Vec<Contact>,
}

/// The blob does not decode as version 1.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct InvalidBlob;

impl Device {
    pub(crate) fn persist(&self) -> Persisted {
        let mut blob = Zeroizing::new(Vec::new());
        blob.extend_from_slice(&self.beacon_day.to_be_bytes());
        blob.extend_from_slice(&self.beacon_key[..]);
        blob.extend_from_slice(&self.next_contact.to_be_bytes());
        let count = u16::try_from(self.contacts.len()).expect("at most 256 neighbours");
        blob.extend_from_slice(&count.to_be_bytes());
        for contact in &self.contacts {
            encode_contact(contact, &mut blob);
        }
        Persisted {
            blob: blob.to_vec(),
            version: BLOB_VERSION,
        }
    }

    pub(crate) fn restore(state: &Persisted) -> Result<Self, InvalidBlob> {
        if state.version != BLOB_VERSION {
            return Err(InvalidBlob);
        }
        let mut reader = Reader(&state.blob);
        let beacon_day = u32::from_be_bytes(reader.array()?);
        let beacon_key = Zeroizing::new(reader.array()?);
        let next_contact = u64::from_be_bytes(reader.array()?);
        let count = u16::from_be_bytes(reader.array()?);
        let contacts = (0..count)
            .map(|_| decode_contact(&mut reader))
            .collect::<Result<Vec<_>, _>>()?;
        if !reader.0.is_empty() || contacts.iter().any(|contact| contact.id.0 >= next_contact) {
            return Err(InvalidBlob);
        }
        Ok(Self {
            beacon_day,
            beacon_key,
            next_contact,
            contacts,
        })
    }
}

fn encode_contact(contact: &Contact, blob: &mut Vec<u8>) {
    blob.extend_from_slice(&contact.id.0.to_be_bytes());
    blob.push(match contact.role {
        PairingRole::A => 0,
        PairingRole::B => 1,
    });
    blob.push(MODE_TOFU);
    blob.push(match contact.verification {
        Verification::Unverified => 0,
        Verification::Verified => 1,
        Verification::Compromised => 2,
    });
    blob.extend_from_slice(&contact.pair_id);
    blob.extend_from_slice(&contact.th);
    blob.extend_from_slice(&contact.nonce_b);
    let card = contact.peer.encode();
    let card_len = u16::try_from(card.len()).expect("cards are below 64 KiB");
    blob.extend_from_slice(&card_len.to_be_bytes());
    blob.extend_from_slice(&card);
    blob.extend_from_slice(&contact.door_a_to_b[..]);
    blob.extend_from_slice(&contact.door_b_to_a[..]);
    blob.extend_from_slice(&contact.resume_index.to_be_bytes());
    blob.extend_from_slice(&contact.chain_key[..]);
    blob.extend_from_slice(&contact.sent_msgno.to_be_bytes());
    match &contact.pending_chain_key {
        None => blob.push(0),
        Some(key) => {
            blob.push(1);
            blob.extend_from_slice(&key[..]);
        }
    }
}

fn decode_contact(reader: &mut Reader<'_>) -> Result<Contact, InvalidBlob> {
    let id = ContactId(u64::from_be_bytes(reader.array()?));
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
    let door_a_to_b = Zeroizing::new(reader.array()?);
    let door_b_to_a = Zeroizing::new(reader.array()?);
    let resume_index = u64::from_be_bytes(reader.array()?);
    let chain_key = Zeroizing::new(reader.array()?);
    let sent_msgno = u32::from_be_bytes(reader.array()?);
    let pending_chain_key = match reader.byte()? {
        0 => None,
        1 => Some(Zeroizing::new(reader.array()?)),
        _ => return Err(InvalidBlob),
    };
    Ok(Contact {
        id,
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
        pending_chain_key,
    })
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
}

#[cfg(test)]
mod tests {
    use super::*;

    fn contact(id: u64, pending: bool) -> Contact {
        Contact {
            id: ContactId(id),
            role: PairingRole::B,
            verification: if pending {
                Verification::Compromised
            } else {
                Verification::Verified
            },
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
            door_a_to_b: Zeroizing::new([6; 32]),
            door_b_to_a: Zeroizing::new([7; 32]),
            resume_index: 8,
            chain_key: Zeroizing::new([9; 32]),
            sent_msgno: 12,
            pending_chain_key: pending.then(|| Zeroizing::new([10; 32])),
        }
    }

    fn device() -> Device {
        Device {
            beacon_day: 20_384,
            beacon_key: Zeroizing::new([11; 32]),
            next_contact: 3,
            contacts: std::vec![
                contact(0, false),
                contact(1, true),
                Contact {
                    role: PairingRole::A,
                    verification: Verification::Unverified,
                    ..contact(2, false)
                },
            ],
        }
    }

    #[test]
    fn every_field_round_trips() {
        let persisted = device().persist();

        let restored = Device::restore(&persisted).unwrap();

        assert_eq!(restored.persist(), persisted);
        assert_eq!(
            restored.contacts[1].pending_chain_key.as_deref(),
            Some(&[10; 32])
        );
        assert_eq!(restored.contacts[0].peer.name, "Bo");
        assert_eq!(restored.contacts[0].verification, Verification::Verified);
        assert_eq!(restored.contacts[2].role, PairingRole::A);
        assert_eq!(restored.contacts[2].verification, Verification::Unverified);
        assert_eq!(restored.contacts[0].sent_msgno, 12);
    }

    #[test]
    fn chat_numbers_start_at_one_and_stop_before_wrapping() {
        let numbers = [0, 1, u32::MAX - 1, u32::MAX].map(|sent_msgno| {
            Contact {
                sent_msgno,
                ..contact(0, false)
            }
            .next_msgno()
        });

        assert_eq!(numbers, [Some(1), Some(2), Some(u32::MAX), None]);
    }

    #[test]
    fn every_truncation_is_rejected() {
        let blob = device().persist().blob;

        let accepted: std::vec::Vec<usize> = (0..blob.len())
            .filter(|&length| {
                Device::restore(&Persisted {
                    blob: blob[..length].to_vec(),
                    version: 1,
                })
                .is_ok()
            })
            .collect();

        assert_eq!(accepted, []);
    }

    #[test]
    fn debug_output_omits_the_blob() {
        let persisted = Persisted {
            blob: std::vec![0xaa; 4],
            version: 1,
        };

        let text = std::format!("{persisted:?}");

        assert_eq!(text, "Persisted { version: 1, .. }");
    }

    #[test]
    fn a_contact_without_a_pending_key_takes_202_bytes_plus_its_card() {
        let empty = Device {
            contacts: std::vec::Vec::new(),
            ..device()
        };

        let sizes = [empty.persist().blob.len(), device().persist().blob.len()];

        assert_eq!(sizes[0], 4 + 32 + 8 + 2);
        assert_eq!(sizes[1] - sizes[0], 3 * (202 + 40) + 32);
    }

    #[test]
    fn corrupt_blobs_are_rejected() {
        let persisted = device().persist();
        let blob = &persisted.blob;
        let mut trailing = blob.clone();
        trailing.push(0);
        let mut bad_role = blob.clone();
        bad_role[46 + 8] = 2;
        let mut bad_mode = blob.clone();
        bad_mode[46 + 9] = 1;
        let mut bad_verification = blob.clone();
        bad_verification[46 + 10] = 3;
        let mut bad_pending_flag = blob.clone();
        bad_pending_flag[46 + 242 - 1] = 2;
        let mut bad_card = blob.clone();
        bad_card[46 + 93] = 0xff;
        let mut stale_next = blob.clone();
        stale_next[36..44].copy_from_slice(&1u64.to_be_bytes());
        let cases = [
            Persisted {
                blob: trailing,
                version: 1,
            },
            Persisted {
                blob: bad_role,
                version: 1,
            },
            Persisted {
                blob: bad_mode,
                version: 1,
            },
            Persisted {
                blob: bad_verification,
                version: 1,
            },
            Persisted {
                blob: bad_pending_flag,
                version: 1,
            },
            Persisted {
                blob: bad_card,
                version: 1,
            },
            Persisted {
                blob: stale_next,
                version: 1,
            },
            Persisted {
                blob: blob.clone(),
                version: 2,
            },
        ];

        let results = cases.map(|state| Device::restore(&state).err());

        assert_eq!(results, [Some(InvalidBlob); 8]);
    }
}
