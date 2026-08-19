//
// Tests for RosetteStyle. The interesting parts are the polar layout and the
// arc tessellation, so both are tested directly: the pattern must be invariant
// under a one-wedge rotation (that is what "n-fold symmetry" means here),
// neighboring bands must contrast, no seed may produce a blank icon, and the
// tessellated cells must actually land on the two radii they claim. The style
// itself is then checked the way the other styles are — determinism, distinct
// inputs, the knob, and both renderers.
//

import Foundation
import Testing

#if canImport(CoreGraphics)
    import CoreGraphics
#endif

@testable import Identikit

/// Seeds used wherever a test wants to assert an invariant over many hashes
/// rather than one hand-picked example.
private let sampleSeeds = (0..<400).map { "rosette-seed-\($0)" }

@Suite("Rosette layout")
struct RosetteLayoutTests {
    private func layout(_ seed: String, bandCount: Int = 3) -> RosetteLayout {
        rosetteLayout(hash: IdenticonHasher.resolve(seed), bandCount: bandCount, paletteSize: 5)
    }

    @Test("Fold count is one of the allowed repeats")
    func foldCountInRange() {
        for seed in sampleSeeds {
            let pattern = layout(seed)
            #expect(rosetteFoldChoices.contains(pattern.folds))
            #expect(pattern.sectors == pattern.folds * rosetteSectorsPerFold)
        }
    }

    @Test("Pattern is invariant under a one-wedge rotation")
    func rotationallySymmetric() {
        for seed in sampleSeeds.prefix(50) {
            let pattern = layout(seed)
            for band in 0..<pattern.ringColors.count {
                for sector in 0..<pattern.sectors {
                    let rotated = (sector + pattern.sectorsPerFold) % pattern.sectors
                    #expect(
                        pattern.isFilled(band: band, sector: sector)
                            == pattern.isFilled(band: band, sector: rotated),
                        "seed \(seed) band \(band) sector \(sector)")
                }
            }
        }
    }

    @Test("Layout is deterministic for a given hash")
    func deterministic() {
        let hash = IdenticonHasher.resolve("burrows")
        let first = rosetteLayout(hash: hash, bandCount: 3, paletteSize: 5)
        let second = rosetteLayout(hash: hash, bandCount: 3, paletteSize: 5)
        #expect(first.folds == second.folds)
        #expect(first.ringColors == second.ringColors)
        #expect(first.wedges == second.wedges)
        #expect(first.hubColor == second.hubColor)
    }

    @Test("Wedges hold a pattern, so bands are not all plain annuli")
    func wedgesCarryDetail() {
        // If every wedge were uniformly filled or empty, every icon would be a
        // plain target. Across the sample at least one band must be mixed.
        let mixed = sampleSeeds.contains { seed in
            layout(seed).wedges.contains { $0.contains(true) && $0.contains(false) }
        }
        #expect(mixed, "some band must have both filled and empty sectors")
    }

    @Test("Color indices stay inside the palette")
    func colorsInRange() {
        for seed in sampleSeeds {
            let pattern = layout(seed)
            #expect(pattern.ringColors.allSatisfy { (0..<5).contains($0) })
            if let hub = pattern.hubColor { #expect((0..<5).contains(hub)) }
        }
    }

    @Test("Neighboring bands never share a clashing lightness")
    func neighborsContrast() {
        for seed in sampleSeeds {
            for bandCount in 1...6 {
                let pattern = layout(seed, bandCount: bandCount)
                let colors = pattern.ringColors
                for band in 1..<colors.count {
                    #expect(colors[band] != colors[band - 1], "seed \(seed) bands \(band - 1)/\(band)")
                    let clash = rosetteClashingColors.contains {
                        $0.contains(colors[band]) && $0.contains(colors[band - 1])
                    }
                    #expect(!clash, "seed \(seed) bands \(band - 1)/\(band) both \(colors[band])")
                }
                // The hub sits against the innermost band and needs the same room.
                if let hub = pattern.hubColor, let innermost = colors.last {
                    #expect(hub != innermost)
                    let clash = rosetteClashingColors.contains {
                        $0.contains(hub) && $0.contains(innermost)
                    }
                    #expect(!clash, "seed \(seed) hub \(hub) vs innermost \(innermost)")
                }
            }
        }
    }

    @Test("No seed produces an entirely empty pattern")
    func neverEmpty() {
        // bandCount 1 makes the all-empty case common (1 in 8 seeds), so this
        // exercises the solid-outer-band fallback rather than just asserting past it.
        for bandCount in 1...4 {
            for seed in sampleSeeds {
                let pattern = layout(seed, bandCount: bandCount)
                #expect(
                    pattern.wedges.contains { $0.contains(true) },
                    "seed \(seed) bandCount \(bandCount) rendered nothing")
            }
        }
    }

    @Test("Both hub states occur across seeds")
    func hubVaries() {
        let hubs = sampleSeeds.map { layout($0).hubColor }
        #expect(hubs.contains { $0 != nil }, "some icons must have a solid hub")
        #expect(hubs.contains { $0 == nil }, "some icons must be left open")
    }
}

