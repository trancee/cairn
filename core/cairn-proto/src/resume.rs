//! Basic Resume S1/S2 without KCI or PQ mixing (spec §6).

use crate::epoch::PairingRole;
use crate::kdf::{hash, kdf, mac, tag};
use cairn_crypto::{CryptoBackend, CryptoError, X25519_KEY_LEN, X25519SecretKey};
use subtle::{ConditionallySelectable, ConstantTimeEq};
use zeroize::Zeroizing;

pub(crate) const S1_LEN: usize = 57;
pub(crate) const S2_LEN: usize = 49;
const S1_HEADER: u8 = 0x10;
const S2_HEADER: u8 = 0x20;
/// Retries after the third reuse attempt 3 (OI-8).
pub(crate) const MAX_ATTEMPT: u8 = 3;

/// One chain key candidate `CK_n` of a contact.
pub(crate) struct Chain<'a> {
    pub(crate) pair_id: &'a [u8; 16],
    pub(crate) n: u64,
    pub(crate) ck: &'a [u8; 32],
}

/// The keys of an established session and the next chain key.
pub(crate) struct Keys {
    pub(crate) i_to_r: Zeroizing<[u8; 32]>,
    pub(crate) r_to_i: Zeroizing<[u8; 32]>,
    /// `CK_{n+1}`.
    pub(crate) next_ck: Zeroizing<[u8; 32]>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ResumeError {
    /// Wrong length or header, or a low-order X25519 share.
    Malformed,
    /// The S2 confirmation did not verify.
    Authentication,
    /// The local backend failed.
    Crypto(CryptoError),
}

/// An all-zero X25519 output is the peer's fault; anything else is local.
impl From<CryptoError> for ResumeError {
    fn from(error: CryptoError) -> Self {
        match error {
            CryptoError::ZeroSharedSecret => Self::Malformed,
            other => Self::Crypto(other),
        }
    }
}

/// I after sending S1, waiting for S2.
pub(crate) struct Initiator {
    s1: [u8; S1_LEN],
    ephemeral: X25519SecretKey,
    ck: Zeroizing<[u8; 32]>,
    ctx: [u8; 24],
}

impl Initiator {
    /// Builds S1 on `chain`; `role` is I's own pairing role `ρ_I`.
    pub(crate) fn start<B: CryptoBackend>(
        chain: &Chain<'_>,
        role: PairingRole,
        attempt: u8,
    ) -> Result<(Self, [u8; S1_LEN]), CryptoError> {
        let (ephemeral, public) = B::x25519_generate()?;
        let mut s1 = [0; S1_LEN];
        s1[0] = S1_HEADER;
        s1[1..9].copy_from_slice(&pseudonym::<B>(chain, role, attempt)?);
        s1[9..41].copy_from_slice(&public);
        let auth_i = auth_i::<B>(chain, role)?;
        let tag = mac::<B>(&auth_i[..], b"S1", &[&s1[..41]])?;
        s1[41..].copy_from_slice(&tag);
        let initiator = Self {
            s1,
            ephemeral,
            ck: Zeroizing::new(*chain.ck),
            ctx: ctx(chain),
        };
        Ok((initiator, s1))
    }

