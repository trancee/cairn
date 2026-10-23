//! The one-byte frame header of spec §4.2.

const MORE: u8 = 0x80;

/// The frame type in bits 6–4 of the header.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FrameType {
    /// Pairing steps P0–P4.
    Pair,
    /// Resume S1, sent by the initiator.
    ResumeInit,
    /// Resume S2, sent by the responder.
    ResumeReply,
    /// An AEAD-protected DATA frame.
    Data,
}

impl FrameType {
    fn code(self) -> u8 {
        match self {
            Self::Pair => 0,
            Self::ResumeInit => 1,
            Self::ResumeReply => 2,
            Self::Data => 3,
        }
    }

    fn allows(self, sub: u8) -> bool {
        match self {
            Self::Pair => sub <= 4,
            Self::ResumeInit => sub & !0b11 == 0,
            Self::ResumeReply => sub & !0b1 == 0,
            Self::Data => sub == 0,
        }
    }
}

/// A header byte that a receiver must close the link on.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HeaderError {
    ReservedType,
    InvalidSub,
}

impl core::fmt::Display for HeaderError {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        formatter.write_str(match self {
            Self::ReservedType => "reserved frame type",
            Self::InvalidSub => "invalid frame sub value",
        })
    }
}

impl core::error::Error for HeaderError {}

/// A validated header: `MORE(1) ‖ type(3) ‖ sub(4)`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Header {
    more: bool,
    frame_type: FrameType,
    sub: u8,
}

impl Header {
    /// A header with MORE clear, if `sub` is allowed for `frame_type`.
    pub fn new(frame_type: FrameType, sub: u8) -> Result<Self, HeaderError> {
        if !frame_type.allows(sub) {
            return Err(HeaderError::InvalidSub);
        }
        Ok(Self {
            more: false,
            frame_type,
            sub,
        })
    }

    pub fn parse(byte: u8) -> Result<Self, HeaderError> {
        let frame_type = match (byte >> 4) & 0x07 {
            0 => FrameType::Pair,
            1 => FrameType::ResumeInit,
            2 => FrameType::ResumeReply,
            3 => FrameType::Data,
            _ => return Err(HeaderError::ReservedType),
        };
        Ok(Self::new(frame_type, byte & 0x0f)?.with_more(byte & MORE != 0))
    }

    pub fn to_byte(self) -> u8 {
        u8::from(self.more) << 7 | self.frame_type.code() << 4 | self.sub
    }

    #[must_use]
    pub fn with_more(self, more: bool) -> Self {
        Self { more, ..self }
    }

    pub fn more(self) -> bool {
        self.more
    }

    pub fn frame_type(self) -> FrameType {
        self.frame_type
    }

    pub fn sub(self) -> u8 {
        self.sub
    }
}
