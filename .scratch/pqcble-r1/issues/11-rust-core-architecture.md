# Rust core architecture and crypto backend seam

Type: grilling
Status: open
Blocked by: 03, 05

## Question

How is the Rust core structured: crate boundaries (wire codec, state machines, crypto backend, storage interface, FFI), the seam that isolates the FIPS crypto backend, sans-IO protocol design vs owning transport, the FFI surface exposed to KMP, and how state persistence is delegated to the platform? Outcome: an ADR and module map.
