//
// Tests for MosaicStyle. The PRNG's 32-bit arithmetic is the only subtle part,
// so it is pinned to a golden sequence generated in node (Fixtures/prng-golden.json,
// normalized to [0, 1)). The rest is verified structurally: symmetry,
// determinism, value range, and renderer-agnosticism.
//

import Foundation
import Testing

@testable import Identikit

@Suite("Mosaic PRNG")
struct MosaicRNGTests {
    private func goldenSequences() throws -> [String: [Double]] {
        let url = try #require(
            Bundle.module.url(forResource: "prng-golden", withExtension: "json"),
            "prng-golden.json must be bundled as a test resource"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: [Double]].self, from: data)
    }

    @Test("xorshift sequence matches the golden values")
    func sequenceMatchesGolden() throws {
        let goldens = try goldenSequences()
        for (seed, expected) in goldens {
            var rng = MosaicRNG(seed: seed)
            for (index, want) in expected.enumerated() {
                let got = rng.next()
                #expect(abs(got - want) < 1e-12, "seed \"\(seed)\" index \(index): \(got) vs \(want)")
            }
        }
    }

    @Test("values stay within [0, 1)")
    func valuesInUnitInterval() {
        var rng = MosaicRNG(seed: "burrows")
        for _ in 0..<1000 {
            let value = rng.next()
            #expect(value >= 0 && value < 1)
        }
    }

    @Test("grid cells are only 0, 1, or 2")
    func gridValuesInRange() {
        var rng = MosaicRNG(seed: "burrows")
        let cells = rng.grid(size: 8)
        #expect(cells.count == 64)
        #expect(cells.allSatisfy { (0...2).contains($0) })
    }

    @Test("values use the full [0, 1) range (regression: 2^31 normalization)")
    func valuesUseFullRange() {
        // The earlier 2^32 normalization squashed every value into [0, 0.5),
        // which collapsed the cell distribution. Guard against it.
        var rng = MosaicRNG(seed: "burrows")
        var sawHigh = false
        for _ in 0..<200 where rng.next() >= 0.5 {
            sawHigh = true
            break
        }
        #expect(sawHigh, "PRNG must produce values >= 0.5")
    }

    @Test("cell distribution is balanced, not background-dominated")
    func cellDistributionIsBalanced() {
        var rng = MosaicRNG(seed: "burrows")
        let cells = rng.grid(size: 24)
        var counts = [0, 0, 0]
        for cell in cells { counts[cell] += 1 }
        let total = Double(cells.count)
        #expect(counts[2] > 0, "spot color (value 2) must appear")
        #expect(Double(counts[0]) / total < 0.65, "background must not dominate")
        #expect(Double(counts[1]) / total > 0.2, "main must be well represented")
    }

    @Test("grid is mirrored left-to-right")
    func gridIsHorizontallySymmetric() {
        var rng = MosaicRNG(seed: "burrows")
        let size = 8
        let cells = rng.grid(size: size)
        for row in 0..<size {
            for col in 0..<size {
                let mirror = cells[row * size + (size - 1 - col)]
                #expect(cells[row * size + col] == mirror)
            }
        }
    }
}

@Suite("Mosaic style")
struct MosaicStyleTests {
    @Test("Generation is deterministic")
    func deterministic() {
        let first = Identicon.svg(for: "burrows", size: 96, style: MosaicStyle())
        let second = Identicon.svg(for: "burrows", size: 96, style: MosaicStyle())
        #expect(first == second)
    }

    @Test("Different inputs produce different icons")
    func distinctInputs() {
        let alice = Identicon.svg(for: "Alice", size: 96, style: MosaicStyle())
        let bob = Identicon.svg(for: "Bob", size: 96, style: MosaicStyle())
        #expect(alice != bob)
    }

    @Test("Different grid sizes produce different icons")
    func gridSizeMatters() {
        let small = Identicon.svg(for: "burrows", size: 96, style: MosaicStyle(gridSize: 5))
        let large = Identicon.svg(for: "burrows", size: 96, style: MosaicStyle(gridSize: 10))
        #expect(small != large)
    }

    @Test("Output is well-formed SVG with transparent ground and tiles")
    func wellFormedSVG() {
        let svg = Identicon.svg(for: "Alice", size: 96, style: MosaicStyle())
        #expect(svg.hasPrefix("<svg "))
        #expect(svg.hasSuffix("</svg>"))
        #expect(svg.contains("viewBox=\"0 0 96 96\""))
        #expect(!svg.contains("<rect "))  // transparent by default (no background fill)
        #expect(svg.contains("<path "))  // at least one tile color
    }

    @Test("An explicit backColor fills the ground")
    func explicitBackground() {
        let config = IdenticonConfig(backColor: IdenticonColor(red: 0, green: 0, blue: 0))
        let svg = Identicon.svg(for: "Alice", size: 96, config: config, style: MosaicStyle())
        #expect(svg.contains("<rect "))
    }

    @Test("Works with the CoreGraphics renderer too")
    func worksWithCoreGraphics() throws {
        #if canImport(CoreGraphics)
            let image = try #require(Identicon.cgImage(for: "burrows", size: 64, style: MosaicStyle()))
            #expect(image.width == 64)
            #expect(image.height == 64)
        #endif
    }
}
