# Gobley Maintenance Status and Alternatives — 2026-10-08

**Decision update (2026-10-08):** after this research, the project owner
selected Ubique instead of Gobley. ADR 0004 records the selection and issue 44
tracks the still-required generated-call/iOS 15 proof; the comparison below is
historical research, not the current project decision.

## Question

ADR 0004 specifies Rust core + KMP/Compose Multiplatform shell using Gobley + UniFFI
bindings. Prior research (`2026-10-05-kmp-rust-ble-toolchain.md`,
`2026-10-08-s0-bootstrap-toolchain.md`) recorded "Gobley 0.3.7 stable, UniFFI 0.29.4
bundled, repo activity through 2026-10-02, no verified better end-to-end replacement."
This note re-verifies that against primary sources as of 2026-10-08 and checks for a
newer/more-current alternative.

## TL;DR

- **Gobley is still maintained** (commits merged as recently as 2026-10-02, i.e. 6 days
  before this note), but its **tagged releases are stale**: the latest tag is `v0.3.7`
  from **2025-10-08**, exactly one year old, even though ~15+ commits have landed on
  `main` since then with no new version tag cut.
  [github.com/gobley/gobley/releases](https://github.com/gobley/gobley/releases),
  [github.com/gobley/gobley commits API](https://api.github.com/repos/gobley/gobley/commits)
- Gobley's own pinned toolchain on `main` is **behind current Kotlin/AGP**: it targets
  **Kotlin 2.1.10** and **AGP 8.7.3**
  ([gradle/libs.versions.toml](https://raw.githubusercontent.com/gobley/gobley/main/gradle/libs.versions.toml))
  while current stable Kotlin is **2.4.21** (released 2026-10-08,
  [JetBrains/kotlin releases](https://api.github.com/repos/JetBrains/kotlin/releases))
  and AGP has moved to the 9.x line.
- Two community-submitted PRs to modernize Gobley — **UniFFI 0.30 support** (PR #277)
  and **AGP 9 support** (PR #281) — were both **closed without merging**
  (closed 2026-02-09 and 2026-03-08 respectively), and the corresponding tracking
  issues **#287 "Bump uniffi to v0.31.x"** (opened 2026-06-18) and **#288 "AGP 9"**
  (opened 2026-06-29) remain open with **zero comments**, unresolved as of 2026-10-08.
  [PR #277](https://github.com/gobley/gobley/pull/277),
  [PR #281](https://github.com/gobley/gobley/pull/281),
  [Issue #287](https://github.com/gobley/gobley/issues/287),
  [Issue #288](https://github.com/gobley/gobley/issues/288)
- Gobley's own README **confirms the "no newer/better alternative" framing is now
  outdated**: as of 2026-10-08, Mozilla's official `uniffi-rs` README lists a **second,
  actively-released Kotlin Multiplatform binding generator**:
  [UbiqueInnovation/uniffi-kotlin-multiplatform-bindings](https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings),
  added the same day via
  [uniffi-rs PR #3015](https://api.github.com/repos/mozilla/uniffi-rs/pulls/3015)
  ("Add Kotlin Multiplatform bindings generator by Ubique to the list of third-party
  bindings", merged 2026-10-08T09:16:55Z).
- Both Gobley and the Ubique project are forks of the same now-dead ancestor,
  **Trixnity's `uniffi-kotlin-multiplatform-bindings`**, whose GitLab README states
  verbatim: *"This project is no longer maintained. For ongoing updates, please visit
  the forked repo at https://github.com/gobley/gobley."*
  [gitlab.com/trixnity/uniffi-kotlin-multiplatform-bindings README](https://gitlab.com/trixnity/uniffi-kotlin-multiplatform-bindings/-/raw/main/README.md)
  — Trixnity itself does **not** mention Ubique, so this pointer is now one-sided/stale,
  but it independently corroborates that Gobley is the maintained successor to the
  original tool, not that Gobley is the *only* maintained successor.

## Is Gobley "maintained"? (commit/release/issue evidence)

**Repo-level signals** (via GitHub API, `gobley/gobley`, queried 2026-10-08):
- `pushed_at`: `2026-10-02T03:46:55Z`; `updated_at`: `2026-10-05T13:13:59Z`; not archived.
- 12 distinct contributors across history; top two (`paxbun`, `ptitjes`) account for
  ~200 of the commits/contributions, i.e. maintenance is concentrated in a small core
  team, not a single dormant author.
- 84 open issues at time of query.
- Most recent commits (2026-10-01/02) are **CI/infra fixes** ("Fix dependency setup
  failures in CI" #296, "Update cmake, cc, and find-msvc-tools for Visual Studio 2026"
  #293) rather than feature or dependency-currency work — consistent with a project
  being kept alive/green but not being pushed forward on version currency.
- `CHANGELOG.md` top entry is `## [Unreleased]` comparing `v0.3.7...HEAD`, confirming
  there is unreleased work sitting on `main` with no cut release since 2025-10-08.
  [CHANGELOG.md](https://raw.githubusercontent.com/gobley/gobley/main/CHANGELOG.md)

**Conclusion on "maintained" vs "recent release" vs "compatible"** (the three must be
kept separate, per the question):
- *Maintained* — **yes**, by primary evidence (commits ~weekly through 6 days before
  this note, non-archived, multi-maintainer).
- *Recent release* — **no**, latest tag is 1 year old; "0.3.7 stable" in the prior
  research notes is accurate but gives a false impression of currency if read as "this
  was just released."
- *Compatible with current Kotlin/AGP* — **not fully**: Gobley's own build pins Kotlin
  2.1.10 / AGP 8.7.3 and still bundles UniFFI in the 0.29.x line per the CHANGELOG
  (commit history shows an internal bump to UniFFI 0.29.5 on 2026-01-02, but the
  community attempt to reach UniFFI 0.30 was abandoned, see PR #277 above). Project
  consumers targeting brand-new AGP 9 / Kotlin 2.4.x toolchains will hit the open,
  unaddressed #287/#288 gaps.

## Is there a more modern/maintained alternative?

### UbiqueInnovation/uniffi-kotlin-multiplatform-bindings — the strongest candidate

- **Same lineage**: forked from the same Trixnity project as Gobley; the two are
  explicitly described as sibling forks by Ubique's own PR description: *"Gobley is
  already listed and the two projects are closely related. Both projects started as
  forks of Trixnity's Kotlin Multiplatform bindings but since have gone in different
  directions."* [uniffi-rs PR #3015 body](https://api.github.com/repos/mozilla/uniffi-rs/pulls/3015)
- **Shared contributors with Gobley**: `paxbun`, `ptitjes`, `benkuly`, `SalvatoreT`,
  `typfel` all appear in both repos' contributor lists — this is not an unrelated
  competitor but an actively cross-pollinated sibling project.
- **Release cadence is materially more current**: tags `v1.3.1` (2026-10-07),
  `v1.3.0` (2026-10-02), `v1.2.3`/`v1.2.2` (2026-09-29), `v1.2.1`/`v1.2.0`
  (2026-08-21), `v1.1.1` (2026-08-14), `v1.1.0` (2026-08-07) — i.e. tagged releases
  roughly every 2-4 weeks, versus Gobley's year-long gap since `v0.3.7`.
  [github.com/UbiqueInnovation/.../tags & releases API](https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/releases)
- **Newer toolchain support, stated in its own README** (fetched 2026-10-08):
  Rust `>=1.91`, **UniFFI `=0.32.0`** (current upstream latest per
  [mozilla/uniffi-rs tags](https://api.github.com/repos/mozilla/uniffi-rs/tags):
  `v0.32.2` is newest), **Gradle `>=9.6.1`**, **Kotlin `>=2.4.0`**, **AGP `9.x`**
  (tested against AGP 9.3.1). Android support uses the newer
  `com.android.kotlin.multiplatform.library` plugin rather than the legacy
  `com.android.library` + `androidTarget{}` combo.
  [github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings README](https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings)
- **Differentiating feature**: multi-module support — "several Rust crates can be
  published as individual Kotlin Multiplatform libraries that share common types,"
  which Gobley does not offer.
- **Production usage claimed**: Ubique states it is used in production, citing
  [KapunSDK/kapun-sdk](https://github.com/KapunSDK/kapun-sdk) (not independently
  verified beyond the linked repo existing).
- **Gaps relative to Gobley** (stated by Ubique's own PR, i.e. the authors are explicit
  about this, not spin): Gobley supports **tvOS, watchOS, and Windows MSVC** targets
  that Ubique's project does **not** currently support. For this project's stated
  targets (Android API 26+, iOS 15+), this gap is not blocking — iOS (device +
  simulator arm64/x64) is supported by both — but it should be confirmed directly
  against Ubique's target list before switching, since "iOS" support was not itemized
  per-architecture in the README excerpt fetched.
- **Scale caveat**: Ubique is a smaller project by community size — 22 GitHub stars,
  1 open issue, 12 contributors (heavily weighted to two authors: `lebedenko-ubique`
  128 contributions, `UBaggeler` 41) versus Gobley's 435 stars / 84 open issues. Fewer
  open issues can mean either "more stable" or "less battle-tested by a wide user base
  that would otherwise file issues" — this is not resolvable from commit data alone
  and should be weighed as a real adoption-risk unknown rather than a maintenance
  signal in either direction.
- It is newly listed in Mozilla's canonical uniffi-rs README **as of today
  (2026-10-08)**, so broad community awareness/validation is effectively zero days
  old; this is the freshest possible signal, not a long track record.

### UniFFI (mozilla/uniffi-rs) core project

- Actively developed: most recent commits as of 2026-10-08 include
  `bc9fb385` (2026-10-05) and `5cba45b4` (2026-10-08, the PR adding Ubique's listing).
  Latest tag `v0.32.2`. [mozilla/uniffi-rs tags API](https://api.github.com/repos/mozilla/uniffi-rs/tags)
- UniFFI itself only ships first-party Kotlin (JVM/Android, not Kotlin/Native) and
  Swift bindings; Kotlin Multiplatform support is exclusively via the third-party
  Gobley/Ubique plugins listed in its README — confirming there is no "plain UniFFI
  Kotlin bindings" path that natively covers KMP/iOS without one of these two layers
  (or a hand-rolled Kotlin/Native cinterop + manual FFI approach).
  [mozilla/uniffi-rs README](https://raw.githubusercontent.com/mozilla/uniffi-rs/main/README.md)

### Other tools mentioned in UniFFI's own "Alternative tools" list

- **Diplomat** (`rust-diplomat/diplomat`) — listed by UniFFI itself as "focused more on
  C/C++ interop," not a Kotlin/KMP-first tool; not independently verified further in
  this pass since it's explicitly out-of-scope per upstream's own description.
- **Interoptopus** — similarly listed as a general-shape alternative, not Kotlin/KMP
  specific.
- Manual JNI + Kotlin/Native `cinterop` remains a fallback with no generator
  maintenance risk at all, at the cost of hand-writing and hand-maintaining the FFI
  boundary — not evaluated further here since it is a "build it yourself" option, not
  a competing maintained project.

## Recommendation / what this changes for ADR 0004

1. The claim "no verified better end-to-end replacement" should be **updated**: as of
   2026-10-08 there is now a **credible, actively-released sibling project**
   (UbiqueInnovation/uniffi-kotlin-multiplatform-bindings) that tracks newer UniFFI/
   Kotlin/AGP versions faster than Gobley, shares Gobley's core contributors, and is
   explicitly endorsed-by-listing in UniFFI's own README alongside Gobley. It is not
   unambiguously "better" — it lacks tvOS/watchOS/Windows MSVC support and has a much
   smaller adoption footprint (22 stars vs. 435) — but it is a real, current
   alternative that should be tracked, not dismissed.
2. Gobley should still be treated as "maintained" for planning purposes (active
   commits within the last week), but ADR 0004 / the toolchain research should flag
   that **Gobley's tagged-release currency (UniFFI 0.29.x, Kotlin 2.1.10, AGP 8.7.3,
   no AGP 9 support) is roughly a year behind upstream Kotlin/AGP**, with the two
   relevant modernization PRs (#277, #281) abandoned/closed and the tracking issues
   (#287, #288) stalled with no maintainer response for 3-4 months as of this note.
3. Given the project has **no KMP/build files yet** (per environment context), this is
   a low-cost moment to decide explicitly between Gobley and Ubique's bindings before
   any code is written against either API, rather than after. This note does not
   recommend a switch — only flags the option for a deliberate ADR-level decision.

## Sources (primary, all fetched/queried 2026-10-08)

- https://github.com/gobley/gobley (repo root, README fork/maintenance note)
- https://github.com/gobley/gobley/releases (release list)
- https://raw.githubusercontent.com/gobley/gobley/main/CHANGELOG.md
- https://raw.githubusercontent.com/gobley/gobley/main/gradle/libs.versions.toml
- https://api.github.com/repos/gobley/gobley (repo metadata)
- https://api.github.com/repos/gobley/gobley/commits
- https://api.github.com/repos/gobley/gobley/tags
- https://api.github.com/repos/gobley/gobley/contributors
- https://api.github.com/repos/gobley/gobley/pulls/277
- https://api.github.com/repos/gobley/gobley/pulls/281
- https://api.github.com/repos/gobley/gobley/issues/287
- https://api.github.com/repos/gobley/gobley/issues/288
- https://gitlab.com/trixnity/uniffi-kotlin-multiplatform-bindings/-/raw/main/README.md
- https://raw.githubusercontent.com/mozilla/uniffi-rs/main/README.md
- https://api.github.com/repos/mozilla/uniffi-rs/tags
- https://api.github.com/repos/mozilla/uniffi-rs/commits
- https://api.github.com/repos/mozilla/uniffi-rs/pulls/3015
- https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings (repo root/README)
- https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings
- https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/releases
- https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/tags
- https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/commits
- https://api.github.com/repos/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings/contributors
- https://api.github.com/repos/JetBrains/kotlin/releases (current Kotlin version for comparison)

## Gaps / not independently verified

- Ubique's per-architecture iOS target matrix (e.g. iosArm64/iosSimulatorArm64/
  iosX64, minimum iOS OS version) was not itemized in the README excerpt retrieved;
  should be checked directly in their docs
  (https://ubiqueinnovation.github.io/uniffi-kotlin-multiplatform-bindings/) before
  any adoption decision, to confirm iOS 15+ compatibility explicitly rather than by
  inference from "Kotlin/Native support."
- "Used in production" (KapunSDK) was not independently audited beyond confirming the
  linked repo exists.
- Diplomat and Interoptopus were not deep-dived (per UniFFI's own framing, they are
  not Kotlin/KMP-first tools, so low priority for this comparison) — if a future note
  needs them, fetch `rust-diplomat/diplomat` releases/commits directly.
- Did not check Gobley or Ubique GitHub Discussions/issue threads beyond the specific
  issues cited for broader qualitative sentiment on either project's roadmap.
