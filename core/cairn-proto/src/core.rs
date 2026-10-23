//! The `CairnCore` event loop (ADR 0004, ADR 0022).

use crate::admission::{Admission, TieBreak, tie_break};
use crate::beacon::{self, DayKey, day, window};
use crate::card::Card;
use crate::data::{EMPTY, Session, chat_plaintext, parse};
use crate::epoch::PairingRole;
use crate::framing::{
    MIN_ATT_MTU, PRE_AUTH_FRAME_LIMIT, Reassembler, SESSION_FRAME_LIMIT, fragment,
};
use crate::pairing::{AwaitingP2, AwaitingP3, AwaitingP4, Paired, PairingError};
use crate::resume::{self, Chain, Initiator, MAX_ATTEMPT, ResumeError, respond, s1_pseudonym};
use crate::state::{Contact, Device, Persisted};
use alloc::boxed::Box;
use alloc::collections::BTreeMap;
use alloc::string::String;
use alloc::vec::Vec;
use cairn_crypto::{CryptoBackend, CryptoError};
use cairn_wire::{FrameType, Header};
use core::marker::PhantomData;
use zeroize::Zeroizing;

/// A pre-authentication link must finish pairing or Resume within 5 s (spec §4.4).
const PRE_AUTH_LINK_MS: u64 = 5_000;
const P0_LEN: usize = 17;

/// The time of an event: monotonic for timers and limits, wall clock for beacon days.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Clock {
    pub mono_ms: u64,
    pub unix_s: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct LinkId(pub u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct TimerId(pub u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct ContactId(pub u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GattRole {
    Central,
    Peripheral,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Verification {
    Unverified,
    Verified,
    Compromised,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChatRejection {
    NoSession,
    TooLong,
    /// Every `msgno` up to 2^32 − 1 has been sent to this contact.
    Exhausted,
}

/// An input to [`Core::handle`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Event {
    /// The first event; `None` is a fresh install.
    Restore {
        state: Option<Persisted>,
    },
    LinkUp {
        link: LinkId,
        gatt_role: GattRole,
        mtu: u16,
        address: Vec<u8>,
    },
    MtuChanged {
        link: LinkId,
        mtu: u16,
    },
    BeaconRead {
        link: LinkId,
        beacon: [u8; 8],
    },
    Received {
        link: LinkId,
        fragment: Vec<u8>,
    },
    LinkDown {
        link: LinkId,
    },
    TimerFired {
        timer: TimerId,
    },
    SendChat {
        contact: ContactId,
        text: String,
    },
}

/// An output of [`Core::handle`], executed by the platform in order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Action {
    /// Seal and store `state` before executing any later action.
    Persist {
        state: Persisted,
    },
    Send {
        link: LinkId,
        fragment: Vec<u8>,
    },
    Disconnect {
        link: LinkId,
    },
    SetTimer {
        timer: TimerId,
        at_mono_ms: u64,
    },
    CancelTimer {
        timer: TimerId,
    },
    ContactAdded {
        contact: ContactId,
    },
    ChatReceived {
        contact: ContactId,
        msgno: u32,
        text: String,
    },
    /// The message was sealed into DATA frames on a live session.
    ChatSent {
        contact: ContactId,
        msgno: u32,
    },
    ChatRejected {
        contact: ContactId,
        reason: ChatRejection,
    },
}

/// A caller contract violation. Peer misbehaviour produces `Disconnect` instead.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CoreError {
    NotRestored,
    AlreadyRestored,
    /// The blob does not decode as a supported version.
    InvalidBlob,
    DuplicateLink,
    /// An ATT MTU below the BLE minimum of 23.
    InvalidMtu,
    /// `BeaconRead` arrived on a peripheral link or after the first read.
    UnexpectedBeaconRead,
    UnknownContact,
    Crypto(CryptoError),
}

impl From<CryptoError> for CoreError {
    fn from(error: CryptoError) -> Self {
        Self::Crypto(error)
    }
}

impl core::fmt::Display for CoreError {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        formatter.write_str(match self {
            Self::NotRestored => "event before Restore",
            Self::AlreadyRestored => "Restore after the first event",
            Self::InvalidBlob => "persisted state does not decode",
            Self::DuplicateLink => "link is already up",
            Self::InvalidMtu => "ATT MTU below 23",
            Self::UnexpectedBeaconRead => "beacon read outside a fresh central link",
            Self::UnknownContact => "unknown contact",
            Self::Crypto(_) => "cryptographic backend failure",
        })
    }
}

impl core::error::Error for CoreError {}

/// A contact as shown to the platform; no key material.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContactInfo {
    pub id: ContactId,
    /// The name the neighbour shared, or empty; the app generates a local label.
    pub name: String,
    pub verification: Verification,
}

enum LinkState {
    /// Central before its beacon read, or peripheral before the first frame.
    Fresh,
    /// B sent P0 and waits for P1.
    SentP0 {
        r: [u8; 16],
    },
    AwaitingP2(Box<AwaitingP2>),
    AwaitingP3(Box<AwaitingP3>),
    AwaitingP4(Box<AwaitingP4>),
    /// A after pairing, waiting for B's S1 on the same link.
    Admitted,
    /// I sent S1 and waits for S2.
    SentS1(Box<Resuming>),
    Session(Box<SessionLink>),
}

