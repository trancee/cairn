#![no_std]

//! ADR 0004 primitive backends; no protocol logic.
//! The seam is `no_std` with `alloc` so `cairn-proto` can use it (ADR 0022).

extern crate alloc;

use alloc::vec::Vec;
use zeroize::Zeroizing;

/// An operation failed without exposing secret material in its diagnostic.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CryptoError {
    InvalidOutputLength,
    BackendFailure,
    /// An ML-KEM key failed the FIPS 203 modulus or hash check.
    InvalidKey,
    /// An X25519 exchange produced the all-zero output, so the peer value was low order.
    ZeroSharedSecret,
    /// AES-256-GCM rejected the tag, or the sealed input was shorter than a tag.
    AuthenticationFailed,
}

impl core::fmt::Display for CryptoError {
    fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        formatter.write_str(match self {
            Self::InvalidOutputLength => "invalid HKDF output length",
            Self::BackendFailure => "cryptographic backend failure",
            Self::InvalidKey => "invalid KEM key",
            Self::ZeroSharedSecret => "all-zero X25519 shared secret",
            Self::AuthenticationFailed => "AEAD authentication failed",
        })
    }
}

impl core::error::Error for CryptoError {}

#[cfg(feature = "aws-lc")]
impl From<aws_lc_rs::error::Unspecified> for CryptoError {
    fn from(_: aws_lc_rs::error::Unspecified) -> Self {
        Self::BackendFailure
    }
}

/// Only reachable through internal failure: callers pass fixed-length keys.
#[cfg(feature = "aws-lc")]
impl From<aws_lc_rs::error::KeyRejected> for CryptoError {
    fn from(_: aws_lc_rs::error::KeyRejected) -> Self {
        Self::BackendFailure
    }
}

#[cfg(feature = "reference")]
impl From<hmac::digest::InvalidLength> for CryptoError {
    fn from(_: hmac::digest::InvalidLength) -> Self {
        Self::BackendFailure
    }
}

#[cfg(feature = "reference")]
impl From<getrandom::Error> for CryptoError {
    fn from(_: getrandom::Error) -> Self {
        Self::BackendFailure
    }
}

/// Only reachable through internal failure: plaintext and AAD lengths are far below GCM limits.
#[cfg(feature = "reference")]
impl From<aes_gcm::Error> for CryptoError {
    fn from(_: aes_gcm::Error) -> Self {
        Self::BackendFailure
    }
}

#[cfg(feature = "reference")]
impl From<hkdf::InvalidLength> for CryptoError {
    fn from(_: hkdf::InvalidLength) -> Self {
        Self::BackendFailure
    }
}

pub const MLKEM768_ENCAPSULATION_KEY_LEN: usize = 1184;
pub const MLKEM768_DECAPSULATION_KEY_LEN: usize = 2400;
pub const MLKEM768_CIPHERTEXT_LEN: usize = 1088;
pub const XWING_ENCAPSULATION_KEY_LEN: usize = MLKEM768_ENCAPSULATION_KEY_LEN + 32;
/// Expanded form: ML-KEM-768 decapsulation key, X25519 scalar, X25519 public key.
pub const XWING_DECAPSULATION_KEY_LEN: usize = MLKEM768_DECAPSULATION_KEY_LEN + 64;
pub const XWING_CIPHERTEXT_LEN: usize = MLKEM768_CIPHERTEXT_LEN + 32;
pub const SHARED_SECRET_LEN: usize = 32;
pub const X25519_KEY_LEN: usize = 32;
pub const AES256GCM_KEY_LEN: usize = 32;
pub const AES256GCM_NONCE_LEN: usize = 12;
pub const AES256GCM_TAG_LEN: usize = 16;

/// Shared secret produced by encapsulation or decapsulation.
pub type SharedSecret = Zeroizing<[u8; SHARED_SECRET_LEN]>;

