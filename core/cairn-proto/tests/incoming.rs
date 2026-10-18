use cairn_proto::{ChunkOutcome, Epoch, IncomingObject, ObjectKind, TransferInvalid};

const EPOCH: Epoch = Epoch::new(4);
const KIND: ObjectKind = ObjectKind::Ciphertext;

fn object_bytes() -> Vec<u8> {
    (0..KIND.length())
        .map(|index| (index % 251) as u8)
        .collect()
}

fn incoming_with_prefix(length: usize) -> IncomingObject {
    let mut incoming = IncomingObject::new(EPOCH, KIND);
    if length > 0 {
        let outcome = incoming.accept_chunk(EPOCH, KIND, 0, &object_bytes()[..length]);
        assert_eq!(
            outcome,
            Ok(ChunkOutcome::Appended),
            "arrange prefix {length}"
        );
    }
    incoming
}

#[test]
fn new_object_reports_zero_progress_and_is_incomplete() {
    let incoming = IncomingObject::new(EPOCH, KIND);

    let state = (incoming.next_offset(), incoming.completed());

    assert_eq!(state, (0, None));
    assert_eq!((incoming.epoch(), incoming.kind()), (EPOCH, KIND));
}

#[test]
fn contiguous_chunk_is_appended_and_advances_progress() {
    let mut incoming = incoming_with_prefix(100);

    let outcome = incoming.accept_chunk(EPOCH, KIND, 100, &object_bytes()[100..300]);

    assert_eq!(outcome, Ok(ChunkOutcome::Appended));
    assert_eq!(incoming.next_offset(), 300);
}

#[test]
fn final_chunk_completes_the_exact_object() {
    let mut incoming = incoming_with_prefix(1000);
    let bytes = object_bytes();

    let outcome = incoming.accept_chunk(EPOCH, KIND, 1000, &bytes[1000..]);

    assert_eq!(outcome, Ok(ChunkOutcome::Appended));
    assert_eq!(incoming.completed(), Some(&bytes[..]));
    assert_eq!(incoming.next_offset(), 1088);
}

#[test]
fn exact_duplicate_within_prefix_is_accepted_without_change() {
    let mut incoming = incoming_with_prefix(300);
    let before = incoming.clone();

    let outcome = incoming.accept_chunk(EPOCH, KIND, 50, &object_bytes()[50..300]);

    assert_eq!(outcome, Ok(ChunkOutcome::Duplicate));
    assert_eq!(incoming, before);
}

#[test]
fn exact_duplicate_of_completed_object_is_accepted() {
    let mut incoming = incoming_with_prefix(KIND.length());

    let outcome = incoming.accept_chunk(EPOCH, KIND, 1080, &object_bytes()[1080..]);

    assert_eq!(outcome, Ok(ChunkOutcome::Duplicate));
}

fn assert_rejected_without_mutation(
    prefix: usize,
    epoch: Epoch,
    kind: ObjectKind,
    offset: u32,
    chunk: &[u8],
) {
    let mut incoming = incoming_with_prefix(prefix);
    let before = incoming.clone();

    let outcome = incoming.accept_chunk(epoch, kind, offset, chunk);

    assert_eq!(
        outcome,
        Err(TransferInvalid),
        "offset {offset}, length {}",
        chunk.len()
    );
    assert_eq!(incoming, before, "rejected chunk mutated state");
}

#[test]
fn empty_chunk_is_rejected() {
    assert_rejected_without_mutation(100, EPOCH, KIND, 100, &[]);
}

#[test]
fn wrong_epoch_is_rejected() {
    let bytes = object_bytes();

    assert_rejected_without_mutation(100, Epoch::new(5), KIND, 100, &bytes[100..110]);
}

#[test]
fn wrong_object_kind_is_rejected() {
    let bytes = object_bytes();

    assert_rejected_without_mutation(
        100,
        EPOCH,
        ObjectKind::EncapsulationKey,
        100,
        &bytes[100..110],
    );
}

#[test]
fn gap_after_frontier_is_rejected() {
    let bytes = object_bytes();

    assert_rejected_without_mutation(100, EPOCH, KIND, 101, &bytes[101..110]);
}

#[test]
fn conflicting_duplicate_is_rejected() {
    let mut conflicting = object_bytes()[10..20].to_vec();
    conflicting[9] ^= 0x01;

    assert_rejected_without_mutation(100, EPOCH, KIND, 10, &conflicting);
}

#[test]
fn overlap_crossing_frontier_is_rejected() {
    let bytes = object_bytes();

    assert_rejected_without_mutation(100, EPOCH, KIND, 90, &bytes[90..110]);
}

#[test]
fn chunk_past_fixed_length_is_rejected() {
    let oversized = vec![0; 89];

    assert_rejected_without_mutation(1000, EPOCH, KIND, 1000, &oversized);
}

#[test]
fn append_to_completed_object_is_rejected() {
    assert_rejected_without_mutation(KIND.length(), EPOCH, KIND, 1088, &[0]);
}

#[test]
fn offsets_near_u32_max_are_rejected_without_overflow() {
    assert_rejected_without_mutation(100, EPOCH, KIND, u32::MAX, &[0; 16]);
}

#[test]
fn transfer_invalid_reports_the_specified_local_reason() {
    let reason = TransferInvalid.to_string();

    assert_eq!(reason, "pq_transfer_invalid");
}
