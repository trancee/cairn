# iOS host app

A minimal SwiftUI shell around the shared `:app` framework (`CairnApp`). At
launch it runs `coreStatus()`, the same core self-test as Android's
`CoreStatusInstrumentation`: two `CairnCore`s pair and chat over an in-memory
loopback, through `:app` → `:sdk` → Rust. It compares the result with
`EXPECTED_CORE_STATUS`, shows the verdict and logs it with `NSLog`.

It then runs `checkStorage()` against the app's sealed row database (ADR 0006,
ADR 0035). `RowStorage` opens `cairn.db` in Application Support/`databases`,
excluded from backup. `KeychainRowSealer` seals each row with CryptoKit
AES-256-GCM under a random key in a `…AfterFirstUnlockThisDeviceOnly` Keychain
item. When the database is missing, as after a reinstall, the stale key is deleted
first. The first launch reports `storage=new`, later launches report
`storage=restored`, and a `reset` or a missing device row is a `FAIL`.

## Chat over BLE

Without `-selfTest`, the app opens the sealed rows and runs the S3 chat
session (ADR 0037). It works like Android's chat screen:
- `IosRadio` advertises and scans for the cairn service and runs both GATT
  roles while the app is in the foreground;
- nearby phones pair automatically;
- the screen lists contacts, opens conversations and shows the links panel.

The first launch asks for Bluetooth permission. The radio logs link events and
fragment headers, never payloads, as `CairnRadio …` lines:

```sh
idevicesyslog -u <udid> -p CairnIos | grep CairnRadio
```

## Unit tests

`iosAppTests` holds XCTest cases for the sealer, the storage, the radio state
machine (`IosRadio`, through a fake `BlePort`), the platform helpers and the
chat model. They run
hosted in the app on a simulator:

```sh
cd iosApp
xcodegen generate
xcodebuild -project CairnIos.xcodeproj -scheme CairnIos \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

CI does not build or run the Swift shell.

## Build and run on an iPhone

Prerequisites: Xcode, XcodeGen, an Apple Development identity, and an
iPhone with Developer Mode on, paired with the Mac.

```sh
cd iosApp
xcodegen generate   # writes the ignored CairnIos.xcodeproj and Info.plist
xcodebuild -project CairnIos.xcodeproj -scheme CairnIos -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/cairn-ios-dd \
  DEVELOPMENT_TEAM=<team-id> -allowProvisioningUpdates build
APP=/tmp/cairn-ios-dd/Build/Products/Debug-iphoneos/CairnIos.app
xcrun devicectl device install app --device <udid> "$APP"
xcrun devicectl device process launch --device <udid> --console \
  --terminate-existing ch.trancee.cairn.ios -- -selfTest
```

The build's pre-build script runs `./gradlew :app:embedAndSignAppleFrameworkForXcode`.
With `-selfTest`, the app exits 0 on `PASS` and 1 on `FAIL`. Without it, the
app stays open and shows the verdict.

The automatic-signing profile covers only the devices registered with the
team. If `devicectl` can't see a phone that usbmux can, install it with
`ios-deploy --id <udid> --bundle "$APP"`, tap the app, and read the verdict
with `idevicesyslog -u <udid> -p CairnIos`.