impl LinkState {
    fn pairing(&self) -> bool {
        matches!(
            self,
            Self::SentP0 { .. } | Self::AwaitingP2(_) | Self::AwaitingP3(_) | Self::AwaitingP4(_)
        )
    }

    /// The contact of a Resume in flight or an established session.
    fn contact(&self) -> Option<ContactId> {
        match self {
            Self::SentS1(resuming) => Some(resuming.contact),
            Self::Session(session) => Some(session.contact),
            _ => None,
        }
    }
}

struct Resuming {
    initiator: Initiator,
    contact: ContactId,
    /// The Resume index of the chain key S1 was built on.
    n: u64,
}

struct SessionLink {
    contact: ContactId,
    session: Session,
    /// R still holds `CK_n` and the pending `CK_{n+1}` until I's first DATA frame.
    unconfirmed: bool,
}

/// The result of one accepted pairing frame.
enum Step {
    Advance(LinkState, Vec<u8>),
    /// The peer is admitted; B still owes P4.
    Admit(Box<Paired>, Option<Vec<u8>>),
}

struct Link {
    gatt_role: GattRole,
    mtu: u16,
    address: Vec<u8>,
    reassembler: Reassembler,
    /// The pre-auth deadline; it leaves the timer map when it fires or a session starts.
    deadline: TimerId,
    state: LinkState,
}

/// The sans-IO protocol core for one device.
pub struct Core<B> {
    device: Option<Device>,
    links: BTreeMap<LinkId, Link>,
    timers: BTreeMap<TimerId, LinkId>,
    next_timer: u64,
    admission: Admission,
    /// Resume attempts per contact since its chain key last changed (OI-8).
    tries: BTreeMap<ContactId, u32>,
    backend: PhantomData<B>,
}

impl<B: CryptoBackend> Default for Core<B> {
    fn default() -> Self {
        Self::new()
    }
}

impl<B: CryptoBackend> Core<B> {
    pub fn new() -> Self {
        Self {
            device: None,
            links: BTreeMap::new(),
            timers: BTreeMap::new(),
            next_timer: 0,
            admission: Admission::default(),
            tries: BTreeMap::new(),
            backend: PhantomData,
        }
    }

    pub fn contacts(&self) -> Vec<ContactInfo> {
        self.device
            .iter()
            .flat_map(|device| &device.contacts)
            .map(|contact| ContactInfo {
                id: contact.id,
                name: contact.peer.name.clone(),
                verification: contact.verification,
            })
            .collect()
    }

    /// The value of the local `beacon` characteristic at `unix_s` (spec §10.1).
    pub fn beacon(&self, unix_s: u64) -> Result<[u8; 8], CoreError> {
        let device = self.device.as_ref().ok_or(CoreError::NotRestored)?;
        Ok(device_key(device).beacon::<B>(window(unix_s))?)
    }

    pub fn handle(&mut self, clock: Clock, event: Event) -> Result<Vec<Action>, CoreError> {
        let mut actions = Vec::new();
        match event {
            Event::Restore { state } => self.restore(clock, state.as_ref(), &mut actions)?,
            _ if self.device.is_none() => return Err(CoreError::NotRestored),
            Event::LinkUp {
                link,
                gatt_role,
                mtu,
                address,
            } => self.link_up(clock, link, gatt_role, mtu, address, &mut actions)?,
            Event::MtuChanged { link, mtu } => {
                check_mtu(mtu)?;
                if let Some(link) = self.links.get_mut(&link) {
                    link.mtu = mtu;
                }
            }
            Event::BeaconRead { link, beacon } => {
                self.beacon_read(clock, link, &beacon, &mut actions)?;
            }
            Event::Received { link, fragment } => {
                self.received(clock, link, &fragment, &mut actions)?;
            }
            Event::LinkDown { link } => self.link_down(clock, link, &mut actions),
            Event::TimerFired { timer } => {
                if let Some(link) = self.timers.remove(&timer) {
                    self.abort(clock, link, &mut actions);
                }
            }
            Event::SendChat { contact, text } => self.send_chat(contact, &text, &mut actions)?,
        }
        Ok(actions)
    }

    fn restore(
        &mut self,
        clock: Clock,
        state: Option<&Persisted>,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        if self.device.is_some() {
            return Err(CoreError::AlreadyRestored);
        }
        if let Some(state) = state {
            self.device = Some(Device::restore(state).map_err(|_| CoreError::InvalidBlob)?);
            return Ok(());
        }
        let mut beacon_key = Zeroizing::new([0; 32]);
        B::fill_random(&mut beacon_key[..])?;
        let device = Device {
            beacon_day: day(clock.unix_s),
            beacon_key,
            next_contact: 0,
            contacts: Vec::new(),
        };
        actions.push(Action::Persist {
            state: device.persist(),
        });
        self.device = Some(device);
        Ok(())
    }

