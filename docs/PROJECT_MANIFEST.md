# Project Manifest: Identikit

## Overview

Identikit is a dependency-free Swift library for Apple platforms that generates
**identicons** — deterministic avatar images derived from an arbitrary string, so
a username, email address, or public key always produces the same recognisable
icon without anyone uploading a picture. The same identicon is emitted as an SVG
string, a `CGImage`, or a SwiftUI view depending on which renderer the caller
reaches for. Its consumers are **developers**, not end users: someone building a
user list, a peer list, or a key-fingerprint display adds Identikit and gets
stable per-identity avatars for free. It solves the gap between "I need an avatar
for this identity" and "I do not want to build, host, or moderate user-uploaded
images", and does so using only system frameworks. `burrows`, a peer-to-peer
project in the same portfolio, depends on it at `0.1.0`, which makes API
stability a real constraint rather than a theoretical one. Current state is a
working `0.1.0`: three styles, three renderers, both extension points expressed
as protocols, and golden-file tests pinning the output.

> This repository (`identikit-pg`) is a disposable copy of `Identikit`, created so
> factory experiments cannot touch the real project or its downstream consumer.

## Tech Stack

| Layer     | Technology | Notes |
|-----------|-----------|-------|
| Frontend  | SwiftUI (`SwiftUICanvasRenderer`, `IdenticonView`) | The library's only UI surface — a view it hands back to a host app. No app of its own. |
| Styling   | n/a | No stylesheets. Visual output is computed: `ColorTheme` derives a five-colour HSL palette from the hash; `IdenticonConfig` tunes padding, saturation, lightness ranges, background, and hue restriction. |
| State     | n/a — stateless by design | Rendering is a pure function of `(seed, size, config, style)`. Renderers are reference types only because one render pass mutates them in place. |
| Routing   | n/a | Library product, no navigation. |
| Backend   | n/a | No service, no network, no I/O beyond returning a string or an image. |
| Database  | n/a | Test fixtures (`Fixtures/goldens.json`, `Fixtures/prng-golden.json`) are the only persisted data. |
| Testing   | swift-testing (`import Testing`) via `swift test` | Golden-file comparison. 5 test files: `JdenticonParityTests`, `GitHubStyleTests`, `MosaicStyleTests`, `CoreGraphicsSpokeTests`, `SwiftUICanvasRendererTests`. |
| Linting   | SwiftLint — **directives present, config not tracked** | Sources carry `// swiftlint:disable identifier_name` pragmas but there is no `.swiftlint.yml` in the repo. Either add the config or drop the pragmas; the Reviewer should not assume lint runs. |
| Language  | Swift, `swift-tools-version: 6.0` | Strict concurrency; value types are `Sendable`. |
| Platforms | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | |
| Hashing   | CryptoKit `Insecure.SHA1` | SHA-1 chosen for Jdenticon parity, not for security. Never used as a security primitive. |
| Raster    | CoreGraphics (`CoreGraphicsRenderer`) | Guarded by `#if canImport(CoreGraphics)`. |
| Build     | Swift Package Manager, command line only | `swift build` / `swift test`. No Xcode project, no signing, no notarisation, no simulator. |
| Dependencies | **Zero third-party** | A design commitment, not an accident. System frameworks only. |
| Distribution | SPM resolving a git tag | Tagging is the closest thing this project has to a deploy step. |

## Project Structure

Actual tree as committed (not proposed):

