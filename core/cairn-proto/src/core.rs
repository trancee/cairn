//! The `CairnCore` event loop (ADR 0004, ADR 0022).

mod couriering;

use crate::admission::{Admission, TieBreak, tie_break};
use crate::beacon::{self, DayKey, day, window};
use crate::card::Card;
use crate::chain::{self, Dir, MAX_SKIPPED, Opened, RETENTION_S, SendChain};
use crate::data::{Chat, EMPTY, Record, Session, parse, plaintext};
use crate::epoch::PairingRole;
use crate::framing::{
    MIN_ATT_MTU, PRE_AUTH_FRAME_LIMIT, Reassembler, SESSION_FRAME_LIMIT, fragment,
};
use crate::pairing::{AwaitingP2, AwaitingP3, AwaitingP4, Paired, PairingError};
use crate::resume::{self, Chain, Initiator, MAX_ATTEMPT, ResumeError, respond, s1_pseudonym};
use crate::state::{
    Contact, ContactRow, CourierConfig, CourierRow, Device, Outgoing, Pending, Persisted,
    QueuedRow, Tombstone,
};
use alloc::boxed::Box;
use alloc::collections::{BTreeMap, BTreeSet};
use alloc::string::String;
use alloc::vec;
use alloc::vec::Vec;
use cairn_crypto::{CryptoBackend, CryptoError};
use cairn_wire::{FrameType, Header};
use core::marker::PhantomData;
use zeroize::Zeroizing;

/// A pre-authentication link must finish pairing or Resume within 5 s (spec §4.4).
const PRE_AUTH_LINK_MS: u64 = 5_000;
const P0_LEN: usize = 17;
/// A's refusal of a P0 (spec §5.6): a PAIR header with step 5 and no body.
const BUSY: [u8; 1] = [0x05];

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
    /// The contact has never completed a Resume, so it has no message chain.
    NoSession,
    TooLong,
    /// Every `msgno` up to 2^32 − 1, or every chain index, has been used.
    Exhausted,
    /// 500 messages to this contact are queued or unacked (spec §8).
    QueueFull,
}

