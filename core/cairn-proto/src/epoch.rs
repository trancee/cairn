/// The pairing role fixed per contact (spec §2.3).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PairingRole {
    A,
    B,
}

/// The ML-KEM-768 object transferred during an epoch (spec §9).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ObjectKind {
    EncapsulationKey,
    Ciphertext,
}

impl ObjectKind {
    /// Fixed object length in bytes.
    pub const fn length(self) -> usize {
        match self {
            Self::EncapsulationKey => 1184,
            Self::Ciphertext => 1088,
        }
    }

    /// The `kind` byte of KEM_PROGRESS (spec §7.3).
    pub const fn progress_code(self) -> u8 {
        match self {
            Self::EncapsulationKey => 0x01,
            Self::Ciphertext => 0x02,
        }
    }

    /// Decode a KEM_PROGRESS `kind` byte, rejecting unknown kinds.
    pub fn from_progress_code(code: u8) -> Result<Self, crate::ProgressRejected> {
        match code {
            0x01 => Ok(Self::EncapsulationKey),
            0x02 => Ok(Self::Ciphertext),
            _ => Err(crate::ProgressRejected),
        }
    }
}

/// A non-wrapping post-quantum epoch identifier (spec §9, OI-21).
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Epoch(u32);

impl Epoch {
    pub const FIRST: Self = Self(0);

    pub const fn new(value: u32) -> Self {
        Self(value)
    }

    pub const fn value(self) -> u32 {
        self.0
    }

    /// The next epoch; after `2^32 - 1` the contact must re-pair instead of wrapping.
    pub fn successor(self) -> Result<Self, EpochExhausted> {
        self.0.checked_add(1).map(Self).ok_or(EpochExhausted)
    }

    /// Role A generates even epochs and role B odd ones (OI-4).
    pub const fn generator(self) -> PairingRole {
        if self.0.is_multiple_of(2) {
            PairingRole::A
        } else {
            PairingRole::B
        }
    }

    /// The object a party with `local` role receives in this epoch.
    pub const fn incoming_kind(self, local: PairingRole) -> ObjectKind {
        match (self.generator(), local) {
            (PairingRole::A, PairingRole::A) | (PairingRole::B, PairingRole::B) => {
                ObjectKind::Ciphertext
            }
            (PairingRole::A, PairingRole::B) | (PairingRole::B, PairingRole::A) => {
                ObjectKind::EncapsulationKey
            }
        }
    }
}

/// The last epoch identifier was mixed; local reason `epoch_exhausted`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EpochExhausted;

impl core::fmt::Display for EpochExhausted {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        formatter.write_str("epoch_exhausted")
    }
}

impl core::error::Error for EpochExhausted {}
