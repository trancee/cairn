//! Queued messages, receipts and expiry between loopback cores (spec §8, ADR 0034).

mod support;

use cairn_proto::{Action, ChatRejection, ContactId, Core, Event, LinkId};
use support::Net;

const STRANGER_BEACON: [u8; 8] = [0x5a; 8];
const WEEK_S: u64 = 7 * 86_400;
const PEER: ContactId = ContactId(0);
/// The first fragment of a DATA frame.
const DATA: u8 = 0x30;

/// Pairs device 0 (central, the first Resume's I) with device 1.
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
    act(
        net,
        device,
        Event::SendChat {
            contact: PEER,
            text: text.into(),
        },
    )
}

fn act(net: &mut Net, device: usize, event: Event) -> Vec<Action> {
    let start = net.devices[device].log.len();
    net.inject(device, event);
    net.run();
    net.devices[device].log[start..].to_vec()
}

/// Device 0 connects to device 1 and resumes.
fn resume(net: &mut Net) -> LinkId {
    let (link, _) = net.connect(0, 1);
    net.read_beacon_of(0, link, 1);
    link
}

fn received(net: &Net, device: usize) -> Vec<(u32, String)> {
    net.devices[device]
        .log
        .iter()
        .filter_map(|action| match action {
            Action::ChatReceived { msgno, text, .. } => Some((*msgno, text.clone())),
            _ => None,
        })
        .collect()
}

fn delivered(net: &Net, device: usize) -> Vec<u32> {
    msgnos(net, device, |action| match action {
        Action::ChatDelivered { msgno, .. } => Some(*msgno),
        _ => None,
    })
}

fn msgnos(net: &Net, device: usize, pick: impl Fn(&Action) -> Option<u32>) -> Vec<u32> {
    net.devices[device].log.iter().filter_map(pick).collect()
}

fn position(log: &[Action], predicate: impl Fn(&Action) -> bool) -> usize {
    log.iter().position(predicate).unwrap()
}

/// Drops every DATA frame `device` sends from now on.
fn mute(net: &mut Net, device: usize) {
    net.intercept = Some(Box::new(move |sender, fragment| {
        sender != device || fragment[0] != DATA
    }));
}

