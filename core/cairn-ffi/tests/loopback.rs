//! Two `CairnCore`s with the real backend, driven only through the exported surface.

use cairn_ffi::{
    Action, CairnCore, ChatRejection, Clock, ContactInfo, CoreError, Event, GattRole, Persisted,
    Verification,
};

const CLOCK: Clock = Clock {
    mono_ms: 1_000,
    unix_s: 1_761_177_600,
};

struct Device {
    core: CairnCore,
    log: Vec<Action>,
    persisted: Option<Persisted>,
}

impl Device {
    fn restored(state: Option<Persisted>) -> Self {
        let mut device = Self {
            core: CairnCore::new(),
            log: Vec::new(),
            persisted: None,
        };
        let actions = device.core.handle(CLOCK, Event::Restore { state }).unwrap();
        device.record(&actions);
        device
    }

    fn record(&mut self, actions: &[Action]) {
        for action in actions {
            if let Action::Persist { state } = action {
                self.persisted = Some(state.clone());
            }
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
/// `Disconnect` to the other device's end of the link, which is `link ^ 1`.
fn drive(devices: &mut [Device; 2], from: usize, event: Event) {
    let mut queue = vec![(from, event)];
    while let Some((device, event)) = queue.pop() {
        let actions = devices[device].core.handle(CLOCK, event).unwrap();
        devices[device].record(&actions);
        let peer = 1 - device;
        for action in actions.into_iter().rev() {
            match action {
                Action::Send { link, fragment } => queue.push((
                    peer,
                    Event::Received {
                        link: link ^ 1,
                        fragment,
                    },
                )),
                Action::Disconnect { link } => {
                    queue.push((peer, Event::LinkDown { link: link ^ 1 }))
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
    let mut devices = [Device::restored(None), Device::restored(None)];
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
    let mut devices = devices.map(|device| Device::restored(device.persisted));
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
fn a_chat_without_a_session_is_rejected() {
    let mut devices = paired();
    let a = devices[0].contact();
    disconnect(&mut devices, 2);

    let actions = devices[0].core.handle(
        CLOCK,
        Event::SendChat {
            contact: a,
            text: "later".into(),
        },
    );

    assert_eq!(
        actions,
        Ok(vec![Action::ChatRejected {
            contact: a,
            reason: ChatRejection::NoSession,
        }])
    );
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
