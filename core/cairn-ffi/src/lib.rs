//! The UniFFI boundary: one `CairnCore` per device (ADR 0022).
//!
//! Keys, `pairID` and session state stay inside the core. Two values that
//! carry secrets do cross by design: the persisted row blobs, which the
//! platform seals with its keystore, and chat text (ADR 0004, ADR 0022 §7,
//! ADR 0034 §1).

use std::sync::{Mutex, MutexGuard};

use cairn_crypto::AwsLc;
pub use cairn_proto::{ChatRejection, Clock, CloseReason, GattRole, Persisted, Verification};
use cairn_proto::{ContactId, Core, LinkId, TimerId};

uniffi::setup_scaffolding!();

#[uniffi::remote(Record)]
pub struct Clock {
    pub mono_ms: u64,
    pub unix_s: u64,
}

#[uniffi::remote(Record)]
pub struct Persisted {
    pub blob: Vec<u8>,
    pub version: u32,
}

#[uniffi::remote(Enum)]
pub enum GattRole {
    Central,
    Peripheral,
}

#[uniffi::remote(Enum)]
pub enum Verification {
    Unverified,
    Verified,
    Compromised,
}

#[uniffi::remote(Enum)]
pub enum ChatRejection {
    NoSession,
    TooLong,
    Exhausted,
    QueueFull,
}

#[uniffi::remote(Enum)]
pub enum CloseReason {
    Expired,
    Busy,
    Duplicate,
    Unknown,
    Malformed,
    Unsupported,
    Commitment,
    Authentication,
    Card,
    StaleCard,
    Exhausted,
}

// `Event`, `Action` and `ContactInfo` mirror the core types with plain `u64`
// ids: a UniFFI custom type for the id newtypes would add an error path that
// an infallible `u64` lift can never take.

/// A contact as shown to the platform; no key material.
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ContactInfo {
    pub id: u64,
    /// The name the neighbour shared, or empty; the app generates a local label.
    pub name: String,
    pub verification: Verification,
}

/// One stored contact row.
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ContactRow {
    pub contact: u64,
    pub state: Persisted,
}

/// One stored queued message.
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct QueuedRow {
    pub contact: u64,
    pub msgno: u32,
    pub state: Persisted,
}

/// One stored courier row: a carried envelope or a tombstone.
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct CourierRow {
    pub slot: u64,
    pub state: Persisted,
}

/// An input to [`CairnCore::handle`]; ids are `LinkId`, `TimerId` and `ContactId`.
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Enum)]
pub enum Event {
    /// The first event: the stored rows; `device: None` is a fresh install.
    Restore {
        device: Option<Persisted>,
        contacts: Vec<ContactRow>,
        queued: Vec<QueuedRow>,
        courier: Vec<CourierRow>,
    },
    LinkUp {
        link: u64,
        gatt_role: GattRole,
        mtu: u16,
        address: Vec<u8>,
    },
    MtuChanged {
        link: u64,
        mtu: u16,
    },
    /// The bytes the peer's `beacon` characteristic returned.
    BeaconRead {
        link: u64,
        beacon: Vec<u8>,
    },
    Received {
        link: u64,
        fragment: Vec<u8>,
    },
    LinkDown {
        link: u64,
    },
    TimerFired {
        timer: u64,
    },
    SendChat {
        contact: u64,
        text: String,
    },
    /// The user has read the peer's messages up to `msgno`.
    MarkRead {
        contact: u64,
        msgno: u32,
    },
    /// The global, reciprocal read-receipt setting.
    SetReadReceipts {
        enabled: bool,
    },
    /// The courier settings: `copies` is 1–16 and `lifetime_minutes` 60–10080.
    SetCourier {
        enabled: bool,
        copies: u8,
        lifetime_minutes: u16,
    },
}

