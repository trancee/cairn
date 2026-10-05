# Formal verification gate

Type: grilling
Status: resolved
Blocked by:

## Question

Must a symbolic formal model (Tamarin and/or ProVerif) of `pqcble-r1` pass before the prototype counts as done — and if so, for which components (pairing modes, resume, PQ ratchet, KCI profile, doorbell) and which security properties? Or is it a parallel non-blocking effort?

## Answer

A symbolic formal model **gates** the prototype for the novel compositions only: **Resume**, **PQ ratchet mixing**, and **SAS commit-then-reveal pairing**. QR/TOFU pairing, data frames, KCI profile and doorbell are not gated (user, 2026-10-05). Tool choice and lemma list remain fog on the map.
