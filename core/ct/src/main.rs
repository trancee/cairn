use cairn_crypto::{
    AES256GCM_KEY_LEN, AES256GCM_NONCE_LEN, AwsLc, CryptoBackend, MLKEM768_CIPHERTEXT_LEN,
    MLKEM768_DECAPSULATION_KEY_LEN, MlKem768DecapsulationKey, Reference,
};
use cairn_proto::PairingRole;
use cairn_proto::probes::{self, Candidate};
use crabgrind::memcheck::{MemState, mark_memory, vbits};

fn mark(bytes: &[u8], state: MemState) {
    mark_memory(bytes.as_ptr().cast(), bytes.len(), state).expect("Valgrind is required");
}

fn require_taint(bytes: &[u8]) {
    let mut shadow = vec![0; bytes.len()];
    vbits(bytes.as_ptr().cast(), &mut shadow).expect("cannot inspect Memcheck shadow state");
    assert!(
        shadow.iter().any(|bits| *bits != 0),
        "secret taint did not reach the cryptographic output"
    );
}

fn check<B: CryptoBackend>() {
    for length in [0, 1, 47, 48, 49, 127, 128, 129, 256] {
        let input = vec![0x36; length];
        let key = vec![0x5c; length];
        let salt = [0xa5; 48];
        mark(&input, MemState::Undefined);
        mark(&key, MemState::Undefined);
        mark(&salt, MemState::Undefined);
        let input = std::hint::black_box(input.as_slice());
        let key = std::hint::black_box(key.as_slice());
        let salt = std::hint::black_box(salt.as_slice());

        let digest = B::sha384(input);
        std::hint::black_box(&digest);
        let tag = B::hmac_sha384(key, input).expect("HMAC failed");
        std::hint::black_box(&tag);
        if length != 0 {
            require_taint(&digest);
            require_taint(&tag[..]);
        }
        for output_length in [0, 1, 47, 48, 49, 128, 255 * 48] {
            for selected_salt in [salt, &[][..]] {
                let output =
                    B::hkdf_sha384(input, selected_salt, b"cairn-ct fixture", output_length)
                        .expect("HKDF failed");
                std::hint::black_box(&output);
                if output_length != 0 && (length != 0 || !selected_salt.is_empty()) {
                    require_taint(&output);
                }
            }
        }
    }
}

/// AES-256-GCM sealing under a secret key and plaintext.
///
/// Opening is not checked: both providers branch on the constant-time tag comparison
/// verdict, a public-by-design result that Memcheck cannot declassify inside the library.
fn check_aead<B: CryptoBackend>() {
    for length in [0, 1, 15, 16, 17, 64, 255] {
        let key = [0x11; AES256GCM_KEY_LEN];
        let plaintext = vec![0x22; length];
        mark(&key, MemState::Undefined);
        mark(&plaintext, MemState::Undefined);
        let sealed = B::aes256gcm_seal(
            std::hint::black_box(&key),
            &[0x33; AES256GCM_NONCE_LEN],
            b"cairn-ct aad",
            std::hint::black_box(&plaintext),
        )
        .expect("AES-GCM sealing failed");
        std::hint::black_box(&sealed);
        require_taint(&sealed);
    }
}

/// Marks `dk_PKE` and `z`; `ek` and `H(ek)` are public inputs to the FIPS 203 §7.3 check.
fn mark_mlkem768_secret_key(key: &[u8]) {
    mark(&key[..1152], MemState::Undefined);
    mark(
        &key[2368..MLKEM768_DECAPSULATION_KEY_LEN],
        MemState::Undefined,
    );
}

/// Decapsulation of valid and implicitly rejected ciphertexts.
///
/// The X25519 scalar stays defined: cairn-r1 mandates aborting on an all-zero X25519 output,
/// a public-by-design branch that Memcheck cannot declassify without instrumenting the library.
fn check_kem<B: CryptoBackend>() {
    let (public, key) = Reference::mlkem768_generate_deterministic(&[1; 32], &[2; 32]);
    let (ciphertext, _) = Reference::mlkem768_encapsulate_deterministic(&public, &[3; 32])
        .expect("ML-KEM encapsulation failed");
    let key = MlKem768DecapsulationKey::from_bytes(key.as_bytes());
    mark_mlkem768_secret_key(key.as_bytes());
    let mut tampered = ciphertext;
    tampered[MLKEM768_CIPHERTEXT_LEN - 1] ^= 1;
    for ciphertext in [ciphertext, tampered] {
        let secret = B::mlkem768_decapsulate(&key, std::hint::black_box(&ciphertext))
            .expect("ML-KEM decapsulation failed");
        std::hint::black_box(&secret);
        require_taint(&secret[..]);
    }

    let (public, key) = Reference::xwing_generate_deterministic(&[4; 32]);
    let (ciphertext, _) = Reference::xwing_encapsulate_deterministic(&public, &[5; 64])
        .expect("X-Wing encapsulation failed");
    mark_mlkem768_secret_key(key.as_bytes());
    let mut tampered = ciphertext;
    tampered[0] ^= 1;
    for ciphertext in [ciphertext, tampered] {
        let secret = B::xwing_decapsulate(&key, std::hint::black_box(&ciphertext))
            .expect("X-Wing decapsulation failed");
        std::hint::black_box(&secret);
        require_taint(&secret[..]);
    }
}

