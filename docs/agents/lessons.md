# Lessons for agents

Orientation and hard-won lessons from building `cairn-r1` (2026-10-05 to
2026-10-31). Read it before radio, fleet, crypto-choice or gate work. It
summarises; the [spec](../spec/cairn-r1.md), the [ADRs](../adr/) and the
[issues](../../.scratch/cairn-r1/issues/) stay authoritative. When this file
and one of them disagree, trust them and fix this file.

## 1. The concept

Cairn gives two phones a post-quantum, end-to-end encrypted link over plain
BLE GATT, with no Bluetooth pairing or bonding. Peers admit each other
automatically (TOFU) and form a neighbour mesh; couriers carry queued
messages to contacts that are out of range.

```
first meeting          every connection             every frame
Pairing (§5) ──RK──►  Resume (§6) ──session keys──►  DATA (§7)
X-Wing, 2,563 B       X25519 + chain key, 57/49 B    AES-256-GCM, +17 B
                         ▲ mixes each finished PQ epoch
                         └── PQ ratchet (§9): ML-KEM-768 ek+ct, 2,272 B,
                             sent in chunks inside DATA padding
```

- The expensive post-quantum bytes are paid **once** at pairing and then
  **amortised** inside padding that DATA frames send anyway. Reconnects
  (Resume) are classical-size, yet still bound to the PQ chain key. This is
  the design's central trick; keep it when proposing changes.
- One fixed suite per version, no negotiation (ADR 0001): X-Wing
  (ML-KEM-768 + X25519), ML-KEM-768, X25519, AES-256-GCM, HKDF/HMAC/SHA-384.
  No signatures anywhere. Security target: NIST level 3.
- Beacons (§10) are rotating HMAC values that let contacts recognise each
  other without a stable identifier; the beacon key ratchets forward daily.
- Pairing roles: the BLE **central is role B** and sends P0, P2, P4; the
  peripheral is role A and sends P1, P3. A link must finish pairing or
  Resume within **5 s** (§4.4).
- Every GATT fragment is `header ‖ body ‖ CRC-16` with body at most
  `min(ATT_MTU − 6, 509)` B (ADR 0042).

Vocabulary is in [`GLOSSARY.md`](../../GLOSSARY.md). Read it before naming
anything: *pairing* means Cairn pairing, never Bluetooth pairing.

## 2. Code map

| Layer | Where | Notes |
|---|---|---|
| Wire codec | `core/cairn-wire` | canonical encoding |
| Crypto seam | `core/cairn-crypto` | `no_std`; backends `aws-lc` (devices) and `reference` (RustCrypto); both are tested |
| Protocol core | `core/cairn-proto` (`core.rs` is the hub) | sans-IO: `CairnCore.handle(Event) -> List<Action>` (ADR 0004, 0022); deterministic, no I/O, no clocks |
| FFI | `core/cairn-ffi` | UniFFI; Kotlin bindings generated at Gradle build time by the ubique plugin, no separate bindgen step |
| SDK | `sdk/` (KMP) | `LinkDriver.kt` executes Actions; its `when` is exhaustive, so a new Action must be added there. `Platform.kt` defines the `Radio` interface |
| Android radio | `androidBle/.../AndroidRadio.kt` | GATT client + server, dial policy, slot budget (ADR 0023, 0025, 0031, 0039, 0040) |
| Shared app | `app/` (CMP) | framework consumed by Android and iOS |
| Android app | `androidApp/` | |
| iOS app | `iosApp/` (`IosRadio.swift`, `CoreBluetoothPort.swift`) | ADR 0037; Swift radio over the shared `:app` framework |
| Proofs | `docs/spec/models/`, `proofs/` | Tamarin/ProVerif, Lean lifecycle certificates |
| Device lab | [issue 13](../../.scratch/cairn-r1/issues/13-device-test-lab.md) | roster of phones and why each exists |

Slice status lives in [`map.md`](../../.scratch/cairn-r1/map.md) and issues
30–41. At the time of writing: S0, S1, S4, S5 are resolved; S2 (Android↔Android)
and S3 (Android↔iOS) run on devices but stay open; Resume rate limits/concurrency (S7), Verify (S8), the PQ ratchet on
the wire (S9, Rust-only per ADR 0016), doorbell and KCI (S10) are open.
`cairn-r1` is unreleased, so wire changes need no migration, only a spec
change-log entry.

## 3. Working with this owner