@Suite("Rosette color contrast")
struct RosetteContrastTests {
    @Test("Clashing pairs fall back to the mid color")
    func clashesResolveToMid() {
        // Palette order is [dark gray, mid color, light gray, light color, dark color].
        #expect(rosetteContrastingColor(2, against: 3, paletteSize: 5) == 1)  // two lights
        #expect(rosetteContrastingColor(3, against: 2, paletteSize: 5) == 1)
        #expect(rosetteContrastingColor(0, against: 4, paletteSize: 5) == 1)  // two darks
        #expect(rosetteContrastingColor(2, against: 2, paletteSize: 5) == 1)  // same light twice
        #expect(rosetteContrastingColor(0, against: 0, paletteSize: 5) == 1)
    }

    @Test("An exact repeat outside a clash group steps to the next entry")
    func repeatStepsOn() {
        #expect(rosetteContrastingColor(1, against: 1, paletteSize: 5) == 2)
    }

    @Test("Contrasting pairs and the outermost band pass through unchanged")
    func noChangeWhenFine() {
        #expect(rosetteContrastingColor(1, against: 3, paletteSize: 5) == 1)
        #expect(rosetteContrastingColor(4, against: 2, paletteSize: 5) == 4)
        #expect(rosetteContrastingColor(3, against: nil, paletteSize: 5) == 3)
    }
}

@Suite("Rosette nibbles")
struct RosetteNibbleTests {
    @Test("Indices wrap around the hash instead of reading past the end")
    func indicesWrap() {
        let hash = IdenticonHasher.resolve("burrows")
        #expect(rosetteNibble(hash, hash.count) == rosetteNibble(hash, 0))
        #expect(rosetteNibble(hash, hash.count + 3) == rosetteNibble(hash, 3))
        #expect(rosetteNibble(hash, -1) == rosetteNibble(hash, hash.count - 1))
    }

    @Test("A large bandCount still varies instead of filling every band")
    func largeBandCountStillVaries() {
        // Reading past a 40-character digest would return 0 for every cell, and
        // 0 is even, so every band would come out solid.
        let pattern = rosetteLayout(
            hash: IdenticonHasher.resolve("burrows"), bandCount: 24, paletteSize: 5)
        let filled = pattern.wedges.flatMap { $0 }.filter { $0 }.count
        let total = pattern.wedges.flatMap { $0 }.count
        #expect(filled > 0)
        #expect(filled < total, "every single cell came out filled")
    }

    @Test("An empty hash is handled without trapping")
    func emptyHash() {
        #expect(rosetteNibble("", 0) == 0)
        let pattern = rosetteLayout(hash: "", bandCount: 3, paletteSize: 5)
        #expect(pattern.wedges.contains { $0.contains(true) })
    }

    @Test("A zero band count yields an empty layout rather than trapping")
    func zeroBandCount() {
        // The empty-pattern fallback writes to the outermost band, which does not
        // exist here; `allSatisfy` is vacuously true on an empty array.
        let pattern = rosetteLayout(
            hash: IdenticonHasher.resolve("burrows"), bandCount: 0, paletteSize: 5)
        #expect(pattern.wedges.isEmpty)
        #expect(pattern.ringColors.isEmpty)
    }
}

@Suite("Rosette geometry")
struct RosetteSectorTests {
    private let center = IdenticonPoint(x: 50, y: 50)

