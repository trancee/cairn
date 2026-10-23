//! TOFU pairing P1–P4 (spec §5.1, §5.2, §5.5).
//!
//! A sends P1 and P3; B sends P2 and P4. Every step consumes the previous
//! state, so a failed step leaves nothing behind: dropping the state erases
//! its secrets, which is the spec's "abort".

use crate::PairingRole;
use crate::card::{Card, CardError};
use crate::kdf::{commit, hash, kdf, mac};
use alloc::vec::Vec;
use cairn_crypto::{
    CryptoBackend, CryptoError, XWING_CIPHERTEXT_LEN, XWING_ENCAPSULATION_KEY_LEN,
    XWingDecapsulationKey,
};
use subtle::ConstantTimeEq;
use zeroize::Zeroizing;

const VERSION: u8 = 0x01;
const MODE_TOFU: u8 = 0x03;
const NONCE_LEN: usize = 16;
const ZERO_NONCE: [u8; 12] = [0; 12];
pub(crate) const P1_LEN: usize = 3 + 32 + XWING_ENCAPSULATION_KEY_LEN;
pub(crate) const P2_LEN: usize = 1 + XWING_CIPHERTEXT_LEN + NONCE_LEN;

/// Any failure aborts the pairing and closes the link.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum PairingError {
    Malformed,
    Version,
    Mode,
    Commitment,
    Authentication,
    Card(CardError),
    Crypto(CryptoError),
}

impl From<CryptoError> for PairingError {
    fn from(error: CryptoError) -> Self {
        Self::Crypto(error)
    }
}

/// The per-contact pairing output that is persisted (spec §5.5).
pub(crate) struct Paired {
    pub(crate) role: PairingRole,
    pub(crate) th: [u8; 48],
    pub(crate) nonce_b: [u8; NONCE_LEN],
    pub(crate) peer: Card,
    pub(crate) pair_id: [u8; 16],
    pub(crate) chain_key: Zeroizing<[u8; 32]>,
    pub(crate) door_a_to_b: Zeroizing<[u8; 32]>,
    pub(crate) door_b_to_a: Zeroizing<[u8; 32]>,
}

/// Keys derived from `RK`; `RK` itself is erased as soon as they exist.
struct Keys {
    th: [u8; 48],
    pair_id: [u8; 16],
    chain_key: Zeroizing<[u8; 32]>,
    door_a_to_b: Zeroizing<[u8; 32]>,
    door_b_to_a: Zeroizing<[u8; 32]>,
    conf_a: Zeroizing<[u8; 32]>,
    conf_b: Zeroizing<[u8; 32]>,
    card_a: Zeroizing<[u8; 32]>,
    card_b: Zeroizing<[u8; 32]>,
}

impl Keys {
    fn derive<B: CryptoBackend>(shared: &[u8], th: [u8; 48]) -> Result<Self, CryptoError> {
        let rk = kdf::<B, 32>(shared, &th, b"rk", &[])?;
        let pair_id = kdf::<B, 16>(&rk[..], &[], b"pairid", &[])?;
        Ok(Self {
            th,
            pair_id: *pair_id,
            chain_key: kdf::<B, 32>(&rk[..], &[], b"ck0", &[])?,
            door_a_to_b: kdf::<B, 32>(&rk[..], &[], b"door A", &[])?,
            door_b_to_a: kdf::<B, 32>(&rk[..], &[], b"door B", &[])?,
            conf_a: kdf::<B, 32>(&rk[..], &[], b"conf A", &[])?,
            conf_b: kdf::<B, 32>(&rk[..], &[], b"conf B", &[])?,
            card_a: kdf::<B, 32>(&rk[..], &[], b"card A", &[])?,
            card_b: kdf::<B, 32>(&rk[..], &[], b"card B", &[])?,
        })
    }

    fn into_paired(self, role: PairingRole, nonce_b: [u8; NONCE_LEN], peer: Card) -> Paired {
        Paired {
            role,
            th: self.th,
            nonce_b,
            peer,
            pair_id: self.pair_id,
            chain_key: self.chain_key,
            door_a_to_b: self.door_a_to_b,
            door_b_to_a: self.door_b_to_a,
        }
    }
}

/// `hdr ‖ [prefix] ‖ Seal(key, 0^12, hdr ‖ th, confirm ‖ card)`.
fn seal_card<B: CryptoBackend>(
    step: u8,
    prefix: &[u8],
    key: &[u8; 32],
    th: &[u8; 48],
    confirm: &[u8; 16],
    card: &Card,
) -> Result<Vec<u8>, CryptoError> {
    let mut plaintext = Zeroizing::new(Vec::from(&confirm[..]));
    plaintext.extend_from_slice(&card.encode());
    let sealed = B::aes256gcm_seal(key, &ZERO_NONCE, &aad(step, th), &plaintext)?;
    let mut frame = Vec::with_capacity(1 + prefix.len() + sealed.len());
    frame.push(step);
    frame.extend_from_slice(prefix);
    frame.extend_from_slice(&sealed);
    Ok(frame)
}

