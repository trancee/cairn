use cairn_crypto::{
    CryptoBackend, CryptoError, MLKEM768_CIPHERTEXT_LEN, MLKEM768_DECAPSULATION_KEY_LEN,
    MLKEM768_ENCAPSULATION_KEY_LEN, MlKem768DecapsulationKey, XWING_CIPHERTEXT_LEN,
    XWING_DECAPSULATION_KEY_LEN, XWING_ENCAPSULATION_KEY_LEN, XWingDecapsulationKey,
};
use serde_json::Value;

fn bytes(value: &Value) -> Vec<u8> {
    let text = value.as_str().unwrap();
    assert_eq!(text.len() % 2, 0);
    (0..text.len())
        .step_by(2)
        .map(|offset| u8::from_str_radix(&text[offset..offset + 2], 16).unwrap())
        .collect()
}

fn array<const N: usize>(value: &Value) -> [u8; N] {
    bytes(value).try_into().unwrap()
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

fn acvp(corpus: &str) -> (Value, Value) {
    let (prompt, expected) = match corpus {
        "keyGen" => (
            include_str!("vectors/acvp-mlkem768/ML-KEM-keyGen-FIPS203/prompt.json"),
            include_str!("vectors/acvp-mlkem768/ML-KEM-keyGen-FIPS203/expectedResults.json"),
        ),
        _ => (
            include_str!("vectors/acvp-mlkem768/ML-KEM-encapDecap-FIPS203/prompt.json"),
            include_str!("vectors/acvp-mlkem768/ML-KEM-encapDecap-FIPS203/expectedResults.json"),
        ),
    };
    (
        serde_json::from_str(prompt).unwrap(),
        serde_json::from_str(expected).unwrap(),
    )
}

/// Pairs each prompt case of the selected function with its expected result.
fn acvp_cases<'a>(
    prompt: &'a Value,
    expected: &'a Value,
    function: Option<&str>,
) -> Vec<(&'a Value, &'a Value)> {
    let mut selected = Vec::new();
    for group in prompt["testGroups"].as_array().unwrap() {
        if group.get("function").and_then(Value::as_str) != function {
            continue;
        }
        let results = expected["testGroups"]
            .as_array()
            .unwrap()
            .iter()
            .find(|result| result["tgId"] == group["tgId"])
            .unwrap();
        let tests = group["tests"].as_array().unwrap();
        let outcomes = results["tests"].as_array().unwrap();
        assert_eq!(tests.len(), outcomes.len());
        for case in tests {
            let outcome = outcomes.iter().find(|o| o["tcId"] == case["tcId"]).unwrap();
            selected.push((case, outcome));
        }
    }
    selected
}

fn xwing_key(case: &Value) -> XWingDecapsulationKey {
    let public: [u8; XWING_ENCAPSULATION_KEY_LEN] = array(&case["pk"]);
    let mut key = [0; XWING_DECAPSULATION_KEY_LEN];
    key[..MLKEM768_DECAPSULATION_KEY_LEN].copy_from_slice(&bytes(&case["dk_m"]));
    key[MLKEM768_DECAPSULATION_KEY_LEN..MLKEM768_DECAPSULATION_KEY_LEN + 32]
        .copy_from_slice(&bytes(&case["sk_x"]));
    key[MLKEM768_DECAPSULATION_KEY_LEN + 32..]
        .copy_from_slice(&public[MLKEM768_ENCAPSULATION_KEY_LEN..]);
    XWingDecapsulationKey::from_bytes(&key)
}

