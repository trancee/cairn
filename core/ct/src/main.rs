use cairn_crypto::{AwsLc, CryptoBackend, Reference};
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
        Some("aws-lc") => check::<AwsLc>(),
        Some("reference") => check::<Reference>(),
        _ => panic!("expected aws-lc, reference, negative-control or negative-index"),
    }
}