```
identikit-pg/
├── Package.swift                      # swift-tools-version 6.0; one library target + one test target
├── README.md                          # public-facing docs (currently claims "Four built-in renderers", lists three)
├── LICENSE
├── Assets/
│   ├── avatars-black.png              # README style-preview images
│   └── avatars-white.png
├── .github/workflows/ci.yml           # swift build + swift test on macos-15 — Actions DISABLED on purpose
├── .beads/                            # beads issue tracking (the backlog)
├── docs/                              # this manifest, PROJECT_OVERVIEW.md, factory manifest
├── Sources/Identikit/                 # 17 files, one type or concern per file
│   ├── Identicon.swift                # public facade: svg(for:), svg(forHash:), cgImage(for:)
│   ├── IdenticonStyle.swift           # SEAM 1: protocol — hash → renderer calls
│   ├── IdenticonRenderer.swift        # SEAM 2: protocol — drawing calls → output
│   ├── IdenticonConfig.swift          # tunable parameters; defaults match Jdenticon exactly
│   ├── IdenticonColor.swift           # 8-bit RGBA value type + clampChannel
│   ├── Geometry.swift                 # IdenticonPoint (public) + Transform (internal)
│   ├── Graphics.swift                 # primitive helper layer: rect/triangle/rhombus/circle
│   ├── IdenticonMath.swift            # JS-semantics helpers: truncToInt, clamp01, number formatting
│   ├── ColorTheme.swift               # hsl, correctedHsl, colorTheme — five-colour palette
│   ├── Hashing.swift                  # IdenticonHasher: isValidHash, resolve, sha1Hex, parseHex, substr
│   ├── JdenticonStyle.swift           # style — byte-for-byte port of Jdenticon v3.3.0
│   ├── GitHubStyle.swift              # style — blocky 5×5 grid, mirrored
│   ├── MosaicStyle.swift              # style — n×n tiles + MosaicRNG (xorshift) + MosaicPalette
│   ├── SVGStringRenderer.swift        # renderer — SVG string
│   ├── CoreGraphicsRenderer.swift     # renderer — CGImage
│   ├── SwiftUICanvasRenderer.swift    # renderer — SwiftUI Canvas + IdenticonView
│   └── Attribution.swift              # IdenticonAttribution — upstream licence notices
└── Tests/IdentikitTests/
    ├── Fixtures/goldens.json          # SVG strings keyed by case (e.g. "alice_100") — NEVER regenerate unattended
    ├── Fixtures/prng-golden.json      # MosaicRNG output sequences keyed by seed — NEVER regenerate unattended
    ├── JdenticonParityTests.swift
    ├── GitHubStyleTests.swift
    ├── MosaicStyleTests.swift
    ├── CoreGraphicsSpokeTests.swift
    └── SwiftUICanvasRendererTests.swift
```

The two protocol files are the load-bearing seams: **every** new style works with
**every** existing renderer, and vice versa. New work should extend along those
seams, not around them.

## Domain Model

There is no persistence layer. The "entities" are the value types and protocols
that make up the public and internal contract. Fields below are read from
`Sources/Identikit/`, not inferred.

**`Identicon`** (public `enum`, namespace facade) — the entry point. No state.
- `svg(for value: String, size: Double, config: IdenticonConfig, style: some IdenticonStyle) -> String`
- `svg(forHash hash: String, size:, config:, style:) -> String`
- `cgImage(for value: String, size:, scale: CGFloat, config:, style:) -> CGImage?` — gated on `canImport(CoreGraphics)`
- Default `style` is `JdenticonStyle()`; default `config` is `IdenticonConfig()`.

**`IdenticonStyle`** (public `protocol`, `Sendable`) — SEAM 1, hash → shapes.
- `render(hash: String, config: IdenticonConfig, into renderer: IdenticonRenderer)`
- Implementations: `JdenticonStyle` (no parameters), `GitHubStyle(gridSize: Int = 5)`, `MosaicStyle(gridSize: Int = 8)`.

**`IdenticonRenderer`** (public `protocol`, `AnyObject`) — SEAM 2, shapes → output.
- `var iconSize: Double { get }`
- `setBackground(_:)` — at most once, before any shapes
- `beginShape(_:)` / `endShape()` — paired; the same colour may begin more than once
- `addPolygon(_ points: [IdenticonPoint])` — winding order significant (nonzero fill rule; reversed = hole)
- `addCircle(_ corner: IdenticonPoint, diameter: Double, counterClockwise: Bool)`
- `finish()` — flush buffered output
- Implementations: `SVGStringRenderer(iconSize:)` exposing `var svg: String`; `CoreGraphicsRenderer(iconSize:scale:)` exposing `makeImage() -> CGImage?`; `SwiftUICanvasRenderer`.
- Reference types because one render pass mutates them across many calls.

