# Apple lane: iOS targets

Type: task
Status: open
Blocked by: 30

## Question

Add the iOS targets to the root Gradle/UniFFI build (iOS 15 deployment floor, which
[ADR 0004](../../../docs/adr/0004-core-architecture.md) still lists as unverified), build the Rust core for the Apple targets, and extend the strict
CodeQL lane to the iOS sources. Moved out of [S0](30-slice-s0.md).

Done when the iOS targets build and test in CI with every applicable gate
green, and the binding is demonstrated on the oldest and newest core-matrix
iPhones.

## Comments

- 2026-10-24: the iOS targets build and test in CI (PR #43, run
  [`40084024801`](https://github.com/trancee/cairn/actions/runs/40084024801)). The strict cell links the device and simulator
  frameworks and the test executable at `minos 15.0`; a fresh simulator
  passes the four common tests. CodeQL cannot extract Kotlin/Native; the
  inventory gate blocks iOS-only sources (ADR 0015). Open: the
  oldest/newest-iPhone demonstration on physical devices.
- 2026-10-26: `iosApp/` (SwiftUI shell over the `:app` framework) runs the
  S1 core self-test on physical iPhones: iPhone 15 (iOS 17.6.1) and iPhone
  SE (2020) (iOS 18.7.8) pass, and so does the newest, the iPhone 12 mini
  (iOS 27.0.1); see [issue 31](31-slice-s1.md). Still open: the iOS 15
  floor phone (SE 1st gen, iOS 15.8.8). Xcode 27 does not offer it as a
  destination, so it needs its UDID registered in the developer portal and a
  tap-to-run, or an older Xcode. The app is not built in CI.
