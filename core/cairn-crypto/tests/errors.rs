use cairn_crypto::CryptoError;

#[test]
fn public_errors_have_fixed_secret_free_diagnostics() {
    assert_eq!(
        CryptoError::InvalidOutputLength.to_string(),
        "invalid HKDF output length"
    );
    assert_eq!(
        CryptoError::BackendFailure.to_string(),
        "cryptographic backend failure"
    );
}

#[cfg(feature = "reference")]
#[test]
fn rustcrypto_length_errors_translate_to_secret_free_backend_failure() {
    let key = hkdf::Hkdf::<sha2::Sha384>::new(None, b"input");
    let error = key.expand(b"info", &mut vec![0; 12_241]).unwrap_err();
    assert_eq!(CryptoError::from(error), CryptoError::BackendFailure);
    assert_eq!(
        CryptoError::from(hmac::digest::InvalidLength),
        CryptoError::BackendFailure
    );
    assert_eq!(
        CryptoError::from(getrandom::Error::UNEXPECTED),
        CryptoError::BackendFailure
    );
}

#[cfg(feature = "aws-lc")]
#[test]
fn aws_lc_expansion_error_translates_to_secret_free_backend_failure() {
    struct ExcessiveLength;
    impl aws_lc_rs::hkdf::KeyType for ExcessiveLength {
        fn len(&self) -> usize {
            12_241
        }
    }
    let salt = aws_lc_rs::hkdf::Salt::new(aws_lc_rs::hkdf::HKDF_SHA384, b"salt");
    let key = salt.extract(b"input");
    let error = match key.expand(&[b"info"], ExcessiveLength) {
        Ok(_) => panic!("provider accepted excessive HKDF output length"),
        Err(error) => error,
    };
    assert_eq!(CryptoError::from(error), CryptoError::BackendFailure);
}

#[cfg(feature = "aws-lc")]
#[test]
fn aws_lc_key_rejection_translates_to_secret_free_backend_failure() {
    let error = match aws_lc_rs::kem::DecapsulationKey::new(&aws_lc_rs::kem::ML_KEM_768, &[0; 1]) {
        Ok(_) => panic!("provider accepted a one-byte ML-KEM decapsulation key"),
        Err(error) => error,
    };
    assert_eq!(CryptoError::from(error), CryptoError::BackendFailure);
}

#[cfg(feature = "reference")]
#[test]
fn rustcrypto_aead_error_translates_to_secret_free_backend_failure() {
    use aes_gcm::{AeadInOut, KeyInit};
    let cipher = aes_gcm::Aes256Gcm::new(&[0; 32].into());
    let error = cipher
        .decrypt_in_place(&[0; 12].into(), b"", &mut Vec::new())
        .unwrap_err();
    assert_eq!(CryptoError::from(error), CryptoError::BackendFailure);
}