**`IdenticonConfig`** (public `struct`, `Sendable`) — every default matches Jdenticon's.
- `padding: Double = 0.08` (fraction of icon size per side)
- `colorSaturation: Double = 0.5`, `grayscaleSaturation: Double = 0`
- `colorLightness: ClosedRange<Double> = 0.4...0.8`
- `grayscaleLightness: ClosedRange<Double> = 0.3...0.9`
- `backColor: IdenticonColor?` — nil leaves the icon transparent
- `hues: [Double]?` — optional hue restriction in degrees; nil/empty imposes none
- internal: `colorLightnessValue(_:)`, `grayscaleLightnessValue(_:)`, `resolvedHue(_:)`

**`IdenticonColor`** (public `struct`, `Equatable`, `Sendable`) — renderer-agnostic colour.
- `red/green/blue/alpha: Int`, each clamped to `0...255` on init (alpha defaults 255)
- `hex: String` → `#rrggbb`; also the grouping key for same-coloured SVG paths
- `opacity: Double` → alpha as `0...1`

**`IdenticonPoint`** (public `struct`, `Equatable`, `Sendable`)
- `x: Double`, `y: Double`. Origin top-left, y grows downward.

**`Transform`** (internal `struct`) — places each symmetric copy of a shape.
- `x`, `y`, `size: Double`; `rotation: Int` in clockwise quarter turns (0–3)
- `point(_ px:_ py:_ w:_ h:) -> IdenticonPoint`; `.none` is the identity

**`Graphics`** (internal `final class`) — primitive layer between style and renderer.
- holds a `renderer` and a mutable `currentTransform: Transform`
- `addPolygon(_ [Double], invert:)`, `addCircle(_:_:_:invert:)`, `addRectangle(_:_:_:_:invert:)`, `addTriangle(_:_:_:_:_ r:invert:)`, `addRhombus(_:_:_:_:invert:)`
- `invert: true` reverses vertex order to punch a hole

**`IdenticonHasher`** (public `enum`) — hash resolution.
- `isValidHash(_:) -> Bool` — true for 11+ hex characters
- `resolve(_:) -> String` — the value verbatim if already a valid hash, else its SHA-1 hex
- `sha1Hex(_:) -> String`
- internal `parseHex(_:_:_:)`, `substr(_:_:_:)` — reproduce JavaScript `parseInt`/`substr`, including negative start positions

**`MosaicRNG`** (internal `struct`) — deterministic xorshift PRNG.
- four `Int32` lanes `s0…s3`, seeded from string bytes (Java-`hashCode`-style fold)
- normalised to `[0, 1)`; 32-bit arithmetic reproduced exactly, pinned by `prng-golden.json`

**`MosaicPalette`** (internal `struct`) — `main: IdenticonColor`, `spot: IdenticonColor`. Region value 0 is left transparent.

**`IdenticonAttribution`** (public `enum`) — upstream licence notices (Jdenticon, blockies).

**`Golden`** (test-private `struct`) — one fixture case: `value: String`, `size: Double`, `svg: String` (fixture also carries `prehash: Bool`), keyed by case name such as `alice_100`.

Relationship, end to end:

```
String seed ──IdenticonHasher.resolve──▶ hash (hex)
                                          │
                    IdenticonConfig ──────┤
                                          ▼
                            IdenticonStyle.render      (SEAM 1)
                                          │  via Graphics + Transform + ColorTheme
                                          ▼
                            IdenticonRenderer calls    (SEAM 2)
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    ▼                     ▼                     ▼
              SVG String              CGImage             SwiftUI View
```

## Conventions

*(inferred from the repository and git history — accurate as of `0.1.0`)*

- **File naming:** `PascalCase.swift`, named for the primary type or concern it
  declares (`JdenticonStyle.swift`, `ColorTheme.swift`). One type or one coherent
  concern per file. Every file opens with a `//` header comment block explaining
  the file's role and, where relevant, the upstream reference it ports.
- **Test files:** `Tests/IdentikitTests/<Subject>Tests.swift` using
  `import Testing` (swift-testing), not XCTest. `@testable import Identikit` for
  internal access. Fixtures under `Tests/IdentikitTests/Fixtures/`, registered as
  `.copy(...)` resources in `Package.swift`.
- **API routes:** n/a — library, no HTTP surface. The equivalent contract is the
  public API: the `Identicon` facade, the two protocols, and the public value types.
- **Doc comments:** `///` on every public declaration. Ported code cites its
  upstream counterpart by filename (e.g. "Mirrors Jdenticon's `hueToRgb`").
