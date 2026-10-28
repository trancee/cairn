# Android extended advert on the 2M secondary PHY

Type: task
Status: needs-triage
Blocked by: none

## Question

Implement and validate [ADR 0038](../../../docs/adr/0038-android-extended-advert-2m-secondary.md)
(proposed). iOS reports extended adverts only when their auxiliary packet is
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