    private func distance(_ point: IdenticonPoint) -> Double {
        ((point.x - center.x) * (point.x - center.x) + (point.y - center.y) * (point.y - center.y))
            .squareRoot()
    }

    @Test("Every vertex lies on one of the cell's two radii")
    func verticesOnRadii() {
        let points = rosetteSector(
            center: center, innerRadius: 12, outerRadius: 40,
            startAngle: 0.4, endAngle: 0.4 + .pi / 6)
        #expect(points.count >= 6)
        for point in points {
            let radius = distance(point)
            let onOuter = abs(radius - 40) < 1e-9
            let onInner = abs(radius - 12) < 1e-9
            #expect(onOuter || onInner, "radius \(radius) is on neither edge")
        }
    }

    @Test("The sweep stays inside the requested angles")
    func sweepIsBounded() {
        let start = 0.3, end = 0.3 + .pi / 5
        let points = rosetteSector(
            center: center, innerRadius: 10, outerRadius: 40, startAngle: start, endAngle: end)
        for point in points {
            var angle = atan2(point.y - center.y, point.x - center.x)
            if angle < 0 { angle += 2 * .pi }
            #expect(angle >= start - 1e-9 && angle <= end + 1e-9, "angle \(angle) outside sweep")
        }
    }

    @Test("A zero inner radius closes on the center as a pie wedge")
    func degenerateInnerRadius() {
        let points = rosetteSector(
            center: center, innerRadius: 0, outerRadius: 40, startAngle: 0, endAngle: .pi / 4)
        #expect(points.contains(center))
        // Exactly one center vertex, not a fan of duplicates.
        #expect(points.filter { $0 == center }.count == 1)
    }

    @Test("Tessellation follows the arc's pixel length, and is capped")
    func tessellationScales() {
        let sweep = Double.pi / 6
        let small = rosetteSector(
            center: center, innerRadius: 3, outerRadius: 10, startAngle: 0, endAngle: sweep)
        let large = rosetteSector(
            center: center, innerRadius: 20, outerRadius: 90, startAngle: 0, endAngle: sweep)
        #expect(large.count > small.count)

        let huge = rosetteSector(
            center: center, innerRadius: 100, outerRadius: 100_000, startAngle: 0, endAngle: sweep)
        #expect(huge.count <= 2 * (64 + 1), "segment count must stay capped")

        // Even a hairline sweep gets a drawable polygon.
        let sliver = rosetteSector(
            center: center, innerRadius: 39, outerRadius: 40, startAngle: 0, endAngle: 0.0001)
        #expect(sliver.count >= 6)
    }
}

@Suite("Rosette style")
struct RosetteStyleTests {
    @Test("Generation is deterministic")
    func deterministic() {
        let first = Identicon.svg(for: "burrows", size: 96, style: RosetteStyle())
        let second = Identicon.svg(for: "burrows", size: 96, style: RosetteStyle())
        #expect(first == second)
    }

    @Test("Different inputs produce different icons")
    func distinctInputs() {
        let alice = Identicon.svg(for: "Alice", size: 96, style: RosetteStyle())
        let bob = Identicon.svg(for: "Bob", size: 96, style: RosetteStyle())
        #expect(alice != bob)
    }

    @Test("Different band counts produce different icons")
    func bandCountMatters() {
        let three = Identicon.svg(for: "burrows", size: 96, style: RosetteStyle(bandCount: 3))
        let five = Identicon.svg(for: "burrows", size: 96, style: RosetteStyle(bandCount: 5))
        #expect(three != five)
    }

    @Test("Band count is clamped to at least one")
    func bandCountClamped() {
        #expect(RosetteStyle(bandCount: 0).bandCount == 1)
        #expect(RosetteStyle(bandCount: -4).bandCount == 1)
        let svg = Identicon.svg(for: "burrows", size: 96, style: RosetteStyle(bandCount: 0))
        #expect(svg.contains("<path "))
    }

