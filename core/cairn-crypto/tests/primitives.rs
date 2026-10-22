use cairn_crypto::{
    AES256GCM_KEY_LEN, AES256GCM_NONCE_LEN, AES256GCM_TAG_LEN, CryptoBackend, CryptoError,
    X25519_KEY_LEN, X25519SecretKey,
};
use serde_json::Value;

const BASEPOINT: [u8; 32] = {
    let mut point = [0; 32];
    point[0] = 9;
    point
};

fn hex(text: &str) -> Vec<u8> {
    assert_eq!(text.len() % 2, 0);
    (0..text.len())
        .step_by(2)
        .map(|offset| u8::from_str_radix(&text[offset..offset + 2], 16).unwrap())
        .collect()
}

fn bytes(value: &Value) -> Vec<u8> {
    hex(value.as_str().unwrap())
}

fn array<const N: usize>(value: &Value) -> [u8; N] {
    bytes(value).try_into().unwrap()
}

fn wycheproof(corpus: &str) -> Value {
    serde_json::from_str(corpus).unwrap()
}

fn cases(corpus: &Value) -> impl Iterator<Item = (&Value, &Value)> {
    corpus["testGroups"]
        .as_array()
        .unwrap()
        .iter()
        .flat_map(|group| {
            group["tests"]
                .as_array()
                .unwrap()
                .iter()
                .map(move |case| (group, case))
        })
}

/// One CAVS GCMVS case: its group headers, assignments and `FAIL` marker.
struct CavsCase {
    headers: Vec<(String, usize)>,
    fields: Vec<(String, String)>,
    fail: bool,
}

impl CavsCase {
    fn field(&self, name: &str) -> Vec<u8> {
        let mut matches = self.fields.iter().filter(|(key, _)| key == name);
        let (_, value) = matches.next().unwrap();
        assert!(matches.next().is_none(), "repeated {name}");
        hex(value)
    }

    fn header(&self, name: &str) -> usize {
        self.headers
            .iter()
            .find(|(key, _)| key == name)
            .map(|(_, value)| *value)
            .unwrap()
    }
}

fn cavs(text: &str) -> Vec<CavsCase> {
    let mut headers = Vec::new();
    let mut fresh_group = true;
    let mut cases = Vec::new();
    for block in text.split("\n\n") {
        let mut current: Option<CavsCase> = None;
        for line in block.lines() {
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            if let Some(header) = line.strip_prefix('[').and_then(|l| l.strip_suffix(']')) {
                if fresh_group {
                    headers.clear();
                    fresh_group = false;
                }
                let (name, value) = header.split_once(" = ").unwrap();
                headers.push((name.to_owned(), value.parse().unwrap()));
            } else if line == "FAIL" {
                current.as_mut().unwrap().fail = true;
            } else {
                let (name, value) = line.split_once(" = ").unwrap();
                if name == "Count" {
                    fresh_group = true;
                    current = Some(CavsCase {
                        headers: headers.clone(),
                        fields: Vec::new(),
                        fail: false,
                    });
                }
                current
                    .as_mut()
                    .unwrap()
                    .fields
                    .push((name.to_owned(), value.trim_end().to_owned()));
            }
        }
        cases.extend(current);
    }
    cases
}

fn check_cavs_case_shape(case: &CavsCase) {
    assert_eq!(case.header("Keylen"), 256);
    assert_eq!(case.header("IVlen"), 96);
    assert_eq!(case.header("Taglen"), 128);
    assert_eq!(case.field("PT").len() * 8, case.header("PTlen"));
    assert_eq!(case.field("AAD").len() * 8, case.header("AADlen"));
}

fn check_cavp_encryption<B: CryptoBackend>() {
    let cases = cavs(include_str!("vectors/cavp-gcm256/gcmEncryptExtIV256.rsp"));
    assert_eq!(cases.len(), 375);
    for case in cases {
        check_cavs_case_shape(&case);
        assert!(!case.fail);
        let key = case.field("Key").try_into().unwrap();
        let nonce = case.field("IV").try_into().unwrap();
        let mut expected = case.field("CT");
        expected.extend(case.field("Tag"));
        assert_eq!(
            B::aes256gcm_seal(&key, &nonce, &case.field("AAD"), &case.field("PT")).unwrap(),
            expected
        );
    }
}

fn check_cavp_decryption<B: CryptoBackend>() {
    let cases = cavs(include_str!("vectors/cavp-gcm256/gcmDecrypt256.rsp"));
    assert_eq!(cases.len(), 375);
    assert_eq!(cases.iter().filter(|case| case.fail).count(), 191);
    for case in cases {
        let key = case.field("Key").try_into().unwrap();
        let nonce = case.field("IV").try_into().unwrap();
        let mut sealed = case.field("CT");
        sealed.extend(case.field("Tag"));
        let opened = B::aes256gcm_open(&key, &nonce, &case.field("AAD"), &sealed);
        if case.fail {
            assert!(case.fields.iter().all(|(name, _)| name != "PT"));
            assert_eq!(opened, Err(CryptoError::AuthenticationFailed));
        } else {
            check_cavs_case_shape(&case);
            assert_eq!(opened.unwrap().as_slice(), case.field("PT"));
        }
    }
}