    fn link_up(
        &mut self,
        clock: Clock,
        id: LinkId,
        gatt_role: GattRole,
        mtu: u16,
        address: Vec<u8>,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        if self.links.contains_key(&id) {
            return Err(CoreError::DuplicateLink);
        }
        check_mtu(mtu)?;
        let timer = self.set_timer(id, clock.mono_ms + PRE_AUTH_LINK_MS, actions);
        self.links.insert(
            id,
            Link {
                gatt_role,
                mtu,
                address,
                reassembler: Reassembler::new(PRE_AUTH_FRAME_LIMIT),
                deadline: timer,
                state: LinkState::Fresh,
            },
        );
        Ok(())
    }

    /// A contact's beacon starts Resume as I; any other read is a stranger,
    /// who is sent P0 if the admission limits allow (spec §5.6, §10.4).
    fn beacon_read(
        &mut self,
        clock: Clock,
        id: LinkId,
        beacon: &[u8; 8],
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let Some(link) = self.links.get(&id) else {
            return Ok(());
        };
        if link.gatt_role != GattRole::Central || !matches!(link.state, LinkState::Fresh) {
            return Err(CoreError::UnexpectedBeaconRead);
        }
        let address = link.address.clone();
        let contacts = &mut self.device.as_mut().expect("restored").contacts;
        // Ratcheting in place bounds each read to one step per elapsed day.
        let since = beacon::first_day(clock.unix_s);
        for contact in contacts.iter_mut() {
            let key = DayKey {
                day: contact.peer.beacon_day,
                key: contact.peer.beacon_key.clone(),
            }
            .at::<B>(since)?;
            contact.peer.beacon_day = key.day;
            contact.peer.beacon_key = key.key;
        }
        let keys: Vec<DayKey> = contacts
            .iter()
            .map(|contact| DayKey {
                day: contact.peer.beacon_day,
                key: contact.peer.beacon_key.clone(),
            })
            .collect();
        let ids: Vec<ContactId> = contacts.iter().map(|contact| contact.id).collect();
        match beacon::find::<B>(&keys, clock.unix_s, beacon)? {
            Some(index) => self.beacon_hit(id, ids[index], actions),
            None => self.beacon_miss(clock, id, &address, actions),
        }
    }

    /// A contact's beacon: Resume, unless that contact already has a link.
    fn beacon_hit(
        &mut self,
        id: LinkId,
        contact: ContactId,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        if self.in_session(contact) {
            self.close(id, actions);
            return Ok(());
        }
        self.start_resume(id, contact, actions)
    }

    /// A stranger: P0, if admission allows it (spec §5).
    fn beacon_miss(
        &mut self,
        clock: Clock,
        id: LinkId,
        address: &[u8],
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        if self.pairing_in_flight() {
            self.close(id, actions);
            return Ok(());
        }
        if !self
            .admission
            .allows(clock.mono_ms, self.contact_count(), address)
        {
            self.admission.back_off(clock.mono_ms, address);
            self.close(id, actions);
            return Ok(());
        }
        self.admission.record_attempt(clock.mono_ms);
        let mut r = [0; 16];
        B::fill_random(&mut r)?;
        let mut p0 = Vec::with_capacity(P0_LEN);
        p0.push(0x00);
        p0.extend_from_slice(&r);
        self.advance(id, LinkState::SentP0 { r }, &p0, actions);
        Ok(())
    }

    fn received(
        &mut self,
        clock: Clock,
        id: LinkId,
        fragment: &[u8],
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let Some(link) = self.links.get_mut(&id) else {
            return Ok(());
        };
        let frame = match link.reassembler.accept(fragment) {
            Ok(Some(frame)) => frame,
            Ok(None) => return Ok(()),
            Err(_) => {
                self.abort(clock, id, actions);
                return Ok(());
            }
        };
        let header = Header::parse(frame[0]).expect("the reassembler validated the header");
        if let LinkState::Session(link) = &mut link.state {
            let opened = match header.frame_type() {
                FrameType::Data => link.session.open::<B>(&frame)?,
                _ => None,
            };
            let contact = link.contact;
            let confirms = core::mem::replace(&mut link.unconfirmed, false);
            self.receive_data(id, contact, opened, confirms, actions);
            return Ok(());
        }
        let state = core::mem::replace(&mut link.state, LinkState::Fresh);
        let pairing = state.pairing();
        let gatt_role = link.gatt_role;
        match (header.frame_type(), gatt_role, state) {
            (FrameType::Pair, _, state) => {
                self.pair_step(clock, id, gatt_role, header.sub(), state, &frame, actions)
            }
            (
                FrameType::ResumeInit,
                GattRole::Peripheral,
                LinkState::Fresh | LinkState::Admitted,
            ) => self.receive_s1(id, &frame, actions),
            (FrameType::ResumeReply, _, LinkState::SentS1(resuming)) => {
                self.receive_s2(id, *resuming, &frame, actions)
            }
            _ => {
                self.fail(clock, id, pairing, actions);
                Ok(())
            }
        }
    }

