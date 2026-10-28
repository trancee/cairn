//! The courier exchange of a session (spec §8.1, ADR 0033, ADR 0036).

use super::{Action, ContactId, Core, CoreError, Verification};
use crate::chain::{self, Delivered, Dir, Queued};
use crate::courier::{self, COURIER_INNER_MAX, Custody, ENVELOPE_HEADER, Envelope};
use crate::data::CourierRecord;
use crate::state::{CourierConfig, Held, OwnEnvelope, Tombstone};
use alloc::collections::BTreeMap;
use alloc::vec::Vec;
use cairn_crypto::CryptoBackend;
use subtle::{Choice, ConditionallySelectable, ConstantTimeEq};

const MAX_OWN: usize = 256;
const MAX_CARRIED: usize = 256;
const MAX_CARRIED_BYTES: usize = 1 << 20;
const MAX_PER_DEPOSITOR: usize = 16;
const MAX_PER_VERIFIED: usize = 32;
const MAX_TOMBSTONES: usize = 1024;
const MAX_INVENTORY: usize = 512;
/// INVENTORY entries per record; 500 × 8 B fits one DATA plaintext.
const INVENTORY_CHUNK: usize = 500;

/// The peer's side of one session's exchange.
#[derive(Default)]
pub(super) struct Exchange {
    listed: Vec<[u8; 8]>,
    complete: bool,
    /// Copies handed over by ENVELOPE and not yet answered, by tag.
    offered: BTreeMap<[u8; 16], u8>,
}

/// One message key of the recipient window and its tag.
#[derive(Clone, Copy)]
struct Reachable {
    contact: ContactId,
    gen_: u8,
    idx: u32,
    tag: [u8; 16],
}

/// The window key of a memoized tag.
pub(super) type TagKey = (ContactId, Dir, u8, u32);

/// The first window entry whose tag starts with `prefix`, scanning every
/// entry in constant time (spec §11).
fn lookup(window: &[Reachable], prefix: &[u8]) -> Option<Reachable> {
    let mut found = 0u64;
    let mut hit = Choice::from(0);
    for (index, entry) in (0u64..).zip(window) {
        let matches = entry.tag[..prefix.len()].ct_eq(prefix) & !hit;
        found.conditional_assign(&index, matches);
        hit |= matches;
    }
    bool::from(hit).then(|| window[found as usize])
}

fn trunc8(tag: &[u8; 16]) -> [u8; 8] {
    *tag.first_chunk().expect("16 > 8")
}

impl<B: CryptoBackend> Core<B> {
    fn config(&self) -> CourierConfig {
        self.device.as_ref().expect("restored").courier
    }

    fn now_min(&self) -> u32 {
        u32::try_from(self.now_s / 60).unwrap_or(u32::MAX)
    }

    /// `now + T` in Unix minutes.
    fn lifetime_end(&self) -> u32 {
        self.now_min()
            .saturating_add(u32::from(self.config().lifetime_min))
    }

    /// An own envelope for a message just sealed on the contact's send
    /// chain, if its `inner` fits and fewer than 256 exist (spec §8.1).
    pub(super) fn own_envelope(
        &self,
        contact: ContactId,
        queued: &Queued,
        s: Delivered,
        inner_len: usize,
    ) -> Result<Option<OwnEnvelope>, CoreError> {
        let device = self.device.as_ref().expect("restored");
        let own = device
            .contacts
            .iter()
            .flat_map(|contact| contact.queued.values())
            .filter(|outgoing| outgoing.envelope.is_some())
            .count();
        if inner_len > COURIER_INNER_MAX || own >= MAX_OWN {
            return Ok(None);
        }
        let record = self.contact(contact);
        let dir = record.send.as_ref().expect("just sealed").dir;
        let tag = courier::route_tag::<B>(&record.route_key, dir, queued.gen_, queued.idx)?;
        Ok(Some(OwnEnvelope {
            tag,
            s,
            expiry_min: self.lifetime_end(),
            copies: self.config().copies,
            renewed: false,
        }))
    }

    /// The INVENTORY records that open the exchange with `peer`.
    pub(super) fn inventory(&self, peer: ContactId) -> Vec<CourierRecord> {
        let tags: Vec<[u8; 8]> = self
            .envelopes(peer)
            .iter()
            .map(|envelope| trunc8(&envelope.tag))
            .collect();
        let mut records: Vec<CourierRecord> = tags
            .chunks(INVENTORY_CHUNK)
            .map(|chunk| CourierRecord::Inventory(chunk.to_vec()))
            .collect();
        records.push(CourierRecord::Inventory(Vec::new()));
        records
    }

    /// Every envelope this device holds that `peer` may see: carried ones and
    /// own ones for other contacts.
    fn envelopes(&self, peer: ContactId) -> Vec<Envelope> {
        let device = self.device.as_ref().expect("restored");
        let own = device
            .contacts
            .iter()
            .filter(|contact| contact.id != peer)
            .flat_map(|contact| contact.queued.values())
            .filter_map(|outgoing| {
                let own = outgoing.envelope.as_ref()?;
                Some(Envelope {
                    tag: own.tag,
                    c: courier::commitment::<B>(&own.s),
                    expiry_min: own.expiry_min,
                    copies: own.copies,
                    ct: outgoing.queued.ct.clone(),
                })
            });
        let carried = device.held.values().filter_map(|held| match held {
            Held::Carried { envelope, .. } => Some(envelope.clone()),
            Held::Tombstone(_) => None,
        });
        own.chain(carried).collect()
    }

