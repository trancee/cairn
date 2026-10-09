---
status: accepted
date: 2026-10-09
version: cairn-r1
---

# 0011: Project name

## Context

The working name `pqcble` described the primitive class and the transport, not the protocol. It is also hard to say, and it would tie the project to Bluetooth Low Energy if another transport is ever added.

The protocol is a compact, ratcheting, post-quantum channel between nearby peers. Each ratchet step is derived from the previous state and cannot be run backwards.

## Decision

1. **Name.** The project is **Cairn**. Version identifiers keep the `-rN` suffix, so the current draft is `cairn-r1`.
2. **Why Cairn.** A cairn is a stack of stones that marks a path, built one stone at a time on top of the last.
   - It mirrors the ratchet: each step is built on the previous state and does not return to it.
   - It marks a trail for people who are nearby but out of contact, which is the setting for store-and-forward messaging between devices.
   - It is small and simple, matching the byte-budget goal.
   - It names no algorithm or transport, so it survives primitive or transport changes.
3. **Namespace.** Code lives under `ch.trancee.cairn`, which the project owner controls. Package names use `cairn-<part>`, for example `cairn-ble` and `cairn-pqc`.
4. **Wire label.** The KDF and MAC domain-separation prefix is now `"cairn-r1 "`. The protocol has no released implementation or test vectors, so this changes no deployed behaviour.
5. **Formal artifacts.** The Tamarin theory is `CairnRatchet` and the Lean namespace is `Cairn`. Recorded theory digests were regenerated for the new names.

## Considered options

- Tessera, Thimble, Fernlock, Lattice Link, Pico and Hush. Cairn fits the ratchet metaphor best and is the least tied to one primitive.

## Consequences

- The bare name `cairn` is taken on crates.io, npm and PyPI by unrelated projects, so published packages use the `cairn-<part>` form. `cairn-pqc` and `cairn-ble` were free on crates.io, npm and PyPI when checked on 2026-10-09.
- "cairn" is a common word and appears in about 2,000 GitHub repository names, mostly AI-agent tools. No repository in cryptography, post-quantum or Bluetooth was found.
- Trademark clearance has not been done and is worth doing before a public launch.
- Dated research notes under `docs/research/` keep the old name as a record of the time they were written.