macro_rules! secret_key {
    ($(#[$attribute:meta])* $name:ident([u8; $length:expr])) => {
        $(#[$attribute])*
        pub struct $name(Zeroizing<[u8; $length]>);

        impl $name {
            pub fn from_bytes(bytes: &[u8; $length]) -> Self {
                Self(Zeroizing::new(*bytes))
            }

            pub fn as_bytes(&self) -> &[u8; $length] {
                &self.0
            }
        }

        impl core::fmt::Debug for $name {
            fn fmt(&self, formatter: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
                formatter.write_str(concat!(stringify!($name), "(..)"))
            }
        }
    };
}

secret_key!(
    /// FIPS 203 expanded decapsulation key: `dk_PKE || ek || H(ek) || z`.
    MlKem768DecapsulationKey([u8; MLKEM768_DECAPSULATION_KEY_LEN])
);

secret_key!(
    /// RFC 7748 X25519 scalar; clamped when used.
    X25519SecretKey([u8; X25519_KEY_LEN])
);

secret_key!(
    /// X-Wing draft-11 decapsulation key in the expanded form permitted by its §5.5.1:
    /// `dk_M || sk_X || pk_X`.
    XWingDecapsulationKey([u8; XWING_DECAPSULATION_KEY_LEN])
);

#[cfg(any(feature = "aws-lc", feature = "reference"))]
impl XWingDecapsulationKey {
    fn parts(&self) -> (&[u8; MLKEM768_DECAPSULATION_KEY_LEN], &[u8; 32], &[u8; 32]) {
        let (ml_kem, rest) = self.0.split_first_chunk().expect("fixed length");
        let (scalar, public) = rest.split_first_chunk().expect("fixed length");
        (ml_kem, scalar, public.try_into().expect("fixed length"))
    }

    fn assemble(
        ml_kem: &[u8; MLKEM768_DECAPSULATION_KEY_LEN],
        scalar: &[u8; 32],
        public: &[u8; 32],
    ) -> Self {
        let mut key = Zeroizing::new([0; XWING_DECAPSULATION_KEY_LEN]);
        key[..MLKEM768_DECAPSULATION_KEY_LEN].copy_from_slice(ml_kem);
        key[MLKEM768_DECAPSULATION_KEY_LEN..MLKEM768_DECAPSULATION_KEY_LEN + 32]
            .copy_from_slice(scalar);
        key[MLKEM768_DECAPSULATION_KEY_LEN + 32..].copy_from_slice(public);
        Self(key)
    }
}

#[cfg(any(feature = "aws-lc", feature = "reference"))]
fn split_xwing_public(
    public: &[u8; XWING_ENCAPSULATION_KEY_LEN],
) -> (&[u8; MLKEM768_ENCAPSULATION_KEY_LEN], &[u8; 32]) {
    let (ml_kem, x25519) = public.split_first_chunk().expect("fixed length");
    (ml_kem, x25519.try_into().expect("fixed length"))
}

#[cfg(any(feature = "aws-lc", feature = "reference"))]
fn split_xwing_ciphertext(
    ciphertext: &[u8; XWING_CIPHERTEXT_LEN],
) -> (&[u8; MLKEM768_CIPHERTEXT_LEN], &[u8; 32]) {
    let (ml_kem, x25519) = ciphertext.split_first_chunk().expect("fixed length");
    (ml_kem, x25519.try_into().expect("fixed length"))
}

#[cfg(any(feature = "aws-lc", feature = "reference"))]
fn join<const A: usize, const B: usize, const N: usize>(
    first: &[u8; A],
    second: &[u8; B],
) -> [u8; N] {
    const { assert!(A + B == N) };
    let mut joined = [0; N];
    joined[..A].copy_from_slice(first);
    joined[A..].copy_from_slice(second);
    joined
}

#[cfg(any(feature = "aws-lc", feature = "reference"))]
/// X-Wing draft-11 combiner input: `ss_M || ss_X || ct_X || pk_X || XWingLabel`.
fn xwing_combiner_input(
    ml_kem_secret: &[u8; 32],
    x25519_secret: &[u8; 32],
    x25519_ciphertext: &[u8; 32],
    x25519_public: &[u8; 32],
) -> Zeroizing<[u8; 134]> {
    let mut input = Zeroizing::new([0; 134]);
    input[..32].copy_from_slice(ml_kem_secret);
    input[32..64].copy_from_slice(x25519_secret);
    input[64..96].copy_from_slice(x25519_ciphertext);
    input[96..128].copy_from_slice(x25519_public);
    input[128..].copy_from_slice(b"\\.//^\\");
    input
}

/// Compile-time backend boundary for the implemented primitives.
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

    fn mlkem768_generate() -> Result<
        (
            [u8; MLKEM768_ENCAPSULATION_KEY_LEN],
            MlKem768DecapsulationKey,
        ),
        CryptoError,
    >;
    fn mlkem768_encapsulate(
        public: &[u8; MLKEM768_ENCAPSULATION_KEY_LEN],
    ) -> Result<([u8; MLKEM768_CIPHERTEXT_LEN], SharedSecret), CryptoError>;
    /// FIPS 203 decapsulation with the §7.3 hash check; returns `InvalidKey` if it fails.
    fn mlkem768_decapsulate(
        key: &MlKem768DecapsulationKey,
        ciphertext: &[u8; MLKEM768_CIPHERTEXT_LEN],
    ) -> Result<SharedSecret, CryptoError>;

    fn xwing_generate()
    -> Result<([u8; XWING_ENCAPSULATION_KEY_LEN], XWingDecapsulationKey), CryptoError>;
    fn xwing_encapsulate(
        public: &[u8; XWING_ENCAPSULATION_KEY_LEN],
    ) -> Result<([u8; XWING_CIPHERTEXT_LEN], SharedSecret), CryptoError>;
    fn xwing_decapsulate(
        key: &XWingDecapsulationKey,
        ciphertext: &[u8; XWING_CIPHERTEXT_LEN],
    ) -> Result<SharedSecret, CryptoError>;

    fn x25519_generate() -> Result<(X25519SecretKey, [u8; X25519_KEY_LEN]), CryptoError>;
    /// RFC 7748 X25519; the all-zero output returns `ZeroSharedSecret` (spec §2.1).
    fn x25519(
        key: &X25519SecretKey,
        public: &[u8; X25519_KEY_LEN],
    ) -> Result<SharedSecret, CryptoError>;

    /// AES-256-GCM encryption returning `ciphertext || tag`. Callers own nonce uniqueness.
    fn aes256gcm_seal(
        key: &[u8; AES256GCM_KEY_LEN],
        nonce: &[u8; AES256GCM_NONCE_LEN],
        aad: &[u8],
        plaintext: &[u8],
    ) -> Result<Vec<u8>, CryptoError>;
    /// Verifies and decrypts `ciphertext || tag`; no plaintext is returned on failure.
    fn aes256gcm_open(
        key: &[u8; AES256GCM_KEY_LEN],
        nonce: &[u8; AES256GCM_NONCE_LEN],
        aad: &[u8],
        sealed: &[u8],
    ) -> Result<Zeroizing<Vec<u8>>, CryptoError>;

    /// Fills `output` from the operating-system CSPRNG.
    fn fill_random(output: &mut [u8]) -> Result<(), CryptoError>;
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
        let key = prk.expand(&information, OutputLength(length))?;
        key.fill(&mut output)?;
        Ok(output)
    }

    fn mlkem768_generate() -> Result<
        (
            [u8; MLKEM768_ENCAPSULATION_KEY_LEN],
            MlKem768DecapsulationKey,
        ),
        CryptoError,
    > {
        use aws_lc_rs::kem;
        let key = kem::DecapsulationKey::generate(&kem::ML_KEM_768)?;
        let public = key.encapsulation_key()?.key_bytes()?;
        let mut private = Zeroizing::new([0; MLKEM768_DECAPSULATION_KEY_LEN]);
        private.copy_from_slice(key.key_bytes()?.as_ref());
        Ok((
            provider_bytes(public.as_ref()),
            MlKem768DecapsulationKey(private),
        ))
    }

    fn mlkem768_encapsulate(
        public: &[u8; MLKEM768_ENCAPSULATION_KEY_LEN],
    ) -> Result<([u8; MLKEM768_CIPHERTEXT_LEN], SharedSecret), CryptoError> {
        use aws_lc_rs::kem;
        // AWS-LC defers the FIPS 203 §7.2 modulus check to an opaque encapsulation error.
        if !mlkem768_coefficients_reduced(public) {
            return Err(CryptoError::InvalidKey);
        }
        let key = kem::EncapsulationKey::new(&kem::ML_KEM_768, public)?;
        let (ciphertext, secret) = key.encapsulate()?;
        Ok((
            provider_bytes(ciphertext.as_ref()),
            aws_lc_secret(secret.as_ref()),
        ))
    }

    fn mlkem768_decapsulate(
        key: &MlKem768DecapsulationKey,
        ciphertext: &[u8; MLKEM768_CIPHERTEXT_LEN],
    ) -> Result<SharedSecret, CryptoError> {
        use aws_lc_rs::kem;
        let bytes = key.as_bytes();
        // AWS-LC rejects a failed FIPS 203 §7.3 hash check only as an opaque decapsulation error.
        let digest = aws_lc_sha3_256(&bytes[1152..2336]);
        if digest[..] != bytes[2336..2368] {
            return Err(CryptoError::InvalidKey);
        }
        let key = kem::DecapsulationKey::new(&kem::ML_KEM_768, bytes)?;
        let secret = key.decapsulate(kem::Ciphertext::from(&ciphertext[..]))?;
        Ok(aws_lc_secret(secret.as_ref()))
    }

    /// Draws `dk_M` and `sk_X` independently: AWS-LC exposes no SHAKE256 for the 32-byte seed.
    fn xwing_generate()
    -> Result<([u8; XWING_ENCAPSULATION_KEY_LEN], XWingDecapsulationKey), CryptoError> {
        let (ml_kem_public, ml_kem_key) = Self::mlkem768_generate()?;
        let mut scalar = Zeroizing::new([0; 32]);
        aws_lc_rs::rand::fill(&mut scalar[..])?;
        let x25519_public = aws_lc_x25519_public(&scalar)?;
        Ok((
            join(&ml_kem_public, &x25519_public),
            XWingDecapsulationKey::assemble(ml_kem_key.as_bytes(), &scalar, &x25519_public),
        ))
    }

    fn xwing_encapsulate(
        public: &[u8; XWING_ENCAPSULATION_KEY_LEN],
    ) -> Result<([u8; XWING_CIPHERTEXT_LEN], SharedSecret), CryptoError> {
        let (ml_kem_public, x25519_public) = split_xwing_public(public);
        let (ml_kem_ciphertext, ml_kem_secret) = Self::mlkem768_encapsulate(ml_kem_public)?;
        let mut ephemeral = Zeroizing::new([0; 32]);
        aws_lc_rs::rand::fill(&mut ephemeral[..])?;
        let x25519_ciphertext = aws_lc_x25519_public(&ephemeral)?;
        let x25519_secret = aws_lc_x25519(&ephemeral, x25519_public)?;
        let input = xwing_combiner_input(
            &ml_kem_secret,
            &x25519_secret,
            &x25519_ciphertext,
            x25519_public,
        );
        Ok((
            join(&ml_kem_ciphertext, &x25519_ciphertext),
            aws_lc_sha3_256(&input[..]),
        ))
    }

    fn xwing_decapsulate(
        key: &XWingDecapsulationKey,
        ciphertext: &[u8; XWING_CIPHERTEXT_LEN],
    ) -> Result<SharedSecret, CryptoError> {
        let (ml_kem_key, scalar, x25519_public) = key.parts();
        let (ml_kem_ciphertext, x25519_ciphertext) = split_xwing_ciphertext(ciphertext);
        let ml_kem_secret = Self::mlkem768_decapsulate(
            &MlKem768DecapsulationKey::from_bytes(ml_kem_key),
            ml_kem_ciphertext,
        )?;
        let x25519_secret = aws_lc_x25519(scalar, x25519_ciphertext)?;
        let input = xwing_combiner_input(
            &ml_kem_secret,
            &x25519_secret,
            x25519_ciphertext,
            x25519_public,
        );
        Ok(aws_lc_sha3_256(&input[..]))
    }

    fn x25519_generate() -> Result<(X25519SecretKey, [u8; X25519_KEY_LEN]), CryptoError> {
        let mut scalar = Zeroizing::new([0; X25519_KEY_LEN]);
        aws_lc_rs::rand::fill(&mut scalar[..])?;
        let public = aws_lc_x25519_public(&scalar)?;
        Ok((X25519SecretKey::from_bytes(&scalar), public))
    }

    fn x25519(
        key: &X25519SecretKey,
        public: &[u8; X25519_KEY_LEN],
    ) -> Result<SharedSecret, CryptoError> {
        aws_lc_x25519(key.as_bytes(), public)
    }

    fn aes256gcm_seal(
        key: &[u8; AES256GCM_KEY_LEN],
        nonce: &[u8; AES256GCM_NONCE_LEN],
        aad: &[u8],
        plaintext: &[u8],
    ) -> Result<Vec<u8>, CryptoError> {
        use aws_lc_rs::aead;
        let key = aead::LessSafeKey::new(aead::UnboundKey::new(&aead::AES_256_GCM, key)?);
        let mut sealed = Vec::with_capacity(plaintext.len() + AES256GCM_TAG_LEN);
        sealed.extend_from_slice(plaintext);
        key.seal_in_place_append_tag(
            aead::Nonce::assume_unique_for_key(*nonce),
            aead::Aad::from(aad),
            &mut sealed,
        )?;
        Ok(sealed)
    }

    fn aes256gcm_open(
        key: &[u8; AES256GCM_KEY_LEN],
        nonce: &[u8; AES256GCM_NONCE_LEN],
        aad: &[u8],
        sealed: &[u8],
    ) -> Result<Zeroizing<Vec<u8>>, CryptoError> {
        use aws_lc_rs::aead;
        let key = aead::LessSafeKey::new(aead::UnboundKey::new(&aead::AES_256_GCM, key)?);
        let mut buffer = Zeroizing::new(sealed.to_vec());
        let length = key
            .open_in_place(
                aead::Nonce::assume_unique_for_key(*nonce),
                aead::Aad::from(aad),
                &mut buffer,
            )
            .map_err(|_| CryptoError::AuthenticationFailed)?
            .len();
        buffer.truncate(length);
        Ok(buffer)
    }

    fn fill_random(output: &mut [u8]) -> Result<(), CryptoError> {
        Ok(aws_lc_rs::rand::fill(output)?)
    }
}

