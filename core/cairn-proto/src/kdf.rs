//! Labelled KDF, MAC and hash helpers (spec §2.2).

use cairn_crypto::{CryptoBackend, CryptoError};
use zeroize::Zeroizing;

/// `KDF(ikm, salt, label, info, N)`; an empty salt is 48 zero bytes.
pub(crate) fn kdf<B: CryptoBackend, const N: usize>(
    ikm: &[u8],
    salt: &[u8],
    label: &[u8],
    info: &[&[u8]],
) -> Result<Zeroizing<[u8; N]>, CryptoError> {
    let mut expand_info = labelled(label);
    for part in info {
        expand_info.extend_from_slice(part);
    }
    let output = B::hkdf_sha384(ikm, salt, &expand_info, N)?;
    let mut key = Zeroizing::new([0; N]);
    key.copy_from_slice(&output);
    Ok(key)
}

/// `MAC(key, label, x) = Trunc16(HMAC(key, lp("cairn-r1 " ‖ label) ‖ x))`, with `x` given in parts.
pub(crate) fn mac<B: CryptoBackend>(
    key: &[u8],
    label: &[u8],
    parts: &[&[u8]],
) -> Result<[u8; 16], CryptoError> {
    tag::<B, 16>(key, label, parts)
}

/// `TruncN(HMAC(key, lp("cairn-r1 " ‖ label) ‖ x))`: MACs, beacons and pseudonyms.
pub(crate) fn tag<B: CryptoBackend, const N: usize>(
    key: &[u8],
    label: &[u8],
    parts: &[&[u8]],
) -> Result<[u8; N], CryptoError> {
    let mut input = labelled(label);
    for part in parts {
        input.extend_from_slice(part);
    }
    let digest = B::hmac_sha384(key, &input)?;
    Ok(*digest.first_chunk::<N>().expect("N <= 48"))
}

/// `H(x)` over the concatenation of `parts`.
pub(crate) fn hash<B: CryptoBackend>(parts: &[&[u8]]) -> [u8; 48] {
    B::sha384(&parts.concat())
}

/// `Trunc32(H(lp("cairn-r1 commit") ‖ nA))` (spec §5.2).
pub(crate) fn commit<B: CryptoBackend>(nonce: &[u8; 16]) -> [u8; 32] {
    let digest = hash::<B>(&[&labelled(b"commit"), nonce]);
    let mut commitment = [0; 32];
    commitment.copy_from_slice(&digest[..32]);
    commitment
}

/// `lp("cairn-r1 " ‖ label)`.
pub(crate) fn labelled(label: &[u8]) -> alloc::vec::Vec<u8> {
    let length = u16::try_from(9 + label.len()).expect("labels are short constants");
    let mut output = alloc::vec::Vec::with_capacity(2 + usize::from(length));
    output.extend_from_slice(&length.to_be_bytes());
    output.extend_from_slice(b"cairn-r1 ");
    output.extend_from_slice(label);
    output
}

#[cfg(test)]
mod tests {
    use super::*;
    use cairn_crypto::Reference;

    fn hex(text: &str) -> std::vec::Vec<u8> {
        (0..text.len())
            .step_by(2)
            .map(|index| u8::from_str_radix(&text[index..index + 2], 16).unwrap())
            .collect()
    }

    fn sequence<const N: usize>(start: u8) -> [u8; N] {
        core::array::from_fn(|index| start + index as u8)
    }

    #[test]
    fn kdf_uses_the_transcript_as_salt_and_the_labelled_info() {
        let (ss, th) = (sequence::<32>(0), sequence::<48>(100));

        let rk = kdf::<Reference, 32>(&ss, &th, b"rk", &[]).unwrap();

        assert_eq!(
            rk[..],
            hex("1c7fd11cad30ac170b439b01afc757d77b164305f49a075a6f7fc41041ccd8c0")
        );
    }

    #[test]
    fn kdf_with_empty_salt_matches_the_zero_salt_vector() {
        let rk = sequence::<32>(0);

        let key = kdf::<Reference, 32>(&rk, &[], b"conf A", &[]).unwrap();

        assert_eq!(
            key[..],
            hex("4163eeecdd3aca6d31e65c8dc4c6c1e14121080295fe8972a2bcb36f7dc27396")
        );
    }

    #[test]
    fn kdf_appends_info_parts_after_the_label() {
        let rk = sequence::<32>(0);

        let key = kdf::<Reference, 32>(&rk, &[], b"id A", &[&[1], &[2]]).unwrap();

        assert_eq!(
            key[..],
            hex("a802442bd1e2b11b4289684946f1082a7e8bbd85383a8232f6b3b94b4edae5cd")
        );
    }

    #[test]
    fn mac_is_the_truncated_labelled_hmac() {
        let (key, th) = (sequence::<32>(0), sequence::<48>(100));

        let tag = mac::<Reference>(&key, b"P3", &[&th[..20], &th[20..]]).unwrap();

        assert_eq!(tag[..], hex("aa66df846066b9671ffd9ec5a595e008"));
    }

    #[test]
    fn commit_hashes_the_labelled_nonce() {
        let nonce = sequence::<16>(0);

        let commitment = commit::<Reference>(&nonce);

        assert_eq!(
            commitment[..],
            hex("68c0038447b32df29efc358bccfb522d886a17cf3abe9a5af8824d975bd0a68b")
        );
    }
}
