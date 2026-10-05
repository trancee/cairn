# Research: Can Kompact shrink `pqcble-r1` payloads, and where should it sit?

Status: research draft, not an approved design. No ADR exists yet. Any
adoption requires an ADR (Constitution O3) and expert review before being
treated as a decision. This answers ticket
`.scratch/pqcble-r1/issues/14-kompact-payload-encoding.md`.

Subject: [Kompact](https://github.com/trancee/kompact), a Kotlin
Multiplatform library for "LSB-first bit-packed messages" with KSP-generated
schemas, fixed and framed layouts, version 0.6.1 (public domain). Findings
below come from cloning the repo (`git clone --depth 50
https://github.com/trancee/kompact`) and reading its runtime source, KSP
codegen, docs, tests, CI config, and GitHub metadata (`gh api
repos/trancee/kompact/...`) directly, on 2026-10-05.

**Headline finding:** on every message already sketched in
`2026-10-05-pqc-over-ble-findings.md` §4 (S1, S2, data-frame header,
doorbell, beacon), Kompact saves **0 bytes**, because those layouts are
already minimal byte-aligned headers in front of high-entropy keys/MACs/
ciphertext, and bit-packing cannot shrink random bytes. The only place
Kompact's framing primitives could plausibly matter is the **chat message
envelope**, which isn't designed yet — and even there, a hand-rolled
presence bitmap in Rust achieves the same thing with none of the
cross-language/dependency risk. Recommendation: **don't adopt it** for the
Rust/Kotlin wire-compatibility layer (option d); treat a possible
Kotlin-only use on already-decrypted chat plaintext (option a) as optional
UI-layer polish, not an architectural dependency.

---

## 1. Exact wire format

**Bit order**: confirmed LSB-first, byte-granular bit-packing, independent
of platform endianness. `kompact/src/commonMain/kotlin/ch/trancee/kompact/runtime/KompactRuntime.kt:1-15`
(doc comment) and the `readBits`/`writeBits` implementations
(`KompactRuntime.kt:17-65`): byte 0 holds bits 0-7, bit 0 of each byte is the
LSB of the field; every byte is masked with `and 0xFF` before shifting so
JVM and Kotlin/Native produce bit-identical output. Multi-byte scalars
(`readBitsLong`/`writeBitsLong`, `KompactRuntime.kt:97-154`) use the same
LSB-first order up to 64 bits — it's a pure bitstream, with no separate
byte-endianness concept. Confirmed again in `README.md:1-3` ("LSB-first
bit-packed messages") and the worked example in
`docs/getting-started.md:9-33` (`[0xA5, 0x40]` for a 4-bit + 10-bit + 1-bit
packed frame).

**Fixed-layout messages**: declared with absolute `bitOffset` + `bitWidth`
per field (`docs/architecture.md:9-14`, `docs/api-reference.md:22-24`).
Granularity is **bits**, not bytes — fields can straddle byte boundaries
(the getting-started example has a 10-bit field starting at bit 4). Size is
validated once when a generated view is constructed
(`docs/architecture.md:12-13`).

**Framed-layout messages**: sequential, not offset-table based. Each field
declares a contiguous `order` (`docs/how-to/define-framed-schema.md:9-46`).
Variable-length fields (`String`, `ByteArray`, nested message, repeated)
carry an explicit **fixed-width** length/count prefix of **8, 16, or 32
bits, little-endian**, chosen per-field at schema-authoring time —
`KompactFraming.kt:28-32` (`VALID_PREFIX_WIDTHS = {8,16,32}`) and
`readLengthPrefix`/`writeLengthPrefix` (`KompactFraming.kt:40-82`).

**No varint/LEB128 anywhere — explicitly rejected by design.** A repo-wide
grep for varint/LEB128/zigzag across source and Markdown finds zero shipped
implementation; the only hits are design-history notes under `.scratch/`:
`.scratch/kompact-spec/issues/05-variable-length-framing.md:22` ("Length-
prefix — fixed-width little-endian, width declared per-field... Varint is
rejected: its loop-based decode and variable CPU conflict with the
zero-allocation / predictable-read ethos, and Kompact's reader is
fixed-width single-pass.") and
`.scratch/kompact-v1/issues/03-arbitrate-framing-prefix-widths.md:48`
("24-bit / LEB128 / bit-length prefixes are wire-incompatible (MAJOR)...
Arbitrary/LEB128 widths stay deferred (out of v1 scope)."). There is **no
adaptive integer encoding at all** — only a smaller *fixed* bit-width
chosen up front, which a hand-rolled layout can do without Kompact.

There is no discriminant/message-type tag mechanism beyond an ordinary
scalar/enum field the schema author places manually
(`KompactWriter.writeScalar`, `KompactRuntime.readScalar`,
`ScalarType.of(bits, signed)` in `ScalarType.kt`) — plain bits at a
declared width, not a special varint or tagged-union discriminant.

**Optional/absent fields — not a first-class concept.** Framed schemas are
strictly positional and all fields are required:
`docs/architecture.md:80-87` ("Framed schemas are positional and strict:
field order and declared types form the wire contract, and fields are
required... Kompact does not add a schema-version discriminator"). No
presence-bitmap, nullable marker bit, or tagged-union/sentinel convention
exists in the runtime or codegen (`kompact-ksp/src/main/kotlin/ch/trancee/kompact/ksp/model/KompactFieldInfo.kt`,
`ModelSpec.kt`; grep for `optional|nullable|presence` across `kompact/` and
`kompact-ksp/` returns nothing relevant). Any optional-field scheme must be
hand-built by the schema author with plain scalar/bool fields.

**Alignment/padding**: no implicit byte-alignment between fields; fields
pack contiguously bit-by-bit. Byte alignment is required only for specific
operations: variable-length regions must start byte-aligned
(`KompactFrame.kt:36-40`, `region()` throws `BadLengthPrefix` if
`cursor % 8 != 0`), and borrowed (blob/nested) fields require byte-aligned
starts (`docs/adr/0008-framed-generated-views.md`). No word-alignment
scheme beyond that.

**Versioning/schema evolution — none; explicitly deferred.**
`docs/adr/0002-defer-versioning-surface-to-v2.md:1-70`: no
`UnsupportedSchemaVersion` error case, no stream version prefix;
`writeLengthPrefix`/`readLengthPrefix` "write and read only the per-field
payload byte-count; no byte in the frame encodes a schema/frame version."
Appending a field is explicitly **not safely compatible**: an older reader
rejects trailing data via `requireComplete()` (`KompactFrame.kt:111-116`),
and a newer reader has no way to default a field an older sender omitted
(`docs/architecture.md:80-87`; `docs/how-to/define-framed-schema.md:149`,
"Appending an optional field is not [safe]..."). No unknown-field-skipping,
no schema hash. **Strictly fixed-schema, compiled-in, zero-evolution** as
of 0.6.1/0.7.0-SNAPSHOT.

**No entropy coding — confirmed.** A repo-wide grep for
`huffman|entropy.cod|arithmetic.cod|range.cod|compress` returns zero
matches. The only operations on field bytes are the LSB-first bit-shift/
mask assembly in `KompactRuntime.kt:17-154` and the byte-aligned
`copyInto`/manual byte loop in `KompactWriter.kt`
(`appendRegion`, ~lines 230-245) — pure structural repositioning of bits,
no statistical/variable-length symbol coding. This is a definitive
confirmation Kompact is **purely structural bit-packing**, not compression
(see §5 for the compression-oracle implication).

**Checked decode / malformed-input behavior — generally safe, with one
caveat**:
- Bounds computations in the checked path use `Long` arithmetic to avoid
  `Int` overflow on buffers ≥256 MiB: `fits()` in
  `KompactRuntime.kt:146-151` (`bitOffset.toLong() + bitWidth.toLong() <=
  raw.size.toLong() * 8L`), exercised by
  `KompactRuntimeBoundsHardeningTest.kt:1-27`.
- `KompactFraming.nestedRegionOrNull` guards against a length-prefix count
  whose `byteCount*8` would overflow signed `Int`
  (`KompactFraming.kt:112-121`).
- `KompactFrame` throws `KompactDecodeException` on any bounds/prefix/UTF-8
  violation during direct reads (`KompactFrame.kt:18-28`, `:36-40`,
  `:50-56`), but the block overload `KompactFrame.decode(raw, start, end,
  block)` (`KompactFrame.kt:158-166`) catches it and returns a typed
  `KompactFrameResult.Failure` — the documented "checked" path for untrusted
  input (`docs/how-to/handle-decode-errors.md`, `docs/architecture.md:16-22`).
- `KompactDecodeError` is a closed sealed hierarchy: `BoundsError`,
  `BadLengthPrefix`, `TruncatedNested`, `InvalidUtf8`, `UnknownEnumCode`
  (`KompactDecodeError.kt:16-24`) — fail-fast, never silent.
- No infinite-loop risk: every bit/byte loop is bounded by a validated
  `remaining`/`count`; `readRepeated` checks `count > (endBit - cursor) /
  minimum` before iterating (`KompactFrame.kt:73-76`), so a malicious huge
  count fails fast as `TruncatedNested`.
- **Caveat**: both checked (`Result`-returning) and throwing convenience
  APIs exist side by side (`docs/api-reference.md:14-17`). A caller using
  the throwing/direct `KompactFrame` reads outside a `decode { }` block, or
  calling `getOrThrow()` without try/catch, gets an uncaught
  `KompactDecodeException` on malformed input. This is a caller-discipline
  risk, not a defect in the checked surface.

**Allocation behavior — mixed, and explicitly unproven by the project's own
admission**:
- Fixed-layout reads/writes operate directly on the caller's `ByteArray`
  with no intermediate object creation; `KompactWriter` uses one growable
  internal `ByteArray` (doubling strategy, `ensureCapacityBits`,
  `KompactWriter.kt` ~lines 207-215), returning an exact-length copy only on
  `build()` (`KompactWriter.kt:171-178`).
- Framed/generated views and byte slices are **borrowed, not copied**
  (`docs/architecture.md:46-55`); repeated-field views decode lazily
  (`docs/adr/0008-framed-generated-views.md`).
- BUT: `docs/research/allocation-boxing-measurement.md:1-10,34-42` states
  plainly "Kompact cannot promise that a value class is allocation-free in
  every call shape... Allocation-free behavior remains unproven for every
  target; do not make a target-specific zero-allocation claim from these
  checks." `docs/ci.md:64-70` reiterates allocation is not CI-measured on
  any target. Kotlin boxes value-class results at generic/interface/
  nullable boundaries (`docs/architecture.md:70-78`).
- Net: architecturally allocation-conscious, but unproven on Android ART or
  iOS Kotlin/Native specifically — treat zero-allocation as an intent, not
  a guarantee.

---

## 2. Byte-savings estimate per `pqcble-r1` message

| Message | Hand-designed size | Kompact-packed size | Savings | Why |
|---|---|---|---|---|
| Resume S1 (`type\|pseudonym(8)\|eI(32)\|mac(16)`) | 57 B | 57 B | **0 B** | `type` already occupies one byte alone (no other sub-byte field to share it with); `pseudonym`/`eI`/`mac` are high-entropy fixed-width fields bit-packing cannot shrink. |
| Resume S2 (`type\|eR(32)\|confirm(16)`) | 49 B | 49 B | **0 B** | Same reasoning. |
| Data frame header (`type\|key-phase\|pad-class`, 1 B) | 1 B | 1 B | **0 B** | If `type` needs ≤2 bits, `key-phase` 1 bit, `pad-class` 2-3 bits, that's ≤6 bits — already fits the existing 1-byte hand layout via ordinary shifts/masks. Kompact could express this declaratively with adjacent `bitOffset/bitWidth` fields, but produces the same 1 byte; there's no leftover sub-byte field to reclaim. |
| Ciphertext + tag (incl. amortized ML-KEM-768 `ek`/`ct` chunks) | padded to size class | unchanged | **0 B** | High-entropy ciphertext/KEM material; not structurally packable, and must never be touched by anything size-revealing before the fixed-size-class padding (§5). |
| Beacon (8–16 B truncated PRF) | 8–16 B | unchanged | **0 B** | Pure high-entropy bytes, no structure. |
| Doorbell (`beacon(8)\|ctr(4)\|tag(8)` = 20 B) | 20 B | 19–18 B if `ctr` hand-shrunk to 24/16 bits | **1–2 B, if bounded** | Kompact has no varint (§1) — it cannot adaptively shrink `ctr`; its only lever is a smaller **fixed** bit-width chosen at schema time (e.g. 24 bits instead of 32), which saves 1 byte only if doorbell-counter values can be bounded below 2^24 over the counter's rollover policy, and is achievable by hand-rolled bit-packing with no need for Kompact at all. A true LEB128 varint would cost 1 byte per 7 bits and could occasionally beat a fixed 32-bit field for small values, but Kompact doesn't offer varints, so no such trade is available through this library. |
| Chat message envelope (undesigned: reply-to ID, attachment ref, timestamp, read-receipt flag, etc.) | not yet designed | plausibly meaningful | **design-dependent — the only real candidate** | Framed layout (length/count prefixes, nested messages, repeated fields — `docs/how-to/define-framed-schema.md:9-46`) can express conditional fields, but only via hand-built sentinels (zero-length string/blob, or a manually placed presence byte), since Kompact has no native optional/nullable/tagged-union primitive (§1). The actual bytes saved depends entirely on how many of the candidate optional fields are typically absent — not quantifiable before the envelope is designed. |

### Airtime/PDU translation (`docs/research/ble_airtime.py`)

Computed via a local snippet importing `pdu_count`/`airtime_microseconds`
from the script (script itself unmodified):

| Case | Size | PDUs@251 (2M DLE) | PDUs@27 (legacy) | Airtime@2M | Airtime@1M |
|---|---:|---:|---:|---:|---:|
| Doorbell, ctr=4 B (hand-designed) | 20 B | 1 | 1 | 0.500 ms | 0.684 ms |
| Doorbell, ctr=3 B (hand bit-pack) | 19 B | 1 | 1 | 0.496 ms | 0.676 ms |
| Doorbell, ctr=2 B (aggressive) | 18 B | 1 | 1 | 0.492 ms | 0.668 ms |
| Resume S1 | 57 B | 1 | 3 | 0.648 ms | 0.980 ms |
| Resume S2 | 49 B | 1 | 2 | 0.616 ms | 0.916 ms |
| S1+S2 combined | 106 B | 1 | 5 | 0.844 ms | 1.372 ms |

**Conclusion: every quantifiable Kompact-enabled saving here is
airtime-irrelevant.** Shrinking the doorbell counter by 1–2 bytes saves
only 4–8 µs at 2M PHY and changes **zero** PDU counts at either PHY (20 B
and 18 B both fit in 1 PDU at 251 B DLE and 1 PDU at 27 B legacy, since both
are < 27). S1/S2 are already single-PDU at DLE 2M PHY and Kompact offers
zero bytes of savings on them. The only place a Kompact-style design choice
could plausibly cross a PDU boundary is the chat envelope — which doesn't
exist yet to measure.

---

## 3. Maturity

**Tests**: an extensive unit/round-trip/golden/property suite —
`kompact/src/commonTest/kotlin/ch/trancee/kompact/runtime/` has ~25 test
files covering cursor boundaries (`KompactCursorBoundaryTest.kt`), framing
edge cases (`KompactFramingEdgeCaseTest.kt`), bit primitives
(`KompactRuntimeBitPrimitivesTest.kt`), a dedicated 256 MiB/Int-overflow
bounds-hardening test (`KompactRuntimeBoundsHardeningTest.kt:1-27`), and a
golden-bytes pinning test for the getting-started example
(`docs/getting-started.md:35-37`: "The executable `GettingStartedTest`
pins these bytes so a wire-format change cannot silently make the example
stale"). `docs/ci.md:30-32` states Kover enforces **100% line and branch
coverage** for the runtime and KSP modules. A separate `mutflowTest` source
set runs mutation testing (MutFlow) for the core runtime classes
(`kompact/build.gradle.kts:29-55`, `docs/ci.md:72-83`), though it is opt-in,
not a CI gate.

**Fuzzing**: **none in shipped code.** A repo-wide grep for `fuzz|Fuzz`
finds only design-history notes describing fuzzing as planned, not done:
`.scratch/kompact-spec/issues/16-grok-review-synthesis.md:40` lists "fuzz
infra" as open work; `.scratch/kompact-v1/map.md:42` calls continuous fuzz
a "mandatory v1 merge gate" — but no AFL/libFuzzer/kotlinx-fuzz harness
exists in the actual source tree, and the one
`KompactRuntimePropertyTest.kt` found uses plain `kotlin.test` assertions,
not a property-based framework (no `Arb`/`forAll`/Kotest) — a hand-written
parametrized test, not true property-based fuzzing.

**Checked-decode/malformed-input**: see §1 — a well-designed typed-error
path exists, but a throwing API surface exists alongside it and the caller
must opt into `decode{}`/`Result` methods for safe behavior.

**Allocation behavior**: architecturally allocation-conscious but
explicitly unproven on any target per the project's own
`docs/research/allocation-boxing-measurement.md` and `docs/ci.md:64-70`.

**KMP targets actually declared and CI-tested**:
`kompact/build.gradle.kts:84-87` declares only `jvm()`, an `android` library
target, `iosArm64()`, `iosSimulatorArm64()`, and `androidNativeArm64()`.
**No `iosX64` (Intel simulator), no `linuxX64`/`macosX64`/`macosArm64`, no
`mingwX64`, no `js`, no `wasmJs`.** Critically, **iOS/Native targets are
compiled/ABI-validated only, never behavior-tested in CI**:
`docs/ci.md:56-66` — "The Linux and macOS CI checks compile or validate
target artifacts... but they do not substitute for runtime behavior tests
on physical iOS Arm64 or Android Native Arm64 devices. The runtime's common
tests currently execute on the JVM..." This matters directly for `pqcble`,
which targets iOS 15+ via Kotlin/Native — Kompact's iOS path has never run
a test in anger.

**Maintainer activity — very young, essentially solo, no external adoption
signal**:
- Repo created **2026-08-30** — about 5 weeks old at research time
  (2026-10-05). Source: `gh api repos/trancee/kompact` → `created_at:
  2026-08-30T16:17:21Z`.
- Last push **2026-10-05T13:48:49Z** — actively maintained right now, but
  over only a 5-week window.
- **15 tags/releases** in 5 weeks, `v0.1.0` → `v0.7.0`
  (`gh api repos/trancee/kompact/tags`); latest Maven-Central release is
  `0.6.1` (2026-10-04, `CHANGELOG.md:19`), with `0.7.0-SNAPSHOT` as an
  unpublished dev version (`README.md:38-40`).
- **Single human contributor**: `gh api repos/trancee/kompact/contributors`
  → `trancee: 110 commits`, plus `github-actions[bot]: 32`,
  `dependabot[bot]: 6`. No other humans.
- **Zero community signal**: `gh repo view` → `stargazerCount: 0`,
  `forks_count: 0`, `issues.totalCount: 0`. All 87 items returned by the
  issues API are actually pull requests (`pull_request != null` for every
  one, `gh api repos/trancee/kompact/issues?state=all`) — no real
  user-filed issues, every PR is the maintainer's own self-merged work
  (the repo even ships `.github/agents/mutation-testing-*.agent.md`,
  consistent with an agent-assisted solo workflow).
- Net: engineering discipline (ADRs, 100% coverage, mutation testing,
  changelog) is unusually rigorous for 5 weeks old, but there is no
  track record of surviving a breaking change or external-consumer
  feedback, and "active vs. abandoned" isn't yet a meaningful distinction —
  the real risk is unknown long-term commitment from one person.

---

## 4. Fit with the Rust core

**(a) Kompact only for app-layer plaintext (chat envelope) inside AEAD, in
Kotlin.** The most defensible usage given the findings. The format's spec
is simple enough to state precisely — "LSB-first bit assembly + fixed-width
8/16/32-bit LE length/count prefixes, no entropy coding, no versioning"
(§1) — and if confined to already-decrypted, already-authenticated
plaintext on the Kotlin side, none of the compression-oracle or
length-side-channel risks in §5 apply. The Rust sans-IO core never needs to
know about Kompact at all — the chat envelope is opaque bytes to it (it
just encrypts/decrypts the blob). This avoids cross-language
wire-compatibility risk for a 5-week-old library with no committed
language-independent spec.

**(b) A Rust implementation of the Kompact wire format so the core codec
stays byte-compatible.** Feasible but costly: the format itself is simple
to reimplement (an LSB-first bit read/write loop is ~30 lines of Rust;
fixed 8/16/32-bit LE length prefixes are trivial), **but there is no
independent byte-level spec document** — `docs/architecture.md` and the API
reference describe behavior in prose, and the authoritative "spec" is
effectively the Kotlin source plus its pinned golden-byte tests
(`GettingStartedTest.kt`). A Rust port would have to be validated against
those same golden vectors and would silently drift if Kompact's Kotlin side
evolves — ADR-0002 explicitly defers any wire-versioning mechanism, so
there's no compatibility guard-rail to pin against. Given the library is
pre-1.0, single-maintainer, and 5 weeks old, shadowing its evolving wire
format in Rust is a maintenance liability disproportionate to the
near-zero byte savings in §2.

**(c) One schema generating both sides (KSP backend emitting Rust).** Not
realistic without major new work. KSP
(`kompact-ksp/src/main/kotlin/ch/trancee/kompact/ksp/KompactSymbolProcessor.kt`
and `gen/*.kt`) is strictly a Kotlin-compiler-plugin tool: it resolves
`KSAnnotated`/`KSClassDeclaration` from the Kotlin compiler's
symbol-processing API and emits Kotlin `FileSpec`s via KotlinPoet
(`ValueClassGenerator.kt`, `FramedClassGenerator.kt`). There is no IR/
schema-description intermediate representation that could be retargeted to
a Rust codegen backend — `KompactModelParser.kt` parses Kotlin annotations/
property declarations directly. A Rust backend reading the same
`@KompactModel`/`@KompactField` annotations is conceivable in principle but
is a multi-month greenfield project, not something achievable by consuming
Kompact as a library, and no such backend or RFC exists in the repo.

**(d) Don't use it.** Fully reasonable given the findings: quantified
byte/airtime savings on every already-sketched message are either exactly
0 bytes or sub-PDU/airtime-irrelevant (§2); the zero-evolution/versioning
gap (§1) is a real long-term liability for a protocol field intended to
evolve (the chat envelope); there's no independent language-neutral wire
spec (§4b), making a Rust-side mirror a long-term shadow-maintenance
burden for no quantified benefit; and the library carries 5-week-old,
single-maintainer, zero-stars/zero-forks supply-chain risk (§3)
disproportionate to the gain.

**Ranking**: (d) is the safe default. (a) is acceptable *if and only if*
there's a specific ergonomic desire for Kompact's declarative bit-packing
on the Kotlin side for the as-yet-undesigned chat envelope, used strictly
on already-AEAD-verified plaintext, never touching nonces/counters/
padding-class decisions in the Rust core. (b) and (c) are not recommended.

---

## 5. Security

**Entropy coding — confirmed absent (answers the compression-oracle
question definitively).** As established in §1, an exhaustive grep of the
shipped source and docs for
`huffman|entropy.cod|arithmetic.cod|range.cod|compress` returns zero
matches, and the only data-transforming operations in the runtime are the
LSB-first bit-shift/mask routines
(`kompact/src/commonMain/kotlin/ch/trancee/kompact/runtime/KompactRuntime.kt:17-154`)
and the byte-aligned copy path in `KompactWriter.kt` (`appendRegion`).
These are pure structural bit repositioning — output size is a
deterministic function of the **declared schema** (bit widths,
length-prefix widths), never of the **content/redundancy** of field
values. There is therefore **no CRIME/BREACH-style compression-oracle
risk**: Kompact cannot leak information about secret plaintext through
variable output size driven by plaintext compressibility, because it does
no compression at all.

**"Verify-then-parse" — caller discipline, not something Kompact enforces,
but its API shape makes this easy to respect.** Kompact's API is not
streaming/incremental: `KompactFrame.decode(raw, start, end)` and the
scalar/framed readers operate on a **complete, already-materialized
`ByteArray`** (`KompactFrame.kt:140-150`) — there is no partial-buffer
parser invokable before a full AEAD tag is available. This naturally
supports "AEAD-open the entire ciphertext into a plaintext `ByteArray`,
then call `KompactFrame.decode(plaintext) { ... }`" — there's no API
surface encouraging parsing before authentication completes. Kompact
itself, however, has no enforcement mechanism: nothing prevents a careless
caller from calling `KompactRuntime.readScalar` directly on raw,
unauthenticated transport bytes before AEAD verification. `pqcble-r1`'s
implementation must impose this discipline at call sites (only ever
construct a `KompactFrame`/call generated `decode()` on the output of a
successful `aead_open`).

**Length leakage vs. padding-size-classes.** Kompact's framed length/count
prefixes (8/16/32-bit, `KompactFraming.kt`) faithfully encode the actual
length of a variable-length field. Used inside the chat envelope, this
doesn't by itself defeat `pqcble-r1`'s size-class padding, provided padding
is applied to the *final encrypted ciphertext* — pad-class determines
total on-wire frame size; Kompact's internal length prefixes are inside the
ciphertext and invisible to a network observer. The risk that does apply is
general, not Kompact-specific: if padding-class selection is itself driven
by a plaintext length that reflects variable-length content (e.g. an
attachment-reference length an adversary can influence), that could leak
which size class a message falls into — any variable-length encoding,
hand-rolled or Kompact-based, has this property equally; Kompact neither
worsens nor improves it.

**Constant-time concerns.** Kompact's bit-reader is not content-branching
for scalar/structural operations: `KompactRuntime.readBits`/
`readBitsLong`/`writeBits` (`KompactRuntime.kt:17-154`) have loop structure
and shift/mask amounts that depend only on `bitOffset`/`bitWidth`
(public, schema-fixed values), never on the data itself — data-independent
timing for fixed-schema scalar fields. However,
`KompactUtf8Validator.isValid` (`KompactUtf8Validator.kt:4-72`) branches
heavily on the **value** of each byte (`when { first <= 0x7F -> ...; first
in 0xC2..0xDF -> ...; ... }`), with a data-dependent iteration step
(`index += 2/3/4`). This matters only if Kompact's `readString`/UTF-8 path
is ever used to parse **secret** string content (an unusual design choice
not proposed here) — for ordinary chat-message plaintext, already
decrypted and intended for display, this is not a meaningful new side
channel. It would become a concern only if someone mistakenly used the
UTF-8 path on secret material (keys, MAC values) rather than confining it
to post-AEAD chat content.

---

## 6. Recommendation

**Do not adopt Kompact** for the Rust/Kotlin wire-compatibility layer of
`pqcble-r1`. The already-designed messages (S1, S2, data-frame header,
doorbell, beacon) gain **0 bytes** from it, except a possible 1–2 byte
doorbell-counter reduction that is airtime-irrelevant at both PHYs (no PDU
boundary crossed, <10 µs saved), because the hand-designed byte-aligned
layout is already minimal and the payload's bulk is high-entropy key/MAC/
ciphertext material that no bit-packing scheme can shrink.

Kompact also carries costs disproportionate to that negligible gain: no
varint/adaptive-length encoding (so it can't even in principle do better
than a hand-picked fixed width); no schema-versioning/evolution story
(ADR-0002 defers this to an unscheduled v2 — risky for a protocol field
meant to evolve, like the chat envelope); no independent language-neutral
wire spec (the Kotlin implementation plus its golden-byte tests *are* the
spec, making a Rust-side reimplementation a long-term shadow-maintenance
burden for zero quantified benefit); and KSP's codegen is Kotlin-only
tooling with no plausible path to a Rust-emitting backend short of a
from-scratch multi-month effort. It is also a five-week-old,
single-maintainer, zero-stars/zero-forks project with no track record —
an unnecessary supply-chain and compatibility risk for essentially no
byte savings.

Confirmed definitively: Kompact does no entropy coding (pure structural
bit-packing), so it carries no compression-oracle risk if used — but that
reassurance is moot given there's nothing here worth the dependency.

The one place a presence/length-prefix scheme could plausibly help — the
undesigned chat-message envelope's optional fields (reply-to ID,
attachment reference, timestamp, read-receipt flag) — doesn't need Kompact
either: a hand-rolled one-byte presence bitmap plus fixed-width or simple
8/16-bit length-prefixed optional fields, implemented directly in Rust and
exposed through UniFFI, achieves the same byte savings with no
cross-language spec-drift risk, no dependency on a pre-1.0
single-maintainer library, and full control over versioning/evolution from
day one.

If there's still a strong ergonomic desire for a declarative bit-packing
DSL purely on the Kotlin side for UI-layer convenience, option (a) —
Kompact only for the chat envelope, only after AEAD verification, never
touching nonces/counters/padding-class logic — is the only configuration
that doesn't introduce new risk, but it remains optional polish, not a
recommended architectural dependency.

---

## Sources

- `https://github.com/trancee/kompact` (cloned locally for this research,
  `git clone --depth 50`), version 0.6.1 / `0.7.0-SNAPSHOT` dev tip, read
  2026-10-05.
- Key files cited: `README.md`; `docs/architecture.md`;
  `docs/api-reference.md`; `docs/getting-started.md`;
  `docs/how-to/define-framed-schema.md`;
  `docs/how-to/handle-decode-errors.md`; `docs/ci.md`;
  `docs/adr/0002-defer-versioning-surface-to-v2.md`;
  `docs/adr/0008-framed-generated-views.md`;
  `docs/research/allocation-boxing-measurement.md`; `CHANGELOG.md`;
  `kompact/build.gradle.kts`;
  `kompact/src/commonMain/kotlin/ch/trancee/kompact/runtime/KompactRuntime.kt`;
  `KompactFraming.kt`; `KompactFrame.kt`; `KompactWriter.kt`;
  `KompactDecodeError.kt`; `KompactUtf8Validator.kt`; `ScalarType.kt`;
  `kompact-ksp/src/main/kotlin/ch/trancee/kompact/ksp/KompactSymbolProcessor.kt`
  and `model/KompactFieldInfo.kt`;
  `kompact/src/commonTest/kotlin/ch/trancee/kompact/runtime/*` (test
  suite); `.scratch/kompact-spec/issues/05-variable-length-framing.md`;
  `.scratch/kompact-spec/issues/16-grok-review-synthesis.md`;
  `.scratch/kompact-v1/issues/03-arbitrate-framing-prefix-widths.md`;
  `.scratch/kompact-v1/map.md`.
- GitHub API metadata via `gh api repos/trancee/kompact`,
  `.../tags`, `.../contributors`, `.../issues?state=all`, `gh repo view
  trancee/kompact` — read 2026-10-05.
- `docs/research/ble_airtime.py` (this project) — used unmodified via a
  local snippet importing `pdu_count`/`airtime_microseconds` to translate
  byte deltas into PDU/airtime numbers.
- `docs/research/2026-10-05-pqc-over-ble-findings.md` §4 — source of the
  `pqcble-r1` message sketch analyzed here.