/// FIPS 203 §7.2 modulus check on public input: every 12-bit coefficient of `ek_PKE` is below q.
#[cfg(feature = "aws-lc")]
fn mlkem768_coefficients_reduced(public: &[u8; MLKEM768_ENCAPSULATION_KEY_LEN]) -> bool {
    public[..1152].as_chunks::<3>().0.iter().all(|bytes| {
        let low = u16::from(bytes[0]) | (u16::from(bytes[1] & 0x0f) << 8);
        let high = u16::from(bytes[1] >> 4) | (u16::from(bytes[2]) << 4);
        low < 3329 && high < 3329
    })
}

/// Copies a public provider output whose length the algorithm fixes.
#[cfg(feature = "aws-lc")]
fn provider_bytes<const N: usize>(bytes: &[u8]) -> [u8; N] {
    let mut output = [0; N];
    output.copy_from_slice(bytes);
    output
}

#[cfg(feature = "aws-lc")]
fn aws_lc_secret(secret: &[u8]) -> SharedSecret {
    let mut output = Zeroizing::new([0; SHARED_SECRET_LEN]);
    output.copy_from_slice(secret);
    output
}

#[cfg(feature = "aws-lc")]
fn aws_lc_sha3_256(input: &[u8]) -> SharedSecret {
    aws_lc_secret(aws_lc_rs::digest::digest(&aws_lc_rs::digest::SHA3_256, input).as_ref())
}

