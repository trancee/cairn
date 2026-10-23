//! The `CairnCore` event loop (ADR 0004, ADR 0022).

use crate::admission::{Admission, TieBreak, tie_break};
use crate::card::Card;
use crate::framing::{MIN_ATT_MTU, PRE_AUTH_FRAME_LIMIT, Reassembler, fragment};
use crate::pairing::{AwaitingP2, AwaitingP3, AwaitingP4, Paired, PairingError};
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
const DAY_S: u64 = 86_400;

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
    Paired,
}

impl LinkState {
    fn pairing(&self) -> bool {
        !matches!(self, Self::Fresh | Self::Paired)
    }
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
    /// The pre-auth deadline; it leaves the timer map when it fires or pairing ends.
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
            Event::BeaconRead { link, .. } => self.beacon_read(clock, link, &mut actions)?,
            Event::Received { link, fragment } => {
                self.received(clock, link, &fragment, &mut actions)?;
            }
            Event::LinkDown { link } => self.link_down(clock, link, &mut actions),
            Event::TimerFired { timer } => {
                if let Some(link) = self.timers.remove(&timer) {
                    self.abort(clock, link, &mut actions);
                }
            }
            Event::SendChat { contact, .. } => {
                if !self.has_contact(contact) {
                    return Err(CoreError::UnknownContact);
                }
                actions.push(Action::ChatRejected {
                    contact,
                    reason: ChatRejection::NoSession,
                });
            }
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
            beacon_day: u32::try_from(clock.unix_s / DAY_S).unwrap_or(u32::MAX),
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

    /// Without beacon matching every read is a stranger: request admission (spec §5.6).
    fn beacon_read(
        &mut self,
        clock: Clock,
        id: LinkId,
        actions: &mut Vec<Action>,
    ) -> Result<(), CoreError> {
        let Some(link) = self.links.get(&id) else {
            return Ok(());
        };
        if link.gatt_role != GattRole::Central || !matches!(link.state, LinkState::Fresh) {
            return Err(CoreError::UnexpectedBeaconRead);
        }
        let address = link.address.clone();
        if self.pairing_in_flight() {
            self.close(id, actions);
            return Ok(());
        }
        if !self
            .admission
            .allows(clock.mono_ms, self.contact_count(), &address)
        {
            self.admission.back_off(clock.mono_ms, &address);
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
        if header.frame_type() != FrameType::Pair {
            self.abort(clock, id, actions);
            return Ok(());
        }
        let state = core::mem::replace(&mut link.state, LinkState::Fresh);
        let pairing = state.pairing();
        let outcome = match (link.gatt_role, header.sub(), state) {
            (GattRole::Peripheral, 0, LinkState::Fresh) => {
                return self.receive_p0(clock, id, &frame, actions);
            }
            (GattRole::Central, 1, LinkState::SentP0 { .. }) => {
                AwaitingP3::receive_p1::<B>(self.own_card(), &frame)
                    .map(|(state, p2)| Step::Advance(LinkState::AwaitingP3(Box::new(state)), p2))
            }
            (GattRole::Peripheral, 2, LinkState::AwaitingP2(state)) => state
                .receive_p2::<B>(&frame)
                .map(|(state, p3)| Step::Advance(LinkState::AwaitingP4(Box::new(state)), p3)),
            (GattRole::Central, 3, LinkState::AwaitingP3(state)) => state
                .receive_p3::<B>(&frame)
                .map(|(paired, p4)| Step::Admit(Box::new(paired), Some(p4))),
            (GattRole::Peripheral, 4, LinkState::AwaitingP4(state)) => state
                .receive_p4::<B>(&frame)
                .map(|paired| Step::Admit(Box::new(paired), None)),
            _ => Err(PairingError::Malformed),
        };
        match outcome {
            Ok(Step::Advance(state, reply)) => self.advance(id, state, &reply, actions),
            Ok(Step::Admit(paired, reply)) => {
                self.admit(clock, id, *paired, actions);
                if let Some(p4) = reply {
                    self.send(id, &p4, actions);
                }
            }
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
        let (state, p1) = AwaitingP2::start::<B>(self.own_card())?;
        self.advance(id, LinkState::AwaitingP2(Box::new(state)), &p1, actions);
        Ok(())
    }

    fn admit(&mut self, clock: Clock, id: LinkId, paired: Paired, actions: &mut Vec<Action>) {
        self.admission.record_admitted(clock.mono_ms);
        let device = self.device.as_mut().expect("restored");
        let contact = ContactId(device.next_contact);
        device.next_contact += 1;
        device.contacts.push(Contact::new(contact, paired));
        actions.push(Action::Persist {
            state: device.persist(),
        });
        let link = self.links.get_mut(&id).expect("admitted on a live link");
        link.state = LinkState::Paired;
        self.timers.remove(&link.deadline);
        actions.push(Action::CancelTimer {
            timer: link.deadline,
        });
        actions.push(Action::ContactAdded { contact });
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

    fn own_card(&self) -> Card {
        let device = self.device.as_ref().expect("restored");
        Card {
            caps: 0,
            beacon_day: device.beacon_day,
            beacon_key: device.beacon_key.clone(),
            name: String::new(),
            static_ek: None,
        }
    }
}

fn check_mtu(mtu: u16) -> Result<(), CoreError> {
    if mtu < MIN_ATT_MTU {
        return Err(CoreError::InvalidMtu);
    }
    Ok(())
}
