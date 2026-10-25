use cairn_wire::{FrameType, Header, HeaderError};

#[test]
fn header_byte_packs_more_type_and_sub() {
    let header = Header::new(FrameType::ResumeInit, 0b10).unwrap();

    let bytes = [header.to_byte(), header.with_more(true).to_byte()];

    assert_eq!(bytes, [0b0001_0010, 0b1001_0010]);
}

#[test]
fn parse_recovers_every_field() {
    let byte = 0b1011_0000;

    let header = Header::parse(byte).unwrap();

    assert!(header.more());
    assert_eq!(header.frame_type(), FrameType::Data);
    assert_eq!(header.sub(), 0);
    assert_eq!(header.to_byte(), byte);
}

#[test]
fn reserved_frame_types_are_rejected() {
    let bytes = [0x40, 0x50, 0x60, 0x70, 0xf0];

    let results = bytes.map(Header::parse);

    assert_eq!(results, [Err(HeaderError::ReservedType); 5]);
}

#[test]
fn pairing_sub_is_the_step_zero_to_four_or_busy() {
    let subs = 0..=15u8;

    let accepted: Vec<u8> = subs
        .filter(|&sub| Header::new(FrameType::Pair, sub).is_ok())
        .collect();

    assert_eq!(accepted, [0, 1, 2, 3, 4, 5]);
    assert_eq!(
        Header::parse(0x06),
        Err(HeaderError::InvalidSub),
        "step 6 does not exist"
    );
}

#[test]
fn resume_init_allows_kci_and_mix_bits_only() {
    let subs = 0..=15u8;

    let accepted: Vec<u8> = subs
        .filter(|&sub| Header::new(FrameType::ResumeInit, sub).is_ok())
        .collect();

    assert_eq!(accepted, [0, 1, 2, 3]);
}

#[test]
fn resume_reply_allows_the_kci_bit_only() {
    let subs = 0..=15u8;

    let accepted: Vec<u8> = subs
        .filter(|&sub| Header::new(FrameType::ResumeReply, sub).is_ok())
        .collect();

    assert_eq!(accepted, [0, 1]);
}

#[test]
fn data_sub_must_be_zero() {
    let parsed = [0x30, 0x31, 0x3f].map(Header::parse);

    assert_eq!(
        parsed,
        [
            Ok(Header::new(FrameType::Data, 0).unwrap()),
            Err(HeaderError::InvalidSub),
            Err(HeaderError::InvalidSub),
        ]
    );
}

#[test]
fn header_errors_have_stable_messages() {
    let errors = [HeaderError::ReservedType, HeaderError::InvalidSub];

    let messages = errors.map(|error| error.to_string());

    assert_eq!(messages, ["reserved frame type", "invalid frame sub value"]);
}

#[test]
fn every_frame_type_round_trips_through_its_byte() {
    let types = [
        FrameType::Pair,
        FrameType::ResumeInit,
        FrameType::ResumeReply,
        FrameType::Data,
    ];

    let parsed = types.map(|frame_type| {
        Header::parse(Header::new(frame_type, 0).unwrap().to_byte())
            .unwrap()
            .frame_type()
    });

    assert_eq!(parsed, types);
}
