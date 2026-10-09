#![cfg(all(feature = "aws-lc", feature = "reference"))]

use cairn_crypto::{AwsLc, CryptoBackend, CryptoError, Reference};

#[test]
fn symmetric_backends_agree_on_reproducible_varied_inputs() {
    let mut state = 0x8bd3_179c_44af_2150_u64;
    let mut next = || {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        state as u8
    };
    for length in [0, 1, 47, 48, 49, 127, 128, 129, 255, 1024] {
        let input: Vec<_> = (0..length).map(|_| next()).collect();
        for key_length in [0, 1, 48, 129] {
            let key: Vec<_> = (0..key_length).map(|_| next()).collect();
            assert_eq!(AwsLc::sha384(&input), Reference::sha384(&input));
            assert_eq!(
                AwsLc::hmac_sha384(&key, &input),
                Reference::hmac_sha384(&key, &input)
            );
            for size in [0, 1, 48, 49, 256] {
                assert_eq!(
                    AwsLc::hkdf_sha384(&input, &key, b"cairn test", size),
                    Reference::hkdf_sha384(&input, &key, b"cairn test", size)
                );
            }
        }
    }
}

#[test]
fn hkdf_rfc5869_limit_is_enforced_by_both_backends() {
    for length in [12_241, usize::MAX] {
        assert_eq!(
            AwsLc::hkdf_sha384(b"input", b"salt", b"info", length),
            Err(CryptoError::InvalidOutputLength)
        );
        assert_eq!(
            Reference::hkdf_sha384(b"input", b"salt", b"info", length),
            Err(CryptoError::InvalidOutputLength)
        );
    }
    assert_eq!(
        AwsLc::hkdf_sha384(b"input", &[], &[], 12_240),
        Reference::hkdf_sha384(b"input", &[], &[], 12_240)
    );
    assert_eq!(
        AwsLc::hkdf_sha384(b"input", &[], &[], 48),
        AwsLc::hkdf_sha384(b"input", &[0; 48], &[], 48)
    );
}