- **Naming discipline:** public types are prefixed `Identicon*` to avoid
  collisions in a dependency-free library (`IdenticonColor`, `IdenticonPoint`,
  `IdenticonConfig`). Internal geometry/math code may use single-letter names
  where they match the ported reference, fenced by
  `// swiftlint:disable identifier_name` … `enable` pairs with a justifying comment.
- **Platform gating:** `#if canImport(CoreGraphics)` / SwiftUI availability guards
  around platform-specific renderers, so the package builds on every declared platform.
- **Commits:** Conventional Commits — `fix:`, `docs:`, `feat:`, `test:`,
  `refactor:` (see `4328153 fix: avoid stray spoke …`, `df69d08 docs: add style
  preview images …`). Subject line in the imperative, lower case after the prefix.
- **Branches:** `identikit-<feature>` — one feature branch per work item off `main`,
  merged after the Deployer gate passes. `main` is the only long-lived branch.
- **Backlog:** beads (`.beads/`). Every feature branch traces to a bead.

## Constraints

- **Determinism is the product.** The same seed must always produce the same
  icon. `Fixtures/goldens.json` and `Fixtures/prng-golden.json` encode this.
- **Never regenerate the goldens unattended.** When a golden test fails there are
  two ways to green the suite: fix the code, or regenerate the fixture. The second
  is faster and almost always wrong. Because the goldens are SVG output,
  regenerating them would mask a style regression, a hashing regression, and an
  SVG-renderer regression in one move — blast radius is the whole library. Any
  diff touching `goldens.json` or `prng-golden.json` requires explicit human
  approval, with the sole exception of adding a *new* key for a *new* style.
- **Byte-for-byte Jdenticon parity.** `JdenticonStyle` is a faithful port of
  Jdenticon v3.3.0 and is verified against it. That parity is a contract with an
  external project, not an internal preference. `IdenticonConfig` defaults,
  `ColorTheme`'s `correctors` array, and `IdenticonMath`'s JS-semantics helpers
  must be reproduced exactly.
- **API stability for `burrows`.** `IdenticonStyle` and `IdenticonRenderer` are
  **public extension points**, not implementation detail — adding a requirement to
  either protocol is a breaking change. Changes are **additive-only until 1.0**.
  Anything breaking needs an explicit human decision and a major version bump.
- **Zero third-party dependencies.** System frameworks only (CryptoKit,
  CoreGraphics, SwiftUI, Foundation). Adding anything to `Package.swift`
  `dependencies` is out of scope.
- **Command-line build only.** No Xcode project, no signing, no notarisation, no
  simulator. If it cannot be done with `swift build` / `swift test`, it is out of scope.
- **Not an app, not a service, deliberately not a CLI.** Library product only.
- **SHA-1 is for parity, not security.** Never present or use Identikit output as
  a security primitive.
- **GitHub Actions is disabled on this repository on purpose.** `.github/workflows/ci.yml`
  stays in place as the *spec* for what the factory gate must do — reimplementing
  that check as a factory gate is the intended exercise. Do not re-enable Actions.
- **No observability, deployment, comms, auth, or data integrations.** Meaningless
  for a library with no runtime of its own.
- **Out of scope:** GitHub Issues / Jira (backlog is beads), Sentry/DataDog, any
  hosted service.

---

## Task Inputs

| Agent     | Receives | From |
|-----------|----------|------|
| Planner   | Feature request (typically a bead from `.beads/`) + Overview, Domain Model, Constraints | Human / beads backlog + `PROJECT_MANIFEST.md` |
| Architect | Work package + Tech Stack and Constraints (zero-deps, Jdenticon parity, API-stability policy, goldens rule) | `work-packages/identikit.md` + `PROJECT_MANIFEST.md` |
| Designer  | Approved ADR + Domain Model (the two seams, `IdenticonConfig` fields, the value types) | `docs/adr/NNNN-identikit.md` + `PROJECT_MANIFEST.md` — **after Gate 1** |
| Coder     | Design spec + Conventions and Project Structure | `design/identikit-spec.md` + `PROJECT_MANIFEST.md` |
| Reviewer  | Code diff on `identikit-<feature>` + Review Standards | `git diff main...identikit-<feature>` + `PROJECT_MANIFEST.md` |
| Deployer  | Approved review report + Release Criteria | `review-reports/identikit-review.md` + `PROJECT_MANIFEST.md` — **after Gate 2** |