/// An output of [`CairnCore::handle`], executed by the platform in order. The
/// row actions of one result are stored in one transaction before any later
/// action (ADR 0034 §1).
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Enum)]
pub enum Action {
    /// Seal and store the device row.
    PersistDevice {
        state: Persisted,
    },
    /// Seal and store one contact row.
    PersistContact {
        contact: u64,
        state: Persisted,
    },
    /// Seal and store one queued message.
    PutQueued {
        contact: u64,
        msgno: u32,
        state: Persisted,
    },
    DeleteQueued {
        contact: u64,
        msgno: u32,
    },
    /// Delete one contact row; the contact has no queued rows (ADR 0044).
    DeleteContact {
        contact: u64,
    },
    /// Seal and store one courier row.
    PutCourier {
        slot: u64,
        state: Persisted,
    },
    DeleteCourier {
        slot: u64,
    },
    Send {
        link: u64,
        fragment: Vec<u8>,
    },
    Disconnect {
        link: u64,
        reason: CloseReason,
    },
    SetTimer {
        timer: u64,
        at_mono_ms: u64,
    },
    CancelTimer {
        timer: u64,
    },
    ContactAdded {
        contact: u64,
    },
    ChatReceived {
        contact: u64,
        msgno: u32,
        text: String,
    },
    /// The message was sealed into DATA frames on a live session.
    ChatSent {
        contact: u64,
        msgno: u32,
    },
    ChatRejected {
        contact: u64,
        reason: ChatRejection,
    },
    /// The message was sealed and stored for the next Resume.
    ChatQueued {
        contact: u64,
        msgno: u32,
    },
    /// The peer's ACK covers the message.
    ChatDelivered {
        contact: u64,
        msgno: u32,
    },
    /// The peer has read the messages up to `msgno`.
    ChatRead {
        contact: u64,
        msgno: u32,
    },
    /// This device gave up on the message.
    ChatExpired {
        contact: u64,
        msgno: u32,
    },
    /// The peer gave up on the messages `from..=to`.
    ChatsExpired {
        contact: u64,
        from: u32,
        to: u32,
    },
}

impl From<Event> for cairn_proto::Event {
    fn from(event: Event) -> Self {
        match event {
            Event::Restore {
                device,
                contacts,
                queued,
                courier,
            } => Self::Restore {
                device,
                contacts: contacts
                    .into_iter()
                    .map(|row| cairn_proto::ContactRow {
                        contact: ContactId(row.contact),
                        state: row.state,
                    })
                    .collect(),
                queued: queued
                    .into_iter()
                    .map(|row| cairn_proto::QueuedRow {
                        contact: ContactId(row.contact),
                        msgno: row.msgno,
                        state: row.state,
                    })
                    .collect(),
                courier: courier
                    .into_iter()
                    .map(|row| cairn_proto::CourierRow {
                        slot: row.slot,
                        state: row.state,
                    })
                    .collect(),
            },
            Event::LinkUp {
                link,
                gatt_role,
                mtu,
                address,
            } => Self::LinkUp {
                link: LinkId(link),
                gatt_role,
                mtu,
                address,
            },
            Event::MtuChanged { link, mtu } => Self::MtuChanged {
                link: LinkId(link),
                mtu,
            },
            Event::BeaconRead { link, beacon } => Self::BeaconRead {
                link: LinkId(link),
                beacon,
            },
            Event::Received { link, fragment } => Self::Received {
                link: LinkId(link),
                fragment,
            },
            Event::LinkDown { link } => Self::LinkDown { link: LinkId(link) },
            Event::TimerFired { timer } => Self::TimerFired {
                timer: TimerId(timer),
            },
            Event::SendChat { contact, text } => Self::SendChat {
                contact: ContactId(contact),
                text,
            },
            Event::MarkRead { contact, msgno } => Self::MarkRead {
                contact: ContactId(contact),
                msgno,
            },
            Event::SetReadReceipts { enabled } => Self::SetReadReceipts { enabled },
            Event::SetCourier {
                enabled,
                copies,
                lifetime_minutes,
            } => Self::SetCourier {
                enabled,
                copies,
                lifetime_minutes,
            },
        }
    }
}

