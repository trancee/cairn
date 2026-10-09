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