/// Opens a P3/P4 body and checks its confirmation in constant time.
fn open_card<B: CryptoBackend>(
    step: u8,
    sealed: &[u8],
    key: &[u8; 32],
    th: &[u8; 48],
    expected: &[u8; 16],
) -> Result<Card, PairingError> {
    let plaintext = B::aes256gcm_open(key, &ZERO_NONCE, &aad(step, th), sealed)
        .map_err(|_| PairingError::Authentication)?;
    let (confirm, card) = plaintext
        .split_first_chunk::<16>()
        .ok_or(PairingError::Malformed)?;
    if !bool::from(confirm.ct_eq(expected)) {
        return Err(PairingError::Authentication);
    }
    Card::decode(card).map_err(PairingError::Card)
}

fn aad(step: u8, th: &[u8; 48]) -> [u8; 49] {
    let mut aad = [0; 49];
    aad[0] = step;
    aad[1..].copy_from_slice(th);
    aad
}

fn random<B: CryptoBackend, const N: usize>() -> Result<Zeroizing<[u8; N]>, CryptoError> {
    let mut bytes = Zeroizing::new([0; N]);
    B::fill_random(&mut bytes[..])?;
    Ok(bytes)
}

/// A after sending P1.
pub(crate) struct AwaitingP2 {
    decapsulation_key: XWingDecapsulationKey,
    nonce_a: Zeroizing<[u8; NONCE_LEN]>,
    p1: Vec<u8>,
    card: Card,
}

impl AwaitingP2 {
    /// Generates `(ek_A, dk_A)` and `nA` and returns the P1 frame.
    pub(crate) fn start<B: CryptoBackend>(card: Card) -> Result<(Self, Vec<u8>), CryptoError> {
        let (public, decapsulation_key) = B::xwing_generate()?;
        let nonce_a = random::<B, NONCE_LEN>()?;
        let mut p1 = Vec::with_capacity(P1_LEN);
        p1.extend_from_slice(&[0x01, VERSION, MODE_TOFU]);
        p1.extend_from_slice(&commit::<B>(&nonce_a));
        p1.extend_from_slice(&public);
        let state = Self {
            decapsulation_key,
            nonce_a,
            p1: p1.clone(),
            card,
        };
        Ok((state, p1))
    }

    /// Decapsulates P2 and returns P3.
    pub(crate) fn receive_p2<B: CryptoBackend>(
        self,
        p2: &[u8],
    ) -> Result<(AwaitingP4, Vec<u8>), PairingError> {
        if p2.len() != P2_LEN || p2[0] != 0x02 {
            return Err(PairingError::Malformed);
        }
        let (ciphertext, nonce_b) = p2[1..]
            .split_first_chunk::<XWING_CIPHERTEXT_LEN>()
            .ok_or(PairingError::Malformed)?;
        let nonce_b: [u8; NONCE_LEN] = nonce_b.try_into().map_err(|_| PairingError::Malformed)?;
        let shared = B::xwing_decapsulate(&self.decapsulation_key, ciphertext)?;
        let th = hash::<B>(&[&self.p1, p2, &self.nonce_a[..]]);
        let keys = Keys::derive::<B>(&shared[..], th)?;
        let confirm = mac::<B>(&keys.conf_a[..], b"P3", &[&th])?;
        let p3 = seal_card::<B>(
            0x03,
            &self.nonce_a[..],
            &keys.card_a,
            &th,
            &confirm,
            &self.card,
        )?;
        Ok((AwaitingP4 { keys, nonce_b }, p3))
    }
}

/// A after sending P3.
pub(crate) struct AwaitingP4 {
    keys: Keys,
    nonce_b: [u8; NONCE_LEN],
}

impl AwaitingP4 {
    pub(crate) fn receive_p4<B: CryptoBackend>(self, p4: &[u8]) -> Result<Paired, PairingError> {
        let (&step, sealed) = p4.split_first().ok_or(PairingError::Malformed)?;
        if step != 0x04 {
            return Err(PairingError::Malformed);
        }
        let th = self.keys.th;
        let expected = mac::<B>(&self.keys.conf_b[..], b"P4", &[&th])?;
        let peer = open_card::<B>(0x04, sealed, &self.keys.card_b, &th, &expected)?;
        Ok(self.keys.into_paired(PairingRole::A, self.nonce_b, peer))
    }
}

/// B after sending P2.
pub(crate) struct AwaitingP3 {
    shared: Zeroizing<[u8; 32]>,
    commitment: [u8; 32],
    nonce_b: [u8; NONCE_LEN],
    p1_p2: Vec<u8>,
    card: Card,
}