impl From<cairn_proto::Action> for Action {
    fn from(action: cairn_proto::Action) -> Self {
        use cairn_proto::Action as Proto;
        match action {
            Proto::PersistDevice { state } => Self::PersistDevice { state },
            Proto::PersistContact { contact, state } => Self::PersistContact {
                contact: contact.0,
                state,
            },
            Proto::PutQueued {
                contact,
                msgno,
                state,
            } => Self::PutQueued {
                contact: contact.0,
                msgno,
                state,
            },
            Proto::DeleteQueued { contact, msgno } => Self::DeleteQueued {
                contact: contact.0,
                msgno,
            },
            Proto::DeleteContact { contact } => Self::DeleteContact { contact: contact.0 },
            Proto::PutCourier { slot, state } => Self::PutCourier { slot, state },
            Proto::DeleteCourier { slot } => Self::DeleteCourier { slot },
            Proto::Send { link, fragment } => Self::Send {
                link: link.0,
                fragment,
            },
            Proto::Disconnect { link, reason } => Self::Disconnect {
                link: link.0,
                reason,
            },
            Proto::SetTimer { timer, at_mono_ms } => Self::SetTimer {
                timer: timer.0,
                at_mono_ms,
            },
            Proto::CancelTimer { timer } => Self::CancelTimer { timer: timer.0 },
            Proto::ContactAdded { contact } => Self::ContactAdded { contact: contact.0 },
            Proto::ChatReceived {
                contact,
                msgno,
                text,
            } => Self::ChatReceived {
                contact: contact.0,
                msgno,
                text,
            },
            Proto::ChatSent { contact, msgno } => Self::ChatSent {
                contact: contact.0,
                msgno,
            },
            Proto::ChatRejected { contact, reason } => Self::ChatRejected {
                contact: contact.0,
                reason,
            },
            Proto::ChatQueued { contact, msgno } => Self::ChatQueued {
                contact: contact.0,
                msgno,
            },
            Proto::ChatDelivered { contact, msgno } => Self::ChatDelivered {
                contact: contact.0,
                msgno,
            },
            Proto::ChatRead { contact, msgno } => Self::ChatRead {
                contact: contact.0,
                msgno,
            },
            Proto::ChatExpired { contact, msgno } => Self::ChatExpired {
                contact: contact.0,
                msgno,
            },
            Proto::ChatsExpired { contact, from, to } => Self::ChatsExpired {
                contact: contact.0,
                from,
                to,
            },
        }
    }
}

impl From<cairn_proto::ContactInfo> for ContactInfo {
    fn from(contact: cairn_proto::ContactInfo) -> Self {
        Self {
            id: contact.id.0,
            name: contact.name,
            verification: contact.verification,
        }
    }
}

/// A caller contract violation or local failure; Kotlin sees `CoreException`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Error)]
pub enum CoreError {
    NotRestored,
    AlreadyRestored,
    InvalidBlob,
    DuplicateLink,
    InvalidMtu,
    UnexpectedBeaconRead,
    UnknownContact,
    InvalidCourierConfig,
    /// The cryptographic backend failed, for example the platform RNG.
    Crypto,
    /// An earlier call panicked; the core refuses every later call.
    Poisoned,
}

impl std::fmt::Display for CoreError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        use cairn_proto::CoreError as Proto;
        let proto = match self {
            Self::NotRestored => Proto::NotRestored,
            Self::AlreadyRestored => Proto::AlreadyRestored,
            Self::InvalidBlob => Proto::InvalidBlob,
            Self::DuplicateLink => Proto::DuplicateLink,
            Self::InvalidMtu => Proto::InvalidMtu,
            Self::UnexpectedBeaconRead => Proto::UnexpectedBeaconRead,
            Self::UnknownContact => Proto::UnknownContact,
            Self::InvalidCourierConfig => Proto::InvalidCourierConfig,
            Self::Crypto => Proto::Crypto(cairn_crypto::CryptoError::BackendFailure),
            Self::Poisoned => return formatter.write_str("core refused after an earlier panic"),
        };
        proto.fmt(formatter)
    }
}

impl std::error::Error for CoreError {}

impl From<cairn_proto::CoreError> for CoreError {
    fn from(error: cairn_proto::CoreError) -> Self {
        use cairn_proto::CoreError as Proto;
        match error {
            Proto::NotRestored => Self::NotRestored,
            Proto::AlreadyRestored => Self::AlreadyRestored,
            Proto::InvalidBlob => Self::InvalidBlob,
            Proto::DuplicateLink => Self::DuplicateLink,
            Proto::InvalidMtu => Self::InvalidMtu,
            Proto::UnexpectedBeaconRead => Self::UnexpectedBeaconRead,
            Proto::UnknownContact => Self::UnknownContact,
            Proto::InvalidCourierConfig => Self::InvalidCourierConfig,
            Proto::Crypto(_) => Self::Crypto,
        }
    }
}

/// The protocol core of one device with the AWS-LC backend.
#[derive(uniffi::Object)]
pub struct CairnCore {
    inner: Mutex<Core<AwsLc>>,
}