/// RFC 7748 u-coordinates whose X25519 output is all zero for every scalar,
/// including non-canonical encodings of 0 and 1.
const LOW_ORDER: [[u8; 32]; 7] = {
    let mut points = [[0; 32]; 7];
    points[1][0] = 1;
    points[2] = [
        0xe0, 0xeb, 0x7a, 0x7c, 0x3b, 0x41, 0xb8, 0xae, 0x16, 0x56, 0xe3, 0xfa, 0xf1, 0x9f, 0xc4,
        0x6a, 0xda, 0x09, 0x8d, 0xeb, 0x9c, 0x32, 0xb1, 0xfd, 0x86, 0x62, 0x05, 0x16, 0x5f, 0x49,
        0xb8, 0x00,
    ];
    points[3] = [
        0x5f, 0x9c, 0x95, 0xbc, 0xa3, 0x50, 0x8c, 0x24, 0xb1, 0xd0, 0xb1, 0x55, 0x9c, 0x83, 0xef,
        0x5b, 0x04, 0x44, 0x5c, 0xc4, 0x58, 0x1c, 0x8e, 0x86, 0xd8, 0x22, 0x4e, 0xdd, 0xd0, 0x9f,
        0x11, 0x57,
    ];
    let mut index = 4;
    while index < 7 {
        let mut point = [0xff; 32];
        point[0] = 0xe8 + index as u8;
        point[31] = 0x7f;
        points[index] = point;
        index += 1;
    }
    points
};

fn check_acvp_decapsulation<B: CryptoBackend>() {
    let (prompt, expected) = acvp("encapDecap");
    let selected = acvp_cases(&prompt, &expected, Some("decapsulation"));
    assert_eq!(selected.len(), 10);
    for (case, outcome) in selected {
        let key = MlKem768DecapsulationKey::from_bytes(&array(&case["dk"]));
        let secret = B::mlkem768_decapsulate(&key, &array(&case["c"])).unwrap();
        assert_eq!(&secret[..], bytes(&outcome["k"]), "tcId={}", case["tcId"]);
    }
}

fn check_acvp_key_checks<B: CryptoBackend>() {
    let (prompt, expected) = acvp("encapDecap");
    let decapsulation = acvp_cases(&prompt, &expected, Some("decapsulationKeyCheck"));
    let encapsulation = acvp_cases(&prompt, &expected, Some("encapsulationKeyCheck"));
    assert_eq!((decapsulation.len(), encapsulation.len()), (10, 10));
    for (case, outcome) in decapsulation {
        let key = MlKem768DecapsulationKey::from_bytes(&array(&case["dk"]));
        let result = B::mlkem768_decapsulate(&key, &[0; MLKEM768_CIPHERTEXT_LEN]);
        match outcome["testPassed"].as_bool().unwrap() {
            true => assert!(result.is_ok(), "tcId={}", case["tcId"]),
            false => assert_eq!(
                result,
                Err(CryptoError::InvalidKey),
                "tcId={}",
                case["tcId"]
            ),
        }
    }
    for (case, outcome) in encapsulation {
        let result = B::mlkem768_encapsulate(&array(&case["ek"]));
        match outcome["testPassed"].as_bool().unwrap() {
            true => assert!(result.is_ok(), "tcId={}", case["tcId"]),
            false => assert_eq!(
                result.map(|_| ()),
                Err(CryptoError::InvalidKey),
                "tcId={}",
                case["tcId"]
            ),
        }
    }
}

fn check_wycheproof_semi_expanded<B: CryptoBackend>() {
    let corpus: Value = serde_json::from_str(include_str!(
        "vectors/mlkem_768_semi_expanded_decaps_test.json"
    ))
    .unwrap();
    let mut count = 0;
    for (_, case) in cases(&corpus) {
        let key: Result<[u8; MLKEM768_DECAPSULATION_KEY_LEN], _> = bytes(&case["dk"]).try_into();
        let ciphertext: Result<[u8; MLKEM768_CIPHERTEXT_LEN], _> = bytes(&case["c"]).try_into();
        let result = match (key, ciphertext) {
            (Ok(key), Ok(ciphertext)) => {
                B::mlkem768_decapsulate(&MlKem768DecapsulationKey::from_bytes(&key), &ciphertext)
                    .map(|secret| secret.to_vec())
            }
            _ => Err(CryptoError::InvalidKey),
        };
        match case["result"].as_str().unwrap() {
            "valid" => assert_eq!(result.unwrap(), bytes(&case["K"]), "tcId={}", case["tcId"]),
            _ => assert!(result.is_err(), "tcId={}", case["tcId"]),
        }
        count += 1;
    }
    assert_eq!(count, corpus["numberOfTests"].as_u64().unwrap());
}

