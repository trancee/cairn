#![no_main]

use cairn_wire::{decode_leb128, decode_length_prefixed, encode_leb128, encode_length_prefixed};
use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    if let Ok((value, consumed)) = decode_leb128(input) {
        let mut encoded = [0; 5];
        let written = encode_leb128(value, &mut encoded).unwrap();
        assert_eq!(written, consumed);
        assert_eq!(&encoded[..written], &input[..consumed]);
    }
    if let Ok((value, consumed)) = decode_length_prefixed(input) {
        let mut encoded = vec![0; consumed];
        assert_eq!(encode_length_prefixed(value, &mut encoded), Ok(consumed));
        assert_eq!(&encoded, &input[..consumed]);
    }
    if let Some(bytes) = input.get(..4) {
        let value = u32::from_be_bytes(bytes.try_into().unwrap());
        let capacity = usize::from(input.get(4).copied().unwrap_or(5) % 6);
        let mut encoded = [0xa5; 5];
        match encode_leb128(value, &mut encoded[..capacity]) {
            Ok(written) => assert_eq!(decode_leb128(&encoded[..written]), Ok((value, written))),
            Err(_) => assert_eq!(encoded, [0xa5; 5]),
        }
    }
});