impl AwaitingP3 {
    /// Checks P1's version and mode, encapsulates to `ek_A` and returns P2.
    pub(crate) fn receive_p1<B: CryptoBackend>(
        card: Card,
        p1: &[u8],
    ) -> Result<(Self, Vec<u8>), PairingError> {
        if p1.len() != P1_LEN || p1[0] != 0x01 {
            return Err(PairingError::Malformed);
        }
        if p1[1] != VERSION {
            return Err(PairingError::Version);
        }
        if p1[2] != MODE_TOFU {
            return Err(PairingError::Mode);
        }
        let commitment: [u8; 32] = p1[3..35].try_into().map_err(|_| PairingError::Malformed)?;
        let public: &[u8; XWING_ENCAPSULATION_KEY_LEN] =
            p1[35..].try_into().map_err(|_| PairingError::Malformed)?;
        let (ciphertext, shared) = B::xwing_encapsulate(public)?;
        let nonce_b = *random::<B, NONCE_LEN>()?;
        let mut p2 = Vec::with_capacity(P2_LEN);
        p2.push(0x02);
        p2.extend_from_slice(&ciphertext);
        p2.extend_from_slice(&nonce_b);
        let mut p1_p2 = Vec::with_capacity(P1_LEN + P2_LEN);
        p1_p2.extend_from_slice(p1);
        p1_p2.extend_from_slice(&p2);
        let state = Self {
            shared,
            commitment,
            nonce_b,
            p1_p2,
            card,
        };
        Ok((state, p2))
    }

