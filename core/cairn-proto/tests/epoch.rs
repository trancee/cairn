use cairn_proto::{Epoch, EpochExhausted, ObjectKind, PairingRole, ProgressRejected};

#[test]
fn epoch_exposes_its_wire_identifier_starting_at_zero() {
    let epochs = [Epoch::FIRST, Epoch::new(u32::MAX)];

    let identifiers = epochs.map(Epoch::value);

    assert_eq!(identifiers, [0, u32::MAX]);
}

#[test]
fn successor_advances_by_exactly_one() {
    let epoch = Epoch::new(127);

    let successor = epoch.successor();

    assert_eq!(successor, Ok(Epoch::new(128)));
}

#[test]
fn successor_of_last_epoch_is_exhausted_instead_of_wrapping() {
    let last = Epoch::new(u32::MAX);

    let successor = last.successor();

    assert_eq!(successor, Err(EpochExhausted));
    assert_eq!(EpochExhausted.to_string(), "epoch_exhausted");
}

#[test]
fn role_a_generates_even_epochs_and_role_b_odd_epochs() {
    let epochs = [
        Epoch::FIRST,
        Epoch::new(1),
        Epoch::new(2),
        Epoch::new(u32::MAX),
    ];

    let generators = epochs.map(Epoch::generator);

    assert_eq!(
        generators,
        [
            PairingRole::A,
            PairingRole::B,
            PairingRole::A,
            PairingRole::B
        ]
    );
}

#[test]
fn generator_receives_ciphertext_and_encapsulator_receives_key() {
    let epoch = Epoch::new(3);

    let kinds = [PairingRole::A, PairingRole::B].map(|role| epoch.incoming_kind(role));

    assert_eq!(
        kinds,
        [ObjectKind::EncapsulationKey, ObjectKind::Ciphertext]
    );
}

#[test]
fn object_kinds_have_fixed_ml_kem_768_lengths_and_progress_codes() {
    let kinds = [ObjectKind::EncapsulationKey, ObjectKind::Ciphertext];

    let properties = kinds.map(|kind| (kind.length(), kind.progress_code()));

    assert_eq!(properties, [(1184, 0x01), (1088, 0x02)]);
}

#[test]
fn progress_codes_round_trip_and_unknown_codes_are_rejected() {
    let codes = [0x00, 0x01, 0x02, 0x03, 0xff];

    let decoded = codes.map(ObjectKind::from_progress_code);

    assert_eq!(
        decoded,
        [
            Err(ProgressRejected),
            Ok(ObjectKind::EncapsulationKey),
            Ok(ObjectKind::Ciphertext),
            Err(ProgressRejected),
            Err(ProgressRejected),
        ]
    );
}
