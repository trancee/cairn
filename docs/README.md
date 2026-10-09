# Cairn documentation

Choose a page for the task you are doing. The executable examples cover the
current Rust foundation, not an implemented messaging SDK.

## Get a first result

[Encode and decode a public field](tutorials/first-wire-roundtrip.md) builds
a small local program using the canonical wire codec. You need a checkout
and a basic Rust development environment.

## Work on the foundation

[Validate the Rust foundation](how-to/validate-foundation.md) runs its local
formatting, static analysis, test and dependency checks. It also points to
the separate interpreter, fuzz, taint and cross-build gates.

## Look up a contract

| Topic | Source |
|---|---|
| Working Rust interfaces and errors | [Foundation API](reference/foundation-api.md) |
| Tool versions, vectors, provenance and platform evidence | [Core reference](../core/README.md) |
| Draft protocol byte layouts and behavior | [Protocol specification](spec/cairn-r1.md) |
| Threats and intended security properties | [Threat model](spec/threat-model.md) |
| Proof profiles, commands and trust boundaries | [Formal model reference](spec/models/README.md) |
| Terms such as pairing, contact and Resume | [Glossary](../GLOSSARY.md) |

The protocol specification defines the draft behavior. Dated research notes
explain investigations and may describe rejected designs. Use the
specification, not the research notes, when implementing the protocol.

## Understand the design

[Why compact post-quantum messaging over BLE needs a hybrid design](explanation/compact-pqc-over-ble.md)
explains where the bytes go and why the implementation is staged.

These pages record design decisions, alternatives, and risks:
[the architecture ADR](adr/0004-core-architecture.md),
[the verification-gates ADR](adr/0007-ct-conformance-gates.md) and
[the bounded foundation ADR](adr/0012-rust-foundation-increment.md).
The [research collection](research/) provides the historical background.

## Understand what is proven

The [project profile](../PROJECT.md) records local and hosted results.
The [remaining foundation work](../.scratch/cairn-r1/issues/46-rust-foundation-gates.md)
lists the open checks. Passing CI does not validate the complete protocol,
mobile timing behavior, or binding integration.