    /// One pairing frame; frames out of order close the link (spec §5).
    #[allow(clippy::too_many_arguments)]
    fn pair_step(
        &mut self,
        clock: Clock,
        id: LinkId,
        gatt_role: GattRole,
        sub: u8,
        state: LinkState,
        frame: &[u8],
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let pairing = state.pairing();
        let outcome = match (gatt_role, sub, state) {
            (GattRole::Peripheral, 0, LinkState::Fresh) => {
                return self.receive_p0(clock, id, frame, actions);
            }
            (GattRole::Central, 1, LinkState::SentP0 { .. }) => {
                AwaitingP3::receive_p1::<B>(self.own_card(clock)?, frame)
                    .map(|(state, p2)| Step::Advance(LinkState::AwaitingP3(Box::new(state)), p2))
            }
            (GattRole::Peripheral, 2, LinkState::AwaitingP2(state)) => state
                .receive_p2::<B>(frame)
                .map(|(state, p3)| Step::Advance(LinkState::AwaitingP4(Box::new(state)), p3)),
            (GattRole::Central, 3, LinkState::AwaitingP3(state)) => state
                .receive_p3::<B>(frame)
                .map(|(paired, p4)| Step::Admit(Box::new(paired), Some(p4))),
            (GattRole::Peripheral, 4, LinkState::AwaitingP4(state)) => state
                .receive_p4::<B>(frame)
                .map(|paired| Step::Admit(Box::new(paired), None)),
            _ => Err(PairingError::Malformed),
        };
        match outcome {
            Ok(Step::Advance(state, reply)) => self.advance(id, state, &reply, actions),
            Ok(Step::Admit(paired, reply)) => self.admit(clock, id, *paired, reply, actions)?,
            Err(PairingError::Crypto(error)) => return Err(error.into()),
            Err(_) => self.fail(clock, id, pairing, actions),
        }
        Ok(())
    }

    /// A answers P0 with P1 if no other pairing is in flight and the limits allow.
    fn receive_p0(
        &mut self,
        clock: Clock,
        id: LinkId,
        frame: &[u8],
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let Ok(incoming) = <[u8; 16]>::try_from(&frame[1..]) else {
            self.abort(clock, id, actions);
            return Ok(());
        };
        let in_flight: Vec<(LinkId, Option<[u8; 16]>)> = self
            .links
            .iter()
            .filter(|(other, link)| **other != id && link.state.pairing())
            .map(|(other, link)| match link.state {
                LinkState::SentP0 { r } => (*other, Some(r)),
                _ => (*other, None),
            })
            .collect();
        match in_flight.as_slice() {
            [] => {}
            [(own, Some(r))] => match tie_break(r, &incoming) {
                TieBreak::AnswerIncoming => self.close(*own, actions),
                TieBreak::CloseIncoming => {
                    self.close(id, actions);
                    return Ok(());
                }
                TieBreak::CloseBoth => {
                    self.close(*own, actions);
                    self.close(id, actions);
                    return Ok(());
                }
            },
            _ => {
                self.close(id, actions);
                return Ok(());
            }
        }
        let address = self.links[&id].address.clone();
        if !self
            .admission
            .allows(clock.mono_ms, self.contact_count(), &address)
        {
            self.close(id, actions);
            return Ok(());
        }
        self.admission.record_attempt(clock.mono_ms);
        let (state, p1) = AwaitingP2::start::<B>(self.own_card(clock)?)?;
        self.advance(id, LinkState::AwaitingP2(Box::new(state)), &p1, actions);
        Ok(())
    }

    /// Stores the new contact. Resume follows on the same link under a fresh
    /// deadline: B sends P4 and then S1 as I (ADR 0022).
    fn admit(
        &mut self,
        clock: Clock,
        id: LinkId,
        paired: Paired,
        p4: Option<Vec<u8>>,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        // The card holds the peer's current key (spec §5); an older day would
        // make every beacon read ratchet it forward again.
        if paired.peer.beacon_day.abs_diff(day(clock.unix_s)) > 1 {
            self.fail(clock, id, true, actions);
            return Ok(());
        }
        self.admission.record_admitted(clock.mono_ms);
        let device = self.device.as_mut().expect("restored");
        let contact = ContactId(device.next_contact);
        device.next_contact += 1;
        device.contacts.push(Contact::new(contact, paired));
        actions.push(Action::Persist {
            state: device.persist(),
        });
        self.links
            .get_mut(&id)
            .expect("admitted on a live link")
            .state = LinkState::Admitted;
        self.cancel_deadline(id, actions);
        let deadline = self.set_timer(id, clock.mono_ms + PRE_AUTH_LINK_MS, actions);
        self.links.get_mut(&id).expect("live link").deadline = deadline;
        actions.push(Action::ContactAdded { contact });
        if let Some(p4) = p4 {
            self.send(id, &p4, actions);
            self.start_resume(id, contact, actions)?;
        }
        Ok(())
    }

    /// I sends S1 on its newest chain key; while R's `CK_{n+1}` is
    /// unconfirmed, retries alternate it with `CK_n` (ADR 0022).
    fn start_resume(
        &mut self,
        id: LinkId,
        contact: ContactId,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let record = self.contact(contact);
        let tries = self.tries.get(&contact).copied().unwrap_or(0);
        let (n, ck) = match &record.pending_chain_key {
            Some(pending) if tries % 2 == 0 => (record.resume_index + 1, pending),
            _ => (record.resume_index, &record.chain_key),
        };
        let chain = Chain {
            pair_id: &record.pair_id,
            n,
            ck,
        };
        let attempt = tries.min(u32::from(MAX_ATTEMPT)) as u8;
        let (initiator, s1) = Initiator::start::<B>(&chain, record.role, attempt)?;
        self.tries.insert(contact, tries.saturating_add(1));
        let resuming = Resuming {
            initiator,
            contact,
            n,
        };
        self.advance(id, LinkState::SentS1(Box::new(resuming)), &s1, actions);
        Ok(())
    }