#[uniffi::export]
impl CairnCore {
    #[uniffi::constructor]
    #[allow(clippy::new_without_default)]
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(Core::new()),
        }
    }

    /// Executes the returned actions in order (ADR 0022 §3).
    pub fn handle(&self, clock: Clock, event: Event) -> Result<Vec<Action>, CoreError> {
        let actions = self.locked()?.handle(clock, event.into())?;
        Ok(actions.into_iter().map(Action::from).collect())
    }

    pub fn contacts(&self) -> Result<Vec<ContactInfo>, CoreError> {
        let contacts = self.locked()?.contacts();
        Ok(contacts.into_iter().map(ContactInfo::from).collect())
    }

    /// The 8 B value of the local `beacon` characteristic at `unix_s`.
    pub fn beacon(&self, unix_s: u64) -> Result<Vec<u8>, CoreError> {
        Ok(self.locked()?.beacon(unix_s)?.to_vec())
    }
}

impl CairnCore {
    // A panic may leave the core between invariants, so it is never used again.
    fn locked(&self) -> Result<MutexGuard<'_, Core<AwsLc>>, CoreError> {
        self.inner.lock().map_err(|_| CoreError::Poisoned)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use cairn_crypto::CryptoError;
    use cairn_proto::{Action as ProtoAction, Event as ProtoEvent};

    fn round_trip<T>(value: T) -> T
    where
        T: uniffi::Lower<crate::UniFfiTag> + uniffi::Lift<crate::UniFfiTag>,
    {
        T::try_lift_from_rust_buffer(T::lower_into_rust_buffer(value)).unwrap()
    }

    fn state() -> Persisted {
        Persisted {
            blob: vec![1, 2, 3],
            version: 1,
        }
    }

    #[test]
    fn every_event_crosses_the_boundary_and_maps_to_the_core_event() {
        let cases = [
            (
                Event::Restore {
                    device: None,
                    contacts: Vec::new(),
                    queued: Vec::new(),
                    courier: Vec::new(),
                },
                ProtoEvent::Restore {
                    device: None,
                    contacts: Vec::new(),
                    queued: Vec::new(),
                    courier: Vec::new(),
                },
            ),
            (
                Event::Restore {
                    device: Some(state()),
                    contacts: vec![ContactRow {
                        contact: 2,
                        state: state(),
                    }],
                    queued: vec![QueuedRow {
                        contact: 2,
                        msgno: 3,
                        state: state(),
                    }],
                    courier: vec![CourierRow {
                        slot: 4,
                        state: state(),
                    }],
                },
                ProtoEvent::Restore {
                    device: Some(state()),
                    contacts: vec![cairn_proto::ContactRow {
                        contact: ContactId(2),
                        state: state(),
                    }],
                    queued: vec![cairn_proto::QueuedRow {
                        contact: ContactId(2),
                        msgno: 3,
                        state: state(),
                    }],
                    courier: vec![cairn_proto::CourierRow {
                        slot: 4,
                        state: state(),
                    }],
                },
            ),
            (
                Event::LinkUp {
                    link: 1,
                    gatt_role: GattRole::Central,
                    mtu: 185,
                    address: vec![4],
                },
                ProtoEvent::LinkUp {
                    link: LinkId(1),
                    gatt_role: GattRole::Central,
                    mtu: 185,
                    address: vec![4],
                },
            ),
            (
                Event::LinkUp {
                    link: 2,
                    gatt_role: GattRole::Peripheral,
                    mtu: 23,
                    address: Vec::new(),
                },
                ProtoEvent::LinkUp {
                    link: LinkId(2),
                    gatt_role: GattRole::Peripheral,
                    mtu: 23,
                    address: Vec::new(),
                },
            ),
            (
                Event::MtuChanged { link: 1, mtu: 247 },
                ProtoEvent::MtuChanged {
                    link: LinkId(1),
                    mtu: 247,
                },
            ),
            (
                Event::BeaconRead {
                    link: 1,
                    beacon: vec![5; 8],
                },
                ProtoEvent::BeaconRead {
                    link: LinkId(1),
                    beacon: vec![5; 8],
                },
            ),
            (
                Event::Received {
                    link: 1,
                    fragment: vec![6],
                },
                ProtoEvent::Received {
                    link: LinkId(1),
                    fragment: vec![6],
                },
            ),
            (
                Event::LinkDown { link: u64::MAX },
                ProtoEvent::LinkDown {
                    link: LinkId(u64::MAX),
                },
            ),
            (
                Event::TimerFired { timer: 7 },
                ProtoEvent::TimerFired { timer: TimerId(7) },
            ),
            (
                Event::SendChat {
                    contact: 8,
                    text: "hi".into(),
                },
                ProtoEvent::SendChat {
                    contact: ContactId(8),
                    text: "hi".into(),
                },
            ),
            (
                Event::MarkRead {
                    contact: 8,
                    msgno: 9,
                },
                ProtoEvent::MarkRead {
                    contact: ContactId(8),
                    msgno: 9,
                },
            ),
            (
                Event::SetReadReceipts { enabled: false },
                ProtoEvent::SetReadReceipts { enabled: false },
            ),
            (
                Event::SetCourier {
                    enabled: true,
                    copies: 6,
                    lifetime_minutes: 1440,
                },
                ProtoEvent::SetCourier {
                    enabled: true,
                    copies: 6,
                    lifetime_minutes: 1440,
                },
            ),
        ];

        for (event, expected) in cases {
            assert_eq!(ProtoEvent::from(round_trip(event)), expected);
        }
    }

