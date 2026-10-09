use cairn_wire::{WireError, decode_leb128, encode_leb128};

#[test]
fn canonical_unsigned_leb128_examples() {
    for (value, expected) in [
        (0, &[0x00][..]),
        (127, &[0x7f][..]),
        (128, &[0x80, 0x01][..]),
        (624_485, &[0xe5, 0x8e, 0x26][..]),
        (u32::MAX, &[0xff, 0xff, 0xff, 0xff, 0x0f][..]),
    ] {
        let mut output = [0; 5];
        let written = encode_leb128(value, &mut output).unwrap();
        assert_eq!(&output[..written], expected);
        assert_eq!(decode_leb128(expected), Ok((value, written)));
    }
}

#[test]
fn malformed_leb128_is_rejected_and_short_output_is_untouched() {
    for (input, error) in [
        (&[][..], WireError::Truncated),
        (&[0x80][..], WireError::Truncated),
        (&[0x80, 0x00][..], WireError::NonMinimal),
        (&[0xff, 0xff, 0xff, 0xff, 0x10][..], WireError::Overflow),
        (&[0x80, 0x80, 0x80, 0x80, 0x80][..], WireError::Overflow),
    ] {
        assert_eq!(decode_leb128(input), Err(error));
    }
    let mut output = [0xaa];
    assert_eq!(
        encode_leb128(128, &mut output),
        Err(WireError::BufferTooSmall)
    );
    assert_eq!(output, [0xaa]);
    assert_eq!(decode_leb128(&[1, 99]), Ok((1, 1)));
}

#[test]
fn length_prefixed_fields_use_big_endian_and_leave_trailing_bytes() {
    let mut output = [0; 6];
    let written = cairn_wire::encode_length_prefixed(b"abc", &mut output).unwrap();
    assert_eq!(&output[..written], b"\x00\x03abc");
    assert_eq!(
        cairn_wire::decode_length_prefixed(b"\x00\x03abc!"),
        Ok((&b"abc"[..], 5))
    );
}

#[test]
fn length_prefix_rejects_truncation_capacity_and_length_overflow() {
    for input in [&[][..], &[0][..], &[0, 2, 1][..]] {
        assert_eq!(
            cairn_wire::decode_length_prefixed(input),
            Err(WireError::Truncated)
        );
    }
    let mut output = [0xaa; 2];
    assert_eq!(
        cairn_wire::encode_length_prefixed(b"a", &mut output),
        Err(WireError::BufferTooSmall)
    );
    assert_eq!(output, [0xaa; 2]);
    assert_eq!(
        cairn_wire::encode_length_prefixed(&vec![0; 65_536], &mut output),
        Err(WireError::LengthOverflow)
    );
    assert_eq!(output, [0xaa; 2]);
    assert_eq!(cairn_wire::encode_length_prefixed(b"", &mut output), Ok(2));
    assert_eq!(output, [0, 0]);
    assert_eq!(
        cairn_wire::decode_length_prefixed(&output),
        Ok((&[][..], 2))
    );
    let mut maximum = vec![0; 65_537];
    assert_eq!(
        cairn_wire::encode_length_prefixed(&vec![42; 65_535], &mut maximum),
        Ok(65_537)
    );
    assert_eq!(
        cairn_wire::decode_length_prefixed(&maximum),
        Ok((&maximum[2..], 65_537))
    );
}