/// An input to [`Core::handle`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Event {
    /// The first event: the stored rows; `device: None` is a fresh install.
    Restore {
        device: Option<Persisted>,
        contacts: Vec<ContactRow>,
        queued: Vec<QueuedRow>,
        courier: Vec<CourierRow>,
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
    /// The bytes the peer's `beacon` characteristic returned; a value that is
    /// not 8 bytes long is peer misbehaviour.
    BeaconRead {
        link: LinkId,
        beacon: Vec<u8>,
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
    /// The user has read the peer's messages up to `msgno`.
    MarkRead {
        contact: ContactId,
        msgno: u32,
    },
    /// The global, reciprocal read-receipt setting (ADR 0002).
    SetReadReceipts {
        enabled: bool,
    },
    /// The courier settings (spec §8.1, ADR 0036 §4): `copies` is the copy
    /// budget, 1–16, and `lifetime_minutes` the envelope lifetime, 60–10080.
    SetCourier {
        enabled: bool,
        copies: u8,
        lifetime_minutes: u16,
    },
}

/// An output of [`Core::handle`], executed by the platform in order. The
/// row actions of one result are stored in one transaction before any
/// later action (ADR 0034 §1).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Action {
    /// Seal and store the device row.
    PersistDevice {
        state: Persisted,
    },
    /// Seal and store one contact row.
    PersistContact {
        contact: ContactId,
        state: Persisted,
    },
    /// Seal and store one queued message.
    PutQueued {
        contact: ContactId,
        msgno: u32,
        state: Persisted,
    },
    DeleteQueued {
        contact: ContactId,
        msgno: u32,
    },
    /// Seal and store one courier row: a carried envelope or a tombstone.
    PutCourier {
        slot: u64,
        state: Persisted,
    },
    DeleteCourier {
        slot: u64,
    },
    Send {
        link: LinkId,
        fragment: Vec<u8>,
    },
    Disconnect {
        link: LinkId,
        reason: CloseReason,
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
    /// The message was sealed and stored for the next Resume.
    ChatQueued {
        contact: ContactId,
        msgno: u32,
    },
    /// The peer's ACK covers the message.
    ChatDelivered {
        contact: ContactId,
        msgno: u32,
    },
    /// The peer has read the messages up to `msgno`.
    ChatRead {
        contact: ContactId,
        msgno: u32,
    },
    /// This device gave up on the message.
    ChatExpired {
        contact: ContactId,
        msgno: u32,
    },
    /// The peer gave up on the messages `from..=to`.
    ChatsExpired {
        contact: ContactId,
        from: u32,
        to: u32,
    },
}

/// Why the core closed a link; local diagnostics, never sent (ADR 0041).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CloseReason {
    /// The pre-auth deadline passed.
    Expired,
    /// A pairing in flight, admission, a BUSY answer or the P0 tie-break.
    Busy,
    /// The contact already has a link.
    Duplicate,
    /// No contact matches the S1 pseudonym.
    Unknown,
    /// A fragment, frame or record that doesn't parse or comes out of order.
    Malformed,
    /// A P1 with another version or mode.
    Unsupported,
    /// P3's nonce doesn't match P1's commitment.
    Commitment,
    /// A MAC, the card's AEAD or a session frame that fails to open.
    Authentication,
    /// A card that opens but doesn't decode.
    Card,
    /// A card for a beacon day more than one day off.
    StaleCard,
    /// The session can't seal another frame.
    Exhausted,
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
    /// Courier copies outside 1–16 or a lifetime outside 60–10080 minutes.
    InvalidCourierConfig,
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
            Self::InvalidCourierConfig => "courier settings out of range",
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
    /// B sent P0 and waits for P1; `attempt_ms` is when the attempt was counted.
    SentP0 {
        r: [u8; 16],
        attempt_ms: u64,
    },
    AwaitingP2(Box<AwaitingP2>),
    AwaitingP3(Box<AwaitingP3>),
    AwaitingP4(Box<AwaitingP4>),
    /// A after pairing, waiting for B's S1 on the same link.
    Admitted,
    /// A answered BUSY and waits for B to close the link.
    Refused,
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
    exchange: couriering::Exchange,
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
    /// The contact this link paired, until B gets a valid S2 or A a valid S1
    /// on this link (ADR 0043).
    provisional: Option<ContactId>,
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
    /// The texts of unacked in-session CHATs with their send times, kept to
    /// re-seal them as QUEUED when the link drops (ADR 0034 §2).
    unacked: BTreeMap<(ContactId, u32), (u64, Zeroizing<String>)>,
    /// Envelope tags that failed to open, by the peer that sent them (spec §8.1).
    bad_tags: BTreeSet<(ContactId, [u8; 16])>,
    /// The recipient window's tags as last computed.
    tags: BTreeMap<couriering::TagKey, [u8; 16]>,
    /// `Clock.unix_s` of the event being handled.
    now_s: u64,
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
            unacked: BTreeMap::new(),
            bad_tags: BTreeSet::new(),
            tags: BTreeMap::new(),
            now_s: 0,
            backend: PhantomData,
        }
    }

    pub fn contacts(&self) -> Vec<ContactInfo> {
        self.device
            .iter()
            .flat_map(|device| &device.contacts)
            .filter(|contact| !self.is_provisional(contact.id))
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
        self.now_s = clock.unix_s;
        if !matches!(event, Event::Restore { .. }) {
            if self.device.is_none() {
                return Err(CoreError::NotRestored);
            }
            self.maintain(&mut actions);
        }
        match event {
            Event::Restore {
                device,
                contacts,
                queued,
                courier,
            } => {
                let rows = (contacts.as_slice(), queued.as_slice(), courier.as_slice());
                self.restore(clock, device.as_ref(), rows, &mut actions)?;
                self.maintain(&mut actions);
            }
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
                    self.expire(clock, link, &mut actions);
                }
            }
            Event::SendChat { contact, text } => self.send_chat(contact, &text, &mut actions)?,
            Event::MarkRead { contact, msgno } => self.mark_read(contact, msgno, &mut actions)?,
            Event::SetReadReceipts { enabled } => {
                let device = self.device.as_mut().expect("restored");
                device.read_receipts = enabled;
                actions.push(Action::PersistDevice {
                    state: device.row(),
                });
            }
            Event::SetCourier {
                enabled,
                copies,
                lifetime_minutes,
            } => {
                let config = CourierConfig::new(enabled, copies, lifetime_minutes)
                    .ok_or(CoreError::InvalidCourierConfig)?;
                let device = self.device.as_mut().expect("restored");
                device.courier = config;
                actions.push(Action::PersistDevice {
                    state: device.row(),
                });
            }
        }
        Ok(actions)
    }

    fn restore(
        &mut self,
        clock: Clock,
        device: Option<&Persisted>,
        (contacts, queued, courier): (&[ContactRow], &[QueuedRow], &[CourierRow]),
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        if self.device.is_some() {
            return Err(CoreError::AlreadyRestored);
        }
        if let Some(device) = device {
            let restored = Device::restore(device, contacts, queued, courier)
                .map_err(|_| CoreError::InvalidBlob)?;
            let lost: Vec<ContactId> = restored
                .contacts
                .iter()
                .filter(|contact| !contact.unacked.is_empty())
                .map(|contact| contact.id)
                .collect();
            self.device = Some(restored);
            for contact in lost {
                let msgnos = core::mem::take(&mut self.contact_mut(contact).unacked);
                self.expire_messages(contact, &msgnos, actions);
            }
            return Ok(());
        }
        if !contacts.is_empty() || !queued.is_empty() || !courier.is_empty() {
            return Err(CoreError::InvalidBlob);
        }
        let mut beacon_key = Zeroizing::new([0; 32]);
        B::fill_random(&mut beacon_key[..])?;
        let device = Device {
            beacon_day: day(clock.unix_s),
            beacon_key,
            next_contact: 0,
            read_receipts: true,
            courier: CourierConfig::default(),
            contacts: Vec::new(),
            held: BTreeMap::new(),
            next_slot: 0,
        };
        actions.push(Action::PersistDevice {
            state: device.row(),
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
                provisional: None,
            },
        );
        Ok(())
    }

    /// A contact's beacon starts Resume as I; any other read is a stranger,
    /// who is sent P0 if the admission limits allow (spec §5.6, §10.4). A
    /// value that is not 8 bytes long closes the link and backs off the address
    /// for 1 h.
    fn beacon_read(
        &mut self,
        clock: Clock,
        id: LinkId,
        beacon: &[u8],
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let Some(link) = self.links.get(&id) else {
            return Ok(());
        };
        if link.gatt_role != GattRole::Central || !matches!(link.state, LinkState::Fresh) {
            return Err(CoreError::UnexpectedBeaconRead);
        }
        let address = link.address.clone();
        let Ok(beacon) = <&[u8; 8]>::try_from(beacon) else {
            self.admission.protocol_failure(clock.mono_ms, &address);
            self.close(id, CloseReason::Malformed, actions);
            return Ok(());
        };
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
        if self.in_session(contact, id) {
            self.close(id, CloseReason::Duplicate, actions);
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
            self.close(id, CloseReason::Busy, actions);
            return Ok(());
        }
        if !self
            .admission
            .allows(clock.mono_ms, self.contact_count(), address)
        {
            self.admission.refused(clock.mono_ms, address);
            self.close(id, CloseReason::Busy, actions);
            return Ok(());
        }
        self.admission.record_attempt(clock.mono_ms);
        let mut r = [0; 16];
        B::fill_random(&mut r)?;
        let mut p0 = Vec::with_capacity(P0_LEN);
        p0.push(0x00);
        p0.extend_from_slice(&r);
        self.advance(
            id,
            LinkState::SentP0 {
                r,
                attempt_ms: clock.mono_ms,
            },
            &p0,
            actions,
        );
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
                self.abort(clock, id, CloseReason::Malformed, actions);
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
            return self.receive_data(id, contact, opened, confirms, actions);
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
                self.fail(clock, id, pairing, CloseReason::Malformed, actions);
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
            (GattRole::Central, 5, LinkState::SentP0 { attempt_ms, .. }) if frame.len() == 1 => {
                self.admission.refund_attempt(attempt_ms);
                self.close(id, CloseReason::Busy, actions);
                return Ok(());
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
            Err(error) => self.fail(clock, id, pairing, pairing_reason(&error), actions),
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
            self.abort(clock, id, CloseReason::Malformed, actions);
            return Ok(());
        };
        let in_flight: Vec<(LinkId, Option<[u8; 16]>)> = self
            .links
            .iter()
            .filter(|(other, link)| **other != id && link.state.pairing())
            .map(|(other, link)| match link.state {
                LinkState::SentP0 { r, .. } => (*other, Some(r)),
                _ => (*other, None),
            })
            .collect();
        match in_flight.as_slice() {
            [] => {}
            [(own, Some(r))] => match tie_break(r, &incoming) {
                TieBreak::AnswerIncoming => self.close(*own, CloseReason::Busy, actions),
                TieBreak::CloseIncoming => {
                    self.advance(id, LinkState::Refused, &BUSY, actions);
                    return Ok(());
                }
                TieBreak::CloseBoth => {
                    self.close(*own, CloseReason::Busy, actions);
                    self.advance(id, LinkState::Refused, &BUSY, actions);
                    return Ok(());
                }
            },
            _ => {
                self.advance(id, LinkState::Refused, &BUSY, actions);
                return Ok(());
            }
        }
        let address = self.links[&id].address.clone();
        if !self
            .admission
            .allows(clock.mono_ms, self.contact_count(), &address)
        {
            self.advance(id, LinkState::Refused, &BUSY, actions);
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
            self.fail(clock, id, true, CloseReason::StaleCard, actions);
            return Ok(());
        }
        self.admission.record_admitted(clock.mono_ms);
        let address = self.links[&id].address.clone();
        self.admission.paired(&address);
        let device = self.device.as_mut().expect("restored");
        let contact = ContactId(device.next_contact);
        device.next_contact += 1;
        device.contacts.push(Contact::new(contact, paired));
        actions.push(Action::PersistDevice {
            state: device.row(),
        });
        let link = self.links.get_mut(&id).expect("admitted on a live link");
        link.state = LinkState::Admitted;
        link.provisional = Some(contact);
        self.cancel_deadline(id, actions);
        let deadline = self.set_timer(id, clock.mono_ms + PRE_AUTH_LINK_MS, actions);
        self.links.get_mut(&id).expect("live link").deadline = deadline;
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
        let (n, ck) = match &record.pending {
            Some(pending) if tries % 2 == 0 => (record.resume_index + 1, &pending.chain_key),
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
        let answer = match self.answer_s1(id, frame)? {
            Ok(answer) => answer,
            Err(reason) => {
                self.close(id, reason, actions);
                return Ok(());
            }
        };
        let (contact, promoted, keys, s2) = answer;
        let record = self.contact_mut(contact);
        if promoted {
            let pending = record.pending.take().expect("matched candidate");
            record.chain_key = pending.chain_key;
            record.resume_index += 1;
            self.tries.remove(&contact);
            self.reseed(contact, &pending.msg_seed, Dir::R, actions)?;
        }
        let record = self.contact_mut(contact);
        record.pending = Some(Pending {
            chain_key: keys.next_ck.clone(),
            msg_seed: keys.msg_seed.clone(),
        });
        self.confirm(id, contact, actions);
        self.establish(id, contact, Session::new(&keys, false), true, actions);
        self.send(id, &s2, actions);
        self.flush(contact, actions)
    }

    /// The matched contact, whether it matched the pending key, the keys and S2;
    /// a reason closes the link.
    #[allow(clippy::type_complexity)]
    fn answer_s1(
        &self,
        id: LinkId,
        frame: &[u8],
    ) -> Result<Result<(ContactId, bool, resume::Keys, [u8; resume::S2_LEN]), CloseReason>, CoreError>
    {
        let Some(pseudonym) = s1_pseudonym(frame) else {
            return Ok(Err(CloseReason::Malformed));
        };
        let contacts = &self.device.as_ref().expect("restored").contacts;
        let candidates: Vec<(&Contact, bool)> = contacts
            .iter()
            .flat_map(|contact| {
                let pending = contact.pending.is_some();
                [(contact, false)]
                    .into_iter()
                    .chain(pending.then_some((contact, true)))
            })
            .collect();
        let chains = candidates
            .iter()
            .map(|&(contact, pending)| candidate(contact, pending));
        let Some(index) = resume::find::<B>(chains, &pseudonym)? else {
            return Ok(Err(CloseReason::Unknown));
        };
        let (contact, pending) = candidates[index];
        if self.in_session(contact.id, id) {
            return Ok(Err(CloseReason::Duplicate));
        }
        let (chain, initiator) = candidate(contact, pending);
        match respond::<B>(&chain, initiator, frame) {
            Ok((keys, s2)) => Ok(Ok((contact.id, pending, keys, s2))),
            Err(error) => peer_fault(error).map(Err),
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
                let reason = peer_fault(error)?;
                self.close(id, reason, actions);
                return Ok(());
            }
        };
        let contact = resuming.contact;
        let record = self.contact_mut(contact);
        let pending = record.pending.take();
        if resuming.n > record.resume_index {
            // S1 used the key R left pending, so the peer committed it and
            // may have queued under its chains (spec §8).
            let pending = pending.expect("S1 used the pending key");
            record.resume_index = resuming.n;
            self.reseed(contact, &pending.msg_seed, Dir::R, actions)?;
        }
        let record = self.contact_mut(contact);
        record.chain_key = keys.next_ck.clone();
        record.resume_index = resuming.n + 1;
        self.tries.remove(&contact);
        self.reseed(contact, &keys.msg_seed, Dir::I, actions)?;
        self.confirm(id, contact, actions);
        let mut session = Session::new(&keys, true);
        let confirmation = session
            .seal::<B>(&EMPTY)?
            .expect("a new session has counters left");
        self.establish(id, contact, session, false, actions);
        self.send(id, &confirmation, actions);
        self.flush(contact, actions)
    }

    /// Handles an opened DATA frame, or closes the link if it did not open.
    /// R's first frame commits `CK_{n+1}` and reseeds its chains before any
    /// message is shown (spec §6, §8).
    fn receive_data(
        &mut self,
        id: LinkId,
        contact: ContactId,
        opened: Option<Zeroizing<Vec<u8>>>,
        confirms: bool,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let Some(plaintext) = opened else {
            self.close(id, CloseReason::Authentication, actions);
            return Ok(());
        };
        if confirms {
            let record = self.contact_mut(contact);
            let pending = record.pending.take().expect("R holds CK_{n+1}");
            record.chain_key = pending.chain_key;
            record.resume_index += 1;
            self.tries.remove(&contact);
            self.reseed(contact, &pending.msg_seed, Dir::R, actions)?;
            self.persist_contact(contact, actions);
        }
        let Ok(records) = parse(&plaintext) else {
            self.close(id, CloseReason::Malformed, actions);
            return Ok(());
        };
        let sent = self.contact(contact).sent_msgno;
        let beyond = records.iter().any(|record| match record {
            Record::Ack(msgno) | Record::Read(msgno) => *msgno > sent,
            _ => false,
        });
        if beyond {
            self.close(id, CloseReason::Malformed, actions);
            return Ok(());
        }
        let mut shown = Vec::new();
        let mut replies = Vec::new();
        let mut ack_due = false;
        let mut malformed = false;
        for record in records {
            match record {
                Record::Chat(chat) => {
                    ack_due = true;
                    self.accept(contact, chat.msgno, chat.text, &mut shown);
                }
                Record::Queued(queued) => {
                    let now = self.now_s;
                    let receiver = &mut self.contact_mut(contact).receiver;
                    let message = match receiver.open::<B>(&queued, now)? {
                        Ok(Opened::Message(inner)) => chain::parse_inner(&inner).map(Some),
                        Ok(Opened::Unknown) => Ok(None),
                        Err(error) => Err(error),
                    };
                    let Ok(message) = message else {
                        malformed = true;
                        break;
                    };
                    ack_due = true;
                    if let Some((msgno, text)) = message {
                        self.accept(contact, msgno, text, &mut shown);
                    }
                }
                Record::Ack(msgno) => self.acked(contact, msgno, actions, &mut shown),
                Record::Read(msgno) => {
                    let receipts = self.device.as_ref().expect("restored").read_receipts;
                    let record = self.contact_mut(contact);
                    if receipts && msgno > record.peer_read {
                        record.peer_read = msgno;
                        shown.push(Action::ChatRead { contact, msgno });
                    }
                }
                Record::Expired { from, to } => {
                    ack_due = true;
                    let received = &mut self.contact_mut(contact).received;
                    if !received.covers(from, to) {
                        received.insert(from, to);
                        shown.push(Action::ChatsExpired { contact, from, to });
                    }
                }
                Record::Courier(courier) => {
                    if self.courier_record(contact, courier, &mut replies, &mut shown, actions)? {
                        malformed = true;
                        break;
                    }
                }
            }
        }
        self.persist_contact(contact, actions);
        actions.extend(shown);
        if malformed {
            self.close(id, CloseReason::Malformed, actions);
            return Ok(());
        }
        let ack = ack_due.then(|| Record::Ack(self.contact(contact).received.contiguous));
        let records = ack
            .into_iter()
            .chain(replies.into_iter().map(Record::Courier))
            .collect();
        self.send_records(contact, records, actions)
    }

    /// Shows a received message unless it is a duplicate.
    fn accept(&mut self, contact: ContactId, msgno: u32, text: String, shown: &mut Vec<Action>) {
        let received = &mut self.contact_mut(contact).received;
        if !received.contains(msgno) {
            received.insert(msgno, msgno);
            shown.push(Action::ChatReceived {
                contact,
                msgno,
                text,
            });
        }
    }

    /// Handles the peer's ACK: every message up to `msgno` was delivered.
    fn acked(
        &mut self,
        contact: ContactId,
        msgno: u32,
        actions: &mut Vec<Action>,
        shown: &mut Vec<Action>,
    ) {
        let record = self.contact_mut(contact);
        if msgno <= record.peer_acked {
            return;
        }
        record.peer_acked = msgno;
        record.expired.retain(|&(_, to)| to > msgno);
        let mut delivered: Vec<u32> = record
            .unacked
            .iter()
            .copied()
            .filter(|&sent| sent <= msgno)
            .collect();
        record.unacked.retain(|&sent| sent > msgno);
        let rest = record.queued.split_off(&(msgno + 1));
        let queued = core::mem::replace(&mut record.queued, rest);
        for (&sent, outgoing) in &queued {
            actions.push(Action::DeleteQueued {
                contact,
                msgno: sent,
            });
            if let Some(own) = &outgoing.envelope {
                let tombstone = Tombstone {
                    tag: own.tag,
                    s: *own.s,
                    expiry_min: own.expiry_min,
                };
                self.store_tombstone(tombstone, actions);
            }
        }
        delivered.extend(queued.into_keys());
        delivered.sort_unstable();
        for sent in delivered {
            self.unacked.remove(&(contact, sent));
            shown.push(Action::ChatDelivered {
                contact,
                msgno: sent,
            });
        }
    }

    /// Sends CHAT on the contact's session, or seals and stores it as
    /// QUEUED; the rows are persisted before the message is shown (spec §8).
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
        let record = self.contact(contact);
        if record.send.is_none() {
            actions.push(reject(ChatRejection::NoSession));
            return Ok(());
        }
        let Some(msgno) = record.next_msgno() else {
            actions.push(reject(ChatRejection::Exhausted));
            return Ok(());
        };
        if record.unacked.len() + record.queued.len() >= MAX_SKIPPED {
            actions.push(reject(ChatRejection::QueueFull));
            return Ok(());
        }
        let Ok(inner) = chain::inner(msgno, text) else {
            actions.push(reject(ChatRejection::TooLong));
            return Ok(());
        };
        if let Some((id, link)) = self.session_mut(contact) {
            let chat = Record::Chat(Chat {
                msgno,
                text: text.into(),
            });
            let plaintext = plaintext(&[chat]).expect("an inner-sized text fits a CHAT");
            if let Some(frame) = link.session.seal::<B>(&plaintext)? {
                let record = self.contact_mut(contact);
                record.sent_msgno = msgno;
                record.unacked.push(msgno);
                self.unacked
                    .insert((contact, msgno), (self.now_s, Zeroizing::new(text.into())));
                self.persist_contact(contact, actions);
                self.send(id, &frame, actions);
                actions.push(Action::ChatSent { contact, msgno });
                return Ok(());
            }
            self.close(id, CloseReason::Exhausted, actions);
        }
        let now = self.now_s;
        let record = self.contact_mut(contact);
        let Some((queued, delivered)) = record.send.as_mut().expect("checked").seal::<B>(&inner)?
        else {
            actions.push(reject(ChatRejection::Exhausted));
            return Ok(());
        };
        record.sent_msgno = msgno;
        let envelope = self.own_envelope(contact, &queued, delivered, inner.len())?;
        let record = self.contact_mut(contact);
        let outgoing = Outgoing {
            created_s: now,
            queued,
            envelope,
        };
        let row = outgoing.row(contact, msgno);
        record.queued.insert(msgno, outgoing);
        self.persist_contact(contact, actions);
        actions.push(Action::PutQueued {
            contact,
            msgno,
            state: row.state,
        });
        actions.push(Action::ChatQueued { contact, msgno });
        Ok(())
    }

    /// Raises the local read mark and sends READ in session (ADR 0034 §4).
    fn mark_read(
        &mut self,
        contact: ContactId,
        msgno: u32,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        if !self.has_contact(contact) {
            return Err(CoreError::UnknownContact);
        }
        let record = self.contact_mut(contact);
        if msgno <= record.read_marked || !record.received.contains(msgno) {
            return Ok(());
        }
        record.read_marked = msgno;
        self.persist_contact(contact, actions);
        let receipts = self.device.as_ref().expect("restored").read_receipts;
        if receipts && self.session_mut(contact).is_some() {
            self.send_records(contact, vec![Record::Read(msgno)], actions)?;
        }
        Ok(())
    }

    /// Installs generation `resume_index mod 256` from `msg_seed`; queued
    /// messages of a colliding generation expire (spec §8, OI-5).
    fn reseed(
        &mut self,
        contact: ContactId,
        msg_seed: &[u8; 32],
        own: Dir,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let peer = own.peer();
        let send = chain::seed::<B>(msg_seed, own)?;
        let receive = chain::seed::<B>(msg_seed, peer)?;
        let now = self.now_s;
        let record = self.contact_mut(contact);
        let gen_ = record.resume_index as u8;
        let colliding: Vec<u32> = record
            .queued
            .iter()
            .filter(|(_, outgoing)| outgoing.queued.gen_ == gen_)
            .map(|(&msgno, _)| msgno)
            .collect();
        record.send = Some(SendChain {
            gen_,
            dir: own,
            idx: 0,
            key: send,
        });
        record.receiver.reseed(gen_, peer, receive, now);
        self.expire_messages(contact, &colliding, actions);
        Ok(())
    }

    /// Gives up on `msgnos`: queued rows are deleted and the numbers are
    /// announced with EXPIRED at the next session.
    fn expire_messages(&mut self, contact: ContactId, msgnos: &[u32], actions: &mut Vec<Action>) {
        if msgnos.is_empty() {
            return;
        }
        let record = self.contact_mut(contact);
        let mut deleted = Vec::new();
        for &msgno in msgnos {
            if record.queued.remove(&msgno).is_some() {
                deleted.push(msgno);
            }
            insert_range(&mut record.expired, msgno);
        }
        self.persist_contact(contact, actions);
        actions.extend(
            deleted
                .into_iter()
                .map(|msgno| Action::DeleteQueued { contact, msgno }),
        );
        for &msgno in msgnos {
            self.unacked.remove(&(contact, msgno));
            actions.push(Action::ChatExpired { contact, msgno });
        }
    }

    /// Applies the 7-day bounds to every contact (spec §8, ADR 0034 §4).
    fn maintain(&mut self, actions: &mut Vec<Action>) {
        let now = self.now_s;
        let ids: Vec<ContactId> = self
            .device
            .as_ref()
            .expect("restored")
            .contacts
            .iter()
            .map(|contact| contact.id)
            .collect();
        for contact in ids {
            let record = self.contact_mut(contact);
            let receiver = &mut record.receiver;
            let before = (receiver.chains.len(), receiver.skipped.len());
            receiver.prune(now);
            let pruned = before != (receiver.chains.len(), receiver.skipped.len());
            let stale: Vec<u32> = record
                .queued
                .iter()
                .filter(|(_, outgoing)| outgoing.created_s.saturating_add(RETENTION_S) <= now)
                .map(|(&msgno, _)| msgno)
                .collect();
            if stale.is_empty() && pruned {
                self.persist_contact(contact, actions);
            }
            self.expire_messages(contact, &stale, actions);
        }
        self.maintain_couriers(actions);
    }

    /// Re-seals the contact's unacked in-session CHATs as QUEUED under the
    /// same numbers; without a chain they expire (spec §8).
    fn reseal(&mut self, contact: ContactId, actions: &mut Vec<Action>) {
        let record = self.contact_mut(contact);
        let msgnos = core::mem::take(&mut record.unacked);
        if msgnos.is_empty() {
            return;
        }
        let mut rows = Vec::new();
        let mut lost = Vec::new();
        for msgno in msgnos {
            let (created_s, text) = self.unacked.remove(&(contact, msgno)).expect("held text");
            let inner = chain::inner(msgno, &text).expect("checked when sent");
            let record = self.contact_mut(contact);
            let sealed = record
                .send
                .as_mut()
                .map(|send| send.seal::<B>(&inner))
                .transpose()
                .ok()
                .flatten()
                .flatten();
            let Some((queued, delivered)) = sealed else {
                lost.push(msgno);
                continue;
            };
            let envelope = self
                .own_envelope(contact, &queued, delivered, inner.len())
                .ok()
                .flatten();
            let outgoing = Outgoing {
                created_s,
                queued,
                envelope,
            };
            rows.push(outgoing.row(contact, msgno));
            self.contact_mut(contact).queued.insert(msgno, outgoing);
        }
        self.persist_contact(contact, actions);
        actions.extend(rows.into_iter().map(|row| Action::PutQueued {
            contact,
            msgno: row.msgno,
            state: row.state,
        }));
        self.expire_messages(contact, &lost, actions);
    }

    /// Sends every queued message, the expired ranges and the read mark at
    /// the start of a session (spec §8).
    fn flush(&mut self, contact: ContactId, actions: &mut Vec<Action>) -> Result<(), CoreError> {
        let receipts = self.device.as_ref().expect("restored").read_receipts;
        let record = self.contact(contact);
        let mut records: Vec<Record> = record
            .queued
            .values()
            .map(|outgoing| Record::Queued(outgoing.queued.clone()))
            .collect();
        records.extend(
            record
                .expired
                .iter()
                .map(|&(from, to)| Record::Expired { from, to }),
        );
        if receipts && record.read_marked > 0 {
            records.push(Record::Read(record.read_marked));
        }
        records.extend(self.inventory(contact).into_iter().map(Record::Courier));
        self.send_records(contact, records, actions)
    }

    /// Packs `records` greedily into DATA frames; a session out of counters
    /// closes the link (spec §7).
    fn send_records(
        &mut self,
        contact: ContactId,
        records: Vec<Record>,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let mut frames = Vec::new();
        let mut batch: Vec<Record> = Vec::new();
        for record in records {
            batch.push(record);
            if plaintext(&batch).is_err() {
                let record = batch.pop().expect("just pushed");
                frames.push(plaintext(&batch).expect("fitted before"));
                batch = vec![record];
            }
        }
        if !batch.is_empty() {
            frames.push(plaintext(&batch).expect("one record fits a frame"));
        }
        for frame in frames {
            let (id, link) = self.session_mut(contact).expect("in session");
            let Some(sealed) = link.session.seal::<B>(&frame)? else {
                self.close(id, CloseReason::Exhausted, actions);
                return Ok(());
            };
            self.send(id, &sealed, actions);
        }
        Ok(())
    }

    /// The contact's established session link.
    fn session_mut(&mut self, contact: ContactId) -> Option<(LinkId, &mut SessionLink)> {
        self.links
            .iter_mut()
            .find_map(|(&id, link)| match &mut link.state {
                LinkState::Session(session) if session.contact == contact => {
                    Some((id, &mut **session))
                }
                _ => None,
            })
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
            exchange: couriering::Exchange::default(),
        }));
    }

    fn cancel_deadline(&mut self, id: LinkId, actions: &mut Vec<Action>) {
        let timer = self.links[&id].deadline;
        self.timers.remove(&timer);
        actions.push(Action::CancelTimer { timer });
    }

    /// Persists a contact after a valid S1 or S2; a contact paired on `id`
    /// becomes a contact only now (ADR 0043).
    fn confirm(&mut self, id: LinkId, contact: ContactId, actions: &mut Vec<Action>) {
        let link = self.links.get_mut(&id).expect("live link");
        let paired = link.provisional.take().is_some();
        self.persist_contact(contact, actions);
        if paired {
            actions.push(Action::ContactAdded { contact });
        }
    }

    fn persist_contact(&self, contact: ContactId, actions: &mut Vec<Action>) {
        let row = self.contact(contact).row();
        actions.push(Action::PersistContact {
            contact,
            state: row.state,
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
            self.admission.link_dropped(clock.mono_ms, &link.address);
        }
    }

    /// Closes a link whose pre-auth deadline passed; a pairing in flight is a
    /// transport failure (spec §5.6).
    fn expire(&mut self, clock: Clock, id: LinkId, actions: &mut Vec<Action>) {
        let link = self.remove_link(id, actions);
        if link.state.pairing() {
            self.admission
                .transport_failure(clock.mono_ms, &link.address);
        }
        actions.push(Action::Disconnect {
            link: id,
            reason: CloseReason::Expired,
        });
    }

    /// Closes a link after a protocol failure; a failed pairing backs off the address.
    fn abort(&mut self, clock: Clock, id: LinkId, reason: CloseReason, actions: &mut Vec<Action>) {
        let pairing = self.links[&id].state.pairing();
        self.fail(clock, id, pairing, reason, actions);
    }

    fn fail(
        &mut self,
        clock: Clock,
        id: LinkId,
        pairing: bool,
        reason: CloseReason,
        actions: &mut Vec<Action>,
    ) {
        let link = self.remove_link(id, actions);
        if pairing {
            self.admission
                .protocol_failure(clock.mono_ms, &link.address);
        }
        actions.push(Action::Disconnect { link: id, reason });
    }

    /// Closes a link without counting it as a failed attempt.
    fn close(&mut self, id: LinkId, reason: CloseReason, actions: &mut Vec<Action>) {
        self.remove_link(id, actions);
        actions.push(Action::Disconnect { link: id, reason });
    }

    fn remove_link(&mut self, id: LinkId, actions: &mut Vec<Action>) -> Link {
        let link = self.links.remove(&id).expect("live link");
        if self.timers.remove(&link.deadline).is_some() {
            actions.push(Action::CancelTimer {
                timer: link.deadline,
            });
        }
        if let LinkState::Session(session) = &link.state {
            self.reseal(session.contact, actions);
        }
        if let Some(contact) = link.provisional {
            let device = self.device.as_mut().expect("restored");
            device.contacts.retain(|record| record.id != contact);
            self.tries.remove(&contact);
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

    /// At most one link per contact is past S1 (spec §6, OI-17); a
    /// provisional contact belongs to the link that paired it (ADR 0043).
    fn in_session(&self, contact: ContactId, asking: LinkId) -> bool {
        self.links.iter().any(|(&id, link)| {
            link.state.contact() == Some(contact)
                || (id != asking && link.provisional == Some(contact))
        })
    }

    fn is_provisional(&self, contact: ContactId) -> bool {
        self.links
            .values()
            .any(|link| link.provisional == Some(contact))
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

/// Adds `msgno` to canonical, non-adjacent ascending ranges.
fn insert_range(ranges: &mut Vec<(u32, u32)>, msgno: u32) {
    let at = ranges.partition_point(|&(_, to)| to < msgno);
    if ranges.get(at).is_some_and(|&(from, _)| from <= msgno) {
        return;
    }
    let joins_below = at > 0 && ranges[at - 1].1 + 1 == msgno;
    let joins_above = ranges.get(at).is_some_and(|&(from, _)| from - 1 == msgno);
    match (joins_below, joins_above) {
        (true, true) => {
            ranges[at - 1].1 = ranges[at].1;
            ranges.remove(at);
        }
        (true, false) => ranges[at - 1].1 = msgno,
        (false, true) => ranges[at].0 = msgno,
        (false, false) => ranges.insert(at, (msgno, msgno)),
    }
}

/// R's chain `CK_n`, or the pending `CK_{n+1}`, with I's pairing role (spec §6).
fn candidate(contact: &Contact, pending: bool) -> (Chain<'_>, PairingRole) {
    let ck = match &contact.pending {
        Some(key) if pending => &key.chain_key,
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

/// The reason for a fault of the peer, which closes the link; a backend failure is local.
fn peer_fault(error: ResumeError) -> Result<CloseReason, CoreError> {
    match error {
        ResumeError::Crypto(error) => Err(error.into()),
        ResumeError::Malformed => Ok(CloseReason::Malformed),
        ResumeError::Authentication => Ok(CloseReason::Authentication),
    }
}

/// Why a pairing frame closed the link; [`PairingError::Crypto`] is local and never gets here.
fn pairing_reason(error: &PairingError) -> CloseReason {
    match error {
        PairingError::Malformed | PairingError::Crypto(_) => CloseReason::Malformed,
        PairingError::Version | PairingError::Mode => CloseReason::Unsupported,
        PairingError::Commitment => CloseReason::Commitment,
        PairingError::Authentication => CloseReason::Authentication,
        PairingError::Card(_) => CloseReason::Card,
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
    use crate::chain::{Queued, ReceiveChain, Receiver, SendChain};
    use crate::data::CourierRecord;
    use crate::resume::Keys;
    use crate::state::{Held, Received};
    use cairn_crypto::Reference;

    pub(super) const CLOCK: Clock = Clock {
        mono_ms: 0,
        unix_s: 1_761_177_600,
    };
    pub(super) const LINK: LinkId = LinkId(0);
    pub(super) const CONTACT: ContactId = ContactId(0);

    fn keys() -> Keys {
        Keys {
            i_to_r: Zeroizing::new([1; 32]),
            r_to_i: Zeroizing::new([2; 32]),
            next_ck: Zeroizing::new([3; 32]),
            msg_seed: Zeroizing::new([12; 32]),
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
            route_key: Zeroizing::new([12; 32]),
            resume_index: 0,
            chain_key: Zeroizing::new([10; 32]),
            sent_msgno,
            pending: pending.then(|| Pending {
                chain_key: Zeroizing::new([11; 32]),
                msg_seed: Zeroizing::new([13; 32]),
            }),
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

    const FRESH: fn() -> Event = || Event::Restore {
        device: None,
        contacts: Vec::new(),
        queued: Vec::new(),
        courier: Vec::new(),
    };

    /// R's core in `session` with contact 0 on `LINK`, and I's session;
    /// `unconfirmed` leaves R holding `CK_{n+1}`. Contact 0 has a message
    /// chain; contact 1 has never resumed.
    pub(super) fn in_session(
        sent_msgno: u32,
        session: Session,
        unconfirmed: bool,
    ) -> (Core<Reference>, Session) {
        let mut core = Core::<Reference>::new();
        core.handle(CLOCK, FRESH()).unwrap();
        let contacts = &mut core.device.as_mut().unwrap().contacts;
        let mut resumed = contact(CONTACT, sent_msgno, unconfirmed);
        resumed.send = Some(SendChain {
            gen_: 0,
            dir: Dir::R,
            idx: 0,
            key: Zeroizing::new([14; 32]),
        });
        contacts.push(resumed);
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
            exchange: couriering::Exchange::default(),
        }));
        (core, Session::new(&keys(), true))
    }

    pub(super) fn responder() -> Session {
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

    /// Delivers a whole frame as the checked fragments of a 517-byte MTU (ADR 0042).
    fn receive(core: &mut Core<Reference>, frame: Vec<u8>) -> Vec<Action> {
        fragment(&frame, 517)
            .unwrap()
            .into_iter()
            .flat_map(|fragment| {
                core.handle(
                    CLOCK,
                    Event::Received {
                        link: LINK,
                        fragment,
                    },
                )
                .unwrap()
            })
            .collect()
    }

    fn sealed(peer: &mut Session, records: &[Record]) -> Vec<u8> {
        peer.seal::<Reference>(&plaintext(records).unwrap())
            .unwrap()
            .unwrap()
    }

    fn count(actions: &[Action], pick: impl Fn(&Action) -> bool) -> usize {
        actions.iter().filter(|action| pick(action)).count()
    }

    // `Core<B>` methods are counted per test binary, so this module covers the
    // DATA paths whole, including those the loopback cannot reach.

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn r_commits_the_pending_key_before_showing_the_first_chat() {
        let (mut core, mut peer) = in_session(0, responder(), true);
        let frame = peer
            .seal::<Reference>(
                &plaintext(&[Record::Chat(Chat {
                    msgno: 1,
                    text: "hi".into(),
                })])
                .unwrap(),
            )
            .unwrap()
            .unwrap();

        let actions = receive(&mut core, frame);

        let shown = actions
            .iter()
            .position(|action| {
                *action
                    == Action::ChatReceived {
                        contact: CONTACT,
                        msgno: 1,
                        text: "hi".into(),
                    }
            })
            .unwrap();
        assert!(matches!(actions[0], Action::PersistContact { .. }));
        assert!(matches!(actions[1], Action::PersistContact { .. }));
        assert_eq!(shown, 2);
        assert!(matches!(actions[3], Action::Send { link: LINK, .. }), "ACK");
        let record = core.contact(CONTACT);
        assert_eq!(
            (
                *record.chain_key,
                record.pending.is_none(),
                record.resume_index,
                record.send.as_ref().map(|send| send.gen_),
            ),
            ([11; 32], true, 1, Some(1))
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_frame_that_does_not_open_closes_the_link() {
        let (mut core, mut peer) = in_session(0, responder(), false);
        let mut frame = peer.seal::<Reference>(&EMPTY).unwrap().unwrap();
        frame[1] ^= 1;

        let actions = receive(&mut core, frame);

        assert_eq!(
            actions.last(),
            Some(&Action::Disconnect {
                link: LINK,
                reason: CloseReason::Authentication
            })
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_chat_is_persisted_then_sent() {
        let (mut core, _) = in_session(0, responder(), false);

        let actions = send_chat(&mut core, CONTACT);

        assert!(matches!(
            &actions[..],
            [
                Action::PersistContact { .. },
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
            send(&mut core, CONTACT, &"x".repeat(4046)),
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

        assert_eq!(
            actions.last(),
            Some(&Action::Disconnect {
                link: LINK,
                reason: CloseReason::Malformed
            })
        );
        assert!(core.links.is_empty());
    }

    #[test]
    fn a_second_inventory_end_closes_the_link() {
        let (mut core, mut peer) = in_session(0, responder(), false);
        let end = || Record::Courier(CourierRecord::Inventory(Vec::new()));
        let frame = sealed(&mut peer, &[end(), end()]);

        let actions = receive(&mut core, frame);

        assert_eq!(
            actions.last(),
            Some(&Action::Disconnect {
                link: LINK,
                reason: CloseReason::Malformed
            })
        );
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
    fn a_session_out_of_nonces_closes_and_queues_the_chat() {
        let mut exhausted = responder();
        exhausted.exhaust();
        let (mut core, _) = in_session(0, exhausted, false);

        let actions = send_chat(&mut core, CONTACT);

        assert!(actions.contains(&Action::Disconnect {
            link: LINK,
            reason: CloseReason::Exhausted
        }));
        assert_eq!(
            actions.last(),
            Some(&Action::ChatQueued {
                contact: CONTACT,
                msgno: 1,
            })
        );
        assert_eq!(core.contact(CONTACT).sent_msgno, 1);
        assert_eq!(core.contact(CONTACT).queued.len(), 1);
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
        core.handle(CLOCK, FRESH()).unwrap();
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
                beacon: vec![0; 8],
            },
        )
        .unwrap();

        assert_eq!(
            core.contact(CONTACT).peer.beacon_day,
            day(CLOCK.unix_s - 300)
        );
    }

    #[test]
    fn rows_without_a_device_row_are_invalid() {
        let queued = Outgoing {
            created_s: 0,
            queued: Queued {
                gen_: 0,
                idx: 0,
                ct: vec![0; 48],
            },
            envelope: None,
        };
        let tombstone = Held::Tombstone(crate::state::Tombstone {
            tag: [1; 16],
            s: [1; 16],
            expiry_min: 1,
        });
        let restore = |contacts, queued, courier| {
            Core::<Reference>::new().handle(
                CLOCK,
                Event::Restore {
                    device: None,
                    contacts,
                    queued,
                    courier,
                },
            )
        };

        let results = [
            restore(
                vec![contact(CONTACT, 0, false).row()],
                Vec::new(),
                Vec::new(),
            ),
            restore(Vec::new(), vec![queued.row(CONTACT, 1)], Vec::new()),
            restore(Vec::new(), Vec::new(), vec![tombstone.row(0)]),
        ];

        assert_eq!(
            results,
            [
                Err(CoreError::InvalidBlob),
                Err(CoreError::InvalidBlob),
                Err(CoreError::InvalidBlob)
            ]
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn courier_settings_outside_their_ranges_are_refused() {
        let mut core = in_session(0, responder(), false).0;
        let mut set = |copies, lifetime_minutes| {
            core.handle(
                CLOCK,
                Event::SetCourier {
                    enabled: true,
                    copies,
                    lifetime_minutes,
                },
            )
            .err()
        };

        let results = [
            set(0, 1440),
            set(17, 1440),
            set(6, 59),
            set(6, 10_081),
            set(16, 60),
            set(1, 10_080),
        ];

        let refused = Some(CoreError::InvalidCourierConfig);
        assert_eq!(results, [refused, refused, refused, refused, None, None]);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn an_ack_beyond_the_last_sent_number_closes_the_link() {
        let (mut core, mut peer) = in_session(0, responder(), false);
        let frame = sealed(&mut peer, &[Record::Ack(1)]);

        let actions = receive(&mut core, frame);

        assert_eq!(
            actions.last(),
            Some(&Action::Disconnect {
                link: LINK,
                reason: CloseReason::Malformed
            })
        );
        assert_eq!(
            count(&actions, |a| matches!(a, Action::PersistContact { .. })),
            0
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_queued_record_of_an_unknown_generation_is_acked_but_not_shown() {
        let (mut core, mut peer) = in_session(0, responder(), false);
        let unknown = Record::Queued(Queued {
            gen_: 9,
            idx: 0,
            ct: vec![0; 48],
        });
        let frame = sealed(&mut peer, &[unknown]);

        let actions = receive(&mut core, frame);

        assert!(matches!(
            actions[..],
            [
                Action::PersistContact { .. },
                Action::Send { link: LINK, .. }
            ]
        ));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_queued_record_that_does_not_open_closes_the_link() {
        let (mut core, mut peer) = in_session(0, responder(), false);
        let receiver = &mut core.contact_mut(CONTACT).receiver;
        receiver.reseed(0, Dir::R, Zeroizing::new([15; 32]), CLOCK.unix_s);
        let forged = Record::Queued(Queued {
            gen_: 0,
            idx: 0,
            ct: vec![0; 48],
        });
        let frame = sealed(&mut peer, &[forged]);

        let actions = receive(&mut core, frame);

        assert_eq!(
            actions.last(),
            Some(&Action::Disconnect {
                link: LINK,
                reason: CloseReason::Malformed
            })
        );
        assert_eq!(count(&actions, |a| matches!(a, Action::Send { .. })), 0);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn stale_receipts_and_repeated_expiry_notices_change_nothing() {
        let (mut core, mut peer) = in_session(2, responder(), false);
        let expired = Record::Expired { from: 2, to: 3 };
        let frame = sealed(
            &mut peer,
            &[
                Record::Ack(2),
                Record::Ack(1),
                Record::Read(1),
                Record::Read(1),
                expired.clone(),
                expired,
            ],
        );

        let actions = receive(&mut core, frame);

        let shown = (
            count(&actions, |a| matches!(a, Action::ChatRead { .. })),
            count(&actions, |a| matches!(a, Action::ChatsExpired { .. })),
            core.contact(CONTACT).peer_acked,
        );
        assert_eq!(shown, (1, 1, 2));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_read_mark_is_not_shown_with_receipts_off() {
        let (mut core, mut peer) = in_session(1, responder(), false);
        core.device.as_mut().unwrap().read_receipts = false;
        let frame = sealed(&mut peer, &[Record::Read(1)]);

        let actions = receive(&mut core, frame);

        assert_eq!(count(&actions, |a| matches!(a, Action::ChatRead { .. })), 0);
        assert_eq!(core.contact(CONTACT).peer_read, 0);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_session_out_of_nonces_closes_instead_of_acking() {
        let mut exhausted = responder();
        exhausted.exhaust();
        let (mut core, mut peer) = in_session(0, exhausted, false);
        let chat = Record::Chat(Chat {
            msgno: 1,
            text: "hi".into(),
        });
        let frame = sealed(&mut peer, &[chat]);

        let actions = receive(&mut core, frame);

        assert_eq!(count(&actions, |a| matches!(a, Action::Send { .. })), 0);
        assert_eq!(
            actions.last(),
            Some(&Action::Disconnect {
                link: LINK,
                reason: CloseReason::Exhausted
            })
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_chat_with_neither_session_nonces_nor_chain_indices_is_rejected() {
        let mut exhausted = responder();
        exhausted.exhaust();
        let (mut core, _) = in_session(0, exhausted, false);
        core.contact_mut(CONTACT).send.as_mut().unwrap().idx = u32::MAX;

        let actions = send_chat(&mut core, CONTACT);

        assert_eq!(
            actions.last(),
            Some(&Action::ChatRejected {
                contact: CONTACT,
                reason: ChatRejection::Exhausted,
            })
        );
        assert!(core.contact(CONTACT).queued.is_empty());
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_chat_to_a_contact_without_a_session_is_queued_beside_another_session() {
        let (mut core, _) = in_session(0, responder(), false);
        core.contact_mut(ContactId(1)).send = Some(SendChain {
            gen_: 0,
            dir: Dir::R,
            idx: 0,
            key: Zeroizing::new([14; 32]),
        });

        let actions = send_chat(&mut core, ContactId(1));

        assert_eq!(
            actions.last(),
            Some(&Action::ChatQueued {
                contact: ContactId(1),
                msgno: 1,
            })
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn marking_read_needs_a_known_contact_and_a_new_received_message() {
        let (mut core, _) = in_session(0, responder(), false);
        let mut mark = |contact, msgno| core.handle(CLOCK, Event::MarkRead { contact, msgno });

        let results = [mark(ContactId(9), 1), mark(CONTACT, 0), mark(CONTACT, 3)];

        assert_eq!(
            results,
            [Err(CoreError::UnknownContact), Ok(vec![]), Ok(vec![])]
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn pruning_an_old_receive_chain_persists_the_contact() {
        let (mut core, _) = in_session(0, responder(), false);
        core.contact_mut(CONTACT)
            .receiver
            .chains
            .push(ReceiveChain {
                gen_: 3,
                dir: Dir::R,
                next: 0,
                key: Zeroizing::new([15; 32]),
                superseded_s: Some(CLOCK.unix_s - RETENTION_S),
            });

        let actions = core
            .handle(CLOCK, Event::SetReadReceipts { enabled: true })
            .unwrap();

        assert!(matches!(
            actions[..],
            [
                Action::PersistContact {
                    contact: CONTACT,
                    ..
                },
                Action::PersistDevice { .. }
            ]
        ));
        assert!(core.contact(CONTACT).receiver.chains.is_empty());
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn an_unacked_chat_expires_when_the_link_drops_without_chain_indices_left() {
        let (mut core, _) = in_session(0, responder(), false);
        send_chat(&mut core, CONTACT);
        core.contact_mut(CONTACT).send.as_mut().unwrap().idx = u32::MAX;

        let actions = core.handle(CLOCK, Event::LinkDown { link: LINK }).unwrap();

        assert!(actions.contains(&Action::ChatExpired {
            contact: CONTACT,
            msgno: 1,
        }));
        assert_eq!(core.contact(CONTACT).expired, [(1, 1)]);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_restart_expires_chats_that_were_sent_but_never_acked() {
        let (mut core, _) = in_session(0, responder(), false);
        send_chat(&mut core, CONTACT);
        core.device.as_mut().unwrap().next_contact = 2;
        let device = core.device.as_ref().unwrap();
        let rows = Event::Restore {
            device: Some(device.row()),
            contacts: device.contacts.iter().map(Contact::row).collect(),
            queued: Vec::new(),
            courier: Vec::new(),
        };
        let mut restarted = Core::<Reference>::new();

        let actions = restarted.handle(CLOCK, rows).unwrap();

        assert!(actions.contains(&Action::ChatExpired {
            contact: CONTACT,
            msgno: 1,
        }));
        assert!(restarted.contact(CONTACT).unacked.is_empty());
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_queued_record_opens_under_the_receive_chain_and_is_shown() {
        let (mut core, mut peer) = in_session(0, responder(), false);
        let key = || Zeroizing::new([15; 32]);
        let receiver = &mut core.contact_mut(CONTACT).receiver;
        receiver.reseed(0, Dir::R, key(), CLOCK.unix_s);
        let mut chain = SendChain {
            gen_: 0,
            dir: Dir::R,
            idx: 0,
            key: key(),
        };
        let inner = chain::inner(1, "later").unwrap();
        let (queued, _) = chain.seal::<Reference>(&inner).unwrap().unwrap();
        let frame = sealed(&mut peer, &[Record::Queued(queued)]);

        let actions = receive(&mut core, frame);

        assert!(actions.contains(&Action::ChatReceived {
            contact: CONTACT,
            msgno: 1,
            text: "later".into(),
        }));
        assert_eq!(
            actions.last().map(|a| matches!(a, Action::Send { .. })),
            Some(true)
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_queued_chat_expires_seven_days_after_it_was_sealed() {
        let (mut core, _) = in_session(1, responder(), false);
        let outgoing = Outgoing {
            created_s: CLOCK.unix_s - RETENTION_S,
            queued: Queued {
                gen_: 0,
                idx: 0,
                ct: vec![0; 48],
            },
            envelope: None,
        };
        core.contact_mut(CONTACT).queued.insert(1, outgoing);

        let actions = core
            .handle(CLOCK, Event::SetReadReceipts { enabled: true })
            .unwrap();

        assert!(actions.contains(&Action::DeleteQueued {
            contact: CONTACT,
            msgno: 1,
        }));
        assert!(actions.contains(&Action::ChatExpired {
            contact: CONTACT,
            msgno: 1,
        }));
        assert_eq!(core.contact(CONTACT).expired, [(1, 1)]);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_new_read_mark_is_persisted_and_sent_in_session() {
        let (mut core, _) = in_session(0, responder(), false);
        core.contact_mut(CONTACT).received.insert(1, 1);

        let actions = core
            .handle(
                CLOCK,
                Event::MarkRead {
                    contact: CONTACT,
                    msgno: 1,
                },
            )
            .unwrap();

        assert!(matches!(
            actions[..],
            [
                Action::PersistContact {
                    contact: CONTACT,
                    ..
                },
                Action::Send { link: LINK, .. }
            ]
        ));
        assert_eq!(core.contact(CONTACT).read_marked, 1);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn five_hundred_undelivered_chats_fill_the_queue() {
        let (mut core, _) = in_session(500, responder(), false);
        core.contact_mut(CONTACT).unacked = (1..=500).collect();

        let actions = send_chat(&mut core, CONTACT);

        assert_eq!(
            actions,
            [Action::ChatRejected {
                contact: CONTACT,
                reason: ChatRejection::QueueFull,
            }]
        );
    }

    #[test]
    fn events_before_restore_are_refused() {
        let mut core = Core::<Reference>::new();

        let result = core.handle(CLOCK, Event::SetReadReceipts { enabled: true });

        assert_eq!(result, Err(CoreError::NotRestored));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_second_restore_is_refused() {
        let (mut core, _) = in_session(0, responder(), false);

        let result = core.handle(CLOCK, FRESH());

        assert_eq!(result, Err(CoreError::AlreadyRestored));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn an_ack_tombstones_the_envelope_of_a_delivered_chat() {
        let (mut core, mut peer) = in_session(1, responder(), false);
        let outgoing = Outgoing {
            created_s: CLOCK.unix_s,
            queued: Queued {
                gen_: 0,
                idx: 0,
                ct: vec![0; 48],
            },
            envelope: Some(crate::state::OwnEnvelope {
                tag: [7; 16],
                s: Zeroizing::new([8; 16]),
                expiry_min: u32::MAX,
                copies: 6,
                renewed: false,
            }),
        };
        core.contact_mut(CONTACT).queued.insert(1, outgoing);
        let frame = sealed(&mut peer, &[Record::Ack(1)]);

        receive(&mut core, frame);

        let held: Vec<&Held> = core.device.as_ref().unwrap().held.values().collect();
        let tombstone = Held::Tombstone(crate::state::Tombstone {
            tag: [7; 16],
            s: [8; 16],
            expiry_min: u32::MAX,
        });
        assert_eq!(held, [&tombstone]);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_device_blob_that_does_not_decode_is_invalid() {
        let device = Persisted {
            blob: vec![0xff],
            version: 1,
        };
        let restore = Event::Restore {
            device: Some(device),
            contacts: Vec::new(),
            queued: Vec::new(),
            courier: Vec::new(),
        };

        let result = Core::<Reference>::new().handle(CLOCK, restore);

        assert_eq!(result, Err(CoreError::InvalidBlob));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn an_ack_delivers_unacked_and_queued_chats_in_order() {
        let (mut core, mut peer) = in_session(2, responder(), false);
        let outgoing = Outgoing {
            created_s: CLOCK.unix_s,
            queued: Queued {
                gen_: 0,
                idx: 0,
                ct: vec![0; 48],
            },
            envelope: None,
        };
        let record = core.contact_mut(CONTACT);
        record.unacked = vec![1];
        record.queued.insert(2, outgoing);
        let frame = sealed(&mut peer, &[Record::Ack(2)]);

        let actions = receive(&mut core, frame);

        let delivered: Vec<&Action> = actions
            .iter()
            .filter(|a| {
                matches!(
                    a,
                    Action::ChatDelivered { .. } | Action::DeleteQueued { .. }
                )
            })
            .collect();
        assert_eq!(
            delivered,
            [
                &Action::DeleteQueued {
                    contact: CONTACT,
                    msgno: 2,
                },
                &Action::ChatDelivered {
                    contact: CONTACT,
                    msgno: 1,
                },
                &Action::ChatDelivered {
                    contact: CONTACT,
                    msgno: 2,
                },
            ]
        );
        assert!(core.contact(CONTACT).queued.is_empty());
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_read_mark_is_persisted_but_not_sent_with_receipts_off() {
        let (mut core, _) = in_session(0, responder(), false);
        core.device.as_mut().unwrap().read_receipts = false;
        core.contact_mut(CONTACT).received.insert(1, 1);

        let actions = core
            .handle(
                CLOCK,
                Event::MarkRead {
                    contact: CONTACT,
                    msgno: 1,
                },
            )
            .unwrap();

        assert!(matches!(
            actions[..],
            [Action::PersistContact {
                contact: CONTACT,
                ..
            }]
        ));
        assert_eq!(core.contact(CONTACT).read_marked, 1);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_read_mark_without_a_session_is_persisted_for_the_next_one() {
        let (mut core, _) = in_session(0, responder(), false);
        core.contact_mut(ContactId(1)).received.insert(1, 1);

        let actions = core
            .handle(
                CLOCK,
                Event::MarkRead {
                    contact: ContactId(1),
                    msgno: 1,
                },
            )
            .unwrap();

        assert!(matches!(
            actions[..],
            [Action::PersistContact {
                contact: ContactId(1),
                ..
            }]
        ));
        assert_eq!(core.contact(ContactId(1)).read_marked, 1);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn an_unacked_chat_is_resealed_when_the_link_drops() {
        let (mut core, _) = in_session(0, responder(), false);
        send_chat(&mut core, CONTACT);

        let actions = core.handle(CLOCK, Event::LinkDown { link: LINK }).unwrap();

        assert!(actions.iter().any(|a| matches!(
            a,
            Action::PutQueued {
                contact: CONTACT,
                ..
            }
        )));
        let record = core.contact(CONTACT);
        assert!(record.unacked.is_empty());
        assert_eq!(record.queued.keys().copied().collect::<Vec<_>>(), [1]);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn records_beyond_one_frame_are_split_and_none_send_nothing() {
        let (mut core, _) = in_session(0, responder(), false);
        let mut expected_session = responder();
        let chat = |msgno| {
            Record::Chat(Chat {
                msgno,
                text: "x".repeat(3000),
            })
        };
        let expected: Vec<Action> = [chat(1), chat(2)]
            .into_iter()
            .flat_map(|record| {
                let frame = sealed(&mut expected_session, &[record]);
                fragment(&frame, 185).unwrap()
            })
            .map(|fragment| Action::Send {
                link: LINK,
                fragment,
            })
            .collect();
        let mut actions = Vec::new();

        core.send_records(CONTACT, Vec::new(), &mut actions)
            .unwrap();
        let empty = actions.len();
        core.send_records(CONTACT, vec![chat(1), chat(2)], &mut actions)
            .unwrap();

        assert_eq!(empty, 0);
        assert_eq!(actions, expected);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn mtu_changes_and_timers_reach_their_link() {
        let mut core = Core::<Reference>::new();
        core.handle(CLOCK, FRESH()).unwrap();
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
        let timer = *core.timers.keys().next().unwrap();

        for link in [LINK, LinkId(9)] {
            core.handle(CLOCK, Event::MtuChanged { link, mtu: 247 })
                .unwrap();
        }
        let mtu = core.links[&LINK].mtu;
        let fired = core.handle(CLOCK, Event::TimerFired { timer }).unwrap();
        let again = core.handle(CLOCK, Event::TimerFired { timer }).unwrap();

        assert_eq!(mtu, 247);
        assert_eq!(
            fired.last(),
            Some(&Action::Disconnect {
                link: LINK,
                reason: CloseReason::Expired
            })
        );
        assert!(again.is_empty());
    }

    #[test]
    fn expired_numbers_merge_into_canonical_ranges() {
        let mut ranges = vec![(1, 1), (3, 3), (6, 6), (10, 12)];

        for msgno in [2, 7, 9, 11, 14] {
            insert_range(&mut ranges, msgno);
        }

        assert_eq!(ranges, [(1, 3), (6, 7), (9, 12), (14, 14)]);
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
                Ok(CloseReason::Malformed),
                Ok(CloseReason::Authentication),
                Err(CoreError::Crypto(CryptoError::BackendFailure))
            ]
        );
    }

    #[test]
    fn each_pairing_failure_names_its_close_reason() {
        let errors = [
            PairingError::Malformed,
            PairingError::Version,
            PairingError::Mode,
            PairingError::Commitment,
            PairingError::Authentication,
            PairingError::Card(crate::card::CardError::Truncated),
        ];

        let reasons = errors.each_ref().map(pairing_reason);

        assert_eq!(
            reasons,
            [
                CloseReason::Malformed,
                CloseReason::Unsupported,
                CloseReason::Unsupported,
                CloseReason::Commitment,
                CloseReason::Authentication,
                CloseReason::Card,
            ]
        );
    }
}
