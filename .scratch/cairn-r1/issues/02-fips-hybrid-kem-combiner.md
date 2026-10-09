# FIPS-conformant hybrid KEM combiner and X-Wing status

Type: research
Status: resolved
Blocked by:

## Question

Can a hybrid ML-KEM-768 + X25519 key establishment be FIPS-conformant, and which exact combiner satisfies NIST SP 800-227 (final) / SP 800-56C Rev. 2 / SP 800-133 while keeping the security of each component? Specifically: is X-Wing (current IETF draft, and the changes since draft -06 that CryptoKit implements) acceptable under FIPS rules, or must the combiner be e.g. HKDF/KMAC-based with ML-KEM as the approved component? Also cover: CNSA 2.0 position on hybrids, approved KDFs for the resume/ratchet key schedule (HKDF-SHA-256/384 vs KMAC256), approved MAC choices (HMAC vs KMAC, truncation limits for 8- and 16-byte tags per SP 800-38D/SP 800-107), and whether ChaCha20-Poly1305 must be replaced by AES-256-GCM.

## Comments

Findings: [docs/research/2026-10-05-fips-hybrid-kem-combiner.md](../../../docs/research/2026-10-05-fips-hybrid-kem-combiner.md)

Hybrid ML-KEM-768 + X25519 can be FIPS-conformant: NIST SP 800-227 (final, Sept 2025, §4.6) uses X-Wing by name as its worked example, and X-Wing's `SHA3-256(ss_M||ss_X||ct_X||pk_X||label)` combiner matches SP 800-227's recommended IND-CCA-preserving combiner construction, so X-Wing itself is acceptable — no separate HKDF/KMAC combiner is required. X25519 is not an approved SP 800-56A primitive (SP 800-186 excludes Curve25519 from EC key establishment), so it must enter only as the non-approved auxiliary secret `T` per SP 800-56C Rev. 2's `Z' = Z || T`. ChaCha20-Poly1305 is absent from every CMVP-approved algorithm list, so AES-256-GCM (or Ascon-AEAD128) is required for FIPS 140-3 validation; HKDF and KMAC256 are both CMVP-approved KDFs. Short (8/16-byte) tags are bounded by SP 800-38D Appendix C (GCM) and SP 800-107 Rev. 1 (HMAC/KMAC truncation, 32-bit hard floor / 64-bit common floor) — truncated-PRF pseudonyms/beacons fall under the latter and are approvable at 8-16 B with caveats. CNSA 2.0's FAQ discourages ad-hoc hybrids for NSS mission systems but tolerates vendor hybrids for interoperability. See the research doc's final recommended-suite table and "UNVERIFIED" flags (e.g., CNSA 2.0 FAQ fetched only via Wayback Machine due to a 403 on media.defense.gov).

## Answer

The hybrid is FIPS-conformant: SP 800-227 §4.6 uses **X-Wing** as its worked example, and X-Wing's SHA3-256 combiner is acceptable as-is. The combiner is unchanged from draft -06 (CryptoKit) to -11, so there is no interop risk there. X25519 is not approved itself; it acts only as the auxiliary secret `T` (SP 800-56C `Z‖T`). **AES-256-GCM** is required because ChaCha20-Poly1305 isn't approved. HKDF and KMAC256 are both approved KDFs. Truncated MACs and PRF outputs must be ≥ 64 bits (hard floor 32), and 8-byte GCM tags are bounded by SP 800-38D Appendix C. Detail: [findings](../../../docs/research/2026-10-05-fips-hybrid-kem-combiner.md).
