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
