#![no_main]

//! Two cores pair, resume and chat over a loopback whose fragments the input
//! drops, truncates, corrupts or replaces. `Net` panics if `handle` ever
//! returns an error for a contract-valid event; every received chat must be
//! one the peer sent under that number.

#[path = "../../cairn-proto/tests/support/mod.rs"]
mod support;

use cairn_proto::{Action, Event, LinkId};
use libfuzzer_sys::fuzz_target;
use std::cell::RefCell;
use std::collections::{BTreeMap, BTreeSet};
use std::rc::Rc;
use support::Net;

const STRANGER_BEACON: [u8; 8] = [0x5a; 8];

struct Script {
    bytes: Vec<u8>,
    at: usize,
}

impl Script {
    fn next(&mut self) -> Option<u8> {
        let byte = *self.bytes.get(self.at)?;
        self.at += 1;
        Some(byte)
    }

    fn take(&mut self, length: usize) -> Vec<u8> {
        let end = (self.at + length).min(self.bytes.len());
        let taken = self.bytes[self.at..end].to_vec();
        self.at = end;
        taken
    }
}

/// Applies the next mutation to an in-flight fragment; `false` drops it.
fn mutate(script: &mut Script, fragment: &mut Vec<u8>) -> bool {
    let Some(op) = script.next() else {
        return true;
    };
    let position = usize::from(script.next().unwrap_or(0));
    match op {
        0..160 => {}
        160..200 if !fragment.is_empty() => {
            let index = position % fragment.len();
            fragment[index] ^= 1 << (position % 8);
        }
        200..220 => fragment.truncate(position % (fragment.len() + 1)),
        220..240 => return false,
        _ => *fragment = script.take(position % 64),
    }
    true
}

fuzz_target!(|input: &[u8]| {
    let Some((seed, script)) = input.split_first_chunk::<8>() else {
        return;
    };
    let script = Rc::new(RefCell::new(Script {
        bytes: script.to_vec(),
        at: 0,
    }));
    let mut net = Net::new(2, u64::from_be_bytes(*seed));
    let tap = Rc::clone(&script);
    net.intercept = Some(Box::new(move |_, fragment| {
        mutate(&mut tap.borrow_mut(), fragment)
    }));
    let mut links: Vec<(LinkId, LinkId)> = Vec::new();
    let mut sent: BTreeMap<(usize, u32), BTreeSet<String>> = BTreeMap::new();

    loop {
        let Some(op) = script.borrow_mut().next() else {
            break;
        };
        let device = usize::from(op >> 7);
        match op % 5 {
            0 => {
                let (central, peripheral) = net.connect(0, 1);
                links.push((central, peripheral));
                if op & 0x40 == 0 {
                    net.inject(
                        0,
                        Event::BeaconRead {
                            link: central,
                            beacon: STRANGER_BEACON.to_vec(),
                        },
                    );
                    net.run();
                } else {
                    net.read_beacon_of(0, central, 1);
                }
            }
            1 => {
                let contacts = net.devices[device].core.contacts();
                let pick = usize::from(script.borrow_mut().next().unwrap_or(0));
                let Some(contact) = contacts.get(pick % contacts.len().max(1)) else {
                    continue;
                };
                let length = usize::from(script.borrow_mut().next().unwrap_or(0));
                let text = String::from_utf8_lossy(&script.borrow_mut().take(length)).into_owned();
                let before = net.devices[device].log.len();
                net.inject(
                    device,
                    Event::SendChat {
                        contact: contact.id,
                        text: text.clone(),
                    },
                );
                net.run();
                for action in &net.devices[device].log[before..] {
                    if let Action::ChatSent { msgno, .. } = action {
                        sent.entry((device, *msgno))
                            .or_default()
                            .insert(text.clone());
                    }
                }
            }
            2 => net.advance(u64::from(script.borrow_mut().next().unwrap_or(0)) * 100),
            3 | 4 => {
                let pick = usize::from(script.borrow_mut().next().unwrap_or(0));
                let Some(&(central, peripheral)) = links.get(pick % links.len().max(1)) else {
                    continue;
                };
                let (end, link) = if op % 5 == 3 {
                    (0, central)
                } else {
                    (1, peripheral)
                };
                if net.is_up(end, link) {
                    net.lose(end, link);
                }
            }
            _ => unreachable!(),
        }
    }
    net.advance(600_000);

    for (device, peer) in [(0, 1), (1, 0)] {
        for action in &net.devices[device].log {
            if let Action::ChatReceived { msgno, text, .. } = action {
                let texts = sent.get(&(peer, *msgno));
                assert!(
                    texts.is_some_and(|texts| texts.contains(text)),
                    "device {device} received a chat {peer} never sent as {msgno}"
                );
            }
        }
    }
});
