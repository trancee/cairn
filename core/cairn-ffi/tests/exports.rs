use cairn_ffi::{
    ChunkOutcome, DecodedField, DecodedLeb128, IncomingObject, ObjectKind, TransferError,
    WireError, decode_leb128, decode_length_prefixed, encode_leb128, encode_length_prefixed,
};

#[test]
fn length_prefixed_field_round_trips() {
    let encoded = encode_length_prefixed(b"cairn".to_vec()).unwrap();

    let decoded = decode_length_prefixed([encoded.as_slice(), &[0xff]].concat()).unwrap();

    assert_eq!(encoded, b"\x00\x05cairn");
    assert_eq!(
        decoded,
        DecodedField {
            value: b"cairn".to_vec(),
            consumed: 7,
        }
    );
}

#[test]
fn truncated_length_prefixed_field_is_typed_error() {
    let result = decode_length_prefixed(vec![0x00, 0x02, 0x01]);

    assert_eq!(result, Err(WireError::Truncated));
}

#[test]
fn oversized_length_prefixed_value_is_typed_error() {
    let result = encode_length_prefixed(vec![0; 65_536]);

    assert_eq!(result, Err(WireError::LengthOverflow));
}

#[test]
fn leb128_value_round_trips() {
    let encoded = encode_leb128(624_485);

    let decoded = decode_leb128(encoded.clone()).unwrap();

    assert_eq!(encoded, [0xe5, 0x8e, 0x26]);
    assert_eq!(
        decoded,
        DecodedLeb128 {
            value: 624_485,
            consumed: 3,
        }
    );
}

#[test]
fn leb128_rejections_map_to_typed_errors() {
    let non_minimal = decode_leb128(vec![0x80, 0x00]);
    let overflow = decode_leb128(vec![0xff, 0xff, 0xff, 0xff, 0x10]);

    assert_eq!(non_minimal, Err(WireError::NonMinimal));
    assert_eq!(overflow, Err(WireError::Overflow));
}

#[test]
fn incoming_object_assembles_complete_ciphertext() {
    let object = IncomingObject::new(3, ObjectKind::Ciphertext);
    let first = object.accept_chunk(3, ObjectKind::Ciphertext, 0, vec![0xa5; 600]);
    let duplicate = object.accept_chunk(3, ObjectKind::Ciphertext, 0, vec![0xa5; 10]);

    let last = object.accept_chunk(3, ObjectKind::Ciphertext, 600, vec![0x5a; 488]);

    assert_eq!(first, Ok(ChunkOutcome::Appended));
    assert_eq!(duplicate, Ok(ChunkOutcome::Duplicate));
    assert_eq!(last, Ok(ChunkOutcome::Appended));
    assert_eq!(object.next_offset(), 1088);
    assert_eq!(object.epoch(), 3);
    assert_eq!(object.kind(), ObjectKind::Ciphertext);
    let completed = object.completed().unwrap();
    assert_eq!(completed.len(), 1088);
    assert_eq!(completed[599..601], [0xa5, 0x5a]);
}

#[test]
fn incoming_object_rejects_wrong_epoch_without_progress() {
    let object = IncomingObject::new(4, ObjectKind::EncapsulationKey);

    let result = object.accept_chunk(5, ObjectKind::EncapsulationKey, 0, vec![1]);

    assert_eq!(result, Err(TransferError::Invalid));
    assert_eq!(object.next_offset(), 0);
    assert_eq!(object.kind(), ObjectKind::EncapsulationKey);
    assert_eq!(object.completed(), None);
}

#[test]
fn transfer_error_reports_the_specified_local_reason() {
    let reason = TransferError::Invalid.to_string();

    assert_eq!(reason, "pq_transfer_invalid");
}