fn check_wycheproof_encapsulation_key_validation<B: CryptoBackend>() {
    let corpus: Value =
        serde_json::from_str(include_str!("vectors/mlkem_768_encaps_test.json")).unwrap();
    let mut count = 0;
    for (_, case) in cases(&corpus) {
        let key: Result<[u8; MLKEM768_ENCAPSULATION_KEY_LEN], _> = bytes(&case["ek"]).try_into();
        let accepted = key.is_ok_and(|key| B::mlkem768_encapsulate(&key).is_ok());
        assert_eq!(accepted, case["result"] == "valid", "tcId={}", case["tcId"]);
        count += 1;
    }
    assert_eq!(count, corpus["numberOfTests"].as_u64().unwrap());
}

fn check_xwing_decapsulation<B: CryptoBackend>() {
    let corpus: Value = serde_json::from_str(include_str!("vectors/xwing_draft11.json")).unwrap();
    let tests = corpus["tests"].as_array().unwrap();
    assert_eq!(tests.len(), 32);
    for case in tests {
        let secret = B::xwing_decapsulate(&xwing_key(case), &array(&case["ct"])).unwrap();
        assert_eq!(&secret[..], bytes(&case["ss"]), "tcId={}", case["tcId"]);
    }
}

fn check_low_order_rejection<B: CryptoBackend>() {
    let (public, key) = B::xwing_generate().unwrap();
    let (ciphertext, _) = B::xwing_encapsulate(&public).unwrap();
    for point in LOW_ORDER {
        let mut bad_public = public;
        bad_public[MLKEM768_ENCAPSULATION_KEY_LEN..].copy_from_slice(&point);
        assert_eq!(
            B::xwing_encapsulate(&bad_public).map(|_| ()),
            Err(CryptoError::ZeroSharedSecret)
        );
        let mut bad_ciphertext = ciphertext;
        bad_ciphertext[MLKEM768_CIPHERTEXT_LEN..].copy_from_slice(&point);
        assert_eq!(
            B::xwing_decapsulate(&key, &bad_ciphertext),
            Err(CryptoError::ZeroSharedSecret)
        );
    }
}

fn check_round_trips<B: CryptoBackend>() {
    let (public, key) = B::mlkem768_generate().unwrap();
    let (ciphertext, secret) = B::mlkem768_encapsulate(&public).unwrap();
    assert_eq!(B::mlkem768_decapsulate(&key, &ciphertext).unwrap(), secret);
    let mut tampered = ciphertext;
    tampered[0] ^= 1;
    assert_ne!(B::mlkem768_decapsulate(&key, &tampered).unwrap(), secret);

    let (public, key) = B::xwing_generate().unwrap();
    let (ciphertext, secret) = B::xwing_encapsulate(&public).unwrap();
    assert_eq!(B::xwing_decapsulate(&key, &ciphertext).unwrap(), secret);
    for index in [0, XWING_CIPHERTEXT_LEN - 1] {
        let mut tampered = ciphertext;
        tampered[index] ^= 1;
        assert_ne!(B::xwing_decapsulate(&key, &tampered).unwrap(), secret);
    }
    let (_, other) = B::xwing_encapsulate(&public).unwrap();
    assert_ne!(other, secret);
}

#[test]
fn decapsulation_keys_round_trip_and_redact_debug_output() {
    let key = [7; MLKEM768_DECAPSULATION_KEY_LEN];
    let decapsulation = MlKem768DecapsulationKey::from_bytes(&key);
    assert_eq!(decapsulation.as_bytes(), &key);
    assert!(!format!("{decapsulation:?}").contains("7, 7"));
    let key = [9; XWING_DECAPSULATION_KEY_LEN];
    let decapsulation = XWingDecapsulationKey::from_bytes(&key);
    assert_eq!(decapsulation.as_bytes(), &key);
    assert!(!format!("{decapsulation:?}").contains("9, 9"));
    assert_eq!(CryptoError::InvalidKey.to_string(), "invalid KEM key");
    assert_eq!(
        CryptoError::ZeroSharedSecret.to_string(),
        "all-zero X25519 shared secret"
    );
}

