# Encode and decode your first public field

Build a small program that encodes a public integer and a length-prefixed
byte string, then decodes both. We call this an encode-decode **roundtrip**.
The program does not encrypt data or connect over BLE.

Use an existing Cairn checkout on macOS or Linux, with `rustup` installed
and network access for the initial Rust toolchain installation. This
walkthrough uses Rust `1.99.0`. It does not build the native crypto provider.

## 1. Create a temporary program

From the Cairn repository root, run:

```sh
export CAIRN_ROOT="$PWD"
rustup toolchain install 1.99.0 --profile minimal
export RUSTUP_TOOLCHAIN=1.99.0
export CAIRN_DEMO="$(mktemp -d)"
cargo new --bin --edition 2024 --name cairn-wire-demo "$CAIRN_DEMO/demo"
cd "$CAIRN_DEMO/demo"
cargo add cairn-wire --path "$CAIRN_ROOT/core/cairn-wire"
```

Cargo reports that it created `cairn-wire-demo` and added the local
`cairn-wire` dependency. The temporary program lives outside the checkout.
If Cargo cannot find that crate, return to the Cairn root and repeat this
step. `CAIRN_ROOT` must contain `core/cairn-wire/Cargo.toml`.

## 2. Replace the program

Run:

```sh
cat > src/main.rs <<'RS'
use cairn_wire::{
	decode_leb128, decode_length_prefixed, encode_leb128, encode_length_prefixed,
};

fn main() {
	let mut integer = [0; 5];
	let integer_size = encode_leb128(624_485, &mut integer).unwrap();
	assert_eq!(&integer[..integer_size], &[0xe5, 0x8e, 0x26]);
	assert_eq!(decode_leb128(&integer[..integer_size]), Ok((624_485, 3)));
	println!("integer: {integer_size} bytes, roundtrip OK");

	let mut field = [0; 7];
	let field_size = encode_length_prefixed(b"hello", &mut field).unwrap();
	assert_eq!(&field, b"\x00\x05hello");
	assert_eq!(decode_length_prefixed(&field), Ok((&b"hello"[..], 7)));
	println!("field: {field_size} bytes, roundtrip OK");
}
RS
```

`src/main.rs` now contains two roundtrips with fixed expected encodings.
Both use public example data. Variable-length integer encoding is not
suitable for secret integers.

## 3. Run it

```sh
cargo run --quiet
```

Expected output:

```text
integer: 3 bytes, roundtrip OK
field: 7 bytes, roundtrip OK
```

The assertions confirm the decoded values and consumed byte counts.
If the program panics, the roundtrip failed.

You can repeat `cargo run --quiet` in this temporary project. To return to
the checkout, run `cd "$CAIRN_ROOT"`. The [API reference](../reference/foundation-api.md)
describes malformed input and output-capacity errors. The
[validation guide](../how-to/validate-foundation.md) covers contributor checks.
