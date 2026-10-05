# Constant-time and conformance CI gates

Type: grilling
Status: open
Blocked by: 17

## Question

Which CI gates does the Rust core have to pass before a merge or a release, and on which targets? Decide which tools from the tooling research are mandatory, the vector sets per primitive, fuzz targets and corpus policy (parsers in `pqcble-wire`, the record parser, state machines), the thresholds/flakiness policy for timing tests, and which gates run per PR vs nightly vs pre-release.

## Comments