#[cfg(feature = "aws-lc")]
mod aws_lc {
    use super::*;
    use cairn_crypto::AwsLc;

    #[test]
    fn acvp_mlkem768_decapsulation() {
        check_acvp_decapsulation::<AwsLc>();
    }

    #[test]
    fn acvp_mlkem768_key_checks() {
        check_acvp_key_checks::<AwsLc>();
    }

    #[test]
    fn wycheproof_mlkem768_semi_expanded_decapsulation() {
        check_wycheproof_semi_expanded::<AwsLc>();
    }

    #[test]
    fn wycheproof_mlkem768_encapsulation_key_validation() {
        check_wycheproof_encapsulation_key_validation::<AwsLc>();
    }

    #[test]
    fn xwing_draft11_decapsulation() {
        check_xwing_decapsulation::<AwsLc>();
    }

    #[test]
    fn xwing_rejects_low_order_x25519_points() {
        check_low_order_rejection::<AwsLc>();
    }

    #[test]
    fn kem_round_trips() {
        check_round_trips::<AwsLc>();
    }
}

#[cfg(feature = "reference")]
mod reference {
    use super::*;
    use cairn_crypto::Reference;

    #[test]
    fn acvp_mlkem768_decapsulation() {
        check_acvp_decapsulation::<Reference>();
    }

    #[test]
    fn acvp_mlkem768_key_checks() {
        check_acvp_key_checks::<Reference>();
    }

    #[test]
    fn wycheproof_mlkem768_semi_expanded_decapsulation() {
        check_wycheproof_semi_expanded::<Reference>();
    }

    #[test]
    fn wycheproof_mlkem768_encapsulation_key_validation() {
        check_wycheproof_encapsulation_key_validation::<Reference>();
    }

    #[test]
    fn xwing_draft11_decapsulation() {
        check_xwing_decapsulation::<Reference>();
    }

    #[test]
    fn xwing_rejects_low_order_x25519_points() {
        check_low_order_rejection::<Reference>();
    }

    #[test]
    fn kem_round_trips() {
        check_round_trips::<Reference>();
    }

    #[test]
    fn acvp_mlkem768_key_generation() {
        let (prompt, expected) = acvp("keyGen");
        let selected = acvp_cases(&prompt, &expected, None);
        assert_eq!(selected.len(), 25);
        for (case, outcome) in selected {
            let (public, key) =
                Reference::mlkem768_generate_deterministic(&array(&case["d"]), &array(&case["z"]));
            assert_eq!(
                public.to_vec(),
                bytes(&outcome["ek"]),
                "tcId={}",
                case["tcId"]
            );
            assert_eq!(
                key.as_bytes().to_vec(),
                bytes(&outcome["dk"]),
                "tcId={}",
                case["tcId"]
            );
        }
    }

    #[test]
    fn acvp_mlkem768_encapsulation() {
        let (prompt, expected) = acvp("encapDecap");
        let selected = acvp_cases(&prompt, &expected, Some("encapsulation"));
        assert_eq!(selected.len(), 25);
        for (case, outcome) in selected {
            let (ciphertext, secret) = Reference::mlkem768_encapsulate_deterministic(
                &array(&case["ek"]),
                &array(&case["m"]),
            )
            .unwrap();
            assert_eq!(
                ciphertext.to_vec(),
                bytes(&outcome["c"]),
                "tcId={}",
                case["tcId"]
            );
            assert_eq!(&secret[..], bytes(&outcome["k"]), "tcId={}", case["tcId"]);
        }
    }

