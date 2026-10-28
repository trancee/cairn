//! Two `CairnCore`s with the real backend, driven only through the exported surface.

use std::collections::{BTreeMap, VecDeque};

use cairn_ffi::{
    Action, CairnCore, Clock, ContactInfo, ContactRow, CoreError, CourierRow, Event, GattRole,
    Persisted, QueuedRow, Verification,
};

const CLOCK: Clock = Clock {
    mono_ms: 1_000,
    unix_s: 1_761_177_600,
};

/// The platform's row store (ADR 0034 §1).
#[derive(Default)]
struct Store {
    device: Option<Persisted>,
    contacts: BTreeMap<u64, Persisted>,
    queued: BTreeMap<(u64, u32), Persisted>,
    courier: BTreeMap<u64, Persisted>,
}

impl Store {
    fn apply(&mut self, action: &Action) {
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
            _ => {}
        }
    }

    fn restore(&self) -> Event {
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
}

struct Device {
    core: CairnCore,
    log: Vec<Action>,
    store: Store,
}

impl Device {
    fn restored(store: Store) -> Self {
        let restore = store.restore();
        let mut device = Self {
            core: CairnCore::new(),
            log: Vec::new(),
            store,
        };
        let actions = device.core.handle(CLOCK, restore).unwrap();
        device.record(&actions);
        device
    }

    fn record(&mut self, actions: &[Action]) {
        for action in actions {
            self.store.apply(action);
        }
        self.log.extend_from_slice(actions);
    }

    fn contact(&self) -> u64 {
        self.log
            .iter()
            .find_map(|action| match action {
                Action::ContactAdded { contact } => Some(*contact),
                _ => None,
            })
            .expect("a paired contact")
    }

    fn chats(&self) -> Vec<(u64, String)> {
        self.log
            .iter()
            .filter_map(|action| match action {
                Action::ChatReceived { contact, text, .. } => Some((*contact, text.clone())),
                _ => None,
            })
            .collect()
    }
}

/// Delivers `event` to `devices[from]`, then every resulting `Send` or
/// `Disconnect`, in order, to the other device's end of the link, which is
/// `link ^ 1`: a link delivers its fragments in order.
fn drive(devices: &mut [Device; 2], from: usize, event: Event) {
    let mut queue = VecDeque::from([(from, event)]);
    while let Some((device, event)) = queue.pop_front() {
        let actions = devices[device].core.handle(CLOCK, event).unwrap();
        devices[device].record(&actions);
        let peer = 1 - device;
        for action in actions {
            match action {
                Action::Send { link, fragment } => queue.push_back((
                    peer,
                    Event::Received {
                        link: link ^ 1,
                        fragment,
                    },
                )),
                Action::Disconnect { link } => {
                    queue.push_back((peer, Event::LinkDown { link: link ^ 1 }))
                }
                _ => {}
            }
        }
    }
}

/// Connects device 0 as central on `link` and device 1 as peripheral on
/// `link ^ 1`, then has the central read the peripheral's beacon.
fn connect(devices: &mut [Device; 2], link: u64) {
    for (device, gatt_role, id) in [
        (0, GattRole::Central, link),
        (1, GattRole::Peripheral, link ^ 1),
    ] {
        drive(
            devices,
            device,
            Event::LinkUp {
                link: id,
                gatt_role,
                mtu: 185,
                address: format!("device-{}", 1 - device).into_bytes(),
            },
        );
    }
    let beacon = devices[1].core.beacon(CLOCK.unix_s).unwrap();
    drive(devices, 0, Event::BeaconRead { link, beacon });
}

fn disconnect(devices: &mut [Device; 2], link: u64) {
    drive(devices, 0, Event::LinkDown { link });
    drive(devices, 1, Event::LinkDown { link: link ^ 1 });
}

fn paired() -> [Device; 2] {
    let mut devices = [
        Device::restored(Store::default()),
        Device::restored(Store::default()),
    ];
    connect(&mut devices, 2);
    devices
}

#[test]
fn two_cores_pair_and_chat_over_the_exported_surface() {
    let mut devices = paired();
    let (a, b) = (devices[0].contact(), devices[1].contact());

    drive(
        &mut devices,
        0,
        Event::SendChat {
            contact: a,
            text: "hello".into(),
        },
    );

    assert_eq!(devices[1].chats(), [(b, "hello".to_string())]);
    assert_eq!(
        devices[1].core.contacts().unwrap(),
        [ContactInfo {
            id: b,
            name: String::new(),
            verification: Verification::Unverified,
        }]
    );
}

#[test]
fn restored_cores_resume_on_a_new_link() {
    let mut devices = paired();
    disconnect(&mut devices, 2);
    let mut devices = devices.map(|device| Device::restored(device.store));
    let (a, b) = (
        devices[0].core.contacts().unwrap()[0].id,
        devices[1].core.contacts().unwrap()[0].id,
    );
    connect(&mut devices, 4);

    drive(
        &mut devices,
        0,
        Event::SendChat {
            contact: a,
            text: "again".into(),
        },
    );

    assert_eq!(devices[1].chats(), [(b, "again".to_string())]);
}

#[test]
fn a_chat_sent_offline_is_queued_and_delivered_at_the_next_resume() {
    let mut devices = paired();
    let (a, b) = (devices[0].contact(), devices[1].contact());
    disconnect(&mut devices, 2);

    drive(
        &mut devices,
        0,
        Event::SendChat {
            contact: a,
            text: "later".into(),
        },
    );
    let stored = devices[0].store.queued.len();
    connect(&mut devices, 4);

    assert_eq!(stored, 1);
    assert_eq!(devices[1].chats(), [(b, "later".to_string())]);
    assert!(devices[0].log.contains(&Action::ChatDelivered {
        contact: a,
        msgno: 1
    }));
    assert!(devices[0].store.queued.is_empty());
}

#[test]
fn caller_contract_violations_are_typed_errors() {
    let core = CairnCore::new();

    let beacon = core.beacon(CLOCK.unix_s);
    let event = core.handle(CLOCK, Event::LinkDown { link: 1 });

    assert_eq!(beacon, Err(CoreError::NotRestored));
    assert_eq!(event, Err(CoreError::NotRestored));
    assert_eq!(core.contacts(), Ok(Vec::new()));
}
