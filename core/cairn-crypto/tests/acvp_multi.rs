use std::collections::BTreeSet;

use cairn_crypto::CryptoBackend;
use serde_json::Value;

fn bytes(value: &Value) -> Vec<u8> {
    let text = value.as_str().unwrap();
    assert_eq!(text.len() % 2, 0);
    (0..text.len())
        .step_by(2)
        .map(|offset| u8::from_str_radix(&text[offset..offset + 2], 16).unwrap())
        .collect()
}

fn check<B: CryptoBackend>() {
    let prompt: Value =
        serde_json::from_str(include_str!("vectors/acvp-hkdf-multi/prompt.json")).unwrap();
    let expected: Value =
        serde_json::from_str(include_str!("vectors/acvp-hkdf-multi/expectedResults.json")).unwrap();
    assert_eq!(prompt["algorithm"], "KDA");
    assert_eq!(prompt["mode"], "HKDF");
    assert_eq!(prompt["revision"], "Sp800-56Cr2");
    for field in ["algorithm", "mode", "revision", "vsId"] {
        assert_eq!(prompt[field], expected[field]);
    }
    let mut seen = BTreeSet::new();
    let mut accepted = 0;
    let mut rejected = 0;
    for group in prompt["testGroups"].as_array().unwrap() {
        assert_eq!(group["multiExpansion"], true);
        assert_eq!(group["usesHybridSharedSecret"], true);
        let config = &group["kdfMultiExpansionConfiguration"];
        assert_eq!(config["hmacAlg"], "SHA2-384");
        assert_eq!(config["kdfType"], "hkdf");
        let result_groups: Vec<_> = expected["testGroups"]
            .as_array()
            .unwrap()
            .iter()
            .filter(|result| result["tgId"] == group["tgId"])
            .collect();
        assert_eq!(result_groups.len(), 1);
        for case in group["tests"].as_array().unwrap() {
            let id = (
                group["tgId"].as_u64().unwrap(),
                case["tcId"].as_u64().unwrap(),
            );
            assert!(seen.insert(id));
            let parameters = &case["kdfMultiExpansionParameter"];
            assert_eq!(parameters["hmacAlg"], "SHA2-384");
            assert_eq!(parameters["kdfType"], "hkdf");
            let mut input = bytes(&parameters["z"]);
            assert_eq!(input.len() as u64 * 8, group["zLength"].as_u64().unwrap());
            let auxiliary = bytes(&parameters["t"]);
            assert_eq!(
                auxiliary.len() as u64 * 8,
                group["auxSharedSecretLen"].as_u64().unwrap()
            );
            input.extend_from_slice(&auxiliary);
            let salt = bytes(&parameters["salt"]);
            assert_eq!(salt.len() as u64 * 8, config["saltLen"].as_u64().unwrap());
            let matches: Vec<_> = result_groups[0]["tests"]
                .as_array()
                .unwrap()
                .iter()
                .filter(|result| result["tcId"] == case["tcId"])
                .collect();
            assert_eq!(matches.len(), 1);
            let target = match group["testType"].as_str().unwrap() {
                "AFT" => &matches[0]["dkms"],
                "VAL" => &case["dkms"],
                kind => panic!("unsupported test type {kind}"),
            }
            .as_array()
            .unwrap();
            let iterations = parameters["iterationParameters"].as_array().unwrap();
            assert_eq!(iterations.len(), target.len());
            let mut all_match = true;
            for (iteration, target) in iterations.iter().zip(target) {
                let bits = iteration["l"].as_u64().unwrap();
                assert_eq!(bits % 8, 0);
                let length = usize::try_from(bits / 8).unwrap();
                let target = bytes(target);
                assert_eq!(target.len(), length);
                let output =
                    B::hkdf_sha384(&input, &salt, &bytes(&iteration["fixedInfo"]), length).unwrap();
                all_match &= output[..] == target;
            }
            if group["testType"] == "AFT" {
                assert!(all_match, "KDA multi case {id:?}");
            } else {
                let valid = matches[0]["testPassed"].as_bool().unwrap();
                assert_eq!(all_match, valid, "KDA multi case {id:?}");
                if valid {
                    accepted += 1;
                } else {
                    rejected += 1;
                }
            }
        }
    }
    let expected_ids: BTreeSet<_> = expected["testGroups"]
        .as_array()
        .unwrap()
        .iter()
        .flat_map(|group| {
            group["tests"].as_array().unwrap().iter().map(|case| {
                (
                    group["tgId"].as_u64().unwrap(),
                    case["tcId"].as_u64().unwrap(),
                )
            })
        })
        .collect();
    assert_eq!(seen, expected_ids);
    assert_eq!(seen.len(), 100);
    assert!(accepted > 0 && rejected > 0);
}

#[cfg(feature = "aws-lc")]
#[test]
fn aws_lc_nist_multi_expansion() {
    check::<cairn_crypto::AwsLc>();
}

#[cfg(feature = "reference")]
#[test]
fn reference_nist_multi_expansion() {
    check::<cairn_crypto::Reference>();
}