    @Test("A band count assigned past the initializer still renders")
    func bandCountClampedAfterAssignment() {
        // `bandCount` is a public var, so the initializer's clamp is not the only
        // way in. An unclamped 0 used to run off the end of the layout's bands.
        var style = RosetteStyle()
        style.bandCount = 0
        let svg = Identicon.svg(for: "burrows", size: 96, style: style)
        #expect(svg.contains("<path "))

        style.bandCount = -3
        #expect(Identicon.svg(for: "burrows", size: 96, style: style).contains("<path "))
    }

    @Test("Padding wide enough to swallow the icon degrades quietly")
    func oversizedPadding() {
        var config = IdenticonConfig()
        config.padding = 0.75  // more padding than there is icon
        let svg = Identicon.svg(for: "burrows", size: 96, config: config, style: RosetteStyle())
        #expect(svg.hasPrefix("<svg "))
        #expect(svg.hasSuffix("</svg>"))
    }

    @Test("Output is well-formed SVG, transparent by default")
    func wellFormedSVG() {
        let svg = Identicon.svg(for: "Alice", size: 96, style: RosetteStyle())
        #expect(svg.hasPrefix("<svg "))
        #expect(svg.hasSuffix("</svg>"))
        #expect(svg.contains("viewBox=\"0 0 96 96\""))
        #expect(!svg.contains("<rect "))  // transparent by default (no background fill)
        #expect(svg.contains("<path "))
    }

    @Test("An explicit backColor fills the ground")
    func explicitBackground() {
        let config = IdenticonConfig(backColor: IdenticonColor(red: 0, green: 0, blue: 0))
        let svg = Identicon.svg(for: "Alice", size: 96, config: config, style: RosetteStyle())
        #expect(svg.contains("<rect "))
    }

    @Test("No seed renders a blank icon")
    func neverBlank() {
        for seed in sampleSeeds {
            let svg = Identicon.svg(for: seed, size: 96, style: RosetteStyle())
            #expect(svg.contains("<path "), "seed \(seed) drew nothing")
        }
    }

    @Test("A hub emits a circle arc alongside the band polygons")
    func hubDrawsACircle() throws {
        // Only about half of all seeds have a hub, so pick one that does — the hub
        // is the style's only use of the renderer's circle primitive, and it lands
        // in the same grouped path as the bands.
        let seed = try #require(
            sampleSeeds.first { seed in
                rosetteLayout(
                    hash: IdenticonHasher.resolve(seed), bandCount: 3, paletteSize: 5
                ).hubColor != nil
            }, "no sample seed produced a hub")
        let svg = Identicon.svg(for: seed, size: 96, style: RosetteStyle())
        // SVGStringRenderer writes circles as "a<r>,<r> 0 1,1 " elliptical arcs;
        // the flag group is unambiguous, whereas a bare "a" also matches "<path ".
        #expect(svg.contains(" 0 1,1 "), "hub circle should emit an SVG arc command")
        #expect(svg.contains("L"), "bands should emit polygon line segments")
    }

    @Test("config.hues restricts the palette")
    func huesRestriction() {
        // Colors come from the shared colorTheme, so the hue restriction that
        // JdenticonStyle honors applies to this style too.
        var config = IdenticonConfig()
        config.hues = [200]
        let restricted = Identicon.svg(for: "Alice", size: 96, config: config, style: RosetteStyle())
        let free = Identicon.svg(for: "Alice", size: 96, style: RosetteStyle())
        #expect(restricted != free)
    }

    @Test("Works with the CoreGraphics renderer too")
    func worksWithCoreGraphics() throws {
        #if canImport(CoreGraphics)
            let image = try #require(Identicon.cgImage(for: "burrows", size: 64, style: RosetteStyle()))
            #expect(image.width == 64)
            #expect(image.height == 64)
        #endif
    }

    @Test("Rasterizes to a non-empty bitmap")
    func rasterizesSomething() throws {
        #if canImport(CoreGraphics)
            let renderer = try #require(CoreGraphicsRenderer(iconSize: 64, scale: 1))
            RosetteStyle().render(
                hash: IdenticonHasher.resolve("burrows"), config: IdenticonConfig(), into: renderer)
            renderer.finish()
            let image = try #require(renderer.makeImage())
            var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
            buffer.withUnsafeMutableBytes { raw in
                let ctx = CGContext(
                    data: raw.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            #expect(buffer.contains { $0 != 0 }, "bitmap came out fully transparent")
        #endif
    }
}