    /// R matches the pseudonym against `{CK_n, CK_{n+1}}` of every contact,
    /// verifies the MAC, persists the pending `CK_{n+1}` and sends S2 (spec §6).
    fn receive_s1(
        &mut self,
        id: LinkId,
        frame: &[u8],
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let Some(answer) = self.answer_s1(frame)? else {
            self.close(id, actions);
            return Ok(());
        };
        let (contact, promoted, keys, s2) = answer;
        let record = self.contact_mut(contact);
        if promoted {
            record.chain_key = record.pending_chain_key.take().expect("matched candidate");
            record.resume_index += 1;
            self.tries.remove(&contact);
        }
        let record = self.contact_mut(contact);
        record.pending_chain_key = Some(keys.next_ck.clone());
        self.persist(actions);
        self.establish(id, contact, Session::new(&keys, false), true, actions);
        self.send(id, &s2, actions);
        Ok(())
    }

    /// The matched contact, whether it matched the pending key, the keys and S2;
    /// `None` closes the link.
    #[allow(clippy::type_complexity)]
    fn answer_s1(
        &self,
        frame: &[u8],
    ) -> Result<Option<(ContactId, bool, resume::Keys, [u8; resume::S2_LEN])>, CoreError> {
        let Some(pseudonym) = s1_pseudonym(frame) else {
            return Ok(None);
        };
        let contacts = &self.device.as_ref().expect("restored").contacts;
        let candidates: Vec<(&Contact, bool)> = contacts
            .iter()
            .flat_map(|contact| {
                let pending = contact.pending_chain_key.is_some();
                [(contact, false)]
                    .into_iter()
                    .chain(pending.then_some((contact, true)))
            })
            .collect();
        let chains = candidates
            .iter()
            .map(|&(contact, pending)| candidate(contact, pending));
        let Some(index) = resume::find::<B>(chains, &pseudonym)? else {
            return Ok(None);
        };
        let (contact, pending) = candidates[index];
        if self.in_session(contact.id) {
            return Ok(None);
        }
        let (chain, initiator) = candidate(contact, pending);
        match respond::<B>(&chain, initiator, frame) {
            Ok((keys, s2)) => Ok(Some((contact.id, pending, keys, s2))),
            Err(error) => peer_fault(error).map(|()| None),
        }
    }

    /// I commits `CK_{n+1}` at a valid S2, persists it and confirms the key
    /// with an empty DATA frame (spec §6, ADR 0022).
    fn receive_s2(
        &mut self,
        id: LinkId,
        resuming: Resuming,
        frame: &[u8],
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let keys = match resuming.initiator.receive_s2::<B>(frame) {
            Ok(keys) => keys,
            Err(error) => {
                peer_fault(error)?;
                self.close(id, actions);
                return Ok(());
            }
        };
        let contact = resuming.contact;
        let record = self.contact_mut(contact);
        record.chain_key = keys.next_ck.clone();
        record.resume_index = resuming.n + 1;
        record.pending_chain_key = None;
        self.tries.remove(&contact);
        self.persist(actions);
        let mut session = Session::new(&keys, true);
        let confirmation = session
            .seal::<B>(&EMPTY)?
            .expect("a new session has counters left");
        self.establish(id, contact, session, false, actions);
        self.send(id, &confirmation, actions);
        Ok(())
    }

    /// Handles an opened DATA frame, or closes the link if it did not open.
    /// R's first frame commits `CK_{n+1}` before any message is shown (spec §6, §7).
    fn receive_data(
        &mut self,
        id: LinkId,
        contact: ContactId,
        opened: Option<Zeroizing<Vec<u8>>>,
        confirms: bool,
        actions: &mut Vec<Action>,
    ) {
        let Some(plaintext) = opened else {
            self.close(id, actions);
            return;
        };
        if confirms {
            let record = self.contact_mut(contact);
            record.chain_key = record.pending_chain_key.take().expect("R holds CK_{n+1}");
            record.resume_index += 1;
            self.tries.remove(&contact);
            self.persist(actions);
        }
        match parse(&plaintext) {
            Ok(chats) => actions.extend(chats.into_iter().map(|chat| Action::ChatReceived {
                contact,
                msgno: chat.msgno,
                text: chat.text,
            })),
            Err(_) => self.close(id, actions),
        }
    }

