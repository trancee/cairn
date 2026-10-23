//! The UniFFI boundary: one `CairnCore` per device (ADR 0022).
//!
//! Keys, `pairID` and session state stay inside the core. Two values that
//! carry secrets do cross by design: the `Persist` blob, which the platform
//! seals with its keystore, and chat text (ADR 0004, ADR 0022 §7).

use std::sync::{Mutex, MutexGuard};

use cairn_crypto::AwsLc;
pub use cairn_proto::{ChatRejection, Clock, GattRole, Persisted, Verification};
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

/// An input to [`CairnCore::handle`]; ids are `LinkId`, `TimerId` and `ContactId`.
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Enum)]
pub enum Event {
    /// The first event; `None` is a fresh install.
    Restore {
        state: Option<Persisted>,
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
}

/// An output of [`CairnCore::handle`], executed by the platform in order.
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Enum)]
pub enum Action {
    /// Seal and store `state` before executing any later action.
    Persist {
        state: Persisted,
    },
    Send {
        link: u64,
        fragment: Vec<u8>,
    },
    Disconnect {
        link: u64,
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
}

impl From<Event> for cairn_proto::Event {
    fn from(event: Event) -> Self {
        match event {
            Event::Restore { state } => Self::Restore { state },
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
        }
    }
}

impl From<cairn_proto::Action> for Action {
    fn from(action: cairn_proto::Action) -> Self {
        use cairn_proto::Action as Proto;
        match action {
            Proto::Persist { state } => Self::Persist { state },
            Proto::Send { link, fragment } => Self::Send {
                link: link.0,
                fragment,
            },
            Proto::Disconnect { link } => Self::Disconnect { link: link.0 },
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
                Event::Restore { state: None },
                ProtoEvent::Restore { state: None },
            ),
            (
                Event::Restore {
                    state: Some(state()),
                },
                ProtoEvent::Restore {
                    state: Some(state()),
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
        ];

        for (event, expected) in cases {
            assert_eq!(ProtoEvent::from(round_trip(event)), expected);
        }
    }

    #[test]
    fn every_action_maps_from_the_core_action_and_crosses_the_boundary() {
        let cases = [
            (
                ProtoAction::Persist { state: state() },
                Action::Persist { state: state() },
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
                ProtoAction::Disconnect { link: LinkId(1) },
                Action::Disconnect { link: 1 },
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
                Event::Restore { state: None },
            ),
            Err(CoreError::Poisoned)
        );
        assert_eq!(core.contacts(), Err(CoreError::Poisoned));
        assert_eq!(core.beacon(0), Err(CoreError::Poisoned));
    }
}
