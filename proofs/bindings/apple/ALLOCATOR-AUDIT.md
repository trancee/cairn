# Apple allocator evidence

Scope: immutable shared smoke fixture, Ubique revision
`b819fb4ea33d0ddeb3f1970e5b0d7367c3c7d300`, and delivered Ubique `1.3.1`
Darwin/device/simulator ARM64 runtimes. Hosted
[run 38143105757](https://github.com/trancee/cairn/actions/runs/38143105757)
at `90a31be` collected this evidence offline, with unchanged input hashes
and ordinary UID/scratch/PF cleanup. No fixture FFI calls ran.

## Source scope

The inspector uses locked offline Cargo metadata plus package-scoped
normal/build feature trees for all three Apple Rust targets. Fixture/runtime
closures each contain 50 unique packages; bindgen contains 81. Every selected
package's Rust/TOML files are searched for `global_allocator`,
`alloc_error_handler`, `GlobalAlloc`, `__rust_alloc` and `__rg_alloc`.
Candidate classification agrees with the earlier
[Linux/Android audit](../linux-android/ALLOCATOR-AUDIT.md):

- `bytes 1.12.1`: allocator declarations in standalone
  `tests/test_bytes_odd_alloc.rs:11` and `tests/test_bytes_vec_alloc.rs:8`,
  not the normal library.
- `autocfg 1.2.0`: trait-reference example at `examples/traits.rs:24-25`,
  not an allocator declaration.
- `hashbrown 0.17.1`: documentation links at `src/raw.rs:3100-3135`.

No other allocator-pattern candidates were reported. This is bounded
source inspection, not exhaustive macro/generated-source or memory-safety
proof. Generated fixture artifacts still require inspection before FFI.

## Delivered runtimes

The inspector extracts the actual Native static archives from published
cinterop KLIBs and the host dylib from the published JVM JAR into assigned
scratch. It records hashes and uses Xcode `nm --no-llvm-bc -j` plus
`llvm-objdump --syms` and targeted `--disassemble --reloc`.
Actual bodies are required, not missing-symbol warnings.

| Delivered ARM64 artifact | SHA-256 |
| --- | --- |
| iOS device `libuniffi_runtime.a` | `3190641054d3893d875716f9f0ff043eae84bf3406526a8d29d485c62e948c85` |
| iOS simulator `libuniffi_runtime.a` | `05df2350858061ae76606983357278702769ea0b73f402ab89c78409c387268e` |
| Darwin `libuniffi_runtime.dylib` | `a4d3a5460e39491e6d378e3906f61acf341c33ac6906bb6ef8728c5d986a03ed` |

All three inspected artifacts' `__rust_alloc`, `__rust_dealloc`,
`__rust_realloc` and `__rust_alloc_zeroed` thunks branch to their matching
Rust default `__rdl_*` functions. Static archives identify targets through
`ARM64_RELOC_BRANCH26`; the host dylib identifies resolved branch symbols.
The names are Rust-v0-mangled, not assumed legacy unmangled exports.

Xcode's LLVM 21 reader cannot parse LLVM 22 compiler-builtins bitcode members;
`--no-llvm-bc` explicitly excludes those from the machine-code symbol scan.
This evidence does not attest complete archive analysis, published-binary
source provenance, fixture artifact allocators, x86-64 Darwin, future
dependencies, or runtime memory safety. Repeat source and delivered-artifact
inspection on input/artifact changes. Fixture compilation is next; generated
FFI calls stay gated pending its actual artifact inspection.
