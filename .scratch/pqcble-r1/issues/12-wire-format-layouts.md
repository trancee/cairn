# Wire-format byte layouts

Type: prototype
Status: open
Blocked by: 05, 09, 10

## Question

What are the exact byte layouts of every `pqcble-r1` message — introduction messages per mode, Resume S1/S2, data frame header, ratchet chunk carriage, beacon payload, doorbell — including type codes, version negotiation, padding classes and length fields? Produce a rough spec draft plus a byte-count table (via `docs/research/ble_airtime.py`) to react to.
