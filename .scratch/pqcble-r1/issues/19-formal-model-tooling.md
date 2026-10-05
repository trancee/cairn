# Formal model tooling and lemmas

Type: research
Status: resolved
Blocked by: 

## Question

For the formal gate (Resume, ratchet mixing, SAS), which tool and modelling approach fits best: Tamarin vs ProVerif vs CryptoVerif (symbolic vs computational), KEM modelling that captures re-encapsulation/binding issues (as in the PQXDH analyses), the commit-then-reveal SAS with a 2^-20 guessing bound, and the PSK + DH Resume with ratchet erasure (FS/PCS lemmas)? Collect prior models to reuse (Signal PQXDH/SPQR Tamarin/ProVerif, WireGuard, Rosenpass, TLS 1.3 PSK, Noise Explorer), the expected modelling effort, and a proposed lemma list per gate.

## Comments

## Answer

Findings: [formal model tooling](../../../docs/research/2026-10-05-formal-model-tooling.md).

- **Tools:**
  - **Tamarin** is the primary tool. It handles unbounded ratchet loops, and the closest prior art (PQXDH, Apple PQ3) uses it.
  - **ProVerif** is secondary, for the SAS guessing bound (`weaksecret`).
  - **CryptoVerif** is optional, for a computational 2^-20 bound.
- **KEM modelling:** KEMs are modelled as explicit `encaps`/`decaps` with binding axioms (Cremers–Dax–Medinger, ePrint 2023/1933).
- **Models to reuse:**
  - WireGuard and TLS 1.3 PSK resumption models for Resume;
  - Bluetooth numeric-comparison models for SAS;
  - Apple PQ3 and Signal ML-KEM Braid as templates for the ratchet.
- **Lemmas:** the report gives lemma lists (Resume 10, ratchet mixing 8, SAS 6).
- **Effort:** ratchet mixing is the hardest; no reusable KEM-binding code exists.
- **Licences:** several prior models are GPL or unlicensed, so reuse them as references, not as copied code.
