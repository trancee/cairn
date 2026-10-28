//! Beacons, Resume and CHAT DATA between loopback cores (spec §6, §7, §10.1; ADR 0022).

mod support;

use cairn_proto::{Action, ChatRejection, ContactId, Core, CoreError, Event, LinkId};
use support::seeded::Seeded;
use support::{Intercept, Net, START};

const STRANGER_BEACON: [u8; 8] = [0x5a; 8];
const DAY_S: u64 = 86_400;

/// Pairs device 0 (central, pairing role B) with device 1 (peripheral, role A).
fn paired(seed: u64) -> (Net, LinkId, LinkId) {
    let mut net = Net::new(2, seed);
    let (central, peripheral) = net.connect(0, 1);
    net.inject(
        0,
        Event::BeaconRead {
            link: central,
            beacon: STRANGER_BEACON.to_vec(),
        },
    );
    net.run();
    (net, central, peripheral)
}

/// Sends a chat from `device` and returns that device's actions.
fn send_chat(net: &mut Net, device: usize, text: &str) -> Vec<Action> {
    net.devices[device].log.clear();
    chat(net, device, text);
    net.devices[device].log.clone()
}

fn chat(net: &mut Net, device: usize, text: &str) {
    net.inject(
        device,
        Event::SendChat {
            contact: ContactId(0),
            text: text.into(),
        },
    );
    net.run();
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

fn position(log: &[Action], predicate: impl Fn(&Action) -> bool) -> usize {
    log.iter().position(predicate).unwrap()
}

fn is_send(action: &Action, header: u8) -> bool {
    matches!(action, Action::Send { fragment, .. } if fragment[0] == header)
}

fn is_persist(action: &Action) -> bool {
    matches!(action, Action::PersistContact { .. })
}

/// Drops everything `silent` sends from its S2 on: an ordered link that
/// stalls after S1, so the responder's S2 and session frames never arrive.
fn silence_after_s2(silent: usize) -> Intercept {
    let mut stalled = false;
    Box::new(move |device, fragment| {
        stalled |= device == silent && fragment[0] == 0x20;
        !(stalled && device == silent)
    })
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn the_central_resumes_right_after_pairing_and_confirms_with_empty_data() {
    let (net, central, peripheral) = paired(100);

    assert_eq!(
        first_fragment_headers(&net, 0, central),
        [0x00, 0x02, 0x04, 0x10, 0x30, 0x30]
    );
    assert_eq!(
        first_fragment_headers(&net, 1, peripheral),
        [0x01, 0x03, 0x20, 0x30]
    );
    assert!(received(&net, 1).is_empty(), "confirmation carries no chat");
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn neighbours_chat_both_ways_after_resume() {
    let (mut net, _, _) = paired(101);

    let sent = send_chat(&mut net, 0, "hello");
    chat(&mut net, 1, "hi back");
    chat(&mut net, 0, "again");

    assert!(sent.contains(&Action::ChatSent {
        contact: ContactId(0),
        msgno: 1
    }));
    assert_eq!(
        received(&net, 1),
        [
            (ContactId(0), 1, "hello".into()),
            (ContactId(0), 2, "again".into()),
        ]
    );
    assert_eq!(received(&net, 0), [(ContactId(0), 1, "hi back".into())]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn the_largest_chat_fills_the_largest_queued_bucket() {
    let (mut net, _, _) = paired(102);
    let text = "x".repeat(4045);

    chat(&mut net, 0, &text);

    assert_eq!(received(&net, 1), [(ContactId(0), 1, text)]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn the_responder_persists_its_pending_key_before_s2_and_commits_on_confirmation() {
    let (net, _, _) = paired(103);

    let log = &net.devices[1].log;
    let s2 = position(log, |action| is_send(action, 0x20));
    let before = log[..s2].iter().rposition(is_persist).unwrap();
    let added = position(log, |action| matches!(action, Action::ContactAdded { .. }));

    assert!(added < before, "a Persist follows pairing and precedes S2");
    assert!(log[s2..].iter().any(is_persist), "confirmation commits");
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn the_initiator_persists_the_new_chain_key_before_its_first_data_frame() {
    let (net, _, _) = paired(104);

    let log = &net.devices[0].log;
    let s1 = position(log, |action| is_send(action, 0x10));
    let data = position(log, |action| is_send(action, 0x30));

    assert!(log[s1..data].iter().any(is_persist));
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_sent_chat_number_is_persisted_before_its_frame() {
    let (mut net, _, _) = paired(105);

    let actions = send_chat(&mut net, 0, "hello");

    let persist = position(&actions, is_persist);
    let data = position(&actions, |action| is_send(action, 0x30));
    let sent = position(&actions, |action| matches!(action, Action::ChatSent { .. }));
    assert!(persist < data && data < sent);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_beacon_hit_resumes_a_known_contact_in_either_direction() {
    let (mut net, central, _) = paired(106);
    net.drop_link(0, central);

    let (again, _) = net.connect(0, 1);
    net.read_beacon_of(0, again, 1);
    chat(&mut net, 0, "one");
    net.drop_link(0, again);
    let (reverse, _) = net.connect(1, 0);
    net.read_beacon_of(1, reverse, 0);
    chat(&mut net, 1, "two");

    assert_eq!(first_fragment_headers(&net, 0, again)[0], 0x10);
    assert_eq!(first_fragment_headers(&net, 1, reverse)[0], 0x10);
    assert_eq!(received(&net, 1), [(ContactId(0), 1, "one".into())]);
    assert_eq!(received(&net, 0), [(ContactId(0), 1, "two".into())]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn beacons_match_neighbouring_windows_and_later_days() {
    let (mut net, central, _) = paired(107);
    net.drop_link(0, central);
    let beacon = net.devices[1].core.beacon(net.clock.unix_s).unwrap();
    let mut outcomes = Vec::new();

    for (offset, read) in [(300, Some(beacon)), (DAY_S, None), (600, Some(beacon))] {
        net.clock.unix_s = START.unix_s + offset;
        let (link, _) = net.connect(0, 1);
        match read {
            Some(beacon) => {
                net.inject(
                    0,
                    Event::BeaconRead {
                        link,
                        beacon: beacon.to_vec(),
                    },
                );
                net.run();
            }
            None => net.read_beacon_of(0, link, 1),
        }
        outcomes.push(first_fragment_headers(&net, 0, link)[0]);
        net.drop_link(0, link);
    }

    assert_eq!(outcomes, [0x10, 0x10, 0x00]);
    assert_ne!(
        net.devices[1].core.beacon(START.unix_s).unwrap(),
        net.devices[1].core.beacon(START.unix_s + 300).unwrap()
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn restored_cores_resume_on_their_persisted_chains() {
    let (mut net, central, _) = paired(108);
    chat(&mut net, 0, "before");
    net.drop_link(0, central);

    for device in 0..2 {
        let event = net.devices[device].store.restore();
        let mut core = Core::new();
        core.handle(net.clock, event).unwrap();
        net.devices[device].core = core;
        net.devices[device].log.clear();
    }
    let (link, _) = net.connect(0, 1);
    net.read_beacon_of(0, link, 1);
    chat(&mut net, 0, "after");

    assert_eq!(received(&net, 1), [(ContactId(0), 2, "after".into())]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn an_unconfirmed_responder_alternates_its_pending_and_current_keys() {
    let mut net = Net::new(2, 109);
    net.intercept = Some(Box::new(|device, fragment| {
        !(device == 0 && fragment[0] == 0x30)
    }));
    let (central, _) = net.connect(0, 1);
    net.inject(
        0,
        Event::BeaconRead {
            link: central,
            beacon: STRANGER_BEACON.to_vec(),
        },
    );
    net.run();
    net.drop_link(0, central);
    net.intercept = Some(silence_after_s2(0));

    let mut answers = Vec::new();
    for attempt in 0..3 {
        let (link, answering) = net.connect(1, 0);
        net.read_beacon_of(1, link, 0);
        answers.push(first_fragment_headers(&net, 0, answering));
        if attempt == 0 {
            net.advance(5_000);
            net.intercept = None;
        }
    }
    chat(&mut net, 1, "made it");

    assert_eq!(answers, [vec![0x20, 0x30], vec![], vec![0x20, 0x30]]);
    assert_eq!(received(&net, 0), [(ContactId(0), 1, "made it".into())]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn tampered_resume_or_data_frames_close_the_link_without_back_off() {
    let mut outcomes = Vec::new();

    for (seed, (sender, header)) in [(0, 0x10), (1, 0x20), (0, 0x30)].into_iter().enumerate() {
        let mut net = Net::new(2, 110 + seed as u64);
        net.intercept = Some(Box::new(move |device, fragment| {
            if device == sender && fragment[0] == header {
                *fragment.last_mut().unwrap() ^= 1;
            }
            true
        }));
        let (central, _) = net.connect(0, 1);
        net.inject(
            0,
            Event::BeaconRead {
                link: central,
                beacon: STRANGER_BEACON.to_vec(),
            },
        );
        net.run();
        net.intercept = None;
        let closed = !net.is_up(0, central);
        let (retry, _) = net.connect(0, 1);
        net.read_beacon_of(0, retry, 1);
        chat(&mut net, 0, "ok");
        outcomes.push((closed, received(&net, 1).len()));
    }

    assert_eq!(outcomes, [(true, 1); 3]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn an_unanswered_s1_times_out() {
    let mut net = Net::new(2, 113);
    net.intercept = Some(silence_after_s2(1));
    let (central, _) = net.connect(0, 1);
    net.inject(
        0,
        Event::BeaconRead {
            link: central,
            beacon: STRANGER_BEACON.to_vec(),
        },
    );
    net.run();

    net.advance(4_999);
    let before = net.is_up(0, central);
    net.advance(1);

    assert!(before);
    assert!(!net.is_up(0, central));
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_second_link_to_a_contact_in_session_is_closed() {
    let (mut net, central, _) = paired(114);
    let (duplicate, _) = net.connect(0, 1);
    net.read_beacon_of(0, duplicate, 1);
    net.lose(0, central);

    let (stale, _) = net.connect(0, 1);
    net.read_beacon_of(0, stale, 1);

    assert!(!net.is_up(0, duplicate), "the central has a session");
    assert!(!net.is_up(0, stale), "the peripheral still has a session");
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_second_link_to_a_contact_mid_resume_is_closed() {
    let (mut net, central, _) = paired(120);
    net.drop_link(0, central);
    net.intercept = Some(silence_after_s2(1));
    let (resuming, _) = net.connect(0, 1);
    net.read_beacon_of(0, resuming, 1);

    let (duplicate, _) = net.connect(0, 1);
    net.read_beacon_of(0, duplicate, 1);

    assert_eq!(
        (net.is_up(0, resuming), net.is_up(0, duplicate)),
        (true, false)
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn an_unknown_pseudonym_or_misplaced_resume_frame_closes_the_link() {
    let mut s1 = vec![0x10];
    s1.extend([7; 56]);
    let frames: [(usize, Vec<u8>); 4] = [
        (1, s1.clone()),
        (0, s1),
        (1, [&[0x20][..], &[7; 48]].concat()),
        (1, vec![0x10; 5]),
    ];
    let mut outcomes = Vec::new();

    for (seed, (device, frame)) in frames.into_iter().enumerate() {
        let mut net = Net::new(2, [115, 116, 117, 121][seed]);
        let (central, peripheral) = net.connect(0, 1);
        let link = [central, peripheral][device];
        net.devices[device].log.clear();
        net.inject(
            device,
            Event::Received {
                link,
                fragment: frame,
            },
        );
        net.run();
        outcomes.push((
            first_fragment_headers(&net, device, link).is_empty(),
            net.is_up(device, link),
        ));
    }

    assert_eq!(outcomes, [(true, false); 4]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn chats_are_rejected_when_too_long_and_queued_without_a_session() {
    let (mut net, central, _) = paired(118);

    let too_long = send_chat(&mut net, 0, &"x".repeat(4046));
    net.drop_link(0, central);
    let queued = send_chat(&mut net, 0, "hi");
    let next = {
        let (link, _) = net.connect(0, 1);
        net.read_beacon_of(0, link, 1);
        send_chat(&mut net, 0, "numbered")
    };

    let rejection = |reason| Action::ChatRejected {
        contact: ContactId(0),
        reason,
    };
    assert_eq!(too_long, [rejection(ChatRejection::TooLong)]);
    assert_eq!(
        queued.last(),
        Some(&Action::ChatQueued {
            contact: ContactId(0),
            msgno: 1
        })
    );
    assert!(next.contains(&Action::ChatSent {
        contact: ContactId(0),
        msgno: 2
    }));
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn the_beacon_query_needs_a_restored_core() {
    Seeded::seed(119);
    let core = Core::<Seeded>::new();

    let result = core.beacon(START.unix_s);

    assert_eq!(result, Err(CoreError::NotRestored));
}
