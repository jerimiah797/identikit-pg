# Project Overview: Identikit

> Draft for L1. Sections 1–2 are grounded in the code as it stands; sections 3–4
> carry the judgement calls and need your review before the manifest generator
> runs against this.

---

## 1. What is this software?

Identikit generates **identicons** — deterministic avatar images derived from an
arbitrary string, so that a username, email address, or public key always
produces the same recognisable icon without anyone uploading a picture. It is a
dependency-free Swift library for Apple platforms, and it emits the same
identicon as an SVG string, a `CGImage`, or a SwiftUI view depending on which
renderer the caller reaches for.

The consumers are **developers**, not end users. Someone building an app with a
user list, a peer list, or a key fingerprint display adds Identikit and gets
stable per-identity avatars for free. `burrows` — a peer-to-peer project in the
same portfolio — depends on it, which makes API stability a real constraint
rather than a theoretical one: a breaking change here breaks a downstream
consumer.

The problem it solves is the gap between "I need an avatar for this identity"
and "I do not want to build, host, or moderate user-uploaded images." Identicons
answer that, and Identikit answers it without pulling in a third-party
dependency graph — only system frameworks (CryptoKit, CoreGraphics, SwiftUI).

Its current state is a working `0.1.0`: three styles, three renderers, both
extension points expressed as protocols, and golden-file tests pinning the
output. Where it goes next is more styles and more renderers along those
existing seams, plus the API-surface discipline a library with a downstream
consumer ought to have.

## 2. Size, Type, Languages, Resource Constraints

- **Size**: small library — 20 source files, ~80 KB, three commits. One person's
  project, no deadline pressure.
- **Type**: Swift package (library product). Not an app, not a service, and
  deliberately not a CLI — though it has no UI of its own beyond the SwiftUI
  view it hands back.
- **Languages / frameworks**: Swift, `swift-tools-version: 6.0`. System
  frameworks only — CryptoKit for hashing, CoreGraphics for raster output,
  SwiftUI for the view renderer. **Zero third-party dependencies**, which is a
  design commitment rather than an accident.
- **Runtime / platform**: iOS 16+, macOS 13+, tvOS 16+, watchOS 9+. Builds and
  tests entirely from the command line with `swift build` / `swift test` — no
  Xcode project, no signing, no notarisation, no simulator.
- **Resource constraints**: no latency or memory budget worth writing down;
  identicon generation is a few hundred shape computations. The real constraints
  are different in kind:
  - **Determinism.** The same seed must always produce the same icon. This is
    the property the library exists to provide, and the golden fixtures
    (`Tests/IdentikitTests/Fixtures/goldens.json`, `prng-golden.json`) encode it.
  - **Byte-for-byte Jdenticon parity.** `JdenticonStyle` is a faithful port of
    an existing implementation and is verified against it. That parity is a
    contract with an external project, not an internal preference.
  - **API stability**, because `burrows` consumes this.
  - **No third-party dependencies**, as above.

## 3. Potential SDLC Service Integrations

Already in use:

- **Source control** — GitHub. This repository (`identikit-pg`) is a disposable
  copy of `Identikit` created so factory experiments cannot touch the real
  project or its downstream consumer.
- **CI** — GitHub Actions. The workflow at `.github/workflows/ci.yml` runs
  `swift build` and `swift test` on `macos-15` for pushes to `main` and all pull
  requests. **Actions are currently disabled on this repository on purpose** —
  reimplementing that check as a factory gate is the intended exercise, so the
  workflow file stays in place as the spec for what the gate must do.

Not in use, and probably not needed:

- **Issue tracking** — no GitHub Issues, no Jira. The backlog lives in beads.
- **Observability** — Sentry, DataDog and friends are meaningless for a library
  with no runtime of its own.
- **Deployment** — nothing to deploy. Distribution is Swift Package Manager
  resolving a git tag, which makes **release tagging** the closest thing to a
  deploy step and the one place a factory could plausibly reach.
- **Comms / data / auth** — none, and no reason to add them.

## 4. Open Questions / Concerns

- **No decision records.** There are real architectural decisions in here —
  dependency-free by choice, protocol seams for styles and renderers,
  byte-for-byte parity with Jdenticon — and none of them are written down. An
  architect gate with nothing to cite produces opinions rather than verdicts.
  Writing those three as ADRs is likely the highest-value early work.

- **Goldens are the acceptance criteria, which creates an obvious failure mode.**
  When a change makes a golden test fail, there are two ways to make the suite
  green: fix the code, or regenerate the fixture. The second is faster and
  almost always wrong. Because the goldens are SVG output, regenerating them
  would mask a style regression, a hashing regression and an SVG-renderer
  regression in one move — the blast radius is the whole library. Regenerating
  `goldens.json` or `prng-golden.json` is the clearest candidate for something a
  factory must **never** do unattended, and it belongs in
  `SOFTWARE_FACTORY_MANIFEST.md` as a hard rule.

- **Coverage is indirect, and that is load-bearing.** The golden fixtures store
  **SVG strings**, so every style test flows through `SVGStringRenderer` on its
  way to a comparison. That gives real coverage to the SVG renderer, `Hashing`,
  `Geometry`, `IdenticonMath` and `ColorTheme` without any of them having a
  dedicated test file — a change to the hash or the geometry math breaks the
  goldens immediately. The catch is that it is all coverage of one shape: a
  golden mismatch says "something downstream of the seed changed" and not which
  layer changed it. Direct unit tests on those pure-function files would
  localise failures instead of merely detecting them, and they are the cheapest
  tests in the codebase to write.

- **What does "a new style is correct" mean?** For `JdenticonStyle` the answer
  is parity with an external reference. For a *new* style there is no reference,
  so a reviewer has nothing objective to check beyond determinism and
  symmetry. Deciding what a style must prove before it lands is an open
  question, and it shapes what the review gate can enforce.

- **No API-stability policy.** `burrows` depends on this at `0.1.0`. There is no
  written statement about what counts as a breaking change, whether the protocols
  are public extension points or internal implementation detail, and how versions
  get tagged. A factory that can open PRs against a library needs that boundary
  drawn.

- **A small README inaccuracy.** The README advertises "Four built-in renderers"
  and then lists three concrete ones plus the protocol seam. Trivial in itself,
  but a useful first bead: unambiguous, verifiable, and it exercises the whole
  pipeline without any architectural judgement.