Sequencing note: the Designer cannot run before Gate 1 approves the ADR, and the
Deployer cannot run before Gate 2 approves the review report.

## Services to Connect

| Service | Purpose | Config |
|---------|---------|--------|
| GitHub | Source control for `identikit-pg` (disposable copy of `Identikit`) | `origin/main`; `main` is the only long-lived branch |
| GitHub Actions | `swift build` + `swift test` on `macos-15`, on push to `main` and all PRs | `.github/workflows/ci.yml` — **disabled on purpose**; the file is the spec the factory's own gate must satisfy. Do not re-enable. |
| beads | Issue tracking / backlog | `.beads/config.yaml`; `.beads/*` gitignored except `identity.toml` |
| Swift Package Manager | Distribution — consumers resolve a git tag | Git tags are the release artefact; tagging is the only deploy-shaped step |
| *(deliberately absent)* | Issue trackers, observability, hosting, comms, auth, analytics | Not needed for a library with no runtime of its own |

## Success Criteria

### Per-Feature Success

- [ ] `swift build` passes on a clean checkout.
- [ ] `swift test` passes on a clean checkout, with **`goldens.json` and `prng-golden.json` unmodified** (adding a new key for a new style is the only permitted change, and it needs human sign-off).
- [ ] `Package.swift` gains **no** third-party dependency.
- [ ] The public API is unchanged or **purely additive** — nothing that breaks `burrows` at `0.1.0`. Adding a requirement to `IdenticonStyle` or `IdenticonRenderer` counts as breaking.
- [ ] Any change to a pure-function file (`Hashing`, `Geometry`, `IdenticonMath`, `ColorTheme`, `Graphics`) ships **direct unit tests**, so a failure localises to that layer instead of only tripping a golden.
- [ ] The change traces to a bead, and carries an **ADR** if it touches a protocol seam, the hashing path, `IdenticonConfig` defaults, or the public API.
- [ ] Builds for every declared platform (iOS 16+, macOS 13+, tvOS 16+, watchOS 9+) — platform-specific code stays behind `canImport`/availability guards.
- [ ] Public declarations carry `///` doc comments; ported code cites its upstream counterpart.

### New-Style Success (a style has no external reference to check against)

- [ ] **Determinism:** the same seed produces identical output across runs and processes.
- [ ] **Symmetry:** the style's documented symmetry property holds (mirror, rotational, or explicitly "none" — stated and tested).
- [ ] **Its own golden fixture,** captured at merge time, so every later change to the style is pinned the way `JdenticonStyle` is.
- [ ] Works with **all three** existing renderers without renderer changes — that is what the seam is for.

### Factory-Level Success

- [ ] The factory reproduces what disabled CI would have done: `swift build` + `swift test` on macOS, as specified in `.github/workflows/ci.yml`.
- [ ] The factory **never** regenerates a golden fixture without explicit human approval.
- [ ] The three undocumented architectural decisions are captured as ADRs: dependency-free by choice, protocol seams for styles and renderers, byte-for-byte Jdenticon parity.
- [ ] A written API-stability policy exists and the Reviewer enforces it.
- [ ] Both human gates fire — no pipeline run reaches the Deployer without an approved ADR and an approved review report.
- [ ] The README inaccuracy ("Four built-in renderers", three listed) is fixed as the first end-to-end pipeline exercise: unambiguous, verifiable, no architectural judgement required.

---

## Review Standards

### Spec Compliance

- Every change in the diff traces to a requirement in `design/identikit-spec.md`. Unrequested changes are flagged, not waved through.
- New styles implement `IdenticonStyle` and touch no renderer; new renderers implement `IdenticonRenderer` and touch no style. Work that crosses both seams in one change needs an ADR explaining why the seam was insufficient.
- New styles satisfy the New-Style Success list above: determinism, stated-and-tested symmetry, own golden, works with all three renderers.
- `IdenticonConfig` defaults are unchanged unless the ADR explicitly authorises it — they are Jdenticon's defaults, and changing one changes every icon.
- Doc comments exist on every new public declaration; ported code cites its upstream counterpart by filename.

### Style

