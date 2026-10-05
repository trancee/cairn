# FIPS-conformant hybrid KEM combiner and X-Wing status

Type: research
Status: open
Blocked by:

## Question

Can a hybrid ML-KEM-768 + X25519 key establishment be FIPS-conformant, and which exact combiner satisfies NIST SP 800-227 (final) / SP 800-56C Rev. 2 / SP 800-133 while keeping the security of each component? Specifically: is X-Wing (current IETF draft, and the changes since draft -06 that CryptoKit implements) acceptable under FIPS rules, or must the combiner be e.g. HKDF/KMAC-based with ML-KEM as the approved component? Also cover: CNSA 2.0 position on hybrids, approved KDFs for the resume/ratchet key schedule (HKDF-SHA-256/384 vs KMAC256), approved MAC choices (HMAC vs KMAC, truncation limits for 8- and 16-byte tags per SP 800-38D/SP 800-107), and whether ChaCha20-Poly1305 must be replaced by AES-256-GCM.