    #[test]
    fn wycheproof_mlkem768_key_generation_from_seed() {
        let corpus: Value =
            serde_json::from_str(include_str!("vectors/mlkem_768_keygen_seed_test.json")).unwrap();
        let mut count = 0;
        for (_, case) in cases(&corpus) {
            let seed = bytes(&case["seed"]);
            let (public, key) = Reference::mlkem768_generate_deterministic(
                seed[..32].try_into().unwrap(),
                seed[32..].try_into().unwrap(),
            );
            assert_eq!(public.to_vec(), bytes(&case["ek"]), "tcId={}", case["tcId"]);
            assert_eq!(
                key.as_bytes().to_vec(),
                bytes(&case["dk"]),
                "tcId={}",
                case["tcId"]
            );
            count += 1;
        }
        assert_eq!(count, corpus["numberOfTests"].as_u64().unwrap());
    }

    #[test]
    fn wycheproof_mlkem768_encapsulation() {
        let corpus: Value =
            serde_json::from_str(include_str!("vectors/mlkem_768_encaps_test.json")).unwrap();
        for (_, case) in cases(&corpus) {
            let key: Result<[u8; MLKEM768_ENCAPSULATION_KEY_LEN], _> =
                bytes(&case["ek"]).try_into();
            let result = key.map_err(|_| CryptoError::InvalidKey).and_then(|key| {
                Reference::mlkem768_encapsulate_deterministic(&key, &array(&case["m"]))
            });
            match case["result"].as_str().unwrap() {
                "valid" => {
                    let (ciphertext, secret) = result.unwrap();
                    assert_eq!(
                        ciphertext.to_vec(),
                        bytes(&case["c"]),
                        "tcId={}",
                        case["tcId"]
                    );
                    assert_eq!(&secret[..], bytes(&case["K"]), "tcId={}", case["tcId"]);
                }
                _ => assert_eq!(result.map(|_| ()), Err(CryptoError::InvalidKey)),
            }
        }
    }

    /// Wycheproof decapsulation cases, with keys expanded from the vector seed.
    pub(super) fn check_wycheproof_decapsulation<B: CryptoBackend>() {
        let corpus: Value =
            serde_json::from_str(include_str!("vectors/mlkem_768_test.json")).unwrap();
        let mut count = 0;
        for (_, case) in cases(&corpus) {
            let seed = bytes(&case["seed"]);
            let ciphertext: Result<[u8; MLKEM768_CIPHERTEXT_LEN], _> = bytes(&case["c"]).try_into();
            let result = match (seed.len(), ciphertext) {
                (64, Ok(ciphertext)) => {
                    let (public, key) = Reference::mlkem768_generate_deterministic(
                        seed[..32].try_into().unwrap(),
                        seed[32..].try_into().unwrap(),
                    );
                    assert_eq!(public.to_vec(), bytes(&case["ek"]), "tcId={}", case["tcId"]);
                    B::mlkem768_decapsulate(&key, &ciphertext).map(|secret| secret.to_vec())
                }
                _ => Err(CryptoError::InvalidKey),
            };
            match case["result"].as_str().unwrap() {
                "valid" => assert_eq!(result.unwrap(), bytes(&case["K"]), "tcId={}", case["tcId"]),
                _ => assert!(result.is_err(), "tcId={}", case["tcId"]),
            }
            count += 1;
        }
        assert_eq!(count, corpus["numberOfTests"].as_u64().unwrap());
    }

    #[test]
    fn wycheproof_mlkem768_decapsulation() {
        check_wycheproof_decapsulation::<Reference>();
    }

    #[test]
    fn xwing_draft11_derandomized_generation_and_encapsulation() {
        let corpus: Value =
            serde_json::from_str(include_str!("vectors/xwing_draft11.json")).unwrap();
        for case in corpus["tests"].as_array().unwrap() {
            let (public, key) = Reference::xwing_generate_deterministic(&array(&case["seed"]));
            assert_eq!(public.to_vec(), bytes(&case["pk"]), "tcId={}", case["tcId"]);
            assert_eq!(
                key.as_bytes(),
                xwing_key(case).as_bytes(),
                "tcId={}",
                case["tcId"]
            );
            let (ciphertext, secret) =
                Reference::xwing_encapsulate_deterministic(&public, &array(&case["eseed"]))
                    .unwrap();
            assert_eq!(
                ciphertext.to_vec(),
                bytes(&case["ct"]),
                "tcId={}",
                case["tcId"]
            );
            assert_eq!(&secret[..], bytes(&case["ss"]), "tcId={}", case["tcId"]);
        }
    }