- `CONSTITUTION.md` and `AGENTS.md` bind. In practice that means:
  - test first, and show the test failing for the intended reason before
    the fix;
  - **100 % line and branch coverage** in Rust (llvm-cov) and Kotlin (Kover);
  - an ADR or ADR amendment, plus a spec OI and change-log entry, for every
    protocol, crypto, wire or radio-policy decision **before** the code;
  - Conventional Commits with the Copilot co-author trailer, a feature
    branch, squash merge, no force-push.
- The owner has pre-authorised commit, push and opening PRs. **Merge only
  when asked**; the usual request is "merge PRs, delete branch and pull main".
  New ADRs start as `proposed`; the owner accepts them ("mark it accepted").
- Answers are short and concrete, with numbers and a recommendation. When
  something is unknown, say so and name the evidence that would settle it.
- Device substitutions come from the owner (for example the iPhone SE 2020
  on iOS 18.7.8 replaced another device). Use the device you are told to.
- Write prose in short plain sentences; the docs follow Diátaxis
  (`docs/README.md`).

## 4. Gates and commands

These are the commands the PRs up to `a77b25f` (#96) passed.

```sh
# Rust (from the repo root; the script cds into core/; it lacks +x)
bash scripts/check-rust.sh
# Coverage: run from core/, else llvm-cov reads a stale report
cd core && cargo +nightly-2026-10-08 llvm-cov --workspace --all-features --locked --branch --json --summary-only
# Miri: set soft hash backends, else it reports false UB in sha2 NEON code
export RUSTFLAGS='--cfg sha2_backend="soft" --cfg keccak_backend="soft"'
# Constant-time harness (valgrind; Linux)
bash scripts/check-ct.sh

# Gradle gates
./gradlew :sdk:jvmTest :sdk:koverVerify :androidBle:testDebugUnitTest :androidBle:koverVerifyDebug \
  :androidBle:lintDebug :androidApp:testDebugUnitTest :androidApp:koverVerifyDebug
# Dependency floors after any Gradle or dependency change
./gradlew --no-configuration-cache --init-script proofs/bindings/linux-android/resolve-repository-inputs.gradle cairnResolveRepositoryInputs
# Device APK
./gradlew :androidApp:assembleDebug -PandroidAbis=arm64-v8a,armeabi-v7a

# iOS simulator tests and device build
cd iosApp && xcodebuild -project CairnIos.xcodeproj -scheme CairnIos -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test
cd iosApp && xcodebuild -project CairnIos.xcodeproj -scheme CairnIos -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/cairn-ios-dd DEVELOPMENT_TEAM=7ZX3WPAP4Y -allowProvisioningUpdates build -quiet
xcrun devicectl device install app --device <UDID> /tmp/cairn-ios-dd/Build/Products/Debug-iphoneos/CairnIos.app
```

- The pre-commit hook (`.githooks/pre-commit`) runs the Rust gates and
  cargo-deny; expect commits to take a while.
- `scripts/check.sh` is the proof and model gate; Tamarin replays are opt-in
  (`docs/spec/models/ENVIRONMENT.md`).
- Kover counts `?.` on a never-null value as an uncovered branch; use `!!`
  with a comment.
- Workspace Clippy denies `all`; fixed-length crypto conversions use
  `.expect("fixed length")`.
- CodeQL `build-mode: none` silently skips Kotlin; Kotlin needs the
  build-backed lane (ADR 0015). The slowest CI job is
  `kotlin-analysis / prepare (codeql)`, about 1 h.
- `.cargo/config.toml` sets `AWS_LC_SYS_NO_JITTER_ENTROPY=1` (ADR 0024).
  Keep it: AWS-LC's jitter source aborted the app on a Kirin phone (issue 51).
- Robolectric: `ShadowBluetoothGattServer.responses` records only values,
  and `ShadowBluetoothGatt.writeCharacteristic` always reports status 0, so
  status-sensitive tests need overriding fakes. Failure details are in
  `androidBle/build/test-results/testDebugUnitTest/*.xml`.
- On macOS, BSD `sed` lacks `0,/re/`; use Python for single in-place
  replacements. `gh pr merge --delete-branch` deletes the local branch too.
- `PROJECT.md` is mostly a dated log of proof and CI runs. Read it for
  provenance, but take everyday commands from here or the scripts.

## 5. Devices and fleet runs

- Roster and rationale: [issue 13](../../.scratch/cairn-r1/issues/13-device-test-lab.md).
  The phones used most recently are:
  - Android: Redmi `2201117TY` (Android 13), Pixel 6 (Android 17).
  - iPhone: 12 mini (iOS 27), SE 2020 (iOS 18.7.8), iPhone 15 (iOS 17),
    iPhone X (iOS 16).
- The adb server is remote: `ADB_SERVER_SOCKET=tcp:192.168.50.100:5037`.
  Wi-Fi phones are at `192.168.50.x:5555`.
- The fleet scripts are **not in the repo**. They live in the session store
  `~/.copilot/session-state/5f760c7e-c0a8-4133-950c-99f35cd77969/files/fleet-scripts/`
  (`orun.sh`, `orun-full.sh <tag> <serial> <mini|se|15|x> [secs]` with
  `APK=` set). Run them as `bash orun-full.sh …`; `./` fails on permissions.
  Logs land in `/tmp/pair/{a,af,i}_<tag>.log`. Use a fresh tag per run;
  reused tags mix old logs into new results.
- The first iOS launch after an install runs only the self-test; discard
  that run.
- `devicectl` error 4016 ("unavailable") means the iPhone is locked or
  asleep; ask the owner to wake it.
- The iPhone X builds from `project-se.yml` with another team, installs
  through pymobiledevice3, and needs its developer disk image remounted
  after a reboot.
- `kill` needs a numeric PID; `pkill` is not allowed in this environment.

**Run discipline:**
- Compare a fix against `main` on the same devices: same number of runs,
  fresh tags, Bluetooth state reset between contaminated runs.
- Count both pairs **and** drops; a pairing that completes and then loses
  its link is a failure.
- Record installed third-party BLE apps; Life360 caused the issue 57 drops.

## 6. Radio lessons: symptom, cause, fix

The first hypothesis was wrong in most of these. Each lesson below is: get
link-layer evidence before changing protocol code.

| Symptom | First guess | Actual cause | Fix |
|---|---|---|---|
| Two Androids both fail `connectGatt` with 133 and retry in step 120 s later (issue 50) | flaky stack | symmetric simultaneous dials with identical back-off | randomised retries 1–5 s, then 5–15 s, then 2 min (§10.4, OI-28) |
| App aborts with SIGABRT at start on the P10 lite (issue 51) | memory bug | AWS-LC CPU-jitter entropy failed its health test | OS entropy only (ADR 0024) |
| Fleet pairing plateaus; links time out pre-auth (issues 52, 53) | 5 s pre-auth limit too tight | GATT slot exhaustion; a pairing takes ~1.1 s | slot budget 5 (API ≤ 34) / 6 (35+), eviction, stable slots (ADR 0025, 0030, 0031); 36 → 49 pairs |
| iOS never sees an extended Android advert although `supports(.extendedScanAndConnect)` is true (issue 33, 56) | UUID filter bug | Core Bluetooth reports extended adverts only when the auxiliary packet is on LE 2M (WWDC19 session 901, undocumented elsewhere) | Android moves its aux packet to 2M while it sees iOS (ADR 0038) |
| Status 133 on Android 8/9 dials to iPhones (issue 58) | generic 133 | HCI `0x3E`, connection failed to be established; Bluedroid can't tell two ACLs to one address apart | Android waits 10 s for iOS to dial first (ADR 0039) |
| A link that came up drops when a crossed dial closes (issue 58) | peer closed | `BluetoothGatt.close()` removes the app's hold; with no holder the stack drops the shared ACL | keep the shared link (ADR 0023 amendment) |
| Link lost to supervision timeout stays down for 2 min | needs prevention | supervision timeouts happen; recovery was slow | redial after 1–5 s (ADR 0040); iOS backs off 45 s on `connectionTimeout` |
| `authentication` closes between iPhones and the Redmi (issue 59) | crypto or MAC bug | the Redmi's controller corrupts a 50–215 B block in some 512 B writes; the link-layer CRC still passes | CRC-16 per fragment, ATT error `0x9E`, up to 3 rewrites (ADR 0042) |
| Only one side stores a contact after pairing (issue 58) | lost frame | two-generals: the last frame can always be lost | contact stays provisional until the first Resume message (ADR 0043) |
| A holds two contacts for B; A's Resumes fail `Unknown` forever (issue 60) | beacon bug | S2 lost after A committed; `beacon::find` returns the first match | a new pairing deletes orphan contacts (ADR 0044, proposed) |
| Pixel 6 ↔ SE 2020 links drop at 7.4–7.8 s (issue 57) | supervision timeout or auth | Life360 briefly became the link's only ACL holder; when it left, the stack closed the link locally (HCI `0x16`) | the GATT server holds inbound links with `server.connect(device, false)` (ADR 0023 amendment) |

**Rejected ideas.** Each of these was built and then lost a fleet A/B. Bring
new evidence before proposing one again:
- congestion controllers that back off advertising and dials (ADR 0026);
- dropping a dial when its target stops advertising (ADR 0029);
- a full radio that stays visible (ADR 0032).

**Diagnostics that worked:**
- Close reasons (ADR 0041) show up in logs as
  `link N close requested (<reason>)`. Read them first.
- Android `adb shell dumpsys bluetooth_manager` gives:
  - per-link disconnect reasons (`reason:22` = `0x16` local host,
    `19` = remote);
  - `ACL holders`;
  - other apps' GATT registrations;
  - on most phones, a `BTSNOOP_LOG_SUMMARY` (base64, 9-byte header, then
    zlib).
  The Pixel 6 has no summary. A full snoop needs
  `setprop persist.bluetooth.btsnooplogmode full`, a Bluetooth toggle and
  `adb bugreport`.
- iOS error codes:
  - `CBError` 6 is `connectionTimeout` and 7 is `peripheralDisconnected`;
  - Apple's syslog link status is `700 + HCI code`.
- Android's server side reports a supervision timeout as status `0x00`.
- Address rotation: an iPhone's rotated RPA is a separate link, not a
  duplicate, so address equality is not peer identity.

**Platform facts to design around:**
- iOS can't advertise service data, can't disconnect a central from its
  GATT server, and reports a 512 B with-response write length whatever the
  MTU. Use the without-response length + 3 as the link MTU (OI-39).
- In S3, iOS advertises only the fixed service UUID, foreground only; the
  beacon UUID and background operation are S6 work (§10.4, issue 04).
- A GATT server does not hold an ACL the peer opened until it calls
  `server.connect(device, false)`.
- Android ≤ 28 has a single dial slot; one failed `0x3E` dial blocks it.

## 7. Crypto choices and rejected alternatives

Researched 2026-10-31 at the owner's request; the conclusion was to keep the
suite as is. Payload baseline: pairing 2,563 B, Resume 57 + 49 B, DATA +17 B,
ratchet step 2,272 B.

| Candidate | Outcome | Why |
|---|---|---|
| ML-KEM-512 | rejected | saves ~700 B per pairing (−27 %) and per ratchet step (−31 %), about one GATT fragment per pairing message; drops to level 1 below the rest of the suite, and X-Wing has no 512 variant, so we would own a combiner |
| SMAUG-T (KpqC winner, MLWE+MLWR) | rejected | only ~8 % smaller at level 3; national (Korean) standard only; Meet-LWE attacks hit some round-2 parameters; reference keygen sampler has a seed-dependent rejection loop; ~3× slower than aws-lc ML-KEM-768 on M1 |
| NTRU+ | rejected | larger than ML-KEM at matched level |
| HQC, BIKE, Classic McEliece | rejected | larger keys or ciphertexts; HQC standard not before ~2027 |
| SQIsign (`../the-sqisign`) | rejected | a signature, not a KEM; adding it grows pairing to 3,129 B; its mp and quaternion layers are not constant-time |
| CSIDH/CTIDH | rejected | small, but slow and its post-quantum security level is disputed |

Rules that came out of the crypto work:
- Use established primitives only, no novel crypto, and stay
  FIPS-approvable: ML-KEM is the approved component of the hybrid.
- Pin known-answer vectors (X-Wing draft-11, ACVP) before writing a backend.
  The order of concatenated components is where composite KEMs break.
- Symbolic proofs say nothing about constant-time behaviour, parsers or
  persistence. Constant-time is gated separately (ADR 0007, `core/ct`,
  `scripts/check-ct.sh`) and parsers by fuzzing (`core/fuzz`).
- Compare secrets in constant time even in "harmless" lookups; for example
  `orphans_of()` compares beacon keys in constant time.

## 8. Proof and verification lessons

- Claim exactly what was rerun. A green aggregate hid unverified helper
  lemmas more than once; name the command, revision and result.
- Tamarin runs are slow and vary with the host. Run one heavy proof at a
  time on the 8 GiB machine. Classify a failure as timeout, teardown or
  kernel-check before acting on it, and reproduce it without the wrapper
  scripts.
- Modelling bugs look like protocol bugs. Untyped epochs, a non-atomic
  candidate commit and a dropped `LockStage` marker each produced false
  counterexamples or false proofs. Diff the model against the spec when a
  result surprises you.
- CI green, simulator green and device green are three different claims.
  Radio behaviour is proven only by device runs.

## 9. Keeping this file alive

Update it in the same PR as the change that makes a line stale: a new ADR
that supersedes a radio rule, a new gate command, a device change. Prune
lines that no longer change what an agent does.
