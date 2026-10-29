# Android extended advert on the 2M secondary PHY

Type: task
Status: done
Blocked by: none

## Question

Implement and validate [ADR 0038](../../../docs/adr/0038-android-extended-advert-2m-secondary.md)
(accepted). iOS reports extended adverts only when their auxiliary packet is
on LE 2M, so it never sees Android's 1M-secondary set (ADR 0028).

1. Spec §10.1 and §10.4, then `GattProfile.advertisingSetParameters` takes
   the secondary PHY: 2M when `isLe2MPhySupported`, else 1M (TDD, Kover 100 %).
2. Fleet A/B against `main` with the issue 53 protocol. Accept ADR 0038
   only if pairs, fast failed dials and dial timeouts don't regress.
3. Device check: an iPhone, with its own advertising off, dials an extended
   Android phone (`link N up CENTRAL`) and completes pairing and Resume.

Evidence so far (2026-10-28, ADR 0038 Context): 0 iOS reports with a 1M
secondary PHY against 58–85 with 2M per 25 s. Measured with two Android
controllers and three iPhones on iOS 17, 18 and 27.

## Resolution

Always-2M regressed Android↔Android dialling in the fleet A/B (pairs 42
against 47 on average, more dial timeouts), so it fails step 2. Instead,
the set's secondary PHY is **on demand**: 1M until the phone sees an iOS
peer (a Cairn scan result without service data), then 2M, if
`isLe2MPhySupported`, and back to 1M at the first window rotation
`BEACON_WINDOW_MS` after the last sighting. ADR 0038 is accepted with this
decision and the A/B table; spec 0.19 records it as OI-40.

Device check (2026-10-29, arm m2): 13 of 14 extended phones switched to 2M
with an iPhone 12 mini in range, and the iPhone connected as central to
five extended-only Android phones.

Tests: `ExtendedAdvertisingTest` (1M until iOS, 2M on sighting, revert at
rotation, renewed sighting, full slots, no 2M support, legacy unaffected).