    #[test]
    fn deterministic_encapsulation_rejects_invalid_and_low_order_keys() {
        let (public, _) = Reference::xwing_generate_deterministic(&[1; 32]);
        let mut unreduced = public;
        unreduced[..2].copy_from_slice(&[0xff, 0xff]);
        assert_eq!(
            Reference::xwing_encapsulate_deterministic(&unreduced, &[2; 64]).map(|_| ()),
            Err(CryptoError::InvalidKey)
        );
        let mut low_order = public;
        low_order[MLKEM768_ENCAPSULATION_KEY_LEN..].copy_from_slice(&LOW_ORDER[0]);
        assert_eq!(
            Reference::xwing_encapsulate_deterministic(&low_order, &[2; 64]).map(|_| ()),
            Err(CryptoError::ZeroSharedSecret)
        );
    }
}

#[cfg(all(feature = "aws-lc", feature = "reference"))]
mod cross {
    use super::*;
    use cairn_crypto::{AwsLc, Reference};

    #[test]
    fn aws_lc_decapsulates_wycheproof_ciphertexts_with_reference_expanded_keys() {
        reference::check_wycheproof_decapsulation::<AwsLc>();
    }

    fn exchange<G: CryptoBackend, E: CryptoBackend, D: CryptoBackend>() {
        for _ in 0..8 {
            let (public, key) = G::mlkem768_generate().unwrap();
            let (ciphertext, secret) = E::mlkem768_encapsulate(&public).unwrap();
            assert_eq!(D::mlkem768_decapsulate(&key, &ciphertext).unwrap(), secret);
            let (public, key) = G::xwing_generate().unwrap();
            let (ciphertext, secret) = E::xwing_encapsulate(&public).unwrap();
            assert_eq!(D::xwing_decapsulate(&key, &ciphertext).unwrap(), secret);
        }
    }

    #[test]
    fn adapters_interoperate_in_every_role_assignment() {
        exchange::<AwsLc, AwsLc, Reference>();
        exchange::<AwsLc, Reference, AwsLc>();
        exchange::<AwsLc, Reference, Reference>();
        exchange::<Reference, AwsLc, AwsLc>();
        exchange::<Reference, AwsLc, Reference>();
        exchange::<Reference, Reference, AwsLc>();
    }

    #[test]
    fn adapters_agree_on_reproducible_varied_ciphertexts() {
        let mut state = 0x5eed_c0de_1234_abcd_u64;
        let mut next = || {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            state as u8
        };
        for _ in 0..16 {
            let mut seed = [0; 32];
            seed.fill_with(&mut next);
            let (public, key) = Reference::xwing_generate_deterministic(&seed);
            let mut ciphertext = [0; XWING_CIPHERTEXT_LEN];
            ciphertext.fill_with(&mut next);
            assert_eq!(
                AwsLc::xwing_decapsulate(&key, &ciphertext),
                Reference::xwing_decapsulate(&key, &ciphertext)
            );
            let mut ml_kem = [0; MLKEM768_CIPHERTEXT_LEN];
            ml_kem.copy_from_slice(&ciphertext[..MLKEM768_CIPHERTEXT_LEN]);
            let mut d = [0; 32];
            d.fill_with(&mut next);
            let (_, ml_kem_key) = Reference::mlkem768_generate_deterministic(&d, &seed);
            assert_eq!(
                AwsLc::mlkem768_decapsulate(&ml_kem_key, &ml_kem),
                Reference::mlkem768_decapsulate(&ml_kem_key, &ml_kem)
            );
            let _ = public;
        }
    }
}
