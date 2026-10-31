//! An in-memory loopback between cores (issue 31).

// Each test binary compiles this module and uses a different subset of it.
#![allow(dead_code)]

pub mod seeded;

use cairn_proto::{
    Action, Clock, CloseReason, ContactId, ContactRow, Core, CourierRow, Event, GattRole, LinkId,
    Persisted, QueuedRow, TimerId,
};
use seeded::Seeded;
use std::collections::{BTreeMap, VecDeque};

pub const MTU: u16 = 185;
pub const START: Clock = Clock {
    mono_ms: 1_000,
    unix_s: 1_761_177_600,
};

/// The rows a platform stores (ADR 0034 §1).
#[derive(Debug, Clone, Default)]
pub struct Store {
    pub device: Option<Persisted>,
    pub contacts: BTreeMap<ContactId, Persisted>,
    pub queued: BTreeMap<(ContactId, u32), Persisted>,
    pub courier: BTreeMap<u64, Persisted>,
}

impl Store {
    /// The `Restore` event for these rows.
    pub fn restore(&self) -> Event {
        Event::Restore {
            device: self.device.clone(),
            contacts: self
                .contacts
                .iter()
                .map(|(&contact, state)| ContactRow {
                    contact,
                    state: state.clone(),
                })
                .collect(),
            queued: self
                .queued
                .iter()
                .map(|(&(contact, msgno), state)| QueuedRow {
                    contact,
                    msgno,
                    state: state.clone(),
                })
                .collect(),
            courier: self
                .courier
                .iter()
                .map(|(&slot, state)| CourierRow {
                    slot,
                    state: state.clone(),
                })
                .collect(),
        }
    }

    /// Stores a row action; `false` for any other action.
    pub fn apply(&mut self, action: &Action) -> bool {
        match action {
            Action::PersistDevice { state } => self.device = Some(state.clone()),
            Action::PersistContact { contact, state } => {
                self.contacts.insert(*contact, state.clone());
            }
            Action::PutQueued {
                contact,
                msgno,
                state,
            } => {
                self.queued.insert((*contact, *msgno), state.clone());
            }
            Action::DeleteQueued { contact, msgno } => {
                self.queued.remove(&(*contact, *msgno));
            }
            Action::PutCourier { slot, state } => {
                self.courier.insert(*slot, state.clone());
            }
            Action::DeleteCourier { slot } => {
                self.courier.remove(slot);
            }
            _ => return false,
        }
        true
    }
}

pub struct Device {
    pub core: Core<Seeded>,
    /// Every action this device emitted, in order.
    pub log: Vec<Action>,
    pub store: Store,
    pub timers: BTreeMap<TimerId, u64>,
    /// Seconds this device's wall clock runs behind the network's.
    pub lag_s: u64,
}

/// Sees each sent fragment with its sender; `false` drops it.
pub type Intercept = Box<dyn FnMut(usize, &mut Vec<u8>) -> bool>;

pub struct Net {
    pub devices: Vec<Device>,
    pub clock: Clock,
    pub intercept: Option<Intercept>,
    /// Each link end and the peer end it delivers to.
    ends: BTreeMap<(usize, LinkId), (usize, LinkId)>,
    queue: VecDeque<(usize, Action)>,
    next_link: u64,
}

impl Net {
    pub fn new(count: usize, seed: u64) -> Self {
        Seeded::seed(seed);
        let mut net = Self {
            devices: (0..count)
                .map(|_| Device {
                    core: Core::new(),
                    log: Vec::new(),
                    store: Store::default(),
                    timers: BTreeMap::new(),
                    lag_s: 0,
                })
                .collect(),
            clock: START,
            intercept: None,
            ends: BTreeMap::new(),
            queue: VecDeque::new(),
            next_link: 0,
        };
        for device in 0..count {
            net.inject(device, Store::default().restore());
        }
        net.run();
        net
    }

    /// Delivers `event` and queues the resulting actions.
    pub fn inject(&mut self, device: usize, event: Event) {
        let clock = Clock {
            unix_s: self.clock.unix_s - self.devices[device].lag_s,
            ..self.clock
        };
        let actions = self.devices[device]
            .core
            .handle(clock, event)
            .expect("the harness keeps the caller contract");
        self.queue
            .extend(actions.into_iter().map(|action| (device, action)));
    }

