use std::collections::BTreeSet;

use cairn_crypto::CryptoBackend;
use serde_json::Value;

fn decode_hex(value: &Value) -> Vec<u8> {
    let text = value.as_str().unwrap();
    assert_eq!(text.len() % 2, 0);
    (0..text.len())
        .step_by(2)
        .map(|offset| u8::from_str_radix(&text[offset..offset + 2], 16).unwrap())
        .collect()
}

fn hmac_vectors<B: CryptoBackend>() {
    let prompt: Value =
        serde_json::from_str(include_str!("vectors/acvp-hmac-sha384/prompt.json")).unwrap();
    let expected: Value = serde_json::from_str(include_str!(
        "vectors/acvp-hmac-sha384/expectedResults.json"
    ))
    .unwrap();
    assert_eq!(prompt["algorithm"], "HMAC-SHA2-384");
    assert_eq!(prompt["revision"], "2.0");
    for field in ["algorithm", "revision", "vsId"] {
        assert_eq!(prompt[field], expected[field]);
    }
    let mut exercised = BTreeSet::new();
    for group in prompt["testGroups"].as_array().unwrap() {
        assert_eq!(group["testType"], "AFT");
        let results: Vec<_> = expected["testGroups"]
            .as_array()
            .unwrap()
            .iter()
            .filter(|result| result["tgId"] == group["tgId"])
            .collect();
        assert_eq!(results.len(), 1);
        for case in group["tests"].as_array().unwrap() {
            let identifier = (
                group["tgId"].as_u64().unwrap(),
                case["tcId"].as_u64().unwrap(),
            );
            assert!(
                exercised.insert(identifier),
                "duplicate case {identifier:?}"
            );
            let key = decode_hex(&case["key"]);
            let message = decode_hex(&case["msg"]);
            assert_eq!(key.len() as u64 * 8, case["keyLen"].as_u64().unwrap());
            assert_eq!(message.len() as u64 * 8, case["msgLen"].as_u64().unwrap());
            let matches: Vec<_> = results[0]["tests"]
                .as_array()
                .unwrap()
                .iter()
                .filter(|result| result["tcId"] == case["tcId"])
                .collect();
            assert_eq!(matches.len(), 1);
            let expected_tag = decode_hex(&matches[0]["mac"]);
            assert_eq!(
                expected_tag.len() as u64 * 8,
                case["macLen"].as_u64().unwrap()
            );
            let actual = B::hmac_sha384(&key, &message).unwrap();
            assert_eq!(
                &actual[..expected_tag.len()],
                expected_tag,
                "ACVP case {identifier:?}"
            );
        }
    }
    let expected_identifiers: BTreeSet<_> = expected["testGroups"]
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
    assert_eq!(exercised, expected_identifiers);
    assert_eq!(exercised.len(), 150);
}

#[cfg(feature = "aws-lc")]
#[test]
fn aws_lc_nist_acvp_hmac_sha384() {
    hmac_vectors::<cairn_crypto::AwsLc>();
}

#[cfg(feature = "reference")]
#[test]
fn reference_nist_acvp_hmac_sha384() {
    hmac_vectors::<cairn_crypto::Reference>();
}