#[cfg(feature = "aws-lc")]
fn aws_lc_x25519_public(scalar: &[u8; 32]) -> Result<[u8; 32], CryptoError> {
    use aws_lc_rs::agreement;
    let key = agreement::PrivateKey::from_private_key(&agreement::X25519, scalar)?;
    Ok(provider_bytes(key.compute_public_key()?.as_ref()))
}

/// AWS-LC fails X25519 only on the all-zero output once both inputs are 32 bytes.
#[cfg(feature = "aws-lc")]
fn aws_lc_x25519(scalar: &[u8; 32], public: &[u8; 32]) -> Result<SharedSecret, CryptoError> {
    use aws_lc_rs::agreement;
    let key = agreement::PrivateKey::from_private_key(&agreement::X25519, scalar)?;
    agreement::agree(
        &key,
        agreement::UnparsedPublicKey::new(&agreement::X25519, public),
        CryptoError::ZeroSharedSecret,
        |secret| Ok(aws_lc_secret(secret)),
    )
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
        let mut mac = hmac::Hmac::<sha2::Sha384>::new_from_slice(key)?;
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
        key.expand(info, &mut output)?;
        Ok(output)
    }

    fn mlkem768_generate() -> Result<
        (
            [u8; MLKEM768_ENCAPSULATION_KEY_LEN],
            MlKem768DecapsulationKey,
        ),
        CryptoError,
    > {
        let mut seed = Zeroizing::new([0; 64]);
        getrandom::fill(&mut seed[..])?;
        let (d, z) = seed.split_first_chunk().expect("fixed length");
        Ok(Self::mlkem768_generate_deterministic(
            d,
            z.try_into().expect("fixed length"),
        ))
    }

    fn mlkem768_encapsulate(
        public: &[u8; MLKEM768_ENCAPSULATION_KEY_LEN],
    ) -> Result<([u8; MLKEM768_CIPHERTEXT_LEN], SharedSecret), CryptoError> {
        let mut message = Zeroizing::new([0; 32]);
        getrandom::fill(&mut message[..])?;
        Self::mlkem768_encapsulate_deterministic(public, &message)
    }

    fn mlkem768_decapsulate(
        key: &MlKem768DecapsulationKey,
        ciphertext: &[u8; MLKEM768_CIPHERTEXT_LEN],
    ) -> Result<SharedSecret, CryptoError> {
        use ml_kem::Decapsulate;
        let key = expanded::decode(key.as_bytes())?;
        let mut secret = key.decapsulate(&(*ciphertext).into());
        Ok(take_secret(&mut secret))
    }

    fn xwing_generate()
    -> Result<([u8; XWING_ENCAPSULATION_KEY_LEN], XWingDecapsulationKey), CryptoError> {
        let mut seed = Zeroizing::new([0; 32]);
        getrandom::fill(&mut seed[..])?;
        Ok(Self::xwing_generate_deterministic(&seed))
    }

    fn xwing_encapsulate(
        public: &[u8; XWING_ENCAPSULATION_KEY_LEN],
    ) -> Result<([u8; XWING_CIPHERTEXT_LEN], SharedSecret), CryptoError> {
        let mut seed = Zeroizing::new([0; 64]);
        getrandom::fill(&mut seed[..])?;
        Self::xwing_encapsulate_deterministic(public, &seed)
    }

    fn xwing_decapsulate(
        key: &XWingDecapsulationKey,
        ciphertext: &[u8; XWING_CIPHERTEXT_LEN],
    ) -> Result<SharedSecret, CryptoError> {
        let (ml_kem_key, scalar, x25519_public) = key.parts();
        let (ml_kem_ciphertext, x25519_ciphertext) = split_xwing_ciphertext(ciphertext);
        let ml_kem_secret = Self::mlkem768_decapsulate(
            &MlKem768DecapsulationKey::from_bytes(ml_kem_key),
            ml_kem_ciphertext,
        )?;
        let x25519_secret = reference_x25519(scalar, x25519_ciphertext)?;
        Ok(reference_sha3_256(
            &xwing_combiner_input(
                &ml_kem_secret,
                &x25519_secret,
                x25519_ciphertext,
                x25519_public,
            )[..],
        ))
    }

    fn x25519_generate() -> Result<(X25519SecretKey, [u8; X25519_KEY_LEN]), CryptoError> {
        let mut scalar = Zeroizing::new([0; X25519_KEY_LEN]);
        getrandom::fill(&mut scalar[..])?;
        let public = x25519_dalek::x25519(*scalar, x25519_dalek::X25519_BASEPOINT_BYTES);
        Ok((X25519SecretKey::from_bytes(&scalar), public))
    }

    fn x25519(
        key: &X25519SecretKey,
        public: &[u8; X25519_KEY_LEN],
    ) -> Result<SharedSecret, CryptoError> {
        reference_x25519(key.as_bytes(), public)
    }

    fn aes256gcm_seal(
        key: &[u8; AES256GCM_KEY_LEN],
        nonce: &[u8; AES256GCM_NONCE_LEN],
        aad: &[u8],
        plaintext: &[u8],
    ) -> Result<Vec<u8>, CryptoError> {
        use aes_gcm::{AeadInOut, KeyInit};
        let mut sealed = Vec::with_capacity(plaintext.len() + AES256GCM_TAG_LEN);
        sealed.extend_from_slice(plaintext);
        aes_gcm::Aes256Gcm::new(key.into()).encrypt_in_place(nonce.into(), aad, &mut sealed)?;
        Ok(sealed)
    }

    fn aes256gcm_open(
        key: &[u8; AES256GCM_KEY_LEN],
        nonce: &[u8; AES256GCM_NONCE_LEN],
        aad: &[u8],
        sealed: &[u8],
    ) -> Result<Zeroizing<Vec<u8>>, CryptoError> {
        use aes_gcm::{AeadInOut, KeyInit};
        let mut buffer = Zeroizing::new(sealed.to_vec());
        aes_gcm::Aes256Gcm::new(key.into())
            .decrypt_in_place(nonce.into(), aad, &mut *buffer)
            .map_err(|_| CryptoError::AuthenticationFailed)?;
        Ok(buffer)
    }

    fn fill_random(output: &mut [u8]) -> Result<(), CryptoError> {
        Ok(getrandom::fill(output)?)
    }
}

