//! Couriers carry queued messages between loopback cores (spec §8.1, ADR 0033).

mod support;

use cairn_proto::{Action, ContactId, Event, LinkId};
use support::Net;

const STRANGER_BEACON: [u8; 8] = [0x5a; 8];
const SENDER: usize = 0;
const COURIER: usize = 1;
const RECIPIENT: usize = 2;

/// The contact ID `device` gave `peer`: contacts are numbered in pairing order.
fn contact(device: usize, peer: usize) -> ContactId {
    let order: &[usize] = match device {
        0 => &[1, 2],
        1 => &[0, 2],
        _ => &[0, 1],
    };
    ContactId(order.iter().position(|&other| other == peer).unwrap() as u64)
}

/// Three devices that are each other's contacts, with no link up.
fn mesh(seed: u64) -> Net {
    let mut net = Net::new(3, seed);
    for (central, peripheral) in [(0, 1), (0, 2), (1, 2)] {
        let (link, _) = net.connect(central, peripheral);
        net.inject(
            central,
            Event::BeaconRead {
                link,
                beacon: STRANGER_BEACON.to_vec(),
            },
        );
        net.run();
        net.drop_link(central, link);
    }
    net
}

/// `central` connects to `peripheral` and resumes.
fn meet(net: &mut Net, central: usize, peripheral: usize) -> LinkId {
    let (link, _) = net.connect(central, peripheral);
    net.read_beacon_of(central, link, peripheral);
    link
}

fn act(net: &mut Net, device: usize, event: Event) -> Vec<Action> {
    let start = net.devices[device].log.len();
    net.inject(device, event);
    net.run();
    net.devices[device].log[start..].to_vec()
}

fn received(net: &Net, device: usize) -> Vec<(ContactId, u32, String)> {
    net.devices[device]
        .log
        .iter()
        .filter_map(|action| match action {
            Action::ChatReceived {
                contact,
                msgno,
                text,
            } => Some((*contact, *msgno, text.clone())),
            _ => None,
        })
        .collect()
}

/// The sender queues one chat for the recipient while no link is up.
fn queue_for_recipient(net: &mut Net) {
    let actions = act(
        net,
        SENDER,
        Event::SendChat {
            contact: contact(SENDER, RECIPIENT),
            text: "via courier".into(),
        },
    );
    assert!(actions.contains(&Action::ChatQueued {
        contact: contact(SENDER, RECIPIENT),
        msgno: 1,
    }));
}

fn courier_rows(net: &Net, device: usize) -> usize {
    net.devices[device].store.courier.len()
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_courier_carries_a_queued_message_to_an_out_of_range_contact() {
    let mut net = mesh(1);
    queue_for_recipient(&mut net);
    let link = meet(&mut net, SENDER, COURIER);
    net.drop_link(SENDER, link);

    let link = meet(&mut net, COURIER, RECIPIENT);

    assert_eq!(
        received(&net, RECIPIENT),
        [(contact(RECIPIENT, SENDER), 1, "via courier".into())]
    );
    assert_eq!(
        courier_rows(&net, RECIPIENT),
        1,
        "the recipient keeps a tombstone"
    );
    assert_eq!(
        courier_rows(&net, COURIER),
        1,
        "the envelope became a tombstone"
    );
    assert!(net.is_up(COURIER, link));
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn the_sender_still_delivers_directly_and_the_recipient_shows_the_message_once() {
    let mut net = mesh(2);
    queue_for_recipient(&mut net);
    let link = meet(&mut net, SENDER, COURIER);
    net.drop_link(SENDER, link);
    let link = meet(&mut net, COURIER, RECIPIENT);
    net.drop_link(COURIER, link);

    meet(&mut net, SENDER, RECIPIENT);

    assert_eq!(received(&net, RECIPIENT).len(), 1);
    assert!(net.devices[SENDER].log.contains(&Action::ChatDelivered {
        contact: contact(SENDER, RECIPIENT),
        msgno: 1,
    }));
    assert!(net.devices[SENDER].store.queued.is_empty());
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_carried_envelope_survives_a_courier_restart() {
    let mut net = mesh(3);
    queue_for_recipient(&mut net);
    let link = meet(&mut net, SENDER, COURIER);
    net.drop_link(SENDER, link);
    net.restart(COURIER);

    meet(&mut net, COURIER, RECIPIENT);

    assert_eq!(received(&net, RECIPIENT).len(), 1);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_courier_with_couriering_off_carries_nothing() {
    let mut net = mesh(4);
    act(
        &mut net,
        COURIER,
        Event::SetCourier {
            enabled: false,
            copies: 6,
            lifetime_minutes: 1440,
        },
    );
    queue_for_recipient(&mut net);
    let link = meet(&mut net, SENDER, COURIER);
    net.drop_link(SENDER, link);

    meet(&mut net, COURIER, RECIPIENT);

    assert_eq!(courier_rows(&net, COURIER), 0);
    assert!(received(&net, RECIPIENT).is_empty());
}