fn check_wycheproof_aes_gcm<B: CryptoBackend>() {
    let corpus = wycheproof(include_str!("vectors/aes_gcm_test.json"));
    let (mut valid, mut invalid, mut unsupported) = (0, 0, 0);
    for (group, case) in cases(&corpus) {
        let sizes = (group["keySize"].as_u64(), group["ivSize"].as_u64());
        if sizes != (Some(256), Some(96)) || group["tagSize"].as_u64() != Some(128) {
            let key = bytes(&case["key"]);
            let nonce = bytes(&case["iv"]);
            assert!(key.len() != AES256GCM_KEY_LEN || nonce.len() != AES256GCM_NONCE_LEN);
            unsupported += 1;
            continue;
        }
        let key = array(&case["key"]);
        let nonce = array(&case["iv"]);
        let aad = bytes(&case["aad"]);
        let mut sealed = bytes(&case["ct"]);
        sealed.extend(bytes(&case["tag"]));
        let opened = B::aes256gcm_open(&key, &nonce, &aad, &sealed);
        match case["result"].as_str().unwrap() {
            "valid" => {
                valid += 1;
                let message = bytes(&case["msg"]);
                assert_eq!(opened.unwrap().as_slice(), message);
                assert_eq!(
                    B::aes256gcm_seal(&key, &nonce, &aad, &message).unwrap(),
                    sealed
                );
            }
            "invalid" => {
                invalid += 1;
                assert_eq!(opened, Err(CryptoError::AuthenticationFailed));
            }
            result => panic!("unexpected result {result}"),
        }
    }
    assert_eq!((valid, invalid, unsupported), (39, 27, 250));
}

fn check_aead_rejections<B: CryptoBackend>() {
    let key = [0x42; AES256GCM_KEY_LEN];
    let nonce = [0x24; AES256GCM_NONCE_LEN];
    let sealed = B::aes256gcm_seal(&key, &nonce, b"header", b"message").unwrap();
    assert_eq!(sealed.len(), b"message".len() + AES256GCM_TAG_LEN);
    assert_eq!(
        B::aes256gcm_open(&key, &nonce, b"header", &sealed)
            .unwrap()
            .as_slice(),
        b"message"
    );
    assert_eq!(
        B::aes256gcm_open(&key, &nonce, b"headex", &sealed),
        Err(CryptoError::AuthenticationFailed)
    );
    let mut other_nonce = nonce;
    other_nonce[11] ^= 1;
    assert_eq!(
        B::aes256gcm_open(&key, &other_nonce, b"header", &sealed),
        Err(CryptoError::AuthenticationFailed)
    );
    for length in 0..AES256GCM_TAG_LEN {
        assert_eq!(
            B::aes256gcm_open(&key, &nonce, b"header", &sealed[..length]),
            Err(CryptoError::AuthenticationFailed)
        );
    }
    let empty = B::aes256gcm_seal(&key, &nonce, b"", b"").unwrap();
    assert_eq!(empty.len(), AES256GCM_TAG_LEN);
    assert!(
        B::aes256gcm_open(&key, &nonce, b"", &empty)
            .unwrap()
            .is_empty()
    );
}

fn check_wycheproof_x25519<B: CryptoBackend>() {
    let corpus = wycheproof(include_str!("vectors/x25519_test.json"));
    let (mut agreed, mut zero) = (0, 0);
    for (group, case) in cases(&corpus) {
        assert_eq!(group["curve"], "curve25519");
        let secret = X25519SecretKey::from_bytes(&array(&case["private"]));
        let shared: [u8; 32] = array(&case["shared"]);
        let flags = case["flags"].as_array().unwrap();
        let zero_flag = flags.iter().any(|flag| flag == "ZeroSharedSecret");
        assert_eq!(zero_flag, shared == [0; 32]);
        assert_ne!(case["result"], "invalid");
        let result = B::x25519(&secret, &array(&case["public"]));
        if zero_flag {
            zero += 1;
            assert_eq!(result.map(|_| ()), Err(CryptoError::ZeroSharedSecret));
        } else {
            agreed += 1;
            assert_eq!(*result.unwrap(), shared, "tcId {}", case["tcId"]);
        }
    }
    assert_eq!((agreed, zero), (487, 31));
}