    fn tombstones(&self) -> impl Iterator<Item = &Tombstone> {
        let device = self.device.as_ref().expect("restored");
        device.held.values().filter_map(|held| match held {
            Held::Tombstone(tombstone) => Some(tombstone),
            Held::Carried { .. } => None,
        })
    }

    /// The recipient window over every contact (spec §8.1). Tags are
    /// memoized by key position, so only new indices cost a MAC.
    fn window(&mut self) -> Result<Vec<Reachable>, CoreError> {
        let device = self.device.as_ref().expect("restored");
        let keys: Vec<TagKey> = device
            .contacts
            .iter()
            .flat_map(|contact| {
                contact
                    .receiver
                    .window()
                    .into_iter()
                    .map(move |(dir, gen_, idx)| (contact.id, dir, gen_, idx))
            })
            .collect();
        let mut tags = BTreeMap::new();
        for key in keys {
            let tag = match self.tags.get(&key) {
                Some(tag) => *tag,
                None => {
                    let (contact, dir, gen_, idx) = key;
                    let route_key = &self.contact(contact).route_key;
                    courier::route_tag::<B>(route_key, dir, gen_, idx)?
                }
            };
            tags.insert(key, tag);
        }
        let window = tags
            .iter()
            .map(|(&(contact, _, gen_, idx), &tag)| Reachable {
                contact,
                gen_,
                idx,
                tag,
            })
            .collect();
        self.tags = tags;
        Ok(window)
    }

    /// The exchange of `peer`'s session; courier records arrive only in one.
    fn exchange_mut(&mut self, peer: ContactId) -> &mut Exchange {
        let (_, session) = self.session_mut(peer).expect("in session");
        &mut session.exchange
    }

    /// Handles one courier record from `peer`; `true` closes the link.
    pub(super) fn courier_record(
        &mut self,
        peer: ContactId,
        record: CourierRecord,
        replies: &mut Vec<CourierRecord>,
        shown: &mut Vec<Action>,
        actions: &mut Vec<Action>,
    ) -> Result<bool, CoreError> {
        match record {
            CourierRecord::Inventory(tags) => self.receive_inventory(peer, tags, replies),
            CourierRecord::Fetch(tag) => {
                let held = self
                    .envelopes(peer)
                    .into_iter()
                    .find(|held| held.tag == tag);
                replies.extend(held.map(CourierRecord::Envelope));
                Ok(false)
            }
            CourierRecord::Envelope(envelope) => {
                self.receive_envelope(peer, envelope, replies, shown, actions)
            }
            CourierRecord::Custody { tag, code } => {
                if let Some(handed) = self.exchange_mut(peer).offered.remove(&tag)
                    && code == Custody::Accepted
                {
                    self.handed_over(&tag, handed, actions);
                }
                Ok(false)
            }
            CourierRecord::Tomb { tag, s } => Ok(self.receive_tomb(&tag, &s, actions)),
        }
    }

    fn receive_inventory(
        &mut self,
        peer: ContactId,
        tags: Vec<[u8; 8]>,
        replies: &mut Vec<CourierRecord>,
    ) -> Result<bool, CoreError> {
        let exchange = self.exchange_mut(peer);
        if exchange.complete || exchange.listed.len() + tags.len() > MAX_INVENTORY {
            return Ok(true);
        }
        if !tags.is_empty() {
            exchange.listed.extend(tags);
            return Ok(false);
        }
        exchange.complete = true;
        let listed = core::mem::take(&mut exchange.listed);
        let window = self.window()?;
        for prefix in &listed {
            if let Some(entry) = lookup(&window, prefix)
                && !self.bad_tags.contains(&(peer, entry.tag))
            {
                replies.push(CourierRecord::Fetch(entry.tag));
            }
        }
        let tombstones: Vec<Tombstone> = self.tombstones().cloned().collect();
        for prefix in &listed {
            if let Some(tombstone) = tombstones.iter().find(|tomb| trunc8(&tomb.tag) == *prefix) {
                replies.push(CourierRecord::Tomb {
                    tag: tombstone.tag,
                    s: tombstone.s,
                });
            }
        }
        let mut offered = BTreeMap::new();
        for mut envelope in self.envelopes(peer) {
            let tombstoned = tombstones.iter().any(|tomb| tomb.tag == envelope.tag);
            if envelope.copies > 1 && !tombstoned && !listed.contains(&trunc8(&envelope.tag)) {
                envelope.copies /= 2;
                offered.insert(envelope.tag, envelope.copies);
                replies.push(CourierRecord::Envelope(envelope));
            }
        }
        self.exchange_mut(peer).offered = offered;
        Ok(false)
    }