/// Derandomized operations for known-answer tests; callers must supply uniform secret randomness.
#[cfg(feature = "reference")]
impl Reference {
    /// FIPS 203 `ML-KEM.KeyGen_internal(d, z)`.
    pub fn mlkem768_generate_deterministic(
        d: &[u8; 32],
        z: &[u8; 32],
    ) -> (
        [u8; MLKEM768_ENCAPSULATION_KEY_LEN],
        MlKem768DecapsulationKey,
    ) {
        use ml_kem::KeyExport;
        let mut seed = ml_kem::Seed::from(join::<32, 32, 64>(d, z));
        let key = ml_kem::DecapsulationKey768::from_seed(seed);
        zeroize::Zeroize::zeroize(&mut seed);
        let public = key.encapsulation_key().to_bytes().into();
        (public, expanded::encode(&key))
    }

    /// FIPS 203 `ML-KEM.Encaps_internal(ek, m)` after the §7.2 modulus check.
    pub fn mlkem768_encapsulate_deterministic(
        public: &[u8; MLKEM768_ENCAPSULATION_KEY_LEN],
        message: &[u8; 32],
    ) -> Result<([u8; MLKEM768_CIPHERTEXT_LEN], SharedSecret), CryptoError> {
        let key = ml_kem::EncapsulationKey768::new(&(*public).into())
            .map_err(|_| CryptoError::InvalidKey)?;
        let (ciphertext, mut secret) = key.encapsulate_deterministic(&(*message).into());
        Ok((ciphertext.into(), take_secret(&mut secret)))
    }

