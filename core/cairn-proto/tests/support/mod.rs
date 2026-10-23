//! An in-memory loopback between cores (issue 31).

pub mod seeded;

use cairn_proto::{Action, Clock, Core, Event, GattRole, LinkId, Persisted, TimerId};
use seeded::Seeded;
use std::collections::{BTreeMap, VecDeque};

pub const MTU: u16 = 185;
pub const START: Clock = Clock {
    mono_ms: 1_000,
    unix_s: 1_761_177_600,
};

pub struct Device {
    pub core: Core<Seeded>,
    /// Every action this device emitted, in order.
    pub log: Vec<Action>,
    pub persisted: Option<Persisted>,
    pub timers: BTreeMap<TimerId, u64>,
}

pub struct Net {
    pub devices: Vec<Device>,
    pub clock: Clock,
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
                    persisted: None,
                    timers: BTreeMap::new(),
                })
                .collect(),
            clock: START,
            ends: BTreeMap::new(),
            queue: VecDeque::new(),
            next_link: 0,
        };
        for device in 0..count {
            net.inject(device, Event::Restore { state: None });
        }
        net.run();
        net
    }

    /// Delivers `event` and queues the resulting actions.
    pub fn inject(&mut self, device: usize, event: Event) {
        let actions = self.devices[device]
            .core
            .handle(self.clock, event)
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
                Action::Send { link, fragment } => {
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
                Action::Disconnect { link } => {
                    if let Some((peer, peer_link)) = self.ends.remove(&(device, link)) {
                        self.ends.remove(&(peer, peer_link));
                        self.inject(peer, Event::LinkDown { link: peer_link });
                    }
                }
                Action::Persist { state } => self.devices[device].persisted = Some(state),
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