    /// Opens an envelope addressed to this device, or answers CUSTODY as a
    /// courier; `true` closes the link.
    fn receive_envelope(
        &mut self,
        peer: ContactId,
        envelope: Envelope,
        replies: &mut Vec<CourierRecord>,
        shown: &mut Vec<Action>,
        actions: &mut Vec<Action>,
    ) -> Result<bool, CoreError> {
        let window = self.window()?;
        let Some(entry) = lookup(&window, &envelope.tag) else {
            let code = self.custody(peer, &envelope);
            if code == Custody::Accepted {
                self.carry(peer, envelope.clone(), actions);
            }
            replies.push(CourierRecord::Custody {
                tag: envelope.tag,
                code,
            });
            return Ok(false);
        };
        let queued = Queued {
            gen_: entry.gen_,
            idx: entry.idx,
            ct: envelope.ct,
        };
        let now = self.now_s;
        let receiver = &mut self.contact_mut(entry.contact).receiver;
        let opened = receiver
            .open_delivered::<B>(&queued, now)?
            .map(|opened| opened.expect("the window lists only derivable keys"))
            .and_then(|(inner, s)| chain::parse_inner(&inner).map(|message| (message, s)));
        let Ok(((msgno, text), s)) = opened else {
            self.persist_contact(entry.contact, actions);
            self.bad_tags.insert((peer, entry.tag));
            return Ok(true);
        };
        self.accept(entry.contact, msgno, text, shown);
        self.persist_contact(entry.contact, actions);
        let tombstone = Tombstone {
            tag: entry.tag,
            s: *s,
            expiry_min: envelope.expiry_min.min(self.lifetime_end()),
        };
        self.store_tombstone(tombstone, actions);
        replies.push(CourierRecord::Tomb {
            tag: entry.tag,
            s: *s,
        });
        Ok(false)
    }

    /// The CUSTODY answer to an envelope not addressed to this device.
    fn custody(&self, peer: ContactId, envelope: &Envelope) -> Custody {
        let device = self.device.as_ref().expect("restored");
        if !device.courier.enabled {
            return Custody::Off;
        }
        if !envelope.valid(self.now_min()) {
            return Custody::Invalid;
        }
        let own = device
            .contacts
            .iter()
            .flat_map(|contact| contact.queued.values())
            .filter_map(|outgoing| outgoing.envelope.as_ref())
            .any(|own| own.tag == envelope.tag);
        if own || device.held.values().any(|held| *held.tag() == envelope.tag) {
            return Custody::Duplicate;
        }
        let carried: Vec<(ContactId, usize)> = device
            .held
            .values()
            .filter_map(|held| match held {
                Held::Carried {
                    depositor,
                    envelope,
                } => Some((*depositor, ENVELOPE_HEADER + envelope.ct.len())),
                Held::Tombstone(_) => None,
            })
            .collect();
        let bytes: usize = carried.iter().map(|(_, size)| size).sum();
        let deposited = carried.iter().filter(|(by, _)| *by == peer).count();
        let quota = match self.contact(peer).verification {
            Verification::Verified => MAX_PER_VERIFIED,
            _ => MAX_PER_DEPOSITOR,
        };
        let size = ENVELOPE_HEADER + envelope.ct.len();
        if carried.len() >= MAX_CARRIED || bytes + size > MAX_CARRIED_BYTES || deposited >= quota {
            return Custody::Full;
        }
        Custody::Accepted
    }

    /// Stores an accepted envelope with its copies and expiry clamped.
    fn carry(&mut self, depositor: ContactId, mut envelope: Envelope, actions: &mut Vec<Action>) {
        envelope.copies = envelope.copies.min(self.config().copies);
        envelope.expiry_min = envelope.expiry_min.min(self.lifetime_end());
        self.put_held(
            None,
            Held::Carried {
                depositor,
                envelope,
            },
            actions,
        );
    }

    /// Stores `held` in `slot`, or in a new slot.
    fn put_held(&mut self, slot: Option<u64>, held: Held, actions: &mut Vec<Action>) {
        let device = self.device.as_mut().expect("restored");
        let slot = slot.unwrap_or_else(|| {
            device.next_slot += 1;
            device.next_slot - 1
        });
        let row = held.row(slot);
        device.held.insert(slot, held);
        actions.push(Action::PutCourier {
            slot,
            state: row.state,
        });
    }

    fn delete_held(&mut self, slot: u64, actions: &mut Vec<Action>) {
        self.device.as_mut().expect("restored").held.remove(&slot);
        actions.push(Action::DeleteCourier { slot });
    }

    /// Keeps a tombstone unless one for its tag exists, dropping the
    /// earliest-expiring when 1024 are held (spec §8.1).
    pub(super) fn store_tombstone(&mut self, tombstone: Tombstone, actions: &mut Vec<Action>) {
        if self.tombstones().any(|tomb| tomb.tag == tombstone.tag) {
            return;
        }
        let device = self.device.as_ref().expect("restored");
        let held: Vec<(u64, u32)> = device
            .held
            .iter()
            .filter(|(_, held)| matches!(held, Held::Tombstone(_)))
            .map(|(&slot, held)| (slot, held.expiry_min()))
            .collect();
        if held.len() >= MAX_TOMBSTONES {
            let (slot, _) = held
                .into_iter()
                .min_by_key(|&(_, expiry)| expiry)
                .expect("at least one tombstone");
            self.delete_held(slot, actions);
        }
        self.put_held(None, Held::Tombstone(tombstone), actions);
    }