- File naming and layout follow the Conventions section: `PascalCase.swift` named for its primary type, one concern per file, `//` header block explaining the file's role.
- Public types keep the `Identicon*` prefix.
- Single-letter identifiers appear only inside an explicitly fenced `swiftlint:disable identifier_name` block with a comment justifying the exception (matching a ported reference, or standard geometry/colour notation).
- Value types are `Sendable`; renderers are reference types only because a render pass mutates them in place — a new value-type renderer is a design smell worth questioning.
- Tests use swift-testing (`import Testing`), never XCTest.
- Commits follow Conventional Commits.
- Platform-specific code stays behind `#if canImport(...)` / availability guards.

### Security

- **SHA-1 is a parity requirement, never a security primitive.** Reject any change that presents identicon output, `IdenticonHasher.sha1Hex`, or a derived hash as a security or integrity guarantee.
- **No new dependency.** Any addition to `Package.swift` `dependencies` is an automatic High.
- Identikit performs no I/O — no network, no filesystem, no `Process`, no dynamic code loading. A diff that introduces any of these is an automatic High.
- No unsafe pointer arithmetic or `unsafeBitCast`; `MosaicRNG`'s 32-bit overflow arithmetic must stay explicit (`&+`, `&<<`) and stay pinned by `prng-golden.json`.
- Seeds are caller-supplied and may be personal data (email addresses, usernames). Never log, cache, or persist a seed or a resolved hash.
- No force-unwrapping on caller-supplied input. `Identicon.cgImage` returning `nil` on renderer-creation failure is the established pattern; keep failures recoverable.

### Severity Scale

- **Low**: cosmetic issues, minor inconsistencies, doc-comment gaps, README wording.
- **Medium**: functional gaps, missing edge cases, a pure-function change without a direct unit test, a new style missing its symmetry test, missing ADR for a seam-touching change.
- **High**: any of —
  - a modified `goldens.json` or `prng-golden.json` that is not a new key for a new style;
  - a breaking public-API change (including a new protocol requirement) without an approved ADR and a major version bump;
  - a new third-party dependency;
  - a determinism regression — output that varies by run, process, platform, or dictionary ordering;
  - loss of byte-for-byte Jdenticon parity;
  - introducing I/O, logging of seeds, or a security claim about SHA-1;
  - a build break on any declared platform.

---

## Release Criteria

### Required (all must PASS)

1. [ ] `swift build` succeeds on `macos-15` — the check `.github/workflows/ci.yml` specifies.
2. [ ] `swift test` succeeds on `macos-15`, all tests green.
3. [ ] `git diff main...HEAD -- Tests/IdentikitTests/Fixtures/` is **empty**, or contains only new keys for a new style **and** carries recorded human approval.
4. [ ] `Package.swift` `dependencies` is still empty.
5. [ ] Public API diff is empty or purely additive. If breaking: an approved ADR exists and the version bump is major.
6. [ ] The package resolves and builds for every declared platform (iOS 16+, macOS 13+, tvOS 16+, watchOS 9+).
7. [ ] The Reviewer report exists, has **zero** open High findings, and carries Gate 2 human approval.
8. [ ] Every pure-function file touched by the diff has a corresponding direct unit test in the same diff.
9. [ ] The work traces to a bead, and to an ADR if it touched a seam, the hashing path, `IdenticonConfig` defaults, or the public API.
10. [ ] `README.md` reflects reality — style and renderer counts match what ships.
11. [ ] Release tag follows semver and matches the API-stability verdict (patch/minor for additive; major for breaking). Tagging is the deploy step: SPM consumers resolve the tag.
12. [ ] GitHub Actions remains disabled — the factory gate is the check, not Actions.

### Informational (reported but non-blocking)

- Test count and per-file test distribution (which of `Hashing`, `Geometry`, `IdenticonMath`, `ColorTheme` still have no dedicated test file).
- Count of golden fixture cases, by style.
- Public API surface size — public types, and the requirement count on each protocol.
- Source file count and total size (baseline at `0.1.0`: 17 source files, ~80 KB).
- Styles × renderers matrix coverage: which combinations are exercised by a test.
- SwiftLint status — whether `.swiftlint.yml` exists yet, and the count of `swiftlint:disable` pragmas in the tree.
- Wall-clock `swift build` and `swift test` duration.
