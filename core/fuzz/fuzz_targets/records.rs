#![no_main]

use cairn_proto::probes::{canonical_plaintext, chat_plaintext, parse_records};
use libfuzzer_sys::fuzz_target;

const BUCKETS: [usize; 8] = [32, 64, 128, 256, 512, 1024, 2048, 4079];
/// CHAT kind byte, the longest body length and the longest message number.
const MAX_OVERHEAD: usize = 1 + 2 + 5;

fuzz_target!(|input: &[u8]| {
    // A plaintext that parses is its records' canonical encoding when the
    // lengths agree.
    if let Some(records) = parse_records(input) {
        assert!(records.iter().all(|(msgno, _)| *msgno != 0));
    }
    if let Some(canonical) = canonical_plaintext(input)
        && canonical.len() == input.len()
    {
        assert_eq!(canonical, input);
    }

    // Every message that fits round-trips through a padding bucket.
    let Some((msgno, text)) = input.split_first_chunk::<4>() else {
        return;
    };
    let msgno = u32::from_be_bytes(*msgno).max(1);
    let text = String::from_utf8_lossy(text);
    match chat_plaintext(msgno, &text) {
        Some(plaintext) => {
            assert!(BUCKETS.contains(&plaintext.len()));
            assert_eq!(
                parse_records(&plaintext),
                Some(vec![(msgno, text.into_owned())])
            );
        }
        None => assert!(text.len() > BUCKETS[7] - MAX_OVERHEAD),
    }
});