    /// Subtracts the copies a CUSTODY 0 took over. Sessions on several links
    /// may each have offered half, so the count stops at zero.
    fn handed_over(&mut self, tag: &[u8; 16], handed: u8, actions: &mut Vec<Action>) {
        let device = self.device.as_mut().expect("restored");
        let carried = device.held.iter_mut().find_map(|(&slot, held)| match held {
            Held::Carried { envelope, .. } if envelope.tag == *tag => Some((slot, envelope)),
            _ => None,
        });
        if let Some((slot, envelope)) = carried {
            envelope.copies = envelope.copies.saturating_sub(handed);
            let row = device.held[&slot].row(slot);
            actions.push(Action::PutCourier {
                slot,
                state: row.state,
            });
            return;
        }
        let own = device.contacts.iter_mut().find_map(|contact| {
            let id = contact.id;
            contact.queued.iter_mut().find_map(|(&msgno, outgoing)| {
                let own = outgoing.envelope.as_mut()?;
                (own.tag == *tag).then_some((id, msgno, outgoing))
            })
        });
        if let Some((contact, msgno, outgoing)) = own {
            let own = outgoing.envelope.as_mut().expect("matched");
            own.copies = own.copies.saturating_sub(handed);
            let row = outgoing.row(contact, msgno);
            actions.push(Action::PutQueued {
                contact,
                msgno,
                state: row.state,
            });
        }
    }

    /// A TOMB deletes a held envelope whose `c` it opens; `true` closes the link.
    fn receive_tomb(&mut self, tag: &[u8; 16], s: &[u8; 16], actions: &mut Vec<Action>) -> bool {
        let device = self.device.as_mut().expect("restored");
        let carried = device.held.iter().find_map(|(&slot, held)| match held {
            Held::Carried { envelope, .. } if envelope.tag == *tag => Some((slot, envelope)),
            _ => None,
        });
        if let Some((slot, envelope)) = carried {
            if !bool::from(courier::tombstone_matches::<B>(&envelope.c, s)) {
                return true;
            }
            let tombstone = Tombstone {
                tag: *tag,
                s: *s,
                expiry_min: envelope.expiry_min,
            };
            self.put_held(Some(slot), Held::Tombstone(tombstone), actions);
            return false;
        }
        let own = device.contacts.iter_mut().find_map(|contact| {
            let id = contact.id;
            contact.queued.iter_mut().find_map(|(&msgno, outgoing)| {
                let own = outgoing.envelope.as_ref()?;
                (own.tag == *tag).then_some((id, msgno, outgoing))
            })
        });
        let Some((contact, msgno, outgoing)) = own else {
            return false;
        };
        let own = outgoing.envelope.as_ref().expect("matched");
        let c = courier::commitment::<B>(&own.s);
        if !bool::from(courier::tombstone_matches::<B>(&c, s)) {
            return true;
        }
        let expiry_min = own.expiry_min;
        outgoing.envelope = None;
        let row = outgoing.row(contact, msgno);
        actions.push(Action::PutQueued {
            contact,
            msgno,
            state: row.state,
        });
        let tombstone = Tombstone {
            tag: *tag,
            s: *s,
            expiry_min,
        };
        self.store_tombstone(tombstone, actions);
        false
    }

