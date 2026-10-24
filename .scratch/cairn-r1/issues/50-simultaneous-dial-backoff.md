# Simultaneous dial delays the first link

Type: task
Status: needs-triage
Blocked by: none

## Question

Two Android phones that start Cairn at the same moment both scan and dial
each other. In the S2 device demonstration
([issue 32](32-slice-s2.md)), both `connectGatt` calls failed with status 133
on the P10 lite and the Nothing Phone (2). `AndroidRadio` allows one attempt
per address every 2 minutes (spec §10.4,
[ADR 0023](../../../docs/adr/0023-android-ble-adapter.md) §3), so the two
phones retried in step at +120 s and collided again. The link came up only
because the P10 lite's dial failed first.

Decide how to break the symmetry. Candidates: a short randomized first-retry
delay after a failed dial, a deterministic dial tie-break from advertised
data, or yielding the central role when an inbound central connection exists.
Address rotation means the advertising address differs from the address the
peer connects from, so the current `address in peripherals` check does not
detect the inbound link.

Done when two phones started together link within seconds in a repeatable
device test, with a Robolectric test of the retry policy written first.
