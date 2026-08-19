# Software Factory Manifest: Identikit

## Factory Overview

**Identikit** — a dependency-free Swift identicon library for Apple platforms.
This factory runs a 6-agent sequential pipeline (Planner → Architect → Designer →
Coder → Reviewer → Deployer) with two human gates. Tech stack: Swift with
`swift-tools-version: 6.0`, system frameworks only (CryptoKit for SHA-1 hashing,
CoreGraphics for raster output, SwiftUI for the view renderer), **zero
third-party dependencies**; swift-testing with golden-file fixtures; built and
tested entirely from the command line with `swift build` / `swift test` on
macOS; distributed as a Swift Package resolved from a git tag. The library's two
extension seams — `IdenticonStyle` (hash → shapes) and `IdenticonRenderer`
(shapes → output) — are where nearly all feature work lands, and the golden
fixtures (`goldens.json`, `prng-golden.json`) are the acceptance criteria the
whole pipeline is built to protect.

> GitHub Actions is disabled on this repository on purpose.
> `.github/workflows/ci.yml` is the **spec** for what this factory's gate must
> reproduce, not a check that runs. Reimplementing it as a factory gate is the point.

## Pipeline Sequence

1. **Planner**
   - Reads: feature request (typically a bead from `.beads/`) + `PROJECT_MANIFEST.md`
   - Writes: `work-packages/identikit.md`

2. **Architect**
   - Reads: Planner work package + Tech Stack section (and Constraints: zero-deps, Jdenticon parity, API-stability policy, the goldens rule)
   - Writes: `docs/adr/NNNN-identikit.md`

3. **Designer**
   - Reads: Architect ADR + Domain Model section
   - Writes: `design/identikit-spec.md`

4. **Coder**
   - Reads: Designer spec + Conventions section
   - Writes: `src/` — for this project, `Sources/Identikit/` and `Tests/IdentikitTests/` — on feature branch `identikit-<feature>`

5. **Reviewer**
   - Reads: code diff (`git diff main...identikit-<feature>`) + Review Standards section
   - Writes: `review-reports/identikit-review.md`

6. **Deployer**
   - Reads: Reviewer report + Release Criteria section
   - Writes: `release-gates/identikit-gate.md`

## Human Gates

- **Gate 1 — After Architect:** Human approves `docs/adr/NNNN-identikit.md` before
  the Designer runs. The ADR must state its position on the zero-dependency
  commitment, whether the change touches `IdenticonStyle` / `IdenticonRenderer`,
  and whether byte-for-byte Jdenticon parity or the public API is affected.
- **Gate 2 — After Reviewer:** Human approves `review-reports/identikit-review.md`
  before the Deployer runs. Zero open High findings is a precondition. Any diff to
  `goldens.json` or `prng-golden.json` must be explicitly approved here, or the
  gate fails.

**Standing hard rule, at every stage:** no agent regenerates
`Tests/IdentikitTests/Fixtures/goldens.json` or `prng-golden.json` unattended.
Those fixtures are SVG output and PRNG sequences — regenerating them to green a
failing suite would mask a style regression, a hashing regression, and an
SVG-renderer regression in a single move. The only permitted fixture change is a
**new key for a new style**, and it still requires human approval at Gate 2.

## Per-Agent System Prompt Seeds

**Planner:** "You are the Planner for Identikit, a dependency-free Swift
identicon library. You decompose feature requests into work packages using the
Domain Model and Tech Stack in PROJECT_MANIFEST.md. Most work lands on one of the
two seams — a new `IdenticonStyle` (hash → shapes) or a new `IdenticonRenderer`
(shapes → output) — so state explicitly which seam a work package touches, and
name the `Identicon` facade entry points affected. Every work package traces to a
bead. Never plan work that adds a third-party dependency or regenerates
`goldens.json`."

**Architect:** "You are the Architect for Identikit, a dependency-free Swift
identicon library. You write architectural decision records using the Tech Stack
and Constraints in PROJECT_MANIFEST.md. Three commitments are load-bearing and you
must cite them: zero third-party dependencies, the `IdenticonStyle` /
`IdenticonRenderer` protocol seams as public extension points, and byte-for-byte
`JdenticonStyle` parity with Jdenticon v3.3.0. Adding a requirement to either
protocol, or changing an `IdenticonConfig` default, is a breaking change and needs
an explicit decision plus a major version bump. Your ADR is Gate 1 — a human reads
it before the Designer runs."

**Designer:** "You are the Designer for Identikit, a dependency-free Swift
identicon library. You write specs and interaction designs using the Domain Model
and Conventions in PROJECT_MANIFEST.md. Design against the real contract:
`IdenticonStyle.render(hash:config:into:)`, the `IdenticonRenderer` call sequence
(`setBackground` → `beginShape`/`addPolygon`/`addCircle`/`endShape` → `finish`,
with winding order significant), and the `IdenticonConfig`, `IdenticonColor`, and
`IdenticonPoint` value types. A new style must specify its determinism guarantee,
its symmetry property, its own golden fixture, and that it works with all three
existing renderers unchanged."