    /// Verifies S2 and derives the session keys.
    pub(crate) fn receive_s2<B: CryptoBackend>(self, s2: &[u8]) -> Result<Keys, ResumeError> {
        if s2.len() != S2_LEN || s2[0] != S2_HEADER {
            return Err(ResumeError::Malformed);
        }
        let e_r: &[u8; X25519_KEY_LEN] = s2[1..33].try_into().expect("S2 length is checked");
        let th_s = hash::<B>(&[&self.s1, e_r]);
        let auth_r = kdf::<B, 32>(&self.ck[..], &[], b"auth R", &[&self.ctx])?;
        let confirm = mac::<B>(&auth_r[..], b"S2", &[&s2[..1], &th_s])?;
        if !bool::from(confirm.ct_eq(&s2[33..])) {
            return Err(ResumeError::Authentication);
        }
        let dh = B::x25519(&self.ephemeral, e_r)?;
        derive::<B>(&self.ck, &self.ctx, &dh[..], &th_s)
    }
}

/// `Trunc8(HMAC(K_id, lp("cairn-r1 pseudonym") ‖ u8(attempt)))` for I with pairing role `initiator`.
pub(crate) fn pseudonym<B: CryptoBackend>(
    chain: &Chain<'_>,
    initiator: PairingRole,
    attempt: u8,
) -> Result<[u8; 8], CryptoError> {
    let label = [b"id ".as_slice(), role_label(initiator)].concat();
    let k_id = kdf::<B, 32>(chain.ck, &[], &label, &[&ctx(chain)])?;
    tag::<B, 8>(&k_id[..], b"pseudonym", &[&[attempt]])
}

/// The index of the first candidate whose pseudonym for any attempt 0–3
/// equals `read`, compared in constant time over every candidate and attempt.
pub(crate) fn find<'a, B: CryptoBackend>(
    candidates: impl IntoIterator<Item = (Chain<'a>, PairingRole)>,
    read: &[u8; 8],
) -> Result<Option<usize>, CryptoError> {
    let mut found = 0u64;
    let mut hit = subtle::Choice::from(0);
    for (index, (chain, initiator)) in (0u64..).zip(candidates) {
        for attempt in 0..=MAX_ATTEMPT {
            let matches = pseudonym::<B>(&chain, initiator, attempt)?.ct_eq(read) & !hit;
            found.conditional_assign(&index, matches);
            hit |= matches;
        }
    }
    Ok(bool::from(hit).then(|| usize::try_from(found).expect("indices fit usize")))
}

/// R's answer to an S1 already matched to `chain`: checks the MAC before any
/// asymmetric operation, then builds S2 and the session keys.
pub(crate) fn respond<B: CryptoBackend>(
    chain: &Chain<'_>,
    initiator: PairingRole,
    s1: &[u8],
) -> Result<(Keys, [u8; S2_LEN]), ResumeError> {
    if s1_pseudonym(s1).is_none() {
        return Err(ResumeError::Malformed);
    }
    let auth_i = auth_i::<B>(chain, initiator)?;
    let expected = mac::<B>(&auth_i[..], b"S1", &[&s1[..41]])?;
    if !bool::from(expected.ct_eq(&s1[41..])) {
        return Err(ResumeError::Authentication);
    }
    let e_i: &[u8; X25519_KEY_LEN] = s1[9..41].try_into().expect("S1 length is checked");
    let (ephemeral, e_r) = B::x25519_generate()?;
    let dh = B::x25519(&ephemeral, e_i)?;
    let context = ctx(chain);
    let th_s = hash::<B>(&[s1, &e_r]);
    let auth_r = kdf::<B, 32>(chain.ck, &[], b"auth R", &[&context])?;
    let mut s2 = [0; S2_LEN];
    s2[0] = S2_HEADER;
    s2[1..33].copy_from_slice(&e_r);
    let confirm = mac::<B>(&auth_r[..], b"S2", &[&[S2_HEADER], &th_s])?;
    s2[33..].copy_from_slice(&confirm);
    Ok((derive::<B>(chain.ck, &context, &dh[..], &th_s)?, s2))
}

/// The pseudonym in a well-formed S1.
pub(crate) fn s1_pseudonym(s1: &[u8]) -> Option<[u8; 8]> {
    (s1.len() == S1_LEN && s1[0] == S1_HEADER)
        .then(|| s1[1..9].try_into().expect("S1 length is checked"))
}

fn role_label(role: PairingRole) -> &'static [u8] {
    match role {
        PairingRole::A => b"A",
        PairingRole::B => b"B",
    }
}

/// `ctx(n) = pairID ‖ u64(n)`.
fn ctx(chain: &Chain<'_>) -> [u8; 24] {
    let mut context = [0; 24];
    context[..16].copy_from_slice(chain.pair_id);
    context[16..].copy_from_slice(&chain.n.to_be_bytes());
    context
}

fn auth_i<B: CryptoBackend>(
    chain: &Chain<'_>,
    initiator: PairingRole,
) -> Result<Zeroizing<[u8; 32]>, CryptoError> {
    let label = [b"auth I ".as_slice(), role_label(initiator)].concat();
    kdf::<B, 32>(chain.ck, &[], &label, &[&ctx(chain)])
}