    #[test]
    fn every_action_maps_from_the_core_action_and_crosses_the_boundary() {
        let cases = [
            (
                ProtoAction::PersistDevice { state: state() },
                Action::PersistDevice { state: state() },
            ),
            (
                ProtoAction::PersistContact {
                    contact: ContactId(4),
                    state: state(),
                },
                Action::PersistContact {
                    contact: 4,
                    state: state(),
                },
            ),
            (
                ProtoAction::PutQueued {
                    contact: ContactId(4),
                    msgno: 5,
                    state: state(),
                },
                Action::PutQueued {
                    contact: 4,
                    msgno: 5,
                    state: state(),
                },
            ),
            (
                ProtoAction::DeleteQueued {
                    contact: ContactId(4),
                    msgno: 5,
                },
                Action::DeleteQueued {
                    contact: 4,
                    msgno: 5,
                },
            ),
            (
                ProtoAction::DeleteContact {
                    contact: ContactId(4),
                },
                Action::DeleteContact { contact: 4 },
            ),
            (
                ProtoAction::PutCourier {
                    slot: 6,
                    state: state(),
                },
                Action::PutCourier {
                    slot: 6,
                    state: state(),
                },
            ),
            (
                ProtoAction::DeleteCourier { slot: 6 },
                Action::DeleteCourier { slot: 6 },
            ),
            (
                ProtoAction::Send {
                    link: LinkId(1),
                    fragment: vec![9],
                },
                Action::Send {
                    link: 1,
                    fragment: vec![9],
                },
            ),
            (
                ProtoAction::Disconnect {
                    link: LinkId(1),
                    reason: CloseReason::Busy,
                },
                Action::Disconnect {
                    link: 1,
                    reason: CloseReason::Busy,
                },
            ),
            (
                ProtoAction::SetTimer {
                    timer: TimerId(2),
                    at_mono_ms: 3,
                },
                Action::SetTimer {
                    timer: 2,
                    at_mono_ms: 3,
                },
            ),
            (
                ProtoAction::CancelTimer { timer: TimerId(2) },
                Action::CancelTimer { timer: 2 },
            ),
            (
                ProtoAction::ContactAdded {
                    contact: ContactId(4),
                },
                Action::ContactAdded { contact: 4 },
            ),
            (
                ProtoAction::ChatReceived {
                    contact: ContactId(4),
                    msgno: 5,
                    text: "hi".into(),
                },
                Action::ChatReceived {
                    contact: 4,
                    msgno: 5,
                    text: "hi".into(),
                },
            ),
            (
                ProtoAction::ChatSent {
                    contact: ContactId(4),
                    msgno: 6,
                },
                Action::ChatSent {
                    contact: 4,
                    msgno: 6,
                },
            ),
            (
                ProtoAction::ChatRejected {
                    contact: ContactId(4),
                    reason: ChatRejection::NoSession,
                },
                Action::ChatRejected {
                    contact: 4,
                    reason: ChatRejection::NoSession,
                },
            ),
            (
                ProtoAction::ChatRejected {
                    contact: ContactId(4),
                    reason: ChatRejection::TooLong,
                },
                Action::ChatRejected {
                    contact: 4,
                    reason: ChatRejection::TooLong,
                },
            ),
            (
                ProtoAction::ChatRejected {
                    contact: ContactId(4),
                    reason: ChatRejection::Exhausted,
                },
                Action::ChatRejected {
                    contact: 4,
                    reason: ChatRejection::Exhausted,
                },
            ),
            (
                ProtoAction::ChatRejected {
                    contact: ContactId(4),
                    reason: ChatRejection::QueueFull,
                },
                Action::ChatRejected {
                    contact: 4,
                    reason: ChatRejection::QueueFull,
                },
            ),
            (
                ProtoAction::ChatQueued {
                    contact: ContactId(4),
                    msgno: 7,
                },
                Action::ChatQueued {
                    contact: 4,
                    msgno: 7,
                },
            ),
            (
                ProtoAction::ChatDelivered {
                    contact: ContactId(4),
                    msgno: 7,
                },
                Action::ChatDelivered {
                    contact: 4,
                    msgno: 7,
                },
            ),
            (
                ProtoAction::ChatRead {
                    contact: ContactId(4),
                    msgno: 7,
                },
                Action::ChatRead {
                    contact: 4,
                    msgno: 7,
                },
            ),
            (
                ProtoAction::ChatExpired {
                    contact: ContactId(4),
                    msgno: 7,
                },
                Action::ChatExpired {
                    contact: 4,
                    msgno: 7,
                },
            ),
            (
                ProtoAction::ChatsExpired {
                    contact: ContactId(4),
                    from: 7,
                    to: 9,
                },
                Action::ChatsExpired {
                    contact: 4,
                    from: 7,
                    to: 9,
                },
            ),
        ];

        for (action, expected) in cases {
            assert_eq!(round_trip(Action::from(action)), expected);
        }
    }