/// Encapsulation from a secret ML-KEM message; the X25519 ephemeral stays defined as above.
fn check_reference_encapsulation() {
    let (public, _) = Reference::xwing_generate_deterministic(&[6; 32]);
    let (ml_kem_public, _) = Reference::mlkem768_generate_deterministic(&[7; 32], &[8; 32]);
    let message = [9; 32];
    let mut seed = [10; 64];
    mark(&message, MemState::Undefined);
    mark(&seed[..32], MemState::Undefined);
    seed = std::hint::black_box(seed);
    let (ciphertext, secret) = Reference::mlkem768_encapsulate_deterministic(
        &ml_kem_public,
        std::hint::black_box(&message),
    )
    .expect("ML-KEM encapsulation failed");
    std::hint::black_box((&ciphertext, &secret));
    require_taint(&ciphertext);
    require_taint(&secret[..]);
    let (ciphertext, secret) = Reference::xwing_encapsulate_deterministic(&public, &seed)
        .expect("X-Wing encapsulation failed");
    std::hint::black_box((&ciphertext, &secret));
    require_taint(&ciphertext);
    require_taint(&secret[..]);
}

/// The protocol's secret comparisons: beacon and pseudonym search, the Resume
/// S1 and S2 MACs, the P3/P4 confirmation and DATA padding (ADR 0022).
///
/// Each verdict and found index must still carry the secret's taint: none was
/// branched on or declassified before the caller's single `bool::from`.
fn check_proto<B: CryptoBackend>() {
    const NOW: u64 = 1_800_000_000;
    let today = u32::try_from(NOW / 86_400).expect("the day fits u32");
    let keys = [(today - 2, [0x41; 32]), (today, [0x42; 32])];
    let hit = probes::beacon::<B>(today, &[0x42; 32], NOW / 300 + 1).expect("beacon failed");
    for (_, key) in &keys {
        mark(key, MemState::Undefined);
    }
    for read in [hit, [0; 8]] {
        let (verdict, index) = probes::beacon_match::<B>(std::hint::black_box(&keys), NOW, &read)
            .expect("beacon match failed");
        std::hint::black_box((verdict, index));
        require_taint(&[verdict]);
        require_taint(&index.to_ne_bytes());
    }

    let candidate = |byte: u8, initiator| Candidate {
        pair_id: [byte; 16],
        n: u64::from(byte),
        ck: [byte ^ 0x5a; 32],
        initiator,
    };
    let candidates = [candidate(1, PairingRole::A), candidate(2, PairingRole::B)];
    let hit = probes::pseudonym::<B>(&candidates[1], 3).expect("pseudonym failed");
    let (s1, s2) = probes::resume::<B>(&candidates[1], 0);
    let (mut forged_s1, mut forged_s2) = (s1, s2);
    forged_s1[56] ^= 1;
    forged_s2[48] ^= 1;
    for candidate in &candidates {
        mark(&candidate.ck, MemState::Undefined);
    }
    let candidates = std::hint::black_box(&candidates);
    for read in [hit, [0; 8]] {
        let (verdict, index) =
            probes::pseudonym_match::<B>(candidates, &read).expect("pseudonym match failed");
        std::hint::black_box((verdict, index));
        require_taint(&[verdict]);
        require_taint(&index.to_ne_bytes());
    }
    for s1 in [s1, forged_s1] {
        let verdict = probes::s1_authentic::<B>(&candidates[1], &s1).expect("S1 check failed");
        require_taint(&[std::hint::black_box(verdict)]);
    }
    for s2 in [s2, forged_s2] {
        let verdict = probes::s2_authentic::<B>(&candidates[1], &s1, &s2).expect("S2 check failed");
        require_taint(&[std::hint::black_box(verdict)]);
    }
}

/// The P3/P4 confirmation and DATA padding checks, which use no backend.
fn check_proto_comparisons() {
    let expected = [0x77; 16];
    mark(&expected, MemState::Undefined);
    for confirm in [[0x77; 16], [0x78; 16]] {
        let verdict = probes::card_confirmed(&confirm, std::hint::black_box(&expected));
        require_taint(&[std::hint::black_box(verdict)]);
    }
    for length in [1, 31, 4078] {
        for last in [0, 1] {
            let mut padding = vec![0; length];
            padding[length - 1] = last;
            mark(&padding, MemState::Undefined);
            let verdict = probes::padding_is_zero(std::hint::black_box(&padding));
            require_taint(&[std::hint::black_box(verdict)]);
        }
    }
}

fn main() {
    assert!(
        crabgrind::valgrind::running_mode().is_valgrind(),
        "run this harness under Valgrind Memcheck"
    );
    match std::env::args().nth(1).as_deref() {
        Some("negative-control") => {
            let secret = [0x42];
            mark(&secret, MemState::Undefined);
            // Keep the intentionally leaking branch observable to the optimizer.
            if std::hint::black_box(&secret)[0] == 0x42 {
                println!("negative control branch taken");
            }
        }
        Some("negative-index") => {
            let secret = [1_u8];
            let table = [0x36, 0x5c];
            mark(&secret, MemState::Undefined);
            let index = usize::from(std::hint::black_box(&secret)[0]);
            std::hint::black_box(std::hint::black_box(&table)[index]);
        }
        Some("aws-lc") => {
            check::<AwsLc>();
            check_kem::<AwsLc>();
            check_aead::<AwsLc>();
            check_proto::<AwsLc>();
            check_proto_comparisons();
        }
        Some("reference") => {
            check::<Reference>();
            check_kem::<Reference>();
            check_aead::<Reference>();
            check_reference_encapsulation();
            check_proto::<Reference>();
            check_proto_comparisons();
        }
        _ => panic!("expected aws-lc, reference, negative-control or negative-index"),
    }
}