    /// Seals one CHAT on the contact's session; the new `msgno` is persisted
    /// before the frame is sent (spec §7, §8).
    fn send_chat(
        &mut self,
        contact: ContactId,
        text: &str,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        if !self.has_contact(contact) {
            return Err(CoreError::UnknownContact);
        }
        let reject = |reason| Action::ChatRejected { contact, reason };
        let found = self
            .links
            .iter_mut()
            .find_map(|(id, link)| match &mut link.state {
                LinkState::Session(session) if session.contact == contact => Some((*id, session)),
                _ => None,
            });
        let Some((id, session)) = found else {
            actions.push(reject(ChatRejection::NoSession));
            return Ok(());
        };
        let Some(msgno) = self
            .device
            .as_ref()
            .expect("restored")
            .contacts
            .iter()
            .find(|record| record.id == contact)
            .and_then(Contact::next_msgno)
        else {
            actions.push(reject(ChatRejection::Exhausted));
            return Ok(());
        };
        let Ok(plaintext) = chat_plaintext(msgno, text) else {
            actions.push(reject(ChatRejection::TooLong));
            return Ok(());
        };
        let Some(frame) = session.session.seal::<B>(&plaintext)? else {
            self.close(id, actions);
            actions.push(reject(ChatRejection::NoSession));
            return Ok(());
        };
        self.contact_mut(contact).sent_msgno = msgno;
        self.persist(actions);
        self.send(id, &frame, actions);
        actions.push(Action::ChatSent { contact, msgno });
        Ok(())
    }

    /// Ends the pre-auth phase: the deadline is cancelled and frames may grow
    /// to the session limit (spec §4.4).
    fn establish(
        &mut self,
        id: LinkId,
        contact: ContactId,
        session: Session,
        unconfirmed: bool,
        actions: &mut Vec<Action>,
    ) {
        self.cancel_deadline(id, actions);
        let link = self.links.get_mut(&id).expect("live link");
        link.reassembler.set_limit(SESSION_FRAME_LIMIT);
        link.state = LinkState::Session(Box::new(SessionLink {
            contact,
            session,
            unconfirmed,
        }));
    }

    fn cancel_deadline(&mut self, id: LinkId, actions: &mut Vec<Action>) {
        let timer = self.links[&id].deadline;
        self.timers.remove(&timer);
        actions.push(Action::CancelTimer { timer });
    }

    fn persist(&self, actions: &mut Vec<Action>) {
        actions.push(Action::Persist {
            state: self.device.as_ref().expect("restored").persist(),
        });
    }

    fn advance(&mut self, id: LinkId, state: LinkState, frame: &[u8], actions: &mut Vec<Action>) {
        self.links.get_mut(&id).expect("live link").state = state;
        self.send(id, frame, actions);
    }

    fn send(&self, id: LinkId, frame: &[u8], actions: &mut Vec<Action>) {
        let mtu = self.links[&id].mtu;
        let fragments = fragment(frame, mtu).expect("link MTUs are checked");
        actions.extend(
            fragments
                .into_iter()
                .map(|fragment| Action::Send { link: id, fragment }),
        );
    }

    fn link_down(&mut self, clock: Clock, id: LinkId, actions: &mut Vec<Action>) {
        if !self.links.contains_key(&id) {
            return;
        }
        let link = self.remove_link(id, actions);
        if link.state.pairing() {
            self.admission.back_off(clock.mono_ms, &link.address);
        }
    }

    /// Closes a link after a protocol failure; a failed pairing backs off the address.
    fn abort(&mut self, clock: Clock, id: LinkId, actions: &mut Vec<Action>) {
        let pairing = self.links[&id].state.pairing();
        self.fail(clock, id, pairing, actions);
    }

    fn fail(&mut self, clock: Clock, id: LinkId, pairing: bool, actions: &mut Vec<Action>) {
        let link = self.remove_link(id, actions);
        if pairing {
            self.admission.back_off(clock.mono_ms, &link.address);
        }
        actions.push(Action::Disconnect { link: id });
    }

    /// Closes a link without counting it as a failed attempt.
    fn close(&mut self, id: LinkId, actions: &mut Vec<Action>) {
        self.remove_link(id, actions);
        actions.push(Action::Disconnect { link: id });
    }

    fn remove_link(&mut self, id: LinkId, actions: &mut Vec<Action>) -> Link {
        let link = self.links.remove(&id).expect("live link");
        if self.timers.remove(&link.deadline).is_some() {
            actions.push(Action::CancelTimer {
                timer: link.deadline,
            });
        }
        link
    }

    fn set_timer(&mut self, link: LinkId, at_mono_ms: u64, actions: &mut Vec<Action>) -> TimerId {
        let timer = TimerId(self.next_timer);
        self.next_timer += 1;
        self.timers.insert(timer, link);
        actions.push(Action::SetTimer { timer, at_mono_ms });
        timer
    }

    fn pairing_in_flight(&self) -> bool {
        self.links.values().any(|link| link.state.pairing())
    }

    fn contact_count(&self) -> usize {
        self.device
            .as_ref()
            .map_or(0, |device| device.contacts.len())
    }

    fn has_contact(&self, id: ContactId) -> bool {
        self.device
            .as_ref()
            .is_some_and(|device| device.contacts.iter().any(|contact| contact.id == id))
    }

    fn contact(&self, id: ContactId) -> &Contact {
        let contacts = &self.device.as_ref().expect("restored").contacts;
        contacts
            .iter()
            .find(|contact| contact.id == id)
            .expect("known contact")
    }

