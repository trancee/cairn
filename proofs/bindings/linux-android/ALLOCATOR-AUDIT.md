# Linux/Android allocator evidence

Scope: standalone smoke fixture from commit `8deda79`, pinned Ubique
`b819fb4ea33d0ddeb3f1970e5b0d7367c3c7d300`, and the delivered Ubique `1.3.1`
Linux x86_64 / Android ARM64 and x86_64 runtime libraries. Inspected directly
over authorized SSH on 2026-10-10. No iOS, foundation crate, release build or
future dependency graph is covered.

## Result

The inspected source graphs contain no identified production global-allocator
override. More importantly, all six delivered Rust shared libraries forward
`__rust_alloc`, `__rust_dealloc`, `__rust_realloc` and
`__rust_alloc_zeroed` to their respective Rust default `__rdl_*` functions.
This supplies bounded default-global-allocator evidence for these artifacts,
including the prebuilt Ubique runtime; a lockfile or successful call alone
would not establish it.

This is not a general memory-safety proof or a reproducible-build attestation
linking the published runtime binary to a particular source build. Source
matching, all generated macro expansions, dependency integrity, and allocator
behavior across future builds are distinct questions. Repeat the source and
delivered-binary inspection whenever dependencies, features or artifacts change.

## Source graph and features

Both manifests were resolved with Rust/Cargo `1.97.1` in a restricted offline
systemd unit, using `--locked --offline`. The targets were
`x86_64-unknown-linux-gnu`, `aarch64-linux-android` and `x86_64-linux-android`.
For each target, metadata supplied package/source identities and package-scoped
normal/build trees supplied relevant versions/features:

```bash
cargo metadata --format-version 1 --locked --offline \
  --filter-platform "$target" --manifest-path "$manifest"
cargo tree --locked --offline --target "$target" \
  --prefix none --no-dedupe -e normal,build --format '{p}|{f}' \
  --manifest-path "$manifest"
```

The runtime tree additionally selected `-p uniffi-runtime`.
Manifests were the fixture's `sdk/rust/Cargo.toml` and
`/opt/cairn-binding-seeds/ubique/runtime/Cargo.toml`.
Workspace-wide metadata initially overapproximated the runtime closure:
79 packages versus the package-scoped 50/51. It was not treated as the
actual active-feature set. Feature rows also distinguish host/target
contexts, so row counts are not unique package counts.

| Scope | Unique packages | Rust/TOML files inspected |
| --- | --- | --- |
| Smoke, Linux host | 50 | 2,289 |
| Runtime source, Linux host | 50 | 2,290 |
| Smoke, each Android target | 51 | 2,297 |
| Runtime source, each Android target | 51 | 2,298 |

The smoke and runtime trees each select UniFFI `0.32.0` with
`cargo-metadata,default`; `uniffi_core` selects `default`.
The upstream workspace lockfile SHA-256 is
`f98610fdac2c98c54e4720656003db31fd1706692bc25b4e1be3c7653e84495a`.
The fixture's exact lockfile remains checked in.

The source inspection searched each selected package's Rust/TOML files for
`global_allocator`, `alloc_error_handler`, `GlobalAlloc`, `__rust_alloc`
and `__rg_alloc`; generated-source candidates additionally included
`include!` and `OUT_DIR`. Findings were classified rather than blindly
rejected:

- `bytes 1.12.1` defines custom allocators only in
  `tests/test_bytes_odd_alloc.rs:11` and `tests/test_bytes_vec_alloc.rs:8`.
  Its `Cargo.toml:77-83` registers these as standalone test targets; they
  are not linked by the normal library dependency.
- `autocfg 1.2.0` references `GlobalAlloc` in
  `examples/traits.rs:24-25`, not an allocator declaration.
- `hashbrown 0.17.1` references `GlobalAlloc` in documentation at
  `src/raw.rs:3100-3135`, not an override.
- No allocator-pattern hit was found in the 11 generated Rust files
  inspected under the fixture's retained Cargo target and binding outputs.
  Build-script output paths in Serde/thiserror were inspected; the delivered
  allocator-thunk inspection below covers the actual compiled selection.

The runtime's `runtime/src/commonMain/rust/lib.rs:1-3` only invokes
`setup_scaffolding!()`. UniFFI `0.32.0`
`uniffi_macros/src/setup_scaffolding.rs:70-94` delegates exported buffer
allocation/free to `uniffi::ffi`. Its
`uniffi_core/src/ffi/rustbuffer.rs:149-180` transfers a `Vec` via
`ManuallyDrop` and reconstructs it with `Vec::from_raw_parts`;
`:211-239` implements buffer allocation/free. The matching global allocator
across Rust libraries is therefore material to buffer ownership.

## Delivered binaries

The cached Android runtime AAR SHA-256 was
`50309e33d53f7babeeb8d76fe8d3503fc27d046d129e0e650a27dfb55eca136c`.
The Linux JVM runtime JAR SHA-256 was
`51af5a5df5d678016f135e8d86cb2c64c539f5d80b08f84b54ec4ef89ce21ceb`.

| ELF | SHA-256 |
| --- | --- |
| Smoke Linux x86_64 | `23cb7eb579635dd83b030bfed237d676b30a8bf8d7a004c97b6f03bb73ca4492` |
| Runtime Linux x86_64 | `794d08b782538dca0c8b6b986f47712427baffaf0b621918e28478f4a79524ec` |
| Smoke Android ARM64 | `2779965a06b3821eb33660b8492853e4301272a7032cf25efec232a49d9a1bed` |
| Runtime Android ARM64 | `69f3d88f18bbb1784e1d6c2348e8e6d3c790ae533742f678827e963f2b4c11e3` |
| Smoke Android x86_64 | `555c3504e2d67757dd1e6a10243e80c01fd7b8d97462757e986298756044df5f` |
| Runtime Android x86_64 | `e1f320a8efd6f478130b6740251db1e02b5fb31f45ab49769fe707c2609caa51` |

Runtime ELFs were extracted from cached delivered JAR/AAR archives. The APK's
ARM64/x86_64 smoke/runtime entries matched the inspected ELF bytes exactly;
the JVM SDK JAR's smoke entry also matched exactly.

`nm -C` located all four allocator symbols; NDK `30.0.16248370`'s
`llvm-objdump -d --demangle --start-address=... --stop-address=...`
inspected the forwarding instruction at each address. Every symbol branched
to the matching `__rdl_*` function, rather than a custom `__rg_*` allocator.
Android runtime dynamic symbols also import libc `malloc`, `calloc`, `free`,
`realloc` and `posix_memalign`; those imports alone were not used as proof.
The ARM64 inspection used four-byte instruction ranges and x86_64 used
five-byte ranges to avoid reading adjacent allocator functions.

Metadata JSON, feature trees and the exact forwarding transcript are preserved
root-owned at `/opt/cairn-binding-seeds/allocator-audit-8deda79/` in the guest.
The inspection did not change the fixture or replace the published runtime.
Cross-module shared types, callbacks, async APIs, Unicode-specific checks,
release/R8 and Apple allocator/linkage evidence remain outside this increment.
