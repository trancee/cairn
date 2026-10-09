# Packaging, distribution and export compliance

Type: research
Status: resolved
Blocked by: 

## Question

How are the `pqcble` SDK and the reference app packaged and distributed, and what compliance applies? Cover: AAR/Maven and XCFramework/SPM publishing for a KMP+Rust (Gobley) library; App Store export compliance for custom non-OS crypto (`ITSAppUsesNonExemptEncryption`, the US BIS EAR 5D002 / License Exception ENC self-classification report, France's ANSSI declaration); the Google Play equivalent; Apple privacy manifests (`PrivacyInfo.xcprivacy`) and required-reason APIs; Bluetooth usage strings; Play Data safety; and open-source licence notices for `aws-lc-rs`, `mlkem-native` and RustCrypto.

## Answer

Findings: [packaging, distribution and export compliance](../../../docs/research/2026-10-05-packaging-export-compliance.md). These are not legal advice.

- **Packaging:** Gobley links iOS statically and Android dynamically. The SDK publishes an AAR to Maven Central and an XCFramework through SPM.
- **App Store:** the app uses non-exempt encryption, so:
  - set `ITSAppUsesNonExemptEncryption`;
  - EAR 5D002 applies, through License Exception ENC or the open-source notification under §742.15(b);
  - distribution in France needs the ANSSI declaration.
- **Google Play** has no export-compliance step, but the EAR still applies to the publisher.
- **Privacy:** a privacy manifest is needed. None of our dependencies is on Apple's SDK-signature list.
- **Bluetooth:** declare `BLUETOOTH_SCAN` with `neverForLocation`, plus `ADVERTISE` and `CONNECT`.
- **Licences:** UniFFI and Gobley are **MPL-2.0** and need NOTICES entries; the rest is permissive.
- **Unverified:** the exact EAR boundaries and the ANSSI statutory text.

## Comments

- 2026-10-08: ADR 0004 now selects Ubique instead of Gobley. The packaging and
  license statements above are Gobley-specific; revalidate Ubique's runtime,
  AAR/XCFramework delivery, and license notices before release. See
  [Ubique compatibility research](../../../docs/research/2026-10-08-ubique-compatibility.md).
