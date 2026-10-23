//! A test-only backend: `Reference` primitives with a seeded, per-thread DRBG (ADR 0022).

use cairn_crypto::{
    CryptoBackend, CryptoError, MLKEM768_CIPHERTEXT_LEN, MLKEM768_ENCAPSULATION_KEY_LEN,
    MlKem768DecapsulationKey, Reference, SharedSecret, X25519_KEY_LEN, X25519SecretKey,
    XWING_CIPHERTEXT_LEN, XWING_ENCAPSULATION_KEY_LEN, XWingDecapsulationKey,
};
use std::cell::Cell;
use zeroize::Zeroizing;

thread_local! {
    static STATE: Cell<([u8; 32], u64)> = const { Cell::new(([0; 32], 0)) };
    static FAILING: Cell<bool> = const { Cell::new(false) };
}

pub struct Seeded;

impl Seeded {
    /// Restarts this thread's stream; equal seeds give equal runs.
    pub fn seed(seed: u64) {
        let mut key = [0; 32];
        key[..8].copy_from_slice(&seed.to_be_bytes());
        STATE.set((key, 0));
        FAILING.set(false);
    }

    /// Makes every later randomness request on this thread fail.
    pub fn fail_randomness() {
        FAILING.set(true);
    }

    fn draw<const N: usize>() -> Result<Zeroizing<[u8; N]>, CryptoError> {
        let mut output = Zeroizing::new([0; N]);
        Self::fill(&mut output[..])?;
        Ok(output)
    }

    fn fill(output: &mut [u8]) -> Result<(), CryptoError> {
        if FAILING.get() {
            return Err(CryptoError::BackendFailure);
        }
        for chunk in output.chunks_mut(48) {
            let (key, counter) = STATE.get();
            let mut input = key.to_vec();
            input.extend_from_slice(&counter.to_be_bytes());
            chunk.copy_from_slice(&Reference::sha384(&input)[..chunk.len()]);
            STATE.set((key, counter + 1));
        }
        Ok(())
    }
}

impl CryptoBackend for Seeded {
    fn sha384(input: &[u8]) -> [u8; 48] {
        Reference::sha384(input)
    }

    fn hmac_sha384(key: &[u8], input: &[u8]) -> Result<Zeroizing<[u8; 48]>, CryptoError> {
        Reference::hmac_sha384(key, input)
    }

    fn hkdf_sha384(
        input: &[u8],
        salt: &[u8],
        info: &[u8],
        length: usize,
    ) -> Result<Zeroizing<Vec<u8>>, CryptoError> {
        Reference::hkdf_sha384(input, salt, info, length)
    }

    fn mlkem768_generate() -> Result<
        (
            [u8; MLKEM768_ENCAPSULATION_KEY_LEN],
            MlKem768DecapsulationKey,
        ),
        CryptoError,
    > {
        Ok(Reference::mlkem768_generate_deterministic(
            &*Self::draw()?,
            &*Self::draw()?,
        ))
    }

    fn mlkem768_encapsulate(
        public: &[u8; MLKEM768_ENCAPSULATION_KEY_LEN],
    ) -> Result<([u8; MLKEM768_CIPHERTEXT_LEN], SharedSecret), CryptoError> {
        Reference::mlkem768_encapsulate_deterministic(public, &*Self::draw()?)
    }

    fn mlkem768_decapsulate(
        key: &MlKem768DecapsulationKey,
        ciphertext: &[u8; MLKEM768_CIPHERTEXT_LEN],
    ) -> Result<SharedSecret, CryptoError> {
        Reference::mlkem768_decapsulate(key, ciphertext)
    }

    fn xwing_generate()
    -> Result<([u8; XWING_ENCAPSULATION_KEY_LEN], XWingDecapsulationKey), CryptoError> {
        Ok(Reference::xwing_generate_deterministic(&*Self::draw()?))
    }

    fn xwing_encapsulate(
        public: &[u8; XWING_ENCAPSULATION_KEY_LEN],
    ) -> Result<([u8; XWING_CIPHERTEXT_LEN], SharedSecret), CryptoError> {
        Reference::xwing_encapsulate_deterministic(public, &*Self::draw()?)
    }

    fn xwing_decapsulate(
        key: &XWingDecapsulationKey,
        ciphertext: &[u8; XWING_CIPHERTEXT_LEN],
    ) -> Result<SharedSecret, CryptoError> {
        Reference::xwing_decapsulate(key, ciphertext)
    }

    fn x25519_generate() -> Result<(X25519SecretKey, [u8; X25519_KEY_LEN]), CryptoError> {
        let secret = X25519SecretKey::from_bytes(&*Self::draw()?);
        let mut base = [0; X25519_KEY_LEN];
        base[0] = 9;
        let public = Reference::x25519(&secret, &base)?;
        Ok((secret, *public))
    }

    fn x25519(
        key: &X25519SecretKey,
        public: &[u8; X25519_KEY_LEN],
    ) -> Result<SharedSecret, CryptoError> {
        Reference::x25519(key, public)
    }

    fn aes256gcm_seal(
        key: &[u8; 32],
        nonce: &[u8; 12],
        aad: &[u8],
        plaintext: &[u8],
    ) -> Result<Vec<u8>, CryptoError> {
        Reference::aes256gcm_seal(key, nonce, aad, plaintext)
    }

    fn aes256gcm_open(
        key: &[u8; 32],
        nonce: &[u8; 12],
        aad: &[u8],
        sealed: &[u8],
    ) -> Result<Zeroizing<Vec<u8>>, CryptoError> {
        Reference::aes256gcm_open(key, nonce, aad, sealed)
    }

    fn fill_random(output: &mut [u8]) -> Result<(), CryptoError> {
        Self::fill(output)
    }
}