    /// Connects `central` to `peripheral` with a distinct address per connection.
    pub fn connect(&mut self, central: usize, peripheral: usize) -> (LinkId, LinkId) {
        let (a, b) = (LinkId(self.next_link), LinkId(self.next_link + 1));
        self.next_link += 2;
        self.ends.insert((central, a), (peripheral, b));
        self.ends.insert((peripheral, b), (central, a));
        let address = |device: usize| format!("device-{device}").into_bytes();
        self.inject(
            central,
            Event::LinkUp {
                link: a,
                gatt_role: GattRole::Central,
                mtu: MTU,
                address: address(peripheral),
            },
        );
        self.inject(
            peripheral,
            Event::LinkUp {
                link: b,
                gatt_role: GattRole::Peripheral,
                mtu: MTU,
                address: address(central),
            },
        );
        (a, b)
    }

    /// Delivers queued actions until none remain.
    pub fn run(&mut self) {
        while let Some((device, action)) = self.queue.pop_front() {
            self.devices[device].log.push(action.clone());
            match action {
                Action::Send { link, mut fragment } => {
                    if let Some(intercept) = &mut self.intercept
                        && !intercept(device, &mut fragment)
                    {
                        continue;
                    }
                    if let Some(&(peer, peer_link)) = self.ends.get(&(device, link)) {
                        self.inject(
                            peer,
                            Event::Received {
                                link: peer_link,
                                fragment,
                            },
                        );
                    }
                }
                Action::Disconnect { link, .. } => {
                    if let Some((peer, peer_link)) = self.ends.remove(&(device, link)) {
                        self.ends.remove(&(peer, peer_link));
                        self.inject(peer, Event::LinkDown { link: peer_link });
                    }
                }
                ref row if self.devices[device].store.apply(row) => {}
                Action::SetTimer { timer, at_mono_ms } => {
                    self.devices[device].timers.insert(timer, at_mono_ms);
                }
                Action::CancelTimer { timer } => {
                    self.devices[device].timers.remove(&timer);
                }
                _ => {}
            }
        }
    }

    /// The central reads the peripheral's current `beacon` characteristic.
    pub fn read_beacon_of(&mut self, central: usize, link: LinkId, peripheral: usize) {
        let beacon = self.devices[peripheral]
            .core
            .beacon(self.clock.unix_s - self.devices[peripheral].lag_s)
            .unwrap();
        self.inject(
            central,
            Event::BeaconRead {
                link,
                beacon: beacon.to_vec(),
            },
        );
        self.run();
    }

    /// `device` loses the link; its peer is not told and keeps its end.
    pub fn lose(&mut self, device: usize, link: LinkId) {
        if let Some(peer_end) = self.ends.remove(&(device, link)) {
            self.ends.remove(&peer_end);
        }
        self.inject(device, Event::LinkDown { link });
        self.run();
    }

    /// Both ends see the link go down.
    pub fn drop_link(&mut self, device: usize, link: LinkId) {
        let (peer, peer_link) = self.ends[&(device, link)];
        self.lose(device, link);
        self.inject(peer, Event::LinkDown { link: peer_link });
        self.run();
    }

    /// Replaces `device`'s core with one restored from its rows.
    pub fn restart(&mut self, device: usize) {
        self.devices[device].core = Core::new();
        self.devices[device].timers.clear();
        let restore = self.devices[device].store.restore();
        self.inject(device, restore);
        self.run();
    }

    /// Every reason a device's core gave for closing a link, in order (ADR 0041).
    pub fn close_reasons(&self, device: usize) -> Vec<CloseReason> {
        self.devices[device]
            .log
            .iter()
            .filter_map(|action| match action {
                Action::Disconnect { reason, .. } => Some(*reason),
                _ => None,
            })
            .collect()
    }

    pub fn is_up(&self, device: usize, link: LinkId) -> bool {
        self.ends.contains_key(&(device, link))
    }

    /// Advances the clock and fires every due timer.
    pub fn advance(&mut self, ms: u64) {
        self.clock.mono_ms += ms;
        for device in 0..self.devices.len() {
            let due: Vec<TimerId> = self.devices[device]
                .timers
                .iter()
                .filter(|&(_, &at)| at <= self.clock.mono_ms)
                .map(|(&timer, _)| timer)
                .collect();
            for timer in due {
                self.devices[device].timers.remove(&timer);
                self.inject(device, Event::TimerFired { timer });
            }
        }
        self.run();
    }
}

/// From `device`'s first fragment of the frame with `header` on, the network
/// drops everything `device` sends.
pub fn silence_from(device: usize, header: u8) -> Intercept {
    let mut silent = false;
    Box::new(move |sender, fragment| {
        silent |= sender == device && fragment[0] == header;
        !(silent && sender == device)
    })
}

/// A hand-built frame as the one checked fragment a 517-byte MTU carries (ADR 0042).
pub fn checked(frame: &[u8]) -> Vec<u8> {
    let mut fragments = cairn_proto::fragment(frame, 517).unwrap();
    assert_eq!(fragments.len(), 1, "a hand-built frame fits one fragment");
    fragments.remove(0)
}