/// `device` dies and restarts from its stored rows; its peer sees the link drop.
fn restart(net: &mut Net, device: usize, peer: usize, peer_link: LinkId) -> Vec<Action> {
    net.devices[device].core = Core::new();
    let rows = net.devices[device].store.restore();
    let actions = act(net, device, rows);
    net.lose(peer, peer_link);
    actions
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_chat_sent_offline_is_stored_then_delivered_after_the_next_resume() {
    let (mut net, central, _) = paired(200);
    net.drop_link(0, central);

    let queued = send_chat(&mut net, 0, "later");
    let stored = net.devices[0].store.queued.len();
    resume(&mut net);

    let row = position(&queued, |action| matches!(action, Action::PutQueued { .. }));
    let contact = position(&queued, |action| {
        matches!(action, Action::PersistContact { .. })
    });
    let shown = position(&queued, |action| {
        *action
            == Action::ChatQueued {
                contact: PEER,
                msgno: 1,
            }
    });
    assert!(contact < shown && row < shown, "rows are stored first");
    assert_eq!(stored, 1);
    assert_eq!(received(&net, 1), [(1, "later".into())]);
    assert_eq!(delivered(&net, 0), [1]);
    assert!(net.devices[0].store.queued.is_empty(), "the ACK deletes it");
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn the_responder_queues_under_its_chain_and_both_sides_flush_after_resume() {
    let (mut net, central, _) = paired(201);
    net.drop_link(0, central);

    send_chat(&mut net, 1, "from R");
    send_chat(&mut net, 0, "from I");
    resume(&mut net);

    assert_eq!(received(&net, 0), [(1, "from R".into())]);
    assert_eq!(received(&net, 1), [(1, "from I".into())]);
    assert_eq!(delivered(&net, 0), [1]);
    assert_eq!(delivered(&net, 1), [1]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_chat_in_session_is_delivered_when_acked() {
    let (mut net, _, _) = paired(202);

    send_chat(&mut net, 0, "hi");
    send_chat(&mut net, 0, "again");

    assert_eq!(delivered(&net, 0), [1, 2]);
    assert!(net.devices[0].store.queued.is_empty());
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn an_unacked_chat_is_resealed_when_the_link_drops_and_resent() {
    let (mut net, central, _) = paired(203);
    mute(&mut net, 0);

    send_chat(&mut net, 0, "lost");
    net.drop_link(0, central);
    let stored = net.devices[0].store.queued.len();
    net.intercept = None;
    resume(&mut net);

    assert_eq!(stored, 1, "the CHAT was resealed as QUEUED");
    assert_eq!(received(&net, 1), [(1, "lost".into())]);
    assert_eq!(delivered(&net, 0), [1]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_message_received_twice_is_shown_once() {
    let (mut net, central, _) = paired(204);
    mute(&mut net, 1);

    send_chat(&mut net, 0, "once");
    net.drop_link(0, central);
    net.intercept = None;
    resume(&mut net);

    assert_eq!(received(&net, 1), [(1, "once".into())]);
    assert_eq!(delivered(&net, 0), [1]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn unacked_chats_expire_after_a_restart_and_the_peer_is_told() {
    let (mut net, _, peripheral) = paired(205);
    mute(&mut net, 0);
    send_chat(&mut net, 0, "gone");
    net.intercept = None;

    let restored = restart(&mut net, 0, 1, peripheral);
    resume(&mut net);
    send_chat(&mut net, 0, "after");

    assert!(restored.contains(&Action::ChatExpired {
        contact: PEER,
        msgno: 1
    }));
    assert!(net.devices[1].log.contains(&Action::ChatsExpired {
        contact: PEER,
        from: 1,
        to: 1
    }));
    assert_eq!(received(&net, 1), [(2, "after".into())]);
    assert_eq!(delivered(&net, 0), [2]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_queued_chat_expires_after_seven_days() {
    let (mut net, central, _) = paired(206);
    net.drop_link(0, central);
    send_chat(&mut net, 0, "stale");

    net.clock.unix_s += WEEK_S;
    resume(&mut net);

    let expired = msgnos(&net, 0, |action| match action {
        Action::ChatExpired { msgno, .. } => Some(*msgno),
        _ => None,
    });
    assert_eq!(expired, [1]);
    assert!(net.devices[0].store.queued.is_empty());
    assert!(received(&net, 1).is_empty());
    assert!(net.devices[1].log.contains(&Action::ChatsExpired {
        contact: PEER,
        from: 1,
        to: 1
    }));
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn read_marks_reach_the_sender_in_session_or_at_the_next_session() {
    let (mut net, central, _) = paired(207);
    send_chat(&mut net, 0, "one");
    send_chat(&mut net, 0, "two");

    act(
        &mut net,
        1,
        Event::MarkRead {
            contact: PEER,
            msgno: 1,
        },
    );
    net.drop_link(0, central);
    act(
        &mut net,
        1,
        Event::MarkRead {
            contact: PEER,
            msgno: 2,
        },
    );
    resume(&mut net);

    let read = msgnos(&net, 0, |action| match action {
        Action::ChatRead { msgno, .. } => Some(*msgno),
        _ => None,
    });
    assert_eq!(read, [1, 2]);
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn read_receipts_off_are_neither_sent_nor_shown() {
    let (mut net, central, _) = paired(208);
    send_chat(&mut net, 0, "one");
    send_chat(&mut net, 1, "two");

    let setting = act(&mut net, 1, Event::SetReadReceipts { enabled: false });
    act(
        &mut net,
        1,
        Event::MarkRead {
            contact: PEER,
            msgno: 1,
        },
    );
    act(
        &mut net,
        0,
        Event::MarkRead {
            contact: PEER,
            msgno: 1,
        },
    );
    let unknown = act(
        &mut net,
        1,
        Event::MarkRead {
            contact: PEER,
            msgno: 9,
        },
    );
    net.drop_link(0, central);
    resume(&mut net);

    assert!(matches!(setting[..], [Action::PersistDevice { .. }]));
    assert!(unknown.is_empty(), "an unreceived number is ignored");
    for device in 0..2 {
        assert!(
            !net.devices[device]
                .log
                .iter()
                .any(|action| matches!(action, Action::ChatRead { .. }))
        );
    }
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn a_full_queue_rejects_new_chats() {
    let (mut net, central, _) = paired(209);
    net.drop_link(0, central);
    for _ in 0..500 {
        send_chat(&mut net, 0, "q");
    }

    let full = send_chat(&mut net, 0, "one more");

    assert_eq!(
        full,
        [Action::ChatRejected {
            contact: PEER,
            reason: ChatRejection::QueueFull
        }]
    );
}

#[test]
#[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
fn queued_chats_larger_than_one_frame_are_flushed_across_frames() {
    let (mut net, central, _) = paired(210);
    net.drop_link(0, central);
    let texts: Vec<String> = (b'a'..=b'c')
        .map(|c| (c as char).to_string().repeat(2000))
        .collect();
    for text in &texts {
        send_chat(&mut net, 0, text);
    }

    resume(&mut net);

    let expected: Vec<(u32, String)> = (1..).zip(texts).collect();
    assert_eq!(received(&net, 1), expected);
    assert_eq!(delivered(&net, 0), [1, 2, 3]);
}