/// `prk = HKDF-Extract(CK_n, dh)`, expanded to `SK_I→R`, `SK_R→I` and `CK_{n+1}`.
fn derive<B: CryptoBackend>(
    ck: &[u8; 32],
    context: &[u8; 24],
    dh: &[u8],
    th_s: &[u8; 48],
) -> Result<Keys, ResumeError> {
    let expand = |label: &[u8]| kdf::<B, 32>(dh, ck, label, &[context, th_s]);
    Ok(Keys {
        i_to_r: expand(b"sk I")?,
        r_to_i: expand(b"sk R")?,
        next_ck: expand(b"ratchet")?,
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn only_a_zero_shared_secret_is_the_peers_fault() {
        let errors = [CryptoError::ZeroSharedSecret, CryptoError::BackendFailure];

        let classified = errors.map(ResumeError::from);

        assert_eq!(
            classified,
            [
                ResumeError::Malformed,
                ResumeError::Crypto(CryptoError::BackendFailure)
            ]
        );
    }

    use super::*;
    use cairn_crypto::Reference;

    const PAIR_ID: [u8; 16] = [1; 16];
    const CK: [u8; 32] = [2; 32];

    fn chain() -> Chain<'static> {
        Chain {
            pair_id: &PAIR_ID,
            n: 7,
            ck: &CK,
        }
    }

    fn ctx() -> std::vec::Vec<u8> {
        [&PAIR_ID[..], &7u64.to_be_bytes()].concat()
    }

    fn labelled(label: &[u8]) -> std::vec::Vec<u8> {
        let mut output = std::vec![0, 9 + label.len() as u8];
        output.extend_from_slice(b"cairn-r1 ");
        output.extend_from_slice(label);
        output
    }

    fn resumed() -> (Keys, Keys, [u8; S1_LEN], [u8; S2_LEN]) {
        let (initiator, s1) = Initiator::start::<Reference>(&chain(), PairingRole::B, 0).unwrap();
        let (r_keys, s2) = respond::<Reference>(&chain(), PairingRole::B, &s1).unwrap();
        let i_keys = initiator.receive_s2::<Reference>(&s2).unwrap();
        (i_keys, r_keys, s1, s2)
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn both_sides_derive_the_same_session_and_next_chain_keys() {
        let (i, r, _, _) = resumed();

        assert_eq!(i.i_to_r, r.i_to_r);
        assert_eq!(i.r_to_i, r.r_to_i);
        assert_eq!(i.next_ck, r.next_ck);
        assert_ne!(i.i_to_r, i.r_to_i);
        assert_ne!(*i.next_ck, CK);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn s1_and_s2_have_the_spec_layout() {
        let (_, _, s1, s2) = resumed();
        let pseudonym = pseudonym::<Reference>(&chain(), PairingRole::B, 0).unwrap();
        let auth_i = kdf::<Reference, 32>(&CK, &[], b"auth I B", &[&ctx()]).unwrap();
        let auth_r = kdf::<Reference, 32>(&CK, &[], b"auth R", &[&ctx()]).unwrap();
        let th_s = Reference::sha384(&[&s1[..], &s2[1..33]].concat());

        assert_eq!((s1[0], &s1[1..9]), (0x10, &pseudonym[..]));
        assert_eq!(
            s1[41..],
            mac::<Reference>(&auth_i[..], b"S1", &[&s1[..41]]).unwrap()
        );
        assert_eq!(s2[0], 0x20);
        assert_eq!(
            s2[33..],
            mac::<Reference>(&auth_r[..], b"S2", &[&s2[..1], &th_s]).unwrap()
        );
        assert_eq!(s1_pseudonym(&s1), Some(pseudonym));
    }

    #[test]
    fn the_pseudonym_is_the_truncated_hmac_under_k_id() {
        let k_id = kdf::<Reference, 32>(&CK, &[], b"id A", &[&ctx()]).unwrap();
        let mut input = labelled(b"pseudonym");
        input.push(2);

        let pseudonym = pseudonym::<Reference>(&chain(), PairingRole::A, 2).unwrap();

        assert_eq!(
            pseudonym[..],
            Reference::hmac_sha384(&k_id[..], &input).unwrap()[..8]
        );
    }

    #[test]
    fn find_matches_every_attempt_up_to_three_with_the_initiator_role() {
        let other_ck = [3; 32];
        let candidates = || {
            [
                (
                    Chain {
                        ck: &other_ck,
                        ..chain()
                    },
                    PairingRole::A,
                ),
                (chain(), PairingRole::A),
            ]
        };
        let read = |role, attempt| pseudonym::<Reference>(&chain(), role, attempt).unwrap();

        let found = [
            (PairingRole::A, 0),
            (PairingRole::A, 3),
            (PairingRole::A, 4),
            (PairingRole::B, 0),
        ]
        .map(|(role, attempt)| find::<Reference>(candidates(), &read(role, attempt)).unwrap());

        assert_eq!(found, [Some(1), Some(1), None, None]);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn the_session_keys_follow_the_spec_schedule() {
        let (initiator, s1) = Initiator::start::<Reference>(&chain(), PairingRole::A, 0).unwrap();
        let ephemeral = X25519SecretKey::from_bytes(&[4; 32]);
        let mut base = [0; 32];
        base[0] = 9;
        let e_i: [u8; 32] = s1[9..41].try_into().unwrap();
        let dh = Reference::x25519(&ephemeral, &e_i).unwrap();
        let e_r = *Reference::x25519(&ephemeral, &base).unwrap();
        let th_s = Reference::sha384(&[&s1[..], &e_r].concat());
        let expand = |label: &[u8]| {
            let info = [&labelled(label)[..], &ctx(), &th_s].concat();
            Reference::hkdf_sha384(&dh[..], &CK, &info, 32).unwrap()
        };
        let auth_r = kdf::<Reference, 32>(&CK, &[], b"auth R", &[&ctx()]).unwrap();
        let mut s2 = std::vec![0x20];
        s2.extend_from_slice(&e_r);
        s2.extend_from_slice(&mac::<Reference>(&auth_r[..], b"S2", &[&[0x20], &th_s]).unwrap());

        let keys = initiator.receive_s2::<Reference>(&s2).unwrap();

        assert_eq!(keys.i_to_r[..], expand(b"sk I")[..]);
        assert_eq!(keys.r_to_i[..], expand(b"sk R")[..]);
        assert_eq!(keys.next_ck[..], expand(b"ratchet")[..]);
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_tampered_s1_is_rejected_before_any_key_agreement() {
        let (_, s1) = Initiator::start::<Reference>(&chain(), PairingRole::B, 0).unwrap();
        let mut tampered = s1;
        tampered[20] ^= 1;

        let results = [
            respond::<Reference>(&chain(), PairingRole::B, &tampered).err(),
            respond::<Reference>(&chain(), PairingRole::A, &s1).err(),
            respond::<Reference>(&chain(), PairingRole::B, &s1[..56]).err(),
        ];

        assert_eq!(
            results,
            [
                Some(ResumeError::Authentication),
                Some(ResumeError::Authentication),
                Some(ResumeError::Malformed),
            ]
        );
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_low_order_initiator_share_is_malformed() {
        let auth_i = kdf::<Reference, 32>(&CK, &[], b"auth I B", &[&ctx()]).unwrap();
        let mut s1 = std::vec![0x10];
        s1.extend_from_slice(&pseudonym::<Reference>(&chain(), PairingRole::B, 0).unwrap());
        s1.extend_from_slice(&[0; 32]);
        let tag = mac::<Reference>(&auth_i[..], b"S1", &[&s1]).unwrap();
        s1.extend_from_slice(&tag);

        let result = respond::<Reference>(&chain(), PairingRole::B, &s1).err();

        assert_eq!(result, Some(ResumeError::Malformed));
    }

    #[test]
    #[cfg_attr(miri, ignore = "RNG and key generation run under careful (ADR 0007)")]
    fn a_bad_s2_is_rejected() {
        let s2 = |edit: fn(&[u8], &mut std::vec::Vec<u8>)| {
            let (initiator, s1) =
                Initiator::start::<Reference>(&chain(), PairingRole::B, 0).unwrap();
            let (_, s2) = respond::<Reference>(&chain(), PairingRole::B, &s1).unwrap();
            let mut s2 = s2.to_vec();
            edit(&s1, &mut s2);
            initiator.receive_s2::<Reference>(&s2).err()
        };

        let results = [
            s2(|_, s2| s2[48] ^= 1),
            s2(|_, s2| s2[0] = 0x21),
            s2(|_, s2| {
                s2.pop();
            }),
            s2(|s1, s2| {
                s2[1..33].fill(0);
                let th_s = Reference::sha384(&[s1, &s2[1..33]].concat());
                let auth_r = kdf::<Reference, 32>(&CK, &[], b"auth R", &[&ctx()]).unwrap();
                let confirm = mac::<Reference>(&auth_r[..], b"S2", &[&[0x20], &th_s]).unwrap();
                s2[33..].copy_from_slice(&confirm);
            }),
        ];

        assert_eq!(
            results,
            [
                Some(ResumeError::Authentication),
                Some(ResumeError::Malformed),
                Some(ResumeError::Malformed),
                Some(ResumeError::Malformed),
            ]
        );
    }

    #[test]
    fn s1_pseudonym_requires_the_s1_layout() {
        let mut s1 = [0; S1_LEN];
        s1[0] = 0x10;
        s1[1..9].copy_from_slice(&[6; 8]);

        let read = [
            s1_pseudonym(&s1),
            s1_pseudonym(&s1[..56]),
            s1_pseudonym(&[[0x11].as_slice(), &s1[1..]].concat()),
        ];

        assert_eq!(read, [Some([6; 8]), None, None]);
    }
}