    /// Checks the commitment and `confirm_A`, then returns the contact and P4.
    pub(crate) fn receive_p3<B: CryptoBackend>(
        self,
        p3: &[u8],
    ) -> Result<(Paired, Vec<u8>), PairingError> {
        if p3.first() != Some(&0x03) {
            return Err(PairingError::Malformed);
        }
        let (nonce_a, sealed) = p3[1..]
            .split_first_chunk::<NONCE_LEN>()
            .ok_or(PairingError::Malformed)?;
        if commit::<B>(nonce_a) != self.commitment {
            return Err(PairingError::Commitment);
        }
        let th = hash::<B>(&[&self.p1_p2, nonce_a]);
        let keys = Keys::derive::<B>(&self.shared[..], th)?;
        let expected = mac::<B>(&keys.conf_a[..], b"P3", &[&th])?;
        let peer = open_card::<B>(0x03, sealed, &keys.card_a, &th, &expected)?;
        let confirm = mac::<B>(&keys.conf_b[..], b"P4", &[&th])?;
        let p4 = seal_card::<B>(0x04, &[], &keys.card_b, &th, &confirm, &self.card)?;
        Ok((keys.into_paired(PairingRole::B, self.nonce_b, peer), p4))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use cairn_crypto::Reference;

    fn card(name: &str, key: u8) -> Card {
        Card {
            caps: 0,
            beacon_day: 20_384,
            beacon_key: Zeroizing::new([key; 32]),
            name: name.into(),
            static_ek: None,
        }
    }

    struct Run {
        frames: [Vec<u8>; 4],
        a: Paired,
        b: Paired,
    }

    fn run() -> Run {
        let (a, p1) = AwaitingP2::start::<Reference>(card("", 0xaa)).unwrap();
        let (b, p2) = AwaitingP3::receive_p1::<Reference>(card("", 0xbb), &p1).unwrap();
        let (a, p3) = a.receive_p2::<Reference>(&p2).unwrap();
        let (b, p4) = b.receive_p3::<Reference>(&p3).unwrap();
        let a = a.receive_p4::<Reference>(&p4).unwrap();
        Run {
            frames: [p1, p2, p3, p4],
            a,
            b,
        }
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn both_roles_derive_the_same_contact_secrets() {
        let Run { a, b, .. } = run();

        assert_eq!((a.role, b.role), (PairingRole::A, PairingRole::B));
        assert_eq!(a.pair_id, b.pair_id);
        assert_eq!(a.chain_key, b.chain_key);
        assert_eq!(a.door_a_to_b, b.door_a_to_b);
        assert_eq!(a.door_b_to_a, b.door_b_to_a);
        assert_ne!(a.door_a_to_b, a.door_b_to_a);
        assert_eq!((a.th, a.nonce_b), (b.th, b.nonce_b));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn each_role_learns_the_other_card() {
        let Run { a, b, .. } = run();

        assert_eq!(a.peer, card("", 0xbb));
        assert_eq!(b.peer, card("", 0xaa));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn frames_have_the_spec_sizes_for_an_empty_name() {
        let Run { frames, .. } = run();

        assert_eq!(frames.each_ref().map(Vec::len), [1251, 1137, 87, 71]);
        assert_eq!(frames.each_ref().map(|frame| frame[0]), [1, 2, 3, 4]);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn b_aborts_on_a_foreign_version_or_retired_mode() {
        let (_, p1) = AwaitingP2::start::<Reference>(card("", 1)).unwrap();
        let mutate = |index: usize, value: u8| {
            let mut frame = p1.clone();
            frame[index] = value;
            AwaitingP3::receive_p1::<Reference>(card("", 2), &frame).err()
        };

        let errors = [
            mutate(1, 0x02),
            mutate(2, 0x01),
            mutate(2, 0x02),
            AwaitingP3::receive_p1::<Reference>(card("", 2), &p1[..1250]).err(),
        ];

        assert_eq!(
            errors,
            [
                Some(PairingError::Version),
                Some(PairingError::Mode),
                Some(PairingError::Mode),
                Some(PairingError::Malformed),
            ]
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn b_aborts_when_na_does_not_open_the_commitment() {
        let (a, p1) = AwaitingP2::start::<Reference>(card("", 1)).unwrap();
        let (b, p2) = AwaitingP3::receive_p1::<Reference>(card("", 2), &p1).unwrap();
        let (_, mut p3) = a.receive_p2::<Reference>(&p2).unwrap();
        p3[1] ^= 1;

        let result = b.receive_p3::<Reference>(&p3).err();

        assert_eq!(result, Some(PairingError::Commitment));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn tampered_cards_fail_authentication_on_both_sides() {
        let (a, p1) = AwaitingP2::start::<Reference>(card("", 1)).unwrap();
        let (b, p2) = AwaitingP3::receive_p1::<Reference>(card("", 2), &p1).unwrap();
        let (a, p3) = a.receive_p2::<Reference>(&p2).unwrap();
        let mut tampered_p3 = p3.clone();
        *tampered_p3.last_mut().unwrap() ^= 1;
        let b_tampered = AwaitingP3 {
            shared: b.shared.clone(),
            commitment: b.commitment,
            nonce_b: b.nonce_b,
            p1_p2: b.p1_p2.clone(),
            card: b.card.clone(),
        };
        let (_, mut p4) = b.receive_p3::<Reference>(&p3).unwrap();
        p4[20] ^= 1;

        let results = [
            b_tampered.receive_p3::<Reference>(&tampered_p3).err(),
            a.receive_p4::<Reference>(&p4).err(),
        ];

        assert_eq!(results, [Some(PairingError::Authentication); 2]);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_wrong_confirmation_under_valid_aead_is_rejected() {
        let (a, p1) = AwaitingP2::start::<Reference>(card("", 1)).unwrap();
        let (b, p2) = AwaitingP3::receive_p1::<Reference>(card("", 2), &p1).unwrap();
        let (a, _) = a.receive_p2::<Reference>(&p2).unwrap();
        let th = a.keys.th;
        let wrong = mac::<Reference>(&a.keys.conf_b[..], b"P3", &[&th]).unwrap();
        let p4 =
            seal_card::<Reference>(0x04, &[], &a.keys.card_b, &th, &wrong, &card("", 2)).unwrap();
        drop(b);

        let result = a.receive_p4::<Reference>(&p4).err();

        assert_eq!(result, Some(PairingError::Authentication));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_rejects_a_p2_of_the_wrong_length() {
        let (a, p1) = AwaitingP2::start::<Reference>(card("", 1)).unwrap();
        let (_, p2) = AwaitingP3::receive_p1::<Reference>(card("", 2), &p1).unwrap();

        let result = a.receive_p2::<Reference>(&p2[..P2_LEN - 1]).err();

        assert_eq!(result, Some(PairingError::Malformed));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn frames_with_the_wrong_step_byte_are_malformed() {
        let wrong_step = |frame: &[u8]| {
            let mut frame = frame.to_vec();
            frame[0] ^= 0x07;
            frame
        };
        let (a, p1) = AwaitingP2::start::<Reference>(card("", 1)).unwrap();
        let (other_a, _) = AwaitingP2::start::<Reference>(card("", 1)).unwrap();
        let (b, p2) = AwaitingP3::receive_p1::<Reference>(card("", 2), &p1).unwrap();
        let (a, p3) = a.receive_p2::<Reference>(&p2).unwrap();

        let results = [
            AwaitingP3::receive_p1::<Reference>(card("", 2), &wrong_step(&p1)).err(),
            other_a.receive_p2::<Reference>(&wrong_step(&p2)).err(),
            b.receive_p3::<Reference>(&wrong_step(&p3)).err(),
            a.receive_p4::<Reference>(&p3).err(),
        ];

        assert_eq!(results, [Some(PairingError::Malformed); 4]);
    }
}
