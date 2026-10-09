# X-Wing draft-11 vector provenance

Type: research
Status: resolved
Blocked by: none

## Question

Do the current BoringSSL and Cloudflare CIRCL X-Wing implementations conform to
IETF X-Wing draft-11, the version required by ADR 0001 and ADR 0007, and can they
independently generate compatible vectors for the project?

Verify the upstream versions/commits and source locations, then compare their
key generation, encapsulation, decapsulation, encodings, and SHA3-256 combiner
inputs against draft-11. Report any version or behavior mismatch and whether
the two implementations are suitable as independent vector sources. Do not
generate or commit vectors, change implementation code, or weaken the ADR gates.

## Answer

The [source audit](../../../docs/research/2026-10-08-x-wing-draft-11-vectors.md)
confirms BoringSSL and CIRCL independently match draft-11's key-stretch,
encodings and SHA3-256 combiner for well-formed inputs, making them suitable
independent vector sources. They differ on low-order X25519 inputs: BoringSSL
fails while CIRCL proceeds with an all-zero component; draft-11 leaves this
case unspecified, so keep it separate from ordinary vector cross-checks.
Draft-11 Appendix C does contain numeric vectors, but their provenance is not
stated. No vectors were generated or executed in this research.