    /// Drops expired carried envelopes and tombstones, and renews an own
    /// envelope once when it expires (spec §8.1).
    pub(super) fn maintain_couriers(&mut self, actions: &mut Vec<Action>) {
        let now = self.now_min();
        let renewed = (self.config().copies, self.lifetime_end());
        let device = self.device.as_mut().expect("restored");
        let expired: Vec<u64> = device
            .held
            .iter()
            .filter(|(_, held)| held.expiry_min() <= now)
            .map(|(&slot, _)| slot)
            .collect();
        for contact in &mut device.contacts {
            for (&msgno, outgoing) in &mut contact.queued {
                let Some(own) = outgoing.envelope.as_mut() else {
                    continue;
                };
                if own.expiry_min > now {
                    continue;
                }
                if own.renewed {
                    outgoing.envelope = None;
                } else {
                    (own.copies, own.expiry_min) = renewed;
                    own.renewed = true;
                }
                let row = outgoing.row(contact.id, msgno);
                actions.push(Action::PutQueued {
                    contact: contact.id,
                    msgno,
                    state: row.state,
                });
            }
        }
        for slot in expired {
            self.delete_held(slot, actions);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::super::tests::{CLOCK, CONTACT, in_session, responder};
    use super::super::{Event, GattRole, LinkId, LinkState, SessionLink};
    use super::*;
    use crate::state::Outgoing;
    use alloc::boxed::Box;
    use alloc::vec;
    use cairn_crypto::Reference;
    use zeroize::Zeroizing;

    const DEPOSITOR: ContactId = ContactId(1);

    fn now_min() -> u32 {
        u32::try_from(CLOCK.unix_s / 60).unwrap()
    }

    /// R's core in session with contact 0, and with `DEPOSITOR` on a
    /// second link.
    fn core() -> Core<Reference> {
        let mut core = in_session(0, responder(), false).0;
        let link = LinkId(1);
        let up = Event::LinkUp {
            link,
            gatt_role: GattRole::Peripheral,
            mtu: 185,
            address: Vec::new(),
        };
        core.handle(CLOCK, up).unwrap();
        core.links.get_mut(&link).unwrap().state = LinkState::Session(Box::new(SessionLink {
            contact: DEPOSITOR,
            session: responder(),
            unconfirmed: false,
            exchange: Exchange::default(),
        }));
        core
    }

    /// An envelope tagged `byte` whose `s` is `[byte; 16]`.
    fn envelope(byte: u8) -> Envelope {
        Envelope {
            tag: [byte; 16],
            c: courier::commitment::<Reference>(&[byte; 16]),
            expiry_min: now_min() + 600,
            copies: 4,
            ct: alloc::vec![0; 48],
        }
    }

    fn carried(envelope: Envelope) -> Held {
        Held::Carried {
            depositor: DEPOSITOR,
            envelope,
        }
    }

    /// The copies of the envelope tagged `byte` that `CONTACT` may see.
    fn copies(core: &Core<Reference>, byte: u8) -> Option<u8> {
        core.envelopes(CONTACT)
            .iter()
            .find(|envelope| envelope.tag == [byte; 16])
            .map(|envelope| envelope.copies)
    }

    /// Queues message `msgno` to `DEPOSITOR` with an own envelope tagged
    /// `byte`, whose `s` is `[byte; 16]`.
    fn own(core: &mut Core<Reference>, msgno: u32, byte: u8, expiry_min: u32) {
        let outgoing = Outgoing {
            created_s: CLOCK.unix_s,
            queued: Queued {
                gen_: 0,
                idx: msgno,
                ct: vec![0; 48],
            },
            envelope: Some(OwnEnvelope {
                tag: [byte; 16],
                s: Zeroizing::new([byte; 16]),
                expiry_min,
                copies: 6,
                renewed: false,
            }),
        };
        core.contact_mut(DEPOSITOR).queued.insert(msgno, outgoing);
    }

    fn own_envelope(core: &Core<Reference>, msgno: u32) -> Option<&OwnEnvelope> {
        core.contact(DEPOSITOR).queued[&msgno].envelope.as_ref()
    }

    /// Opens contact 0's receive chain, so its first indices are in the window.
    fn reachable(core: &mut Core<Reference>, idx: u32) -> [u8; 16] {
        let receiver = &mut core.contact_mut(CONTACT).receiver;
        receiver.reseed(0, Dir::R, Zeroizing::new([15; 32]), CLOCK.unix_s);
        courier::route_tag::<Reference>(&[12; 32], Dir::R, 0, idx).unwrap()
    }

    fn tombstone(byte: u8, expiry_min: u32) -> Tombstone {
        Tombstone {
            tag: [byte; 16],
            s: [byte; 16],
            expiry_min,
        }
    }

    struct Outcome {
        closed: bool,
        replies: Vec<CourierRecord>,
        actions: Vec<Action>,
    }

    fn deliver(core: &mut Core<Reference>, peer: ContactId, record: CourierRecord) -> Outcome {
        let (mut replies, mut shown, mut actions) = (Vec::new(), Vec::new(), Vec::new());
        let closed = core
            .courier_record(peer, record, &mut replies, &mut shown, &mut actions)
            .unwrap();
        Outcome {
            closed,
            replies,
            actions,
        }
    }

    fn inventory(core: &mut Core<Reference>, peer: ContactId, tags: &[[u8; 8]]) -> Outcome {
        deliver(core, peer, CourierRecord::Inventory(tags.to_vec()));
        deliver(core, peer, CourierRecord::Inventory(Vec::new()))
    }

    #[test]
    fn an_own_envelope_is_made_only_for_short_messages_while_fewer_than_256_exist() {
        let mut core = core();
        let queued = Queued {
            gen_: 0,
            idx: 0,
            ct: vec![0; 48],
        };
        let make = |core: &Core<Reference>, inner_len| {
            core.own_envelope(CONTACT, &queued, Zeroizing::new([1; 16]), inner_len)
                .unwrap()
                .map(|own| (own.copies, own.expiry_min))
        };

        let short = make(&core, 2048);
        let long = make(&core, 2049);
        for msgno in 0..256 {
            own(&mut core, msgno, 2, now_min() + 600);
        }
        let full = make(&core, 32);

        assert_eq!(short, Some((6, now_min() + 1440)));
        assert_eq!((long, full), (None, None));
    }

    #[test]
    fn a_courier_answers_off_invalid_duplicate_and_full_before_it_accepts() {
        let mut off = core();
        off.device.as_mut().unwrap().courier = CourierConfig::new(false, 6, 1440).unwrap();
        let mut core = core();
        let mut actions = Vec::new();
        own(&mut core, 1, 9, now_min() + 600);
        core.store_tombstone(tombstone(8, now_min() + 600), &mut actions);
        for byte in 100..116 {
            core.put_held(None, carried(envelope(byte)), &mut actions);
        }
        let invalid = [
            Envelope {
                expiry_min: now_min(),
                ..envelope(2)
            },
            Envelope {
                copies: 0,
                ..envelope(2)
            },
            Envelope {
                ct: vec![0; 49],
                ..envelope(2)
            },
        ];

        let codes = [
            off.custody(DEPOSITOR, &envelope(2)),
            core.custody(DEPOSITOR, &invalid[0]),
            core.custody(DEPOSITOR, &invalid[1]),
            core.custody(DEPOSITOR, &invalid[2]),
            core.custody(DEPOSITOR, &envelope(9)),
            core.custody(DEPOSITOR, &envelope(8)),
            core.custody(DEPOSITOR, &envelope(100)),
            core.custody(DEPOSITOR, &envelope(2)),
            core.custody(CONTACT, &envelope(2)),
        ];

        use Custody::*;
        assert_eq!(
            codes,
            [
                Off, Invalid, Invalid, Invalid, Duplicate, Duplicate, Duplicate, Full, Accepted
            ]
        );
    }

    #[test]
    fn a_verified_depositor_may_leave_32_envelopes() {
        let mut core = core();
        let mut actions = Vec::new();
        core.contact_mut(DEPOSITOR).verification = Verification::Verified;
        for byte in 100..131 {
            core.put_held(None, carried(envelope(byte)), &mut actions);
        }

        let last = core.custody(DEPOSITOR, &envelope(2));
        core.put_held(None, carried(envelope(131)), &mut actions);
        let beyond = core.custody(DEPOSITOR, &envelope(2));

        assert_eq!((last, beyond), (Custody::Accepted, Custody::Full));
    }

    #[test]
    fn a_courier_holds_at_most_256_envelopes_and_one_mebibyte() {
        let held = |count, ct_len| {
            let mut core = core();
            let other = Envelope {
                ct: vec![0; ct_len],
                ..envelope(200)
            };
            let device = core.device.as_mut().unwrap();
            for slot in 0..count {
                let held = Held::Carried {
                    depositor: ContactId(9),
                    envelope: other.clone(),
                };
                device.held.insert(slot, held);
            }
            core.custody(DEPOSITOR, &envelope(2))
        };
        let fits = MAX_CARRIED_BYTES - 2 * ENVELOPE_HEADER - 48;

        let codes = [
            held(255, 48),
            held(256, 48),
            held(1, fits),
            held(1, fits + 1),
        ];

        use Custody::*;
        assert_eq!(codes, [Accepted, Full, Accepted, Full]);
    }

    #[test]
    fn a_refused_envelope_is_answered_but_not_carried() {
        let mut core = core();
        core.device.as_mut().unwrap().courier.enabled = false;

        let outcome = deliver(&mut core, DEPOSITOR, CourierRecord::Envelope(envelope(2)));

        let off = CourierRecord::Custody {
            tag: [2; 16],
            code: Custody::Off,
        };
        assert_eq!((outcome.replies, outcome.actions), (vec![off], vec![]));
    }

    #[test]
    fn an_accepted_envelope_is_stored_with_its_copies_and_expiry_clamped() {
        let mut core = core();
        core.device.as_mut().unwrap().courier = CourierConfig::new(true, 2, 60).unwrap();

        let outcome = deliver(&mut core, DEPOSITOR, CourierRecord::Envelope(envelope(2)));

        let stored = carried(Envelope {
            copies: 2,
            expiry_min: now_min() + 60,
            ..envelope(2)
        });
        assert_eq!(
            outcome.replies,
            [CourierRecord::Custody {
                tag: [2; 16],
                code: Custody::Accepted,
            }]
        );
        assert_eq!(
            outcome.actions,
            [Action::PutCourier {
                slot: 0,
                state: stored.row(0).state,
            }]
        );
        assert_eq!(core.device.as_ref().unwrap().held[&0], stored);
    }

    #[test]
    fn an_inventory_after_its_end_or_beyond_512_entries_closes_the_link() {
        let mut long = core();
        let mut ended = core();

        let closed = [
            deliver(
                &mut long,
                CONTACT,
                CourierRecord::Inventory(vec![[0; 8]; 500]),
            )
            .closed,
            deliver(
                &mut long,
                CONTACT,
                CourierRecord::Inventory(vec![[0; 8]; 13]),
            )
            .closed,
            deliver(
                &mut ended,
                CONTACT,
                CourierRecord::Inventory(vec![[0; 8]; 512]),
            )
            .closed,
            deliver(&mut ended, CONTACT, CourierRecord::Inventory(Vec::new())).closed,
            deliver(&mut ended, CONTACT, CourierRecord::Inventory(Vec::new())).closed,
        ];

        assert_eq!(closed, [false, true, false, false, true]);
    }

    #[test]
    fn a_complete_inventory_is_answered_with_fetch_tomb_and_halved_envelopes() {
        let mut core = core();
        let mut actions = Vec::new();
        let wanted = reachable(&mut core, 0);
        let refused = reachable(&mut core, 1);
        core.bad_tags.insert((CONTACT, refused));
        core.store_tombstone(tombstone(8, now_min() + 600), &mut actions);
        core.put_held(None, carried(envelope(3)), &mut actions);
        let single = Envelope {
            copies: 1,
            ..envelope(4)
        };
        core.put_held(None, carried(single), &mut actions);
        core.put_held(None, carried(envelope(5)), &mut actions);
        core.put_held(None, carried(envelope(8)), &mut actions);
        own(&mut core, 1, 6, now_min() + 600);
        let listed = [wanted, refused, [8; 16], [5; 16], [0xee; 16]].map(|tag| trunc8(&tag));

        let outcome = inventory(&mut core, CONTACT, &listed);

        let own = Envelope {
            copies: 3,
            ..envelope(6)
        };
        let carried = Envelope {
            copies: 2,
            ..envelope(3)
        };
        assert!(!outcome.closed);
        assert_eq!(
            outcome.replies,
            [
                CourierRecord::Fetch(wanted),
                CourierRecord::Tomb {
                    tag: [8; 16],
                    s: [8; 16],
                },
                CourierRecord::Envelope(own),
                CourierRecord::Envelope(carried),
            ]
        );
    }

    #[test]
    fn custody_0_takes_over_the_offered_copies_and_other_answers_keep_them() {
        let mut core = core();
        let mut actions = Vec::new();
        core.put_held(None, carried(envelope(3)), &mut actions);
        own(&mut core, 1, 6, now_min() + 600);
        inventory(&mut core, CONTACT, &[]);
        let custody = |tag, code| CourierRecord::Custody { tag, code };

        let answers = [
            custody([3; 16], Custody::Full),
            custody([6; 16], Custody::Accepted),
            custody([6; 16], Custody::Accepted),
            custody([4; 16], Custody::Accepted),
        ]
        .map(|record| deliver(&mut core, CONTACT, record));

        let own_row = core.contact(DEPOSITOR).queued[&1].row(DEPOSITOR, 1);
        assert_eq!(
            answers.map(|outcome| outcome.actions),
            [
                vec![],
                vec![Action::PutQueued {
                    contact: DEPOSITOR,
                    msgno: 1,
                    state: own_row.state,
                }],
                vec![],
                vec![],
            ]
        );
        assert_eq!(copies(&core, 3), Some(4));
        assert_eq!(own_envelope(&core, 1).map(|own| own.copies), Some(3));
    }

    #[test]
    fn custody_for_an_envelope_tombstoned_meanwhile_changes_nothing() {
        let mut core = core();
        core.put_held(None, carried(envelope(3)), &mut Vec::new());
        inventory(&mut core, CONTACT, &[]);
        let tomb = CourierRecord::Tomb {
            tag: [3; 16],
            s: [3; 16],
        };
        deliver(&mut core, DEPOSITOR, tomb);

        let accepted = CourierRecord::Custody {
            tag: [3; 16],
            code: Custody::Accepted,
        };
        let outcome = deliver(&mut core, CONTACT, accepted);

        assert_eq!(outcome.actions, []);
        assert_eq!(copies(&core, 3), None);
    }

    #[test]
    fn custody_from_more_links_than_copies_remain_leaves_none() {
        let mut core = core();
        let mut actions = Vec::new();
        core.put_held(None, carried(envelope(1)), &mut actions);

        for _ in 0..3 {
            core.handed_over(&[1; 16], 2, &mut actions);
        }

        assert_eq!(copies(&core, 1), Some(0));
    }

    #[test]
    fn a_fetch_is_answered_with_the_held_envelope_and_an_unknown_tag_is_ignored() {
        let mut core = core();
        core.put_held(None, carried(envelope(3)), &mut Vec::new());

        let held = deliver(&mut core, CONTACT, CourierRecord::Fetch([3; 16]));
        let unknown = deliver(&mut core, CONTACT, CourierRecord::Fetch([4; 16]));

        assert_eq!(held.replies, [CourierRecord::Envelope(envelope(3))]);
        assert_eq!(unknown.replies, []);
    }

    #[test]
    fn an_envelope_for_this_device_is_answered_with_its_tombstone() {
        let mut core = core();
        let tag = reachable(&mut core, 0);
        let mut sender = chain::SendChain {
            gen_: 0,
            dir: Dir::R,
            idx: 0,
            key: Zeroizing::new([15; 32]),
        };
        let inner = chain::inner(1, "hi").unwrap();
        let (queued, s) = sender.seal::<Reference>(&inner).unwrap().unwrap();
        let sealed = Envelope {
            tag,
            ct: queued.ct,
            ..envelope(2)
        };

        let outcome = deliver(&mut core, DEPOSITOR, CourierRecord::Envelope(sealed));

        assert!(!outcome.closed);
        assert_eq!(outcome.replies, [CourierRecord::Tomb { tag, s: *s }]);
    }

    #[test]
    fn an_envelope_that_does_not_open_closes_the_link_and_is_not_fetched_from_that_peer() {
        let mut core = core();
        let tag = reachable(&mut core, 0);
        let forged = Envelope { tag, ..envelope(2) };

        let outcome = deliver(&mut core, DEPOSITOR, CourierRecord::Envelope(forged));
        let again = inventory(&mut core, DEPOSITOR, &[trunc8(&tag)]);
        let elsewhere = inventory(&mut core, CONTACT, &[trunc8(&tag)]);

        assert!(outcome.closed);
        assert!(matches!(
            outcome.actions[..],
            [Action::PersistContact {
                contact: CONTACT,
                ..
            }]
        ));
        assert_eq!(again.replies, []);
        assert_eq!(elsewhere.replies, [CourierRecord::Fetch(tag)]);
    }

    #[test]
    fn a_tomb_turns_a_carried_envelope_into_a_tombstone_only_if_s_opens_c() {
        let mut core = core();
        core.put_held(None, carried(envelope(3)), &mut Vec::new());
        let tomb = |tag, s| CourierRecord::Tomb { tag, s };

        let wrong = deliver(&mut core, CONTACT, tomb([3; 16], [4; 16]));
        let unknown = deliver(&mut core, CONTACT, tomb([9; 16], [9; 16]));
        let right = deliver(&mut core, CONTACT, tomb([3; 16], [3; 16]));

        let expected = Held::Tombstone(tombstone(3, envelope(3).expiry_min));
        assert_eq!(
            [wrong.closed, unknown.closed, right.closed],
            [true, false, false]
        );
        assert_eq!(unknown.actions, []);
        assert_eq!(
            right.actions,
            [Action::PutCourier {
                slot: 0,
                state: expected.row(0).state,
            }]
        );
        assert_eq!(core.device.as_ref().unwrap().held[&0], expected);
    }

    #[test]
    fn a_tomb_for_an_own_envelope_clears_it_and_keeps_the_tombstone() {
        let mut core = core();
        own(&mut core, 1, 6, now_min() + 600);
        let tomb = |s| CourierRecord::Tomb { tag: [6; 16], s };

        let wrong = deliver(&mut core, CONTACT, tomb([7; 16]));
        let right = deliver(&mut core, CONTACT, tomb([6; 16]));

        let row = core.contact(DEPOSITOR).queued[&1].row(DEPOSITOR, 1);
        let kept = Held::Tombstone(tombstone(6, now_min() + 600));
        assert_eq!([wrong.closed, right.closed], [true, false]);
        assert_eq!(own_envelope(&core, 1), None);
        assert_eq!(
            right.actions,
            [
                Action::PutQueued {
                    contact: DEPOSITOR,
                    msgno: 1,
                    state: row.state,
                },
                Action::PutCourier {
                    slot: 0,
                    state: kept.row(0).state,
                },
            ]
        );
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "1024 tombstone inserts take 24 min under Miri; runs under careful (ADR 0007)"
    )]
    fn a_tombstone_is_kept_once_and_the_earliest_expiring_goes_first_at_1024() {
        let mut core = core();
        let mut actions = Vec::new();
        let numbered = |n: u32| Tombstone {
            tag: {
                let mut tag = [0; 16];
                tag[..4].copy_from_slice(&n.to_le_bytes());
                tag
            },
            s: [0; 16],
            expiry_min: now_min() + 5000 - n,
        };
        for n in 0..1024 {
            core.store_tombstone(numbered(n), &mut actions);
        }
        let mut again = Vec::new();
        let mut full = Vec::new();

        core.store_tombstone(numbered(0), &mut again);
        core.store_tombstone(numbered(1024), &mut full);

        assert_eq!(again, []);
        assert_eq!(
            full,
            [
                Action::DeleteCourier { slot: 1023 },
                Action::PutCourier {
                    slot: 1024,
                    state: Held::Tombstone(numbered(1024)).row(1024).state,
                },
            ]
        );
    }

    #[test]
    fn maintenance_drops_expired_rows_and_renews_an_own_envelope_once() {
        let mut core = core();
        let mut actions = Vec::new();
        let soon = Envelope {
            expiry_min: now_min() + 10,
            ..envelope(3)
        };
        core.put_held(None, carried(soon), &mut actions);
        core.put_held(None, carried(envelope(4)), &mut actions);
        own(&mut core, 1, 6, now_min() + 10);
        own(&mut core, 2, 7, now_min() + 600);
        core.contact_mut(DEPOSITOR)
            .queued
            .get_mut(&2)
            .unwrap()
            .envelope = None;
        own(&mut core, 3, 8, now_min() + 600);
        let mut first = Vec::new();
        let mut second = Vec::new();

        core.now_s += 10 * 60;
        core.maintain_couriers(&mut first);
        let renewed = own_envelope(&core, 1).map(|own| (own.copies, own.expiry_min, own.renewed));
        core.now_s += 1440 * 60;
        core.maintain_couriers(&mut second);

        assert_eq!(renewed, Some((6, now_min() + 10 + 1440, true)));
        assert!(first.contains(&Action::DeleteCourier { slot: 0 }));
        assert!(!first.contains(&Action::DeleteCourier { slot: 1 }));
        assert_eq!(own_envelope(&core, 1), None);
        assert!(second.contains(&Action::DeleteCourier { slot: 1 }));
    }
}