    fn contact_mut(&mut self, id: ContactId) -> &mut Contact {
        let contacts = &mut self.device.as_mut().expect("restored").contacts;
        contacts
            .iter_mut()
            .find(|contact| contact.id == id)
            .expect("known contact")
    }

    /// At most one link per contact is past S1 (spec §6, OI-17).
    fn in_session(&self, contact: ContactId) -> bool {
        self.links
            .values()
            .any(|link| link.state.contact() == Some(contact))
    }

    /// The card carries the device beacon key ratcheted to today (spec §10.2).
    fn own_card(&self, clock: Clock) -> Result<Card, CoreError> {
        let key = device_key(self.device.as_ref().expect("restored")).at::<B>(day(clock.unix_s))?;
        Ok(Card {
            caps: 0,
            beacon_day: key.day,
            beacon_key: key.key,
            name: String::new(),
            static_ek: None,
        })
    }
}

/// R's chain `CK_n`, or the pending `CK_{n+1}`, with I's pairing role (spec §6).
fn candidate(contact: &Contact, pending: bool) -> (Chain<'_>, PairingRole) {
    let ck = match &contact.pending_chain_key {
        Some(key) if pending => key,
        _ => &contact.chain_key,
    };
    let chain = Chain {
        pair_id: &contact.pair_id,
        n: contact.resume_index + u64::from(pending),
        ck,
    };
    (chain, peer_role(contact.role))
}

fn device_key(device: &Device) -> DayKey {
    DayKey {
        day: device.beacon_day,
        key: device.beacon_key.clone(),
    }
}

/// The other side's pairing role: R looks up I's pseudonym with it (OI-16).
fn peer_role(role: PairingRole) -> PairingRole {
    match role {
        PairingRole::A => PairingRole::B,
        PairingRole::B => PairingRole::A,
    }
}

/// `Ok` for a fault of the peer, which closes the link; a backend failure is local.
fn peer_fault(error: ResumeError) -> Result<(), CoreError> {
    match error {
        ResumeError::Crypto(error) => Err(error.into()),
        ResumeError::Malformed | ResumeError::Authentication => Ok(()),
    }
}