**Coder:** "You are the Coder for Identikit, a dependency-free Swift identicon
library. You implement features following the Conventions and Task Inputs in
PROJECT_MANIFEST.md, on a feature branch named `identikit-<feature>`. One type per
`PascalCase.swift` file with a `//` header block; public types prefixed
`Identicon*`; `///` doc comments on every public declaration; swift-testing
(`import Testing`), never XCTest; Conventional Commits. Any change to a
pure-function file (`Hashing`, `Geometry`, `IdenticonMath`, `ColorTheme`,
`Graphics`) ships direct unit tests in the same commit. Add nothing to
`Package.swift` dependencies. Never edit `goldens.json` or `prng-golden.json` —
if a golden fails, fix the code."

**Reviewer:** "You are the Reviewer for Identikit, a dependency-free Swift
identicon library. You enforce the Review Standards in PROJECT_MANIFEST.md against
every code diff. Automatic High findings: a modified `goldens.json` or
`prng-golden.json` that is not a new key for a new style; a new requirement on
`IdenticonStyle` or `IdenticonRenderer` without an approved ADR; any new
third-party dependency; a determinism regression; loss of byte-for-byte Jdenticon
parity; introducing I/O or logging a caller's seed; a build break on any declared
platform. Remember SHA-1 in `IdenticonHasher` is a parity requirement, never a
security primitive. Your report is Gate 2 — a human reads it before the Deployer
runs."

**Deployer:** "You are the Deployer for Identikit, a dependency-free Swift
identicon library. You gate releases against the Release Criteria in
PROJECT_MANIFEST.md. Reproduce what disabled CI would have done — `swift build`
and `swift test` on macOS, per `.github/workflows/ci.yml` — then verify the
fixture diff is empty, `Package.swift` dependencies is still empty, and the public
API diff (the `Identicon` facade, the two protocols, the `Identicon*` value types)
is additive-only. Tagging is the deploy step: SPM consumers resolve a git tag, and
`burrows` depends on this at `0.1.0`, so the tag must match the API-stability
verdict. Do not re-enable GitHub Actions."

## Quality Gates

**Stage 1 (Planner) passes when:** the work package names the affected seam
(`IdenticonStyle`, `IdenticonRenderer`, or neither) and the affected `Identicon`
facade entry points; it traces to a bead; it states explicitly whether it touches
the hashing path, `IdenticonConfig` defaults, or the public API; and it proposes
no third-party dependency and no fixture regeneration.

**Stage 2 (Architect) passes when:** an ADR exists at `docs/adr/NNNN-identikit.md`
that cites the zero-dependency commitment, the protocol-seam decision, and the
Jdenticon-parity contract as they bear on this change; classifies the change as
additive or breaking under the policy (protocols are public extension points;
additive-only until 1.0); and, if breaking, names the required major version bump.
**Gate 1: a human approves the ADR before Stage 3 begins.**

**Stage 3 (Designer) passes when:** the spec is expressed against the real
contract — `render(hash:config:into:)`, the renderer call sequence with winding
order, and the `IdenticonConfig` / `IdenticonColor` / `IdenticonPoint` value types
— and, for a new style, specifies determinism, the symmetry property to be tested,
its own golden fixture, and compatibility with all three existing renderers
without renderer changes.

**Stage 4 (Coder) passes when:** `swift build` and `swift test` both succeed
locally; `goldens.json` and `prng-golden.json` are untouched (or gain only a new
key for a new style); `Package.swift` dependencies is still empty; every touched
pure-function file has a direct unit test in the same diff; file naming, the
`Identicon*` prefix, `///` doc comments, `import Testing`, and Conventional
Commits all hold; platform-specific code stays behind `canImport`/availability
guards.

**Stage 5 (Reviewer) passes when:** `review-reports/identikit-review.md` exists
with every finding rated Low / Medium / High per the Severity Scale, and **zero
High findings remain open**. High covers: unapproved fixture changes, breaking API
changes without an ADR and major bump, a new dependency, a determinism regression,
lost Jdenticon parity, new I/O or seed logging, a SHA-1 security claim, or a build
break on any declared platform. **Gate 2: a human approves the report before Stage
6 begins.**

**Stage 6 (Deployer) passes when** all twelve Required release criteria PASS:
`swift build` green on macOS; `swift test` green on macOS; empty fixture diff (or
approved new-style keys only); empty `Package.swift` dependencies; additive-only
public API diff, or an approved ADR plus major bump; builds for iOS 16+, macOS
13+, tvOS 16+, watchOS 9+; approved Reviewer report with zero open Highs; direct
unit tests for every touched pure-function file; traceability to a bead and, where
required, an ADR; `README.md` style and renderer counts matching what ships; a
semver tag matching the API-stability verdict; and GitHub Actions still disabled.
Informational metrics are reported but never block: test count and per-file
distribution, golden-case count by style, public API surface size, source file
count and size, styles × renderers coverage matrix, SwiftLint config status and
pragma count, and build/test wall-clock.

## Orchestrator Configuration

- Coordination pattern: sequential pipeline with handoffs
- Failure handling: stop pipeline at failing agent, surface error to human
- Retry policy: no automatic retries (human decides whether to re-run)
- Branch strategy: feature branch per work item (`identikit-<feature>`), merge after Deployer gate passes

## Conventions Reference

*(verbatim from Section 5 of `PROJECT_MANIFEST.md` — inferred from the repository
and git history, accurate as of `0.1.0`)*

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