fn check_x25519_generation<B: CryptoBackend>() {
    let (first, first_public) = B::x25519_generate().unwrap();
    let (second, second_public) = B::x25519_generate().unwrap();
    assert_ne!(first.as_bytes(), second.as_bytes());
    assert_eq!(*B::x25519(&first, &BASEPOINT).unwrap(), first_public);
    assert_eq!(
        B::x25519(&first, &second_public).unwrap(),
        B::x25519(&second, &first_public).unwrap()
    );
}

fn check_random<B: CryptoBackend>() {
    let mut first = [0; 64];
    let mut second = [0; 64];
    B::fill_random(&mut first).unwrap();
    B::fill_random(&mut second).unwrap();
    assert_ne!(first, [0; 64]);
    assert_ne!(first, second);
    B::fill_random(&mut []).unwrap();
    let mut large = vec![0; 65_536];
    B::fill_random(&mut large).unwrap();
    assert!(large.chunks(32).all(|chunk| chunk != [0; 32]));
}

#[test]
fn x25519_secret_keys_round_trip_and_redact_debug_output() {
    let key = X25519SecretKey::from_bytes(&[7; X25519_KEY_LEN]);
    assert_eq!(key.as_bytes(), &[7; X25519_KEY_LEN]);
    assert_eq!(format!("{key:?}"), "X25519SecretKey(..)");
    assert_eq!(
        CryptoError::AuthenticationFailed.to_string(),
        "AEAD authentication failed"
    );
}

macro_rules! backend_tests {
    ($module:ident, $feature:literal, $backend:ident) => {
        #[cfg(feature = $feature)]
        mod $module {
            use super::*;
            use cairn_crypto::$backend;

            #[test]
            fn cavp_aes256gcm_encryption() {
                check_cavp_encryption::<$backend>();
            }

            #[test]
            fn cavp_aes256gcm_decryption() {
                check_cavp_decryption::<$backend>();
            }

            #[test]
            fn wycheproof_aes256gcm() {
                check_wycheproof_aes_gcm::<$backend>();
            }

            #[test]
            fn aead_rejects_modified_inputs() {
                check_aead_rejections::<$backend>();
            }

            #[test]
            fn wycheproof_x25519() {
                check_wycheproof_x25519::<$backend>();
            }

            #[test]
            fn x25519_generation_agrees() {
                check_x25519_generation::<$backend>();
            }

            #[test]
            fn random_fills_buffers() {
                check_random::<$backend>();
            }
        }
    };
}

backend_tests!(aws_lc, "aws-lc", AwsLc);
backend_tests!(reference, "reference", Reference);

#[cfg(all(feature = "aws-lc", feature = "reference"))]
mod cross {
    use super::*;
    use cairn_crypto::{AwsLc, Reference};

    struct XorShift(u64);

    impl XorShift {
        fn fill(&mut self, output: &mut [u8]) {
            for byte in output {
                self.0 ^= self.0 << 13;
                self.0 ^= self.0 >> 7;
                self.0 ^= self.0 << 17;
                *byte = self.0 as u8;
            }
        }
    }

    #[test]
    fn adapters_agree_on_varied_aead_inputs() {
        let mut generator = XorShift(0x2026_1022_0000_0019);
        for length in [0, 1, 15, 16, 17, 63, 64, 65, 255, 1024] {
            let mut key = [0; AES256GCM_KEY_LEN];
            let mut nonce = [0; AES256GCM_NONCE_LEN];
            let mut aad = vec![0; length % 37];
            let mut plaintext = vec![0; length];
            generator.fill(&mut key);
            generator.fill(&mut nonce);
            generator.fill(&mut aad);
            generator.fill(&mut plaintext);
            let sealed = AwsLc::aes256gcm_seal(&key, &nonce, &aad, &plaintext).unwrap();
            assert_eq!(
                Reference::aes256gcm_seal(&key, &nonce, &aad, &plaintext).unwrap(),
                sealed
            );
            assert_eq!(
                Reference::aes256gcm_open(&key, &nonce, &aad, &sealed)
                    .unwrap()
                    .as_slice(),
                plaintext
            );
        }
    }

    #[test]
    fn adapters_agree_on_varied_x25519_inputs() {
        let mut generator = XorShift(0x2026_1022_0000_2551);
        for _ in 0..64 {
            let mut scalar = [0; X25519_KEY_LEN];
            let mut public = [0; X25519_KEY_LEN];
            generator.fill(&mut scalar);
            generator.fill(&mut public);
            let secret = X25519SecretKey::from_bytes(&scalar);
            assert_eq!(
                AwsLc::x25519(&secret, &public),
                Reference::x25519(&secret, &public)
            );
        }
        let (aws_secret, aws_public) = AwsLc::x25519_generate().unwrap();
        let (reference_secret, reference_public) = Reference::x25519_generate().unwrap();
        assert_eq!(
            AwsLc::x25519(&aws_secret, &reference_public).unwrap(),
            Reference::x25519(&reference_secret, &aws_public).unwrap()
        );
    }
}
