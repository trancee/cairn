//! Symmetric foundation only; not the complete ADR 0004 backend.

use zeroize::Zeroizing;

/// An operation failed without exposing secret material in its diagnostic.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CryptoError {
    InvalidOutputLength,
    BackendFailure,
}

impl core::fmt::Display for CryptoError {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        formatter.write_str(match self {
            Self::InvalidOutputLength => "invalid HKDF output length",
            Self::BackendFailure => "cryptographic backend failure",
        })
    }
}

impl std::error::Error for CryptoError {}

/// Compile-time backend boundary for the implemented symmetric primitives.
pub trait CryptoBackend {
    fn sha384(input: &[u8]) -> [u8; 48];
    fn hmac_sha384(key: &[u8], input: &[u8]) -> Result<Zeroizing<[u8; 48]>, CryptoError>;
    /// RFC 5869 extract-and-expand, with an empty salt interpreted as 48 zero bytes.
    fn hkdf_sha384(
        input: &[u8],
        salt: &[u8],
        info: &[u8],
        length: usize,
    ) -> Result<Zeroizing<Vec<u8>>, CryptoError>;
}

/// Non-FIPS AWS-LC adapter.
#[cfg(feature = "aws-lc")]
pub struct AwsLc;

#[cfg(feature = "aws-lc")]
impl CryptoBackend for AwsLc {
    fn sha384(input: &[u8]) -> [u8; 48] {
        let digest = aws_lc_rs::digest::digest(&aws_lc_rs::digest::SHA384, input);
        let mut output = [0; 48];
        output.copy_from_slice(digest.as_ref());
        output
    }

    fn hmac_sha384(key: &[u8], input: &[u8]) -> Result<Zeroizing<[u8; 48]>, CryptoError> {
        let key = aws_lc_rs::hmac::Key::new(aws_lc_rs::hmac::HMAC_SHA384, key);
        let tag = aws_lc_rs::hmac::sign(&key, input);
        let mut output = Zeroizing::new([0; 48]);
        output.copy_from_slice(tag.as_ref());
        Ok(output)
    }

    fn hkdf_sha384(
        input: &[u8],
        salt: &[u8],
        info: &[u8],
        length: usize,
    ) -> Result<Zeroizing<Vec<u8>>, CryptoError> {
        use aws_lc_rs::hkdf;
        struct OutputLength(usize);
        impl hkdf::KeyType for OutputLength {
            fn len(&self) -> usize {
                self.0
            }
        }
        let mut output = hkdf_output(length)?;
        let salt = hkdf::Salt::new(hkdf::HKDF_SHA384, salt);
        let prk = salt.extract(input);
        let information = [info];
        let key = prk
            .expand(&information, OutputLength(length))
            .map_err(|_| CryptoError::BackendFailure)?;
        key.fill(&mut output)
            .map_err(|_| CryptoError::BackendFailure)?;
        Ok(output)
    }
}

/// RustCrypto reference adapter.
#[cfg(feature = "reference")]
pub struct Reference;

#[cfg(feature = "reference")]
impl CryptoBackend for Reference {
    fn sha384(input: &[u8]) -> [u8; 48] {
        use sha2::Digest;
        sha2::Sha384::digest(input).into()
    }

    fn hmac_sha384(key: &[u8], input: &[u8]) -> Result<Zeroizing<[u8; 48]>, CryptoError> {
        use hmac::{KeyInit, Mac};
        let mut mac = hmac::Hmac::<sha2::Sha384>::new_from_slice(key)
            .map_err(|_| CryptoError::BackendFailure)?;
        mac.update(input);
        let tag = mac.finalize().into_bytes();
        Ok(Zeroizing::new(tag.into()))
    }

    fn hkdf_sha384(
        input: &[u8],
        salt: &[u8],
        info: &[u8],
        length: usize,
    ) -> Result<Zeroizing<Vec<u8>>, CryptoError> {
        let mut output = hkdf_output(length)?;
        let key = hkdf::Hkdf::<sha2::Sha384>::new(Some(salt), input);
        key.expand(info, &mut output)
            .map_err(|_| CryptoError::BackendFailure)?;
        Ok(output)
    }
}

fn hkdf_output(length: usize) -> Result<Zeroizing<Vec<u8>>, CryptoError> {
    if length > 255 * 48 {
        return Err(CryptoError::InvalidOutputLength);
    }
    Ok(Zeroizing::new(vec![0; length]))
}
