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

fn check_hkdf<B: CryptoBackend>() {
    let corpus: Value =
        serde_json::from_str(include_str!("vectors/hkdf_sha384_test.json")).unwrap();
    let mut count = 0;
    for group in corpus["testGroups"].as_array().unwrap() {
        for case in group["tests"].as_array().unwrap() {
            let output = B::hkdf_sha384(
                &bytes(&case["ikm"]),
                &bytes(&case["salt"]),
                &bytes(&case["info"]),
                case["size"].as_u64().unwrap().try_into().unwrap(),
            );
            match case["result"].as_str().unwrap() {
                "valid" => assert_eq!(
                    &output.unwrap()[..],
                    bytes(&case["okm"]),
                    "HKDF tcId={}",
                    case["tcId"]
                ),
                "invalid" => assert!(output.is_err(), "HKDF tcId={}", case["tcId"]),
                result => panic!("unsupported vector result: {result}"),
            }
            count += 1;
        }
    }
    assert_eq!(count, corpus["numberOfTests"].as_u64().unwrap());
}

fn check_hmac<B: CryptoBackend>() {
    let corpus: Value =
        serde_json::from_str(include_str!("vectors/hmac_sha384_test.json")).unwrap();
    let mut count = 0;
    for group in corpus["testGroups"].as_array().unwrap() {
        let length = usize::try_from(group["tagSize"].as_u64().unwrap() / 8).unwrap();
        for case in group["tests"].as_array().unwrap() {
            let output = B::hmac_sha384(&bytes(&case["key"]), &bytes(&case["msg"])).unwrap();
            let matches = output[..length] == bytes(&case["tag"]);
            match case["result"].as_str().unwrap() {
                "valid" => assert!(matches, "HMAC tcId={}", case["tcId"]),
                "invalid" => assert!(!matches, "HMAC tcId={}", case["tcId"]),
                result => panic!("unsupported vector result: {result}"),
            }
            count += 1;
        }
    }
    assert_eq!(count, corpus["numberOfTests"].as_u64().unwrap());
}

#[cfg(feature = "aws-lc")]
#[test]
fn aws_lc_hkdf_vectors() {
    check_hkdf::<cairn_crypto::AwsLc>();
}

#[cfg(feature = "reference")]
#[test]
fn reference_hkdf_vectors() {
    check_hkdf::<cairn_crypto::Reference>();
}

#[cfg(feature = "aws-lc")]
#[test]
fn aws_lc_hmac_vectors() {
    check_hmac::<cairn_crypto::AwsLc>();
}

#[cfg(feature = "reference")]
#[test]
fn reference_hmac_vectors() {
    check_hmac::<cairn_crypto::Reference>();
}
