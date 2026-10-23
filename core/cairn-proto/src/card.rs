//! The contact card carried inside P3 and P4 (spec §5.4).

use alloc::boxed::Box;
use alloc::string::String;
use alloc::vec::Vec;
use cairn_crypto::MLKEM768_ENCAPSULATION_KEY_LEN;
use zeroize::Zeroizing;

const CAPS_COC: u8 = 0b01;
const CAPS_KCI: u8 = 0b10;
pub(crate) const MAX_NAME_LEN: usize = 48;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum CardError {
    Truncated,
    ReservedCaps,
    NameTooLong,
    NameNotUtf8,
    TrailingBytes,
}

/// A decoded card. `beacon_key` is the sender's device beacon key for `beacon_day`.
#[derive(Clone, PartialEq, Eq)]
pub(crate) struct Card {
    pub(crate) caps: u8,
    pub(crate) beacon_day: u32,
    pub(crate) beacon_key: Zeroizing<[u8; 32]>,
    pub(crate) name: String,
    pub(crate) static_ek: Option<Box<[u8; MLKEM768_ENCAPSULATION_KEY_LEN]>>,
}

impl core::fmt::Debug for Card {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        formatter
            .debug_struct("Card")
            .field("caps", &self.caps)
            .field("beacon_day", &self.beacon_day)
            .field("name", &self.name)
            .finish_non_exhaustive()
    }
}

impl Card {
    pub(crate) fn encode(&self) -> Zeroizing<Vec<u8>> {
        let name = self.name.as_bytes();
        let key = self.static_ek.as_deref().map_or(&[][..], |key| &key[..]);
        let mut output = Zeroizing::new(Vec::with_capacity(38 + name.len() + key.len()));
        output.push(self.caps);
        output.extend_from_slice(&self.beacon_day.to_be_bytes());
        output.extend_from_slice(&self.beacon_key[..]);
        output.push(u8::try_from(name.len()).expect("names are at most 48 bytes"));
        output.extend_from_slice(name);
        output.extend_from_slice(key);
        output
    }

    pub(crate) fn decode(input: &[u8]) -> Result<Self, CardError> {
        let (&caps, rest) = input.split_first().ok_or(CardError::Truncated)?;
        if caps & !(CAPS_COC | CAPS_KCI) != 0 {
            return Err(CardError::ReservedCaps);
        }
        let (day, rest) = rest.split_first_chunk::<4>().ok_or(CardError::Truncated)?;
        let (key, rest) = rest.split_first_chunk::<32>().ok_or(CardError::Truncated)?;
        let (&name_len, rest) = rest.split_first().ok_or(CardError::Truncated)?;
        let name_len = usize::from(name_len);
        if name_len > MAX_NAME_LEN {
            return Err(CardError::NameTooLong);
        }
        let (name, rest) = rest
            .split_at_checked(name_len)
            .ok_or(CardError::Truncated)?;
        let name = core::str::from_utf8(name).map_err(|_| CardError::NameNotUtf8)?;
        let (static_ek, rest) = if caps & CAPS_KCI == 0 {
            (None, rest)
        } else {
            let (key, rest) = rest
                .split_first_chunk::<MLKEM768_ENCAPSULATION_KEY_LEN>()
                .ok_or(CardError::Truncated)?;
            (Some(Box::new(*key)), rest)
        };
        if !rest.is_empty() {
            return Err(CardError::TrailingBytes);
        }
        Ok(Self {
            caps,
            beacon_day: u32::from_be_bytes(*day),
            beacon_key: Zeroizing::new(*key),
            name: name.into(),
            static_ek,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn card(name: &str) -> Card {
        Card {
            caps: 0,
            beacon_day: 0x0102_0304,
            beacon_key: Zeroizing::new([9; 32]),
            name: name.into(),
            static_ek: None,
        }
    }

    #[test]
    fn default_card_is_38_bytes_in_field_order() {
        let card = card("");

        let encoded = card.encode();

        let mut expected = std::vec![0, 1, 2, 3, 4];
        expected.extend([9; 32]);
        expected.push(0);
        assert_eq!(encoded[..], expected[..]);
    }

    #[test]
    fn debug_output_omits_the_beacon_key() {
        let text = std::format!("{:?}", card("Bo"));

        assert_eq!(
            text,
            "Card { caps: 0, beacon_day: 16909060, name: \"Bo\", .. }"
        );
    }

    #[test]
    fn a_named_card_round_trips() {
        let card = card("Ada ✓");

        let decoded = Card::decode(&card.encode());

        assert_eq!(decoded, Ok(card));
    }

    #[test]
    fn a_kci_card_carries_the_static_key() {
        let mut card = card("");
        card.caps = CAPS_KCI | CAPS_COC;
        card.static_ek = Some(Box::new([7; MLKEM768_ENCAPSULATION_KEY_LEN]));

        let encoded = card.encode();

        assert_eq!(encoded.len(), 38 + MLKEM768_ENCAPSULATION_KEY_LEN);
        assert_eq!(Card::decode(&encoded), Ok(card));
    }

    #[test]
    fn malformed_cards_are_rejected() {
        let valid = card("").encode();
        let mut reserved = valid.to_vec();
        reserved[0] = 0b100;
        let mut long_name = valid.to_vec();
        long_name[37] = 49;
        long_name.extend([b'a'; 49]);
        let mut bad_utf8 = valid.to_vec();
        bad_utf8[37] = 1;
        bad_utf8.push(0xff);
        let mut trailing = valid.to_vec();
        trailing.push(0);
        let mut kci_without_key = valid.to_vec();
        kci_without_key[0] = CAPS_KCI;

        let results = [
            &valid[..37],
            &reserved[..],
            &long_name[..],
            &bad_utf8[..],
            &trailing[..],
            &kci_without_key[..],
        ]
        .map(Card::decode);

        assert_eq!(
            results,
            [
                Err(CardError::Truncated),
                Err(CardError::ReservedCaps),
                Err(CardError::NameTooLong),
                Err(CardError::NameNotUtf8),
                Err(CardError::TrailingBytes),
                Err(CardError::Truncated),
            ]
        );
    }
}
