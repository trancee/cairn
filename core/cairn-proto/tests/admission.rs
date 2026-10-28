//! Automatic admission and TOFU pairing between loopback cores (spec §5, ADR 0021).

mod support;

use cairn_crypto::CryptoError;
use cairn_proto::{
    Action, Clock, ContactId, Core, CoreError, Event, GattRole, LinkId, Persisted, TimerId,
    Verification,
};
use support::seeded::Seeded;
use support::{Net, START, Store};

const STRANGER_BEACON: [u8; 8] = [0x5a; 8];

fn read_beacon(net: &mut Net, device: usize, link: LinkId) {
    net.inject(
        device,
        Event::BeaconRead {
            link,
            beacon: STRANGER_BEACON.to_vec(),
        },
    );
}

fn added(net: &Net, device: usize) -> Vec<ContactId> {
    net.devices[device]
        .log
        .iter()
        .filter_map(|action| match action {
            Action::ContactAdded { contact } => Some(*contact),
            _ => None,
        })
        .collect()
}

fn first_fragment_headers(net: &Net, device: usize, link: LinkId) -> Vec<u8> {
    net.devices[device]
        .log
        .iter()
        .filter_map(|action| match action {
            Action::Send {
                link: sent,
                fragment,
            } if *sent == link => Some(fragment[0]),
            _ => None,
        })
        .filter(|header| header & 0x80 == 0)
        .collect()
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_central_admits_a_stranger_after_a_non_matching_beacon_read() {
    let mut net = Net::new(2, 1);
    let (central, peripheral) = net.connect(0, 1);

    read_beacon(&mut net, 0, central);
    net.run();

    assert_eq!(added(&net, 0), [ContactId(0)]);
    assert_eq!(added(&net, 1), [ContactId(0)]);
    for device in [0, 1] {
        let contacts = net.devices[device].core.contacts();
        assert_eq!(contacts.len(), 1);
        assert_eq!(contacts[0].name, "");
        assert_eq!(contacts[0].verification, Verification::Unverified);
    }
    assert!(net.is_up(0, central), "the link survives pairing");
    assert_eq!(
        first_fragment_headers(&net, 0, central),
        [0x00, 0x02, 0x04, 0x10, 0x30, 0x30]
    );
    assert_eq!(
        first_fragment_headers(&net, 1, peripheral),
        [0x01, 0x03, 0x20, 0x30]
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn completing_pairing_cancels_the_pre_auth_deadline() {
    let mut net = Net::new(2, 2);
    let (central, _) = net.connect(0, 1);
    read_beacon(&mut net, 0, central);
    net.run();

    net.advance(10_000);

    assert!(net.is_up(0, central));
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn b_persists_the_contact_before_sending_p4() {
    let mut net = Net::new(2, 3);
    let (central, _) = net.connect(0, 1);

    read_beacon(&mut net, 0, central);
    net.run();

    let log = &net.devices[0].log;
    let p4 = log
        .iter()
        .position(
            |action| matches!(action, Action::Send { fragment, .. } if fragment[0] & 0x7f == 0x04),
        )
        .unwrap();
    let persists = log[..p4]
        .iter()
        .filter(|action| {
            matches!(
                action,
                Action::PersistDevice { .. } | Action::PersistContact { .. }
            )
        })
        .count();
    assert_eq!(
        persists, 3,
        "the fresh install, then the device and its contact"
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn persisted_contacts_survive_a_restore() {
    let mut net = Net::new(2, 4);
    let (central, _) = net.connect(0, 1);
    read_beacon(&mut net, 0, central);
    net.run();
    let mut restored: Vec<Core<Seeded>> = (0..2).map(|_| Core::new()).collect();

    for (device, core) in restored.iter_mut().enumerate() {
        let event = net.devices[device].store.restore();
        core.handle(START, event).unwrap();
    }

    for (device, core) in restored.iter().enumerate() {
        assert_eq!(core.contacts(), net.devices[device].core.contacts());
    }
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_fresh_install_persists_its_new_device_key() {
    let net = Net::new(1, 5);

    let persisted = net.devices[0].store.device.as_ref().unwrap();

    assert_eq!(persisted.version, 3);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn crossing_p0s_are_resolved_by_the_tie_break_to_one_pairing() {
    let mut net = Net::new(2, 6);
    let (x_to_y, _) = net.connect(0, 1);
    let (y_to_x, _) = net.connect(1, 0);

    read_beacon(&mut net, 0, x_to_y);
    read_beacon(&mut net, 1, y_to_x);
    net.run();

    assert_eq!(net.devices[0].core.contacts().len(), 1);
    assert_eq!(net.devices[1].core.contacts().len(), 1);
    assert_ne!(
        net.is_up(0, x_to_y),
        net.is_up(1, y_to_x),
        "exactly one link survives"
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_second_p0_while_pairing_is_in_flight_is_answered_busy_and_may_retry() {
    let mut net = Net::new(3, 7);
    let (first, _) = net.connect(1, 0);
    let (second, refused) = net.connect(2, 0);

    read_beacon(&mut net, 1, first);
    read_beacon(&mut net, 2, second);
    net.run();
    let (retry, _) = net.connect(2, 0);
    read_beacon(&mut net, 2, retry);
    net.run();

    assert_eq!(first_fragment_headers(&net, 0, refused), [0x05]);
    assert!(!net.is_up(2, second), "B closes on BUSY");
    assert_eq!(net.devices[0].core.contacts().len(), 2);
    assert_eq!(net.devices[1].core.contacts().len(), 1);
    assert_eq!(
        net.devices[2].core.contacts().len(),
        1,
        "BUSY backs off neither side"
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_central_with_a_pairing_in_flight_does_not_send_p0() {
    let mut net = Net::new(3, 8);
    let (first, _) = net.connect(0, 1);
    let (second, _) = net.connect(0, 2);
    read_beacon(&mut net, 0, first);

    read_beacon(&mut net, 0, second);
    net.run();

    assert!(first_fragment_headers(&net, 0, second).is_empty());
    assert!(!net.is_up(0, second));
    assert_eq!(net.devices[0].core.contacts().len(), 1);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_card_more_than_a_day_old_fails_pairing() {
    let outcomes = [(1, 38), (2, 39)].map(|(days, seed)| {
        let mut net = Net::new(2, seed);
        net.clock.unix_s += days * 86_400;
        net.devices[1].lag_s = days * 86_400;
        let (central, _) = net.connect(0, 1);
        read_beacon(&mut net, 0, central);
        net.run();
        (
            net.devices[0].core.contacts().len(),
            net.devices[1].core.contacts().len(),
        )
    });

    assert_eq!(outcomes, [(1, 1), (0, 0)]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_contacts_beacon_resumes_even_while_a_stranger_is_pairing() {
    let mut net = Net::new(3, 37);
    let (paired, _) = net.connect(0, 1);
    read_beacon(&mut net, 0, paired);
    net.run();
    net.drop_link(0, paired);
    let (stranger, _) = net.connect(0, 2);
    read_beacon(&mut net, 0, stranger);

    let (contact, _) = net.connect(0, 1);
    net.read_beacon_of(0, contact, 1);

    assert_eq!(first_fragment_headers(&net, 0, contact), [0x10, 0x30, 0x30]);
    assert!(net.is_up(0, contact));
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn an_unfinished_pairing_times_out_and_backs_off_the_address() {
    Seeded::seed(9);
    let mut core = restored(START);
    let deadline = core
        .handle(START, link_up(LinkId(1), GattRole::Peripheral, 185))
        .unwrap()
        .into_iter()
        .find_map(|action| match action {
            Action::SetTimer { timer, at_mono_ms } => Some((timer, at_mono_ms)),
            _ => None,
        })
        .unwrap();
    let p0 = [&[0x00][..], &[1; 16]].concat();
    let p1 = sent(
        &core
            .handle(
                START,
                Event::Received {
                    link: LinkId(1),
                    fragment: p0.clone(),
                },
            )
            .unwrap(),
    );
    let fired = Clock {
        mono_ms: deadline.1,
        ..START
    };

    let expired = core
        .handle(fired, Event::TimerFired { timer: deadline.0 })
        .unwrap();
    core.handle(fired, link_up(LinkId(2), GattRole::Peripheral, 185))
        .unwrap();
    let retry = core
        .handle(
            fired,
            Event::Received {
                link: LinkId(2),
                fragment: p0,
            },
        )
        .unwrap();

    assert_eq!(deadline.1, START.mono_ms + 5_000);
    assert!(!p1.is_empty());
    assert_eq!(expired, [Action::Disconnect { link: LinkId(1) }]);
    assert_eq!(
        sent(&retry),
        [vec![0x05]],
        "BUSY, not P1, to a backed-off address"
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_peripheral_answers_at_most_thirty_attempts_per_hour() {
    let mut net = Net::new(32, 10);
    let mut answered = Vec::new();

    for stranger in 1..=31 {
        let (central, peripheral) = net.connect(stranger, 0);
        net.inject(
            0,
            Event::Received {
                link: peripheral,
                fragment: [&[0x00][..], &[stranger as u8; 16]].concat(),
            },
        );
        net.run();
        answered.push(first_fragment_headers(&net, 0, peripheral));
        net.inject(stranger, Event::LinkDown { link: central });
        net.inject(0, Event::LinkDown { link: peripheral });
        net.run();
    }

    assert!(answered[..30].iter().all(|headers| headers[0] == 0x01));
    assert_eq!(answered[30], [0x05]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn malformed_or_unexpected_frames_close_the_link_without_a_reply() {
    let frames: [&[u8]; 5] = [&[0x00, 1, 2], &[0x02; 20], &[0x30; 20], &[0x40], &[0x05]];
    let mut outcomes = Vec::new();

    for (seed, frame) in frames.into_iter().enumerate() {
        let mut net = Net::new(2, 20 + seed as u64);
        let (_, peripheral) = net.connect(0, 1);
        net.devices[1].log.clear();
        net.inject(
            1,
            Event::Received {
                link: peripheral,
                fragment: frame.to_vec(),
            },
        );
        net.run();
        outcomes.push((
            first_fragment_headers(&net, 1, peripheral).is_empty(),
            net.is_up(1, peripheral),
        ));
    }

    assert_eq!(outcomes, [(true, false); 5]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn caller_contract_violations_are_errors() {
    let mut fresh = Core::<Seeded>::new();
    let not_restored = fresh.handle(START, Event::LinkDown { link: LinkId(0) });
    fresh.handle(START, Store::default().restore()).unwrap();
    let twice = fresh.handle(START, Store::default().restore());
    let unknown_contact = fresh.handle(
        START,
        Event::SendChat {
            contact: ContactId(9),
            text: String::new(),
        },
    );
    let duplicate_link = [
        link_up(LinkId(1), GattRole::Peripheral, 23),
        link_up(LinkId(1), GattRole::Central, 23),
    ]
    .map(|event| fresh.handle(START, event))[1]
        .clone();
    let peripheral_beacon_read = fresh.handle(
        START,
        Event::BeaconRead {
            link: LinkId(1),
            beacon: STRANGER_BEACON.to_vec(),
        },
    );
    fresh
        .handle(START, link_up(LinkId(3), GattRole::Central, 185))
        .unwrap();
    let read = Event::BeaconRead {
        link: LinkId(3),
        beacon: STRANGER_BEACON.to_vec(),
    };
    fresh.handle(START, read.clone()).unwrap();
    let second_beacon_read = fresh.handle(START, read);
    let tiny_link = fresh.handle(START, link_up(LinkId(2), GattRole::Central, 22));
    let tiny_change = fresh.handle(
        START,
        Event::MtuChanged {
            link: LinkId(1),
            mtu: 22,
        },
    );
    let wrong_version = Core::<Seeded>::new().handle(
        START,
        Event::Restore {
            device: Some(Persisted {
                blob: Vec::new(),
                version: 3,
            }),
            contacts: Vec::new(),
            queued: Vec::new(),
            courier: Vec::new(),
        },
    );

    assert_eq!(
        [
            not_restored,
            twice,
            unknown_contact,
            duplicate_link,
            peripheral_beacon_read,
            second_beacon_read,
            tiny_link,
            tiny_change,
            wrong_version,
        ]
        .map(Result::err),
        [
            Some(CoreError::NotRestored),
            Some(CoreError::AlreadyRestored),
            Some(CoreError::UnknownContact),
            Some(CoreError::DuplicateLink),
            Some(CoreError::UnexpectedBeaconRead),
            Some(CoreError::UnexpectedBeaconRead),
            Some(CoreError::InvalidMtu),
            Some(CoreError::InvalidMtu),
            Some(CoreError::InvalidBlob),
        ]
    );
}

fn link_up(link: LinkId, gatt_role: GattRole, mtu: u16) -> Event {
    Event::LinkUp {
        link,
        gatt_role,
        mtu,
        address: b"peer".to_vec(),
    }
}

fn restored(clock: Clock) -> Core<Seeded> {
    let mut core = Core::default();
    core.handle(clock, Store::default().restore()).unwrap();
    core
}

fn sent(actions: &[Action]) -> Vec<Vec<u8>> {
    actions
        .iter()
        .filter_map(|action| match action {
            Action::Send { fragment, .. } => Some(fragment.clone()),
            _ => None,
        })
        .collect()
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn core_errors_have_stable_messages() {
    let errors = [
        CoreError::NotRestored,
        CoreError::AlreadyRestored,
        CoreError::InvalidBlob,
        CoreError::DuplicateLink,
        CoreError::InvalidMtu,
        CoreError::UnexpectedBeaconRead,
        CoreError::UnknownContact,
        CoreError::InvalidCourierConfig,
        CoreError::Crypto(CryptoError::BackendFailure),
    ];

    let messages = errors.map(|error| error.to_string());

    assert_eq!(
        messages,
        [
            "event before Restore",
            "Restore after the first event",
            "persisted state does not decode",
            "link is already up",
            "ATT MTU below 23",
            "beacon read outside a fresh central link",
            "unknown contact",
            "courier settings out of range",
            "cryptographic backend failure",
        ]
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn events_for_unknown_links_and_stale_timers_are_ignored() {
    Seeded::seed(30);
    let mut core = restored(START);
    let unknown = LinkId(7);
    let events = [
        Event::MtuChanged {
            link: unknown,
            mtu: 185,
        },
        Event::BeaconRead {
            link: unknown,
            beacon: STRANGER_BEACON.to_vec(),
        },
        Event::Received {
            link: unknown,
            fragment: vec![0x00; 17],
        },
        Event::LinkDown { link: unknown },
        Event::TimerFired { timer: TimerId(99) },
    ];

    let results = events.map(|event| core.handle(START, event));

    assert_eq!(results, [const { Ok(Vec::new()) }; 5]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_raised_mtu_sends_p1_in_fewer_fragments() {
    let mut counts = Vec::new();

    for mtu in [None, Some(512)] {
        let mut net = Net::new(2, 31);
        let (_, peripheral) = net.connect(0, 1);
        if let Some(mtu) = mtu {
            net.inject(
                1,
                Event::MtuChanged {
                    link: peripheral,
                    mtu,
                },
            );
        }
        net.inject(
            1,
            Event::Received {
                link: peripheral,
                fragment: [&[0x00][..], &[1; 16]].concat(),
            },
        );
        net.run();
        counts.push(
            net.devices[1]
                .log
                .iter()
                .filter(|action| matches!(action, Action::Send { .. }))
                .count(),
        );
    }

    assert_eq!(counts, [7, 3]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn crossing_p0s_with_equal_nonces_close_the_own_link_and_answer_busy() {
    Seeded::seed(32);
    let mut core = restored(START);
    let (own, incoming) = (LinkId(1), LinkId(2));
    core.handle(START, link_up(own, GattRole::Central, 185))
        .unwrap();
    let p0 = sent(
        &core
            .handle(
                START,
                Event::BeaconRead {
                    link: own,
                    beacon: STRANGER_BEACON.to_vec(),
                },
            )
            .unwrap(),
    );
    core.handle(START, link_up(incoming, GattRole::Peripheral, 185))
        .unwrap();

    let actions = core
        .handle(
            START,
            Event::Received {
                link: incoming,
                fragment: p0[0].clone(),
            },
        )
        .unwrap();

    assert_eq!(sent(&actions), [vec![0x05]]);
    assert!(actions.contains(&Action::Disconnect { link: own }));
    assert!(
        !actions.contains(&Action::Disconnect { link: incoming }),
        "A waits for B to close"
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_frame_on_an_admitted_link_closes_it_without_back_off() {
    let mut net = Net::new(2, 33);
    let (central, peripheral) = net.connect(0, 1);
    read_beacon(&mut net, 0, central);
    net.run();

    net.inject(
        1,
        Event::Received {
            link: peripheral,
            fragment: [&[0x00][..], &[1; 16]].concat(),
        },
    );
    net.run();
    let (_, retry) = net.connect(0, 1);
    net.devices[1].log.clear();
    net.inject(
        1,
        Event::Received {
            link: retry,
            fragment: [&[0x00][..], &[2; 16]].concat(),
        },
    );
    net.run();

    assert!(!net.is_up(1, peripheral));
    assert!(
        !first_fragment_headers(&net, 1, retry).is_empty(),
        "the address was not backed off"
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn an_admitted_link_going_down_needs_no_cleanup() {
    let mut net = Net::new(2, 34);
    let (central, peripheral) = net.connect(0, 1);
    read_beacon(&mut net, 0, central);
    net.run();

    let actions = net.devices[1]
        .core
        .handle(net.clock, Event::LinkDown { link: peripheral })
        .unwrap();

    assert!(actions.is_empty());
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn backend_failures_are_returned_to_the_caller() {
    Seeded::seed(35);
    let mut a = restored(START);
    let mut b = restored(START);
    a.handle(START, link_up(LinkId(1), GattRole::Peripheral, 185))
        .unwrap();
    b.handle(START, link_up(LinkId(1), GattRole::Central, 185))
        .unwrap();
    let p0 = sent(
        &b.handle(
            START,
            Event::BeaconRead {
                link: LinkId(1),
                beacon: STRANGER_BEACON.to_vec(),
            },
        )
        .unwrap(),
    );
    let p1 = sent(
        &a.handle(
            START,
            Event::Received {
                link: LinkId(1),
                fragment: p0[0].clone(),
            },
        )
        .unwrap(),
    );
    let (last, rest) = p1.split_last().unwrap();
    for fragment in rest {
        b.handle(
            START,
            Event::Received {
                link: LinkId(1),
                fragment: fragment.clone(),
            },
        )
        .unwrap();
    }
    Seeded::fail_randomness();

    let answering_p1 = b.handle(
        START,
        Event::Received {
            link: LinkId(1),
            fragment: last.clone(),
        },
    );
    let fresh_install = Core::<Seeded>::new().handle(START, Store::default().restore());

    let failure = Some(CoreError::Crypto(CryptoError::BackendFailure));
    assert_eq!(
        [answering_p1.err(), fresh_install.err()],
        [failure, failure]
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_central_does_not_send_p0_to_a_backed_off_address() {
    Seeded::seed(36);
    let mut core = restored(START);
    let read = |link| Event::BeaconRead {
        link,
        beacon: STRANGER_BEACON.to_vec(),
    };
    let timer = core
        .handle(START, link_up(LinkId(1), GattRole::Central, 185))
        .unwrap()
        .into_iter()
        .find_map(|action| match action {
            Action::SetTimer { timer, .. } => Some(timer),
            _ => None,
        })
        .unwrap();
    core.handle(START, read(LinkId(1))).unwrap();
    core.handle(START, Event::TimerFired { timer }).unwrap();
    core.handle(START, link_up(LinkId(2), GattRole::Central, 185))
        .unwrap();

    let retry = core.handle(START, read(LinkId(2))).unwrap();

    assert!(sent(&retry).is_empty());
    assert!(retry.contains(&Action::Disconnect { link: LinkId(2) }));
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_beacon_of_the_wrong_length_closes_the_link_and_backs_off_the_address() {
    Seeded::seed(37);
    let mut core = restored(START);
    core.handle(START, link_up(LinkId(1), GattRole::Central, 185))
        .unwrap();
    core.handle(START, link_up(LinkId(2), GattRole::Central, 185))
        .unwrap();

    let short = core.handle(
        START,
        Event::BeaconRead {
            link: LinkId(1),
            beacon: STRANGER_BEACON[..7].to_vec(),
        },
    );
    let retry = core
        .handle(
            START,
            Event::BeaconRead {
                link: LinkId(2),
                beacon: STRANGER_BEACON.to_vec(),
            },
        )
        .unwrap();

    assert_eq!(
        short,
        Ok(vec![
            Action::CancelTimer { timer: TimerId(0) },
            Action::Disconnect { link: LinkId(1) }
        ])
    );
    assert!(sent(&retry).is_empty());
    assert!(retry.contains(&Action::Disconnect { link: LinkId(2) }));
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn busy_neither_backs_off_nor_counts_against_the_attempt_limit() {
    Seeded::seed(40);
    let mut core = restored(START);
    let mut p0s = Vec::new();

    for link in (1..=31).map(LinkId) {
        core.handle(START, link_up(link, GattRole::Central, 185))
            .unwrap();
        let read = core
            .handle(
                START,
                Event::BeaconRead {
                    link,
                    beacon: STRANGER_BEACON.to_vec(),
                },
            )
            .unwrap();
        p0s.push(sent(&read).len());
        let busy = core
            .handle(
                START,
                Event::Received {
                    link,
                    fragment: vec![0x05],
                },
            )
            .unwrap();
        assert!(sent(&busy).is_empty());
        assert!(busy.contains(&Action::Disconnect { link }));
    }

    assert_eq!(p0s, [1; 31]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_refused_link_accepts_nothing_more_and_closes_at_its_deadline_without_back_off() {
    Seeded::seed(41);
    let mut core = restored(START);
    let up = |link, address: &[u8]| Event::LinkUp {
        link,
        gatt_role: GattRole::Peripheral,
        mtu: 185,
        address: address.to_vec(),
    };
    let p0 = |link| Event::Received {
        link,
        fragment: [&[0x00][..], &[7; 16]].concat(),
    };
    core.handle(START, up(LinkId(1), b"x")).unwrap();
    core.handle(START, p0(LinkId(1))).unwrap();
    core.handle(START, up(LinkId(2), b"y")).unwrap();
    let deadline = core
        .handle(START, up(LinkId(3), b"z"))
        .unwrap()
        .into_iter()
        .find_map(|action| match action {
            Action::SetTimer { timer, .. } => Some(timer),
            _ => None,
        })
        .unwrap();

    let busy = core.handle(START, p0(LinkId(2))).unwrap();
    let again = core.handle(START, p0(LinkId(2))).unwrap();
    core.handle(START, p0(LinkId(3))).unwrap();
    let expired = core
        .handle(START, Event::TimerFired { timer: deadline })
        .unwrap();
    core.handle(START, Event::LinkDown { link: LinkId(1) })
        .unwrap();
    core.handle(START, up(LinkId(4), b"z")).unwrap();
    let retry = core.handle(START, p0(LinkId(4))).unwrap();

    assert_eq!(sent(&busy), [vec![0x05]]);
    assert!(!busy.contains(&Action::Disconnect { link: LinkId(2) }));
    assert!(sent(&again).is_empty());
    assert!(again.contains(&Action::Disconnect { link: LinkId(2) }));
    assert_eq!(expired, [Action::Disconnect { link: LinkId(3) }]);
    assert!(!sent(&retry).is_empty(), "z is not backed off");
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn busy_with_a_body_fails_the_pairing_and_backs_off_the_address() {
    Seeded::seed(42);
    let mut core = restored(START);
    let read = |link| Event::BeaconRead {
        link,
        beacon: STRANGER_BEACON.to_vec(),
    };
    core.handle(START, link_up(LinkId(1), GattRole::Central, 185))
        .unwrap();
    core.handle(START, read(LinkId(1))).unwrap();

    let malformed = core
        .handle(
            START,
            Event::Received {
                link: LinkId(1),
                fragment: vec![0x05, 0],
            },
        )
        .unwrap();
    core.handle(START, link_up(LinkId(2), GattRole::Central, 185))
        .unwrap();
    let retry = core.handle(START, read(LinkId(2))).unwrap();

    assert!(malformed.contains(&Action::Disconnect { link: LinkId(1) }));
    assert!(sent(&retry).is_empty());
}

/// Dials `link` as central at `mono_ms` and reads a stranger's beacon; returns
/// whether P0 was sent and the latest pre-auth deadline.
fn dial(core: &mut Core<Seeded>, link: LinkId, mono_ms: u64) -> (bool, Option<TimerId>) {
    let clock = Clock { mono_ms, ..START };
    let mut actions = core
        .handle(clock, link_up(link, GattRole::Central, 185))
        .unwrap();
    actions.extend(
        core.handle(
            clock,
            Event::BeaconRead {
                link,
                beacon: STRANGER_BEACON.to_vec(),
            },
        )
        .unwrap(),
    );
    let deadline = actions.iter().rev().find_map(|action| match action {
        Action::SetTimer { timer, .. } => Some(*timer),
        _ => None,
    });
    (!sent(&actions).is_empty(), deadline)
}

const MINUTE: u64 = 60_000;

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn transport_failures_back_off_the_address_two_minutes_then_four() {
    Seeded::seed(43);
    let mut core = restored(START);
    let t0 = START.mono_ms;
    let at = |mono_ms| Clock { mono_ms, ..START };

    let (first, _) = dial(&mut core, LinkId(1), t0);
    core.handle(at(t0), Event::LinkDown { link: LinkId(1) })
        .unwrap();
    let (early, _) = dial(&mut core, LinkId(2), t0 + 2 * MINUTE - 1);
    let (second, deadline) = dial(&mut core, LinkId(3), t0 + 2 * MINUTE);
    let t1 = t0 + 2 * MINUTE + 5_000;
    core.handle(
        at(t1),
        Event::TimerFired {
            timer: deadline.unwrap(),
        },
    )
    .unwrap();
    let (before_four, _) = dial(&mut core, LinkId(4), t1 + 4 * MINUTE - 1);
    let (after_four, _) = dial(&mut core, LinkId(5), t1 + 4 * MINUTE);

    assert_eq!(
        [first, early, second, before_four, after_four],
        [true, false, true, false, true],
        "refused dials do not extend the back-off"
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_protocol_failure_backs_off_the_address_for_one_hour() {
    Seeded::seed(44);
    let mut core = restored(START);
    let t0 = START.mono_ms;
    dial(&mut core, LinkId(1), t0);
    core.handle(
        START,
        Event::Received {
            link: LinkId(1),
            fragment: vec![0x05, 0],
        },
    )
    .unwrap();

    let (after_two_minutes, _) = dial(&mut core, LinkId(2), t0 + 2 * MINUTE);
    let (before_an_hour, _) = dial(&mut core, LinkId(3), t0 + 60 * MINUTE - 1);
    let (after_an_hour, _) = dial(&mut core, LinkId(4), t0 + 60 * MINUTE);

    assert_eq!(
        [after_two_minutes, before_an_hour, after_an_hour],
        [false, false, true]
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn three_dials_refused_by_the_limits_back_off_the_address_for_one_hour() {
    Seeded::seed(45);
    let mut core = restored(START);
    let t0 = START.mono_ms;
    for n in 0..30 {
        let link = LinkId(100 + n);
        core.handle(
            START,
            Event::LinkUp {
                link,
                gatt_role: GattRole::Central,
                mtu: 185,
                address: vec![n as u8],
            },
        )
        .unwrap();
        core.handle(
            START,
            Event::BeaconRead {
                link,
                beacon: STRANGER_BEACON.to_vec(),
            },
        )
        .unwrap();
        core.handle(START, Event::LinkDown { link }).unwrap();
    }

    let refused = [0, 2, 4].map(|minute| dial(&mut core, LinkId(minute), t0 + minute * MINUTE).0);
    let (budget_free, _) = dial(&mut core, LinkId(60), t0 + 60 * MINUTE);
    let (backed_off_ended, _) = dial(&mut core, LinkId(64), t0 + 64 * MINUTE);

    assert_eq!(refused, [false; 3]);
    assert_eq!([budget_free, backed_off_ended], [false, true]);
}