    /// X-Wing draft-11 `GenerateKeyPairDerand(sk)`, returning the expanded decapsulation key.
    pub fn xwing_generate_deterministic(
        seed: &[u8; 32],
    ) -> ([u8; XWING_ENCAPSULATION_KEY_LEN], XWingDecapsulationKey) {
        use shake::{ExtendableOutput, Update, XofReader};
        let mut expanded = Zeroizing::new([0; 96]);
        let mut shake = shake::Shake256::default();
        shake.update(seed);
        shake.finalize_xof().read(&mut expanded[..]);
        let (d, rest) = expanded.split_first_chunk::<32>().expect("fixed length");
        let (z, scalar) = rest.split_first_chunk::<32>().expect("fixed length");
        let scalar: &[u8; 32] = scalar.try_into().expect("fixed length");
        let (ml_kem_public, ml_kem_key) = Self::mlkem768_generate_deterministic(d, z);
        let x25519_public = x25519_dalek::x25519(*scalar, x25519_dalek::X25519_BASEPOINT_BYTES);
        (
            join(&ml_kem_public, &x25519_public),
            XWingDecapsulationKey::assemble(ml_kem_key.as_bytes(), scalar, &x25519_public),
        )
    }

    /// X-Wing draft-11 `EncapsulateDerand(pk, eseed)`.
    pub fn xwing_encapsulate_deterministic(
        public: &[u8; XWING_ENCAPSULATION_KEY_LEN],
        seed: &[u8; 64],
    ) -> Result<([u8; XWING_CIPHERTEXT_LEN], SharedSecret), CryptoError> {
        let (ml_kem_public, x25519_public) = split_xwing_public(public);
        let (message, ephemeral) = seed.split_first_chunk::<32>().expect("fixed length");
        let ephemeral: &[u8; 32] = ephemeral.try_into().expect("fixed length");
        let (ml_kem_ciphertext, ml_kem_secret) =
            Self::mlkem768_encapsulate_deterministic(ml_kem_public, message)?;
        let x25519_ciphertext =
            x25519_dalek::x25519(*ephemeral, x25519_dalek::X25519_BASEPOINT_BYTES);
        let x25519_secret = reference_x25519(ephemeral, x25519_public)?;
        let secret = reference_sha3_256(
            &xwing_combiner_input(
                &ml_kem_secret,
                &x25519_secret,
                &x25519_ciphertext,
                x25519_public,
            )[..],
        );
        Ok((join(&ml_kem_ciphertext, &x25519_ciphertext), secret))
    }
}

