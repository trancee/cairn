use cairn_proto::{
    PRE_AUTH_FRAME_LIMIT, Reassembler, ReassemblyError, SESSION_FRAME_LIMIT, fragment,
    fragment_intact,
};
use cairn_wire::HeaderError;

const MIN_ATT_MTU: u16 = 23;

/// CRC-16/CCITT-FALSE, written independently of the crate as the oracle (ADR 0042).
fn crc(bytes: &[u8]) -> u16 {
    bytes.iter().fold(0xffff, |crc, &byte| {
        (0..8).fold(crc ^ (u16::from(byte) << 8), |crc, _| {
            (crc << 1) ^ if crc & 0x8000 == 0 { 0 } else { 0x1021 }
        })
    })
}

/// Appends the check to a hand-built fragment.
fn checked(fragment: &[u8]) -> Vec<u8> {
    let mut checked = fragment.to_vec();
    checked.extend_from_slice(&crc(fragment).to_be_bytes());
    checked
}

fn data_frame(body_len: usize) -> Vec<u8> {
    let mut frame = vec![0x30];
    frame.extend((0..body_len).map(|index| index as u8));
    frame
}

#[test]
fn fragments_carry_mtu_minus_six_body_bytes_and_repeat_the_header() {
    let frame = data_frame(40);

    let fragments = fragment(&frame, MIN_ATT_MTU).unwrap();

    let lengths: Vec<usize> = fragments.iter().map(Vec::len).collect();
    let headers: Vec<u8> = fragments.iter().map(|fragment| fragment[0]).collect();
    assert_eq!(lengths, [20, 20, 9]);
    assert_eq!(headers, [0xb0, 0xb0, 0x30]);
}

#[test]
fn a_frame_that_fits_is_one_checked_fragment_without_more() {
    let frame = data_frame(17);

    let fragments = fragment(&frame, MIN_ATT_MTU).unwrap();

    assert_eq!(fragments, [checked(&frame)]);
}

#[test]
fn every_fragment_ends_with_its_crc16_ccitt_false_check() {
    let frame = data_frame(1000);

    let fragments = fragment(&frame, 185).unwrap();

    assert!(fragments.iter().all(|fragment| {
        let (value, check) = fragment.split_at(fragment.len() - 2);
        check == crc(value).to_be_bytes()
    }));
}

#[test]
fn the_check_matches_the_standard_test_vector() {
    let intact = fragment_intact(b"123456789\x29\xb1");

    assert!(intact);
}

#[test]
fn a_fragment_with_any_byte_changed_fails_its_check() {
    let fragment = checked(&data_frame(30));

    let failures = (0..fragment.len())
        .filter(|&index| {
            let mut corrupted = fragment.clone();
            corrupted[index] ^= 0x10;
            !fragment_intact(&corrupted)
        })
        .count();

    assert!(fragment_intact(&fragment));
    assert_eq!(failures, fragment.len());
}

#[test]
fn a_value_too_short_for_a_header_and_check_is_not_intact() {
    let intact = [&[][..], &[0x30][..], &[0xff, 0xff][..]].map(fragment_intact);

    assert_eq!(intact, [false; 3]);
}

#[test]
fn a_fragment_whose_check_fails_is_rejected() {
    let mut reassembler = Reassembler::new(PRE_AUTH_FRAME_LIMIT);
    let mut corrupted = checked(&data_frame(4));
    corrupted[2] ^= 1;

    let result = reassembler.accept(&corrupted);

    assert_eq!(result, Err(ReassemblyError::Check));
}

#[test]
fn fragments_never_exceed_the_512_byte_att_value_limit() {
    let frame = data_frame(1024);

    let fragments = fragment(&frame, 517).unwrap();

    let lengths: Vec<usize> = fragments.iter().map(Vec::len).collect();
    assert_eq!(lengths, [512, 512, 9]);
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

    let outcome = reassembler.accept(&checked(&[0xb0, 1, 2])).unwrap();

    assert_eq!(outcome, None);
    assert!(reassembler.in_progress());
}

#[test]
fn a_fragment_whose_header_differs_beyond_more_is_rejected() {
    let mut reassembler = Reassembler::new(PRE_AUTH_FRAME_LIMIT);
    reassembler.accept(&checked(&[0x80, 1])).unwrap();

    let result = reassembler.accept(&checked(&[0x01, 2]));

    assert_eq!(result, Err(ReassemblyError::HeaderMismatch));
}

#[test]
fn a_reassembled_frame_above_the_limit_is_rejected() {
    let mut reassembler = Reassembler::new(40);
    reassembler.accept(&checked(&[0xb0; 20])).unwrap();

    let result = reassembler.accept(&checked(&[0x30; 22]));

    assert_eq!(result, Err(ReassemblyError::TooLarge));
}

#[test]
fn a_frame_exactly_at_the_limit_is_accepted() {
    let mut reassembler = Reassembler::new(40);
    reassembler.accept(&checked(&[0xb0; 20])).unwrap();

    let result = reassembler
        .accept(&checked(&[0x30; 21]))
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

    let results = [vec![0x30, 0], checked(&[0x40, 0]), checked(&[0x31])]
        .map(|fragment| reassembler.accept(&fragment));

    assert_eq!(
        results,
        [
            Err(ReassemblyError::Short),
            Err(ReassemblyError::Header(HeaderError::ReservedType)),
            Err(ReassemblyError::Header(HeaderError::InvalidSub)),
        ]
    );
}

#[test]
fn reset_discards_a_partial_frame() {
    let mut reassembler = Reassembler::new(PRE_AUTH_FRAME_LIMIT);
    reassembler.accept(&checked(&[0xb0, 1])).unwrap();

    reassembler.reset();

    assert!(!reassembler.in_progress());
    assert_eq!(
        reassembler.accept(&checked(&[0x00, 7])),
        Ok(Some(vec![0x00, 7]))
    );
}

#[test]
fn an_empty_frame_has_no_fragments() {
    let fragments = fragment(&[], 23);

    assert_eq!(fragments, Ok(Vec::new()));
}
