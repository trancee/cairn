# Crypto suite and parameter set under FIPS

Type: grilling
Status: open
Blocked by: 01, 02

## Question

Given the charting decision that 'FIPS required' means **FIPS-approved algorithms now, hybrid with X25519 allowed via a SP 800-56C/227-conformant combiner with ML-KEM as the approved component, and a CMVP-validated module as the later target behind a backend seam**, which concrete primitive set does `pqcble-r1` use: KEM/hybrid combiner for introduction, resume DH/KEM, KDF, MAC, AEAD, tag lengths (16 B vs compact 8 B), PRF for pseudonyms/beacons? Outcome: an ADR fixing the suite.
