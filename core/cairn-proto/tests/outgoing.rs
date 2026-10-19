use cairn_proto::{
    Epoch, ObjectKind, ObjectLengthInvalid, OutgoingChunk, OutgoingObject, ProgressRejected,
};

const EPOCH: Epoch = Epoch::new(6);
const KIND: ObjectKind = ObjectKind::EncapsulationKey;

fn object_bytes() -> Vec<u8> {
    (0..KIND.length())
        .map(|index| (index % 253) as u8)
        .collect()
}

fn outgoing() -> OutgoingObject {
    OutgoingObject::new(EPOCH, KIND, object_bytes()).expect("fixed-length object")
}

fn outgoing_after_sending(lengths: &[usize]) -> OutgoingObject {
    let mut object = outgoing();
    for &length in lengths {
        assert!(object.next_chunk(length).is_some(), "arrange send {length}");
    }
    object
}

#[test]
fn object_with_wrong_length_is_rejected() {
    let short = vec![0; KIND.length() - 1];

    let object = OutgoingObject::new(EPOCH, KIND, short);

    assert_eq!(object, Err(ObjectLengthInvalid));
}

#[test]
fn new_object_has_no_acknowledged_bytes() {
    let object = outgoing();

    let state = (object.acknowledged(), object.is_fully_acknowledged());

    assert_eq!(state, (0, false));
    assert_eq!((object.epoch(), object.kind()), (EPOCH, KIND));
}

#[test]
fn chunks_are_sequential_and_bounded_by_capacity() {
    let mut object = outgoing_after_sending(&[500]);
    let bytes = object_bytes();

    let chunk = object.next_chunk(500);

    assert_eq!(
        chunk,
        Some(OutgoingChunk {
            offset: 500,
            bytes: &bytes[500..1000]
        })
    );
}

#[test]
fn last_chunk_is_truncated_to_the_remaining_bytes() {
    let mut object = outgoing_after_sending(&[1000]);
    let bytes = object_bytes();

    let chunk = object.next_chunk(500);

    assert_eq!(
        chunk,
        Some(OutgoingChunk {
            offset: 1000,
            bytes: &bytes[1000..]
        })
    );
}

#[test]
fn no_chunk_is_produced_after_the_whole_object_was_sent() {
    let mut object = outgoing_after_sending(&[KIND.length()]);

    let chunk = object.next_chunk(500);

    assert_eq!(chunk, None);
}

#[test]
fn zero_capacity_produces_no_empty_chunk() {
    let mut object = outgoing();

    let chunk = object.next_chunk(0);

    assert_eq!(chunk, None);
}

#[test]
fn progress_within_sent_bytes_is_acknowledged() {
    let mut object = outgoing_after_sending(&[700]);

    let result = object.accept_progress(EPOCH, KIND, 600);

    assert_eq!(result, Ok(()));
    assert_eq!(object.acknowledged(), 600);
}

#[test]
fn full_progress_acknowledges_the_whole_object() {
    let mut object = outgoing_after_sending(&[KIND.length()]);

    let result = object.accept_progress(EPOCH, KIND, 1184);

    assert_eq!(result, Ok(()));
    assert!(object.is_fully_acknowledged());
}

#[test]
fn older_progress_does_not_decrease_acknowledgement() {
    let mut object = outgoing_after_sending(&[700]);
    object
        .accept_progress(EPOCH, KIND, 600)
        .expect("arrange progress");

    let result = object.accept_progress(EPOCH, KIND, 200);

    assert_eq!(result, Ok(()));
    assert_eq!(object.acknowledged(), 600);
}

fn assert_progress_rejected(epoch: Epoch, kind: ObjectKind, next_offset: u32) {
    let mut object = outgoing_after_sending(&[700]);
    let before = object.clone();

    let result = object.accept_progress(epoch, kind, next_offset);

    assert_eq!(result, Err(ProgressRejected), "next_offset {next_offset}");
    assert_eq!(object, before, "rejected progress mutated state");
}

#[test]
fn progress_for_wrong_epoch_is_rejected() {
    assert_progress_rejected(Epoch::new(7), KIND, 100);
}

#[test]
fn progress_for_wrong_kind_is_rejected() {
    assert_progress_rejected(EPOCH, ObjectKind::Ciphertext, 100);
}

#[test]
fn progress_beyond_sent_bytes_is_rejected() {
    assert_progress_rejected(EPOCH, KIND, 701);
}

#[test]
fn progress_beyond_object_length_is_rejected() {
    assert_progress_rejected(EPOCH, KIND, u32::MAX);
}

#[test]
fn new_session_resends_from_the_acknowledged_offset() {
    let mut object = outgoing_after_sending(&[700]);
    object
        .accept_progress(EPOCH, KIND, 400)
        .expect("arrange progress");
    object.restart_session();
    let bytes = object_bytes();

    let chunk = object.next_chunk(100);

    assert_eq!(
        chunk,
        Some(OutgoingChunk {
            offset: 400,
            bytes: &bytes[400..500]
        })
    );
}

#[test]
fn new_session_without_progress_resends_from_zero() {
    let mut object = outgoing_after_sending(&[700]);
    object.restart_session();
    let bytes = object_bytes();

    let chunk = object.next_chunk(100);

    assert_eq!(
        chunk,
        Some(OutgoingChunk {
            offset: 0,
            bytes: &bytes[..100]
        })
    );
}

#[test]
fn reconnect_progress_for_previously_sent_bytes_skips_ahead() {
    let mut object = outgoing_after_sending(&[700]);
    object.restart_session();
    object
        .accept_progress(EPOCH, KIND, 650)
        .expect("arrange reconnect progress");
    let bytes = object_bytes();

    let chunk = object.next_chunk(100);

    assert_eq!(
        chunk,
        Some(OutgoingChunk {
            offset: 650,
            bytes: &bytes[650..750]
        })
    );
}

#[test]
fn progress_rejection_has_a_redacted_diagnostic() {
    let diagnostic = (
        ProgressRejected.to_string(),
        ObjectLengthInvalid.to_string(),
    );

    assert_eq!(
        diagnostic,
        (
            "KEM_PROGRESS rejected".into(),
            "KEM object length invalid".into()
        )
    );
}