/// The expanded encoding is deprecated upstream in favour of seeds, but it is the only private
/// key form the AWS-LC safe API can import, so both adapters share it.
#[cfg(feature = "reference")]
#[expect(
    deprecated,
    reason = "AWS-LC interoperability requires the FIPS 203 expanded key"
)]
mod expanded {
    use super::{CryptoError, MLKEM768_DECAPSULATION_KEY_LEN, MlKem768DecapsulationKey};
    use ml_kem::ExpandedKeyEncoding;

    pub(super) fn encode(key: &ml_kem::DecapsulationKey768) -> MlKem768DecapsulationKey {
        let mut bytes = key.to_expanded_bytes();
        let encoded = MlKem768DecapsulationKey::from_bytes(&bytes.into());
        zeroize::Zeroize::zeroize(&mut bytes);
        encoded
    }

    pub(super) fn decode(
        bytes: &[u8; MLKEM768_DECAPSULATION_KEY_LEN],
    ) -> Result<ml_kem::DecapsulationKey768, CryptoError> {
        let mut array = (*bytes).into();
        let key = ml_kem::DecapsulationKey768::from_expanded_bytes(&array)
            .map_err(|_| CryptoError::InvalidKey);
        zeroize::Zeroize::zeroize(&mut array);
        key
    }
}

