//! Beacons and the device beacon key day ratchet (spec §10.1, §10.2).

use crate::kdf::{kdf, tag};
use cairn_crypto::{CryptoBackend, CryptoError};
use subtle::{ConditionallySelectable, ConstantTimeEq};
use zeroize::Zeroizing;

const WINDOW_S: u64 = 300;
pub(crate) const DAY_S: u64 = 86_400;

/// A beacon key `BK_day` for one day.
#[derive(Clone)]
pub(crate) struct DayKey {
    pub(crate) day: u32,
    pub(crate) key: Zeroizing<[u8; 32]>,
}

/// The beacon window `w = floor(unix_time / 300)`.
pub(crate) fn window(unix_s: u64) -> u64 {
    unix_s / WINDOW_S
}

/// The day `d = floor(unix_time / 86400)`, saturated to `u32`.
pub(crate) fn day(unix_s: u64) -> u32 {
    u32::try_from(unix_s / DAY_S).unwrap_or(u32::MAX)
}

impl DayKey {
    /// The key for `day`, ratcheted forward. A day before the key's own day,
    /// such as after the clock moved back, uses the key's day.
    pub(crate) fn at<B: CryptoBackend>(&self, day: u32) -> Result<Self, CryptoError> {
        let mut current = self.clone();
        while current.day < day {
            current.key = kdf::<B, 32>(&current.key[..], &[], b"beacon day", &[])?;
            current.day += 1;
        }
        Ok(current)
    }

    /// `Trunc8(HMAC(BK_d, lp("cairn-r1 beacon") ‖ u64(w)))` with `d` the day of window `w`.
    pub(crate) fn beacon<B: CryptoBackend>(&self, window: u64) -> Result<[u8; 8], CryptoError> {
        let key = self.at::<B>(day(window * WINDOW_S))?;
        tag::<B, 8>(&key.key[..], b"beacon", &[&window.to_be_bytes()])
    }
}

/// The day of window `w−1`, the oldest window a beacon read is matched against.
pub(crate) fn first_day(unix_s: u64) -> u32 {
    day(window(unix_s).saturating_sub(1) * WINDOW_S)
}

/// The index of the first key with a beacon equal to `read` in windows
/// `{w−1, w, w+1}`. Every key and window is compared in constant time.
pub(crate) fn find<'a, B: CryptoBackend>(
    keys: impl IntoIterator<Item = &'a DayKey>,
    unix_s: u64,
    read: &[u8; 8],
) -> Result<Option<usize>, CryptoError> {
    let (hit, found) = matching::<B>(keys, unix_s, read)?;
    Ok(bool::from(hit).then(|| usize::try_from(found).expect("indices fit usize")))
}

/// The undeclassified verdict and index of [`find`].
pub(crate) fn matching<'a, B: CryptoBackend>(
    keys: impl IntoIterator<Item = &'a DayKey>,
    unix_s: u64,
    read: &[u8; 8],
) -> Result<(subtle::Choice, u64), CryptoError> {
    let now = window(unix_s);
    let mut found = 0u64;
    let mut hit = subtle::Choice::from(0);
    let first = now.saturating_sub(1);
    for (index, key) in (0u64..).zip(keys) {
        let key = key.at::<B>(first_day(unix_s))?;
        for window in [first, now, now + 1] {
            let matches = key.beacon::<B>(window)?.ct_eq(read) & !hit;
            found.conditional_assign(&index, matches);
            hit |= matches;
        }
    }
    Ok((hit, found))
}

#[cfg(test)]
mod tests {
    use super::*;
    use cairn_crypto::Reference;

    fn key(day: u32, byte: u8) -> DayKey {
        DayKey {
            day,
            key: Zeroizing::new([byte; 32]),
        }
    }

    fn hmac_tag(key: &[u8], label: &[u8], message: &[u8]) -> [u8; 8] {
        let mut input = std::vec![0, 9 + label.len() as u8];
        input.extend_from_slice(b"cairn-r1 ");
        input.extend_from_slice(label);
        input.extend_from_slice(message);
        Reference::hmac_sha384(key, &input).unwrap()[..8]
            .try_into()
            .unwrap()
    }

    #[test]
    fn windows_are_five_minutes_and_days_are_utc_days() {
        assert_eq!(window(1_761_177_899), 5_870_592);
        assert_eq!(day(1_761_177_600), 20_384);
        assert_eq!(day(u64::MAX), u32::MAX);
    }

    #[test]
    fn the_day_ratchet_applies_the_beacon_day_kdf_once_per_day() {
        let start = key(10, 1);
        let once = kdf::<Reference, 32>(&start.key[..], &[], b"beacon day", &[]).unwrap();
        let twice = kdf::<Reference, 32>(&once[..], &[], b"beacon day", &[]).unwrap();

        let keys = [10, 11, 12].map(|day| start.at::<Reference>(day).unwrap());

        assert_eq!(keys.each_ref().map(|key| key.day), [10, 11, 12]);
        assert_eq!(keys[0].key, start.key);
        assert_eq!(keys[1].key, once);
        assert_eq!(keys[2].key, twice);
    }

    #[test]
    fn a_day_before_the_key_day_uses_the_key_day() {
        let start = key(10, 1);

        let earlier = start.at::<Reference>(9).unwrap();

        assert_eq!((earlier.day, earlier.key), (10, start.key));
    }

    #[test]
    fn the_beacon_is_the_truncated_hmac_of_the_window_under_its_day_key() {
        let start = key(20_383, 2);
        let next_day = start.at::<Reference>(20_384).unwrap();
        let first_window_of_the_day = 20_384 * 288;

        let beacons = [first_window_of_the_day - 1, first_window_of_the_day]
            .map(|window| start.beacon::<Reference>(window).unwrap());

        assert_eq!(
            beacons,
            [
                hmac_tag(
                    &start.key[..],
                    b"beacon",
                    &(first_window_of_the_day - 1).to_be_bytes()
                ),
                hmac_tag(
                    &next_day.key[..],
                    b"beacon",
                    &first_window_of_the_day.to_be_bytes()
                ),
            ]
        );
    }

    #[test]
    fn find_matches_the_previous_current_and_next_window_only() {
        let keys = [key(20_384, 3), key(20_384, 4)];
        let now = 1_761_177_600 + 3_600;
        let w = window(now);
        let beacon = |offset: u64| keys[1].beacon::<Reference>(w + offset - 2).unwrap();

        let found =
            [0, 1, 2, 3, 4].map(|offset| find::<Reference>(&keys, now, &beacon(offset)).unwrap());

        assert_eq!(found, [None, Some(1), Some(1), Some(1), None]);
    }

    #[test]
    fn find_in_the_first_window_does_not_underflow() {
        let keys = [key(0, 5)];
        let beacon = keys[0].beacon::<Reference>(0).unwrap();

        let found = find::<Reference>(&keys, 0, &beacon).unwrap();

        assert_eq!(found, Some(0));
    }

    #[test]
    fn find_without_keys_finds_nothing() {
        let found = find::<Reference>(&[], 1_761_177_600, &[0; 8]).unwrap();

        assert_eq!(found, None);
    }
}
