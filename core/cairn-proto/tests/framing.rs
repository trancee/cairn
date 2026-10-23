use cairn_proto::{
    PRE_AUTH_FRAME_LIMIT, Reassembler, ReassemblyError, SESSION_FRAME_LIMIT, fragment,
};
use cairn_wire::HeaderError;

const MIN_ATT_MTU: u16 = 23;

fn data_frame(body_len: usize) -> Vec<u8> {
    let mut frame = vec![0x30];
    frame.extend((0..body_len).map(|index| index as u8));
    frame
}

#[test]
fn fragments_carry_mtu_minus_four_body_bytes_and_repeat_the_header() {
    let frame = data_frame(40);

    let fragments = fragment(&frame, MIN_ATT_MTU).unwrap();

    let lengths: Vec<usize> = fragments.iter().map(Vec::len).collect();
    let headers: Vec<u8> = fragments.iter().map(|fragment| fragment[0]).collect();
    assert_eq!(lengths, [20, 20, 3]);
    assert_eq!(headers, [0xb0, 0xb0, 0x30]);
}

#[test]
fn a_frame_that_fits_is_one_fragment_without_more() {
    let frame = data_frame(19);

    let fragments = fragment(&frame, MIN_ATT_MTU).unwrap();

    assert_eq!(fragments, [frame]);
}

#[test]
fn mtu_below_the_att_minimum_is_rejected() {
    let frame = data_frame(4);

    let result = fragment(&frame, MIN_ATT_MTU - 1);

    assert!(result.is_err());
}

#[test]
fn reassembly_restores_the_frame_with_more_cleared() {
    let frame = data_frame(1000);
    let mut reassembler = Reassembler::new(PRE_AUTH_FRAME_LIMIT);
    let fragments = fragment(&frame, 185).unwrap();

    let outcomes: Vec<Option<Vec<u8>>> = fragments
        .iter()
        .map(|fragment| reassembler.accept(fragment).unwrap())
        .collect();

    let (last, earlier) = outcomes.split_last().unwrap();
    assert!(earlier.iter().all(Option::is_none));
    assert_eq!(last.as_deref(), Some(&frame[..]));
    assert!(!reassembler.in_progress());
}

#[test]
fn reassembler_reports_a_partial_frame_in_progress() {
    let mut reassembler = Reassembler::new(PRE_AUTH_FRAME_LIMIT);

    let outcome = reassembler.accept(&[0xb0, 1, 2]).unwrap();

    assert_eq!(outcome, None);
    assert!(reassembler.in_progress());
}

#[test]
fn a_fragment_whose_header_differs_beyond_more_is_rejected() {
    let mut reassembler = Reassembler::new(PRE_AUTH_FRAME_LIMIT);
    reassembler.accept(&[0x80, 1]).unwrap();

    let result = reassembler.accept(&[0x01, 2]);

    assert_eq!(result, Err(ReassemblyError::HeaderMismatch));
}

#[test]
fn a_reassembled_frame_above_the_limit_is_rejected() {
    let mut reassembler = Reassembler::new(40);
    reassembler.accept(&[0xb0; 20]).unwrap();

    let result = reassembler.accept(&[0x30; 22]);

    assert_eq!(result, Err(ReassemblyError::TooLarge));
}

#[test]
fn a_frame_exactly_at_the_limit_is_accepted() {
    let mut reassembler = Reassembler::new(40);
    reassembler.accept(&[0xb0; 20]).unwrap();

    let result = reassembler
        .accept(&[0x30; 21])
        .map(|frame| frame.map(|frame| frame.len()));

    assert_eq!(result, Ok(Some(40)));
}

#[test]
fn raising_the_limit_admits_session_sized_frames() {
    let mut reassembler = Reassembler::new(PRE_AUTH_FRAME_LIMIT);
    let fragments = fragment(&data_frame(SESSION_FRAME_LIMIT - 1), 512).unwrap();

    reassembler.set_limit(SESSION_FRAME_LIMIT);
    let frames: Vec<_> = fragments
        .iter()
        .map(|fragment| reassembler.accept(fragment).unwrap())
        .collect();

    assert_eq!(
        frames.last().unwrap().as_ref().map(Vec::len),
        Some(SESSION_FRAME_LIMIT)
    );
}

#[test]
fn invalid_headers_and_empty_fragments_are_rejected() {
    let mut reassembler = Reassembler::new(PRE_AUTH_FRAME_LIMIT);

    let results =
        [&[][..], &[0x40, 0][..], &[0x31][..]].map(|fragment| reassembler.accept(fragment));

    assert_eq!(
        results,
        [
            Err(ReassemblyError::Empty),
            Err(ReassemblyError::Header(HeaderError::ReservedType)),
            Err(ReassemblyError::Header(HeaderError::InvalidSub)),
        ]
    );
}

#[test]
fn reset_discards_a_partial_frame() {
    let mut reassembler = Reassembler::new(PRE_AUTH_FRAME_LIMIT);
    reassembler.accept(&[0xb0, 1]).unwrap();

    reassembler.reset();

    assert!(!reassembler.in_progress());
    assert_eq!(reassembler.accept(&[0x00, 7]), Ok(Some(vec![0x00, 7])));
}

#[test]
fn an_empty_frame_has_no_fragments() {
    let fragments = fragment(&[], 23);

    assert_eq!(fragments, Ok(Vec::new()));
}
