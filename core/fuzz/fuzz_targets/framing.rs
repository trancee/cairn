#![no_main]

use cairn_proto::{PRE_AUTH_FRAME_LIMIT, Reassembler, SESSION_FRAME_LIMIT, fragment};
use cairn_wire::Header;
use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    // Arbitrary length-prefixed fragments: every frame is in bounds and well formed.
    let mut reassembler = Reassembler::new(PRE_AUTH_FRAME_LIMIT);
    let mut rest = input;
    while let Some((&length, after)) = rest.split_first() {
        let (piece, after) = after.split_at(usize::from(length).min(after.len()));
        rest = after;
        match reassembler.accept(piece) {
            Ok(Some(frame)) => {
                assert!(frame.len() <= PRE_AUTH_FRAME_LIMIT);
                assert!(!Header::parse(frame[0]).unwrap().more());
                assert!(!reassembler.in_progress());
            }
            Ok(None) => assert!(reassembler.in_progress()),
            Err(_) => reassembler.reset(),
        }
    }

    // Any well-formed frame survives fragmentation at any MTU unchanged.
    let Some((&mtu, frame)) = input.split_first() else {
        return;
    };
    let mtu = 23 + u16::from(mtu) * 2;
    let Some(header) = frame.first().and_then(|byte| Header::parse(*byte).ok()) else {
        return;
    };
    if header.more() || frame.len() > SESSION_FRAME_LIMIT {
        return;
    }
    let fragments = fragment(frame, mtu).unwrap();
    let mut reassembler = Reassembler::new(SESSION_FRAME_LIMIT);
    let (last, init) = fragments.split_last().unwrap();
    for piece in init {
        assert!(piece.len() <= usize::from(mtu) - 3);
        assert_eq!(reassembler.accept(piece), Ok(None));
    }
    assert!(last.len() <= usize::from(mtu) - 3);
    assert_eq!(reassembler.accept(last), Ok(Some(frame.to_vec())));
});
