//
// Byte-for-byte parity tests against golden fixtures captured from the
// reference Jdenticon v3.3.0 (`jdenticon.toSvg`). The fixtures live in
// Fixtures/goldens.json; regenerate them with /tmp tooling if the upstream
// algorithm ever changes (it is stable across the 3.x line).
//

import Foundation
import Testing

@testable import Identikit

/// One golden case decoded from the fixture file.
private struct Golden: Decodable {
    let value: String
    let size: Double
    let svg: String
}

private func loadGoldens() throws -> [String: Golden] {
    let url = try #require(
        Bundle.module.url(forResource: "goldens", withExtension: "json"),
        "goldens.json must be bundled as a test resource"
    )
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([String: Golden].self, from: data)
}

/// Per-name configuration overrides for the two fixtures generated with a
/// non-default Jdenticon config.
private func config(for name: String) -> IdenticonConfig {
    switch name {
    case "alice_cfg_100":
        // Generated with { backColor: "#0000", padding: 0.12 } — transparent
        // background (alpha 0 => no rect) and wider padding.
        return IdenticonConfig(padding: 0.12, backColor: IdenticonColor(red: 0, green: 0, blue: 0, alpha: 0))
    case "alice_back_100":
        // Generated with { backColor: "#ffffffff" } — opaque white background.
        return IdenticonConfig(backColor: IdenticonColor(red: 255, green: 255, blue: 255, alpha: 255))
    default:
        return IdenticonConfig()
    }
}

@Suite("Jdenticon SVG parity")
struct JdenticonParityTests {
    @Test("SVG output matches Jdenticon v3.3.0 golden fixtures")
    func svgMatchesGoldens() throws {
        let goldens = try loadGoldens()
        #expect(!goldens.isEmpty)

        for (name, golden) in goldens.sorted(by: { $0.key < $1.key }) {
            let produced = Identicon.svg(for: golden.value, size: golden.size, config: config(for: name))
            #expect(produced == golden.svg, "mismatch for case \"\(name)\"")
        }
    }
}

@Suite("Identicon API")
struct IdenticonAPITests {
    @Test("Generation is deterministic")
    func deterministic() {
        let first = Identicon.svg(for: "burrows", size: 100)
        let second = Identicon.svg(for: "burrows", size: 100)
        #expect(first == second)
    }

    @Test("Different inputs produce different icons")
    func distinctInputs() {
        #expect(Identicon.svg(for: "Alice", size: 100) != Identicon.svg(for: "Bob", size: 100))
    }

    @Test("A valid hex hash is used verbatim, not re-hashed")
    func prehashUsedVerbatim() {
        let hash = "fa3b9c1d2e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b"
        #expect(IdenticonHasher.isValidHash(hash))
        #expect(Identicon.svg(for: hash, size: 100) == Identicon.svg(forHash: hash, size: 100))
    }

    @Test("Short non-hex input is hashed with SHA-1")
    func shortInputHashed() {
        #expect(!IdenticonHasher.isValidHash("Bob"))
        #expect(IdenticonHasher.sha1Hex("") == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    @Test("Output is well-formed SVG of the requested size")
    func wellFormedSVG() {
        let svg = Identicon.svg(for: "Alice", size: 64)
        #expect(svg.hasPrefix("<svg "))
        #expect(svg.hasSuffix("</svg>"))
        #expect(svg.contains("width=\"64\""))
        #expect(svg.contains("viewBox=\"0 0 64 64\""))
    }
}

#if canImport(CoreGraphics)
    @Suite("CoreGraphics renderer")
    struct CoreGraphicsRendererTests {
        @Test("Produces an image of the expected pixel size")
        func imageSize() throws {
            let image = try #require(Identicon.cgImage(for: "Alice", size: 64, scale: 2))
            #expect(image.width == 128)
            #expect(image.height == 128)
        }
    }
#endif