#[cfg(feature = "reference")]
fn take_secret(secret: &mut ml_kem::SharedKey) -> SharedSecret {
    let output = Zeroizing::new((*secret).into());
    zeroize::Zeroize::zeroize(secret);
    output
}

#[cfg(feature = "reference")]
fn reference_sha3_256(input: &[u8]) -> SharedSecret {
    use sha3::Digest;
    Zeroizing::new(sha3::Sha3_256::digest(input).into())
}

/// Rejects the all-zero output with a constant-time identity test.
#[cfg(feature = "reference")]
fn reference_x25519(scalar: &[u8; 32], public: &[u8; 32]) -> Result<SharedSecret, CryptoError> {
    let secret = x25519_dalek::StaticSecret::from(*scalar);
    let shared = secret.diffie_hellman(&x25519_dalek::PublicKey::from(*public));
    if !shared.was_contributory() {
        return Err(CryptoError::ZeroSharedSecret);
    }
    Ok(Zeroizing::new(shared.to_bytes()))
}

#[cfg(any(feature = "aws-lc", feature = "reference"))]
fn hkdf_output(length: usize) -> Result<Zeroizing<Vec<u8>>, CryptoError> {
    if length > 255 * 48 {
        return Err(CryptoError::InvalidOutputLength);
    }
    Ok(Zeroizing::new(alloc::vec![0; length]))
}