fn check_mtu(mtu: u16) -> Result<(), CoreError> {
    if mtu < MIN_ATT_MTU {
        return Err(CoreError::InvalidMtu);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::resume::Keys;
    use cairn_crypto::Reference;

    const CLOCK: Clock = Clock {
        mono_ms: 0,
        unix_s: 1_761_177_600,
    };
    const LINK: LinkId = LinkId(0);
    const CONTACT: ContactId = ContactId(0);

    fn keys() -> Keys {
        Keys {
            i_to_r: Zeroizing::new([1; 32]),
            r_to_i: Zeroizing::new([2; 32]),
            next_ck: Zeroizing::new([3; 32]),
        }
    }

    fn contact(id: ContactId, sent_msgno: u32, pending: bool) -> Contact {
        Contact {
            id,
            role: PairingRole::A,
            verification: Verification::Unverified,
            pair_id: [4; 16],
            th: [5; 48],
            nonce_b: [6; 16],
            peer: Card {
                caps: 0,
                beacon_day: 0,
                beacon_key: Zeroizing::new([7; 32]),
                name: String::new(),
                static_ek: None,
            },
            door_a_to_b: Zeroizing::new([8; 32]),
            door_b_to_a: Zeroizing::new([9; 32]),
            resume_index: 0,
            chain_key: Zeroizing::new([10; 32]),
            sent_msgno,
            pending_chain_key: pending.then(|| Zeroizing::new([11; 32])),
        }
    }

    /// R's core in `session` with contact 0 on `LINK`, and I's session;
    /// `unconfirmed` leaves R holding `CK_{n+1}`.
    fn in_session(
        sent_msgno: u32,
        session: Session,
        unconfirmed: bool,
    ) -> (Core<Reference>, Session) {
        let mut core = Core::<Reference>::new();
        core.handle(CLOCK, Event::Restore { state: None }).unwrap();
        let contacts = &mut core.device.as_mut().unwrap().contacts;
        contacts.push(contact(CONTACT, sent_msgno, unconfirmed));
        contacts.push(contact(ContactId(1), 0, false));
        core.handle(
            CLOCK,
            Event::LinkUp {
                link: LINK,
                gatt_role: GattRole::Peripheral,
                mtu: 185,
                address: Vec::new(),
            },
        )
        .unwrap();
        core.links.get_mut(&LINK).unwrap().state = LinkState::Session(Box::new(SessionLink {
            contact: CONTACT,
            session,
            unconfirmed,
        }));
        (core, Session::new(&keys(), true))
    }

    fn responder() -> Session {
        Session::new(&keys(), false)
    }

    fn send_chat(core: &mut Core<Reference>, contact: ContactId) -> Vec<Action> {
        send(core, contact, "hi").unwrap()
    }

    fn send(
        core: &mut Core<Reference>,
        contact: ContactId,
        text: &str,
    ) -> Result<Vec<Action>, CoreError> {
        core.handle(
            CLOCK,
            Event::SendChat {
                contact,
                text: text.into(),
            },
        )
    }

    fn receive(core: &mut Core<Reference>, fragment: Vec<u8>) -> Vec<Action> {
        core.handle(
            CLOCK,
            Event::Received {
                link: LINK,
                fragment,
            },
        )
        .unwrap()
    }

    // `Core<B>` methods are counted per test binary, so this module covers the
    // DATA paths whole, including those the loopback cannot reach.

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn r_commits_the_pending_key_before_showing_the_first_chat() {
        let (mut core, mut peer) = in_session(0, responder(), true);
        let frame = peer
            .seal::<Reference>(&chat_plaintext(1, "hi").unwrap())
            .unwrap()
            .unwrap();

        let actions = receive(&mut core, frame);

        assert!(matches!(actions[0], Action::Persist { .. }));
        assert_eq!(
            actions[1..],
            [Action::ChatReceived {
                contact: CONTACT,
                msgno: 1,
                text: "hi".into(),
            }]
        );
        let record = core.contact(CONTACT);
        assert_eq!(
            (
                *record.chain_key,
                record.pending_chain_key.is_none(),
                record.resume_index
            ),
            ([11; 32], true, 1)
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_frame_that_does_not_open_closes_the_link() {
        let (mut core, mut peer) = in_session(0, responder(), false);
        let mut frame = peer.seal::<Reference>(&EMPTY).unwrap().unwrap();
        frame[1] ^= 1;

        let actions = receive(&mut core, frame);

        assert_eq!(actions.last(), Some(&Action::Disconnect { link: LINK }));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_chat_is_persisted_then_sent() {
        let (mut core, _) = in_session(0, responder(), false);

        let actions = send_chat(&mut core, CONTACT);

        assert!(matches!(
            &actions[..],
            [
                Action::Persist { .. },
                Action::Send { link: LINK, .. },
                Action::ChatSent {
                    contact: CONTACT,
                    msgno: 1
                },
            ]
        ));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn chats_to_unknown_contacts_fail_and_long_chats_are_rejected() {
        let (mut core, _) = in_session(0, responder(), false);

        let results = [
            send(&mut core, ContactId(9), "hi"),
            send(&mut core, CONTACT, &"x".repeat(4076)),
        ];

        assert_eq!(
            results,
            [
                Err(CoreError::UnknownContact),
                Ok(vec![Action::ChatRejected {
                    contact: CONTACT,
                    reason: ChatRejection::TooLong,
                }]),
            ]
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn an_authenticated_but_malformed_plaintext_closes_the_link() {
        let (mut core, mut peer) = in_session(0, responder(), false);
        let frame = peer.seal::<Reference>(&[0x02; 32]).unwrap().unwrap();

        let actions = receive(&mut core, frame);

        assert_eq!(actions.last(), Some(&Action::Disconnect { link: LINK }));
        assert!(core.links.is_empty());
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_contact_out_of_message_numbers_rejects_chats() {
        let (mut core, _) = in_session(u32::MAX, responder(), false);

        let actions = send_chat(&mut core, CONTACT);

        assert_eq!(
            actions,
            [Action::ChatRejected {
                contact: CONTACT,
                reason: ChatRejection::Exhausted,
            }]
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_session_out_of_nonces_closes_instead_of_sending() {
        let mut exhausted = responder();
        exhausted.exhaust();
        let (mut core, _) = in_session(0, exhausted, false);

        let actions = send_chat(&mut core, CONTACT);

        assert!(actions.contains(&Action::Disconnect { link: LINK }));
        assert_eq!(
            actions.last(),
            Some(&Action::ChatRejected {
                contact: CONTACT,
                reason: ChatRejection::NoSession,
            })
        );
        assert_eq!(core.contact(CONTACT).sent_msgno, 0);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn another_contacts_session_does_not_carry_a_chat() {
        let (mut core, _) = in_session(0, responder(), false);

        let actions = send_chat(&mut core, ContactId(1));

        assert_eq!(
            actions,
            [Action::ChatRejected {
                contact: ContactId(1),
                reason: ChatRejection::NoSession,
            }]
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_beacon_read_keeps_contact_beacon_keys_current() {
        let mut core = Core::<Reference>::new();
        core.handle(CLOCK, Event::Restore { state: None }).unwrap();
        let mut stale = contact(CONTACT, 0, false);
        stale.peer.beacon_day = day(CLOCK.unix_s) - 3;
        core.device.as_mut().unwrap().contacts.push(stale);
        core.handle(
            CLOCK,
            Event::LinkUp {
                link: LINK,
                gatt_role: GattRole::Central,
                mtu: 185,
                address: Vec::new(),
            },
        )
        .unwrap();

        core.handle(
            CLOCK,
            Event::BeaconRead {
                link: LINK,
                beacon: [0; 8],
            },
        )
        .unwrap();

        assert_eq!(
            core.contact(CONTACT).peer.beacon_day,
            day(CLOCK.unix_s - 300)
        );
    }

    #[test]
    fn only_backend_failures_in_resume_are_local() {
        let errors = [
            ResumeError::Malformed,
            ResumeError::Authentication,
            ResumeError::Crypto(CryptoError::BackendFailure),
        ];

        let classified = errors.map(peer_fault);

        assert_eq!(
            classified,
            [
                Ok(()),
                Ok(()),
                Err(CoreError::Crypto(CryptoError::BackendFailure))
            ]
        );
    }
}