    #[test]
    fn contacts_and_clocks_cross_the_boundary() {
        let contacts = [
            Verification::Unverified,
            Verification::Verified,
            Verification::Compromised,
        ]
        .into_iter()
        .zip(1..)
        .map(|(verification, id)| cairn_proto::ContactInfo {
            id: ContactId(id),
            name: "a".into(),
            verification,
        });
        let clock = Clock {
            mono_ms: 1,
            unix_s: 2,
        };

        let crossed = round_trip(contacts.clone().map(ContactInfo::from).collect::<Vec<_>>());

        assert_eq!(
            crossed,
            contacts
                .map(|contact| ContactInfo {
                    id: contact.id.0,
                    name: contact.name,
                    verification: contact.verification,
                })
                .collect::<Vec<_>>()
        );
        assert_eq!(round_trip(clock), clock);
    }

    #[test]
    fn every_core_error_maps_to_the_matching_exception() {
        use cairn_proto::CoreError as Proto;
        let cases = [
            (Proto::NotRestored, CoreError::NotRestored),
            (Proto::AlreadyRestored, CoreError::AlreadyRestored),
            (Proto::InvalidBlob, CoreError::InvalidBlob),
            (Proto::DuplicateLink, CoreError::DuplicateLink),
            (Proto::InvalidMtu, CoreError::InvalidMtu),
            (Proto::UnexpectedBeaconRead, CoreError::UnexpectedBeaconRead),
            (Proto::UnknownContact, CoreError::UnknownContact),
            (Proto::InvalidCourierConfig, CoreError::InvalidCourierConfig),
            (
                Proto::Crypto(CryptoError::BackendFailure),
                CoreError::Crypto,
            ),
        ];

        for (proto, expected) in cases {
            assert_eq!(CoreError::from(proto), expected);
            assert_eq!(expected.to_string(), proto.to_string());
        }
        assert_eq!(
            CoreError::Poisoned.to_string(),
            "core refused after an earlier panic"
        );
    }

    #[test]
    fn a_panic_inside_the_core_fails_every_later_call_closed() {
        let core = CairnCore::new();
        let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            let _guard = core.inner.lock();
            panic!("simulated panic while handling an event");
        }));

        assert_eq!(
            core.handle(
                Clock {
                    mono_ms: 0,
                    unix_s: 0,
                },
                Event::Restore {
                    device: None,
                    contacts: Vec::new(),
                    queued: Vec::new(),
                    courier: Vec::new(),
                },
            ),
            Err(CoreError::Poisoned)
        );
        assert_eq!(core.contacts(), Err(CoreError::Poisoned));
        assert_eq!(core.beacon(0), Err(CoreError::Poisoned));
    }
}
