//
// MosaicStyle — a symmetric tiled-block identicon. The icon is an `n × n` grid
// of colored squares, mirrored left↔right, driven by a small seeded PRNG. It is
// a deliberate counterpoint to JdenticonStyle: pixel tiles instead of vector
// shapes, and a PRNG stream instead of hash-nibble lookups — which makes it a
// good exercise of the Style × Renderer seam.
//
// The symmetric pixel-grid technique is inspired by the MIT-licensed "blockies"
// identicon algorithm (see Attribution.swift). This is a clean reimplementation,
// not a port: the PRNG is normalized to [0, 1) so the documented cell
// probabilities actually hold, the palette is computed in muted HSL ranges, and
// the seed is the caller's hash — there is no association with any external
// addressing scheme.
//

import Foundation

// Single-letter loop/coordinate names match standard grid/geometry notation.
// swiftlint:disable identifier_name

/// The two foreground colors of a mosaic icon. The third region (value 0) is
/// left transparent so the icon adapts to whatever surface it sits on.
struct MosaicPalette {
    let main: IdenticonColor
    let spot: IdenticonColor
}

/// A deterministic xorshift PRNG seeded from a string. The 32-bit arithmetic is
/// reproduced exactly (validated against a golden sequence) so output is stable
/// across platforms.
struct MosaicRNG {
    private var s0: Int32 = 0
    private var s1: Int32 = 0
    private var s2: Int32 = 0
    private var s3: Int32 = 0

    /// Seeds the generator from the bytes of `seed` (Java-`hashCode`-style fold
    /// into four 32-bit lanes).
    init(seed: String) {
        var state: [Int32] = [0, 0, 0, 0]
        for (i, byte) in seed.utf8.enumerated() {
            let lane = i % 4
            state[lane] = (state[lane] &<< 5) &- state[lane] &+ Int32(byte)
        }
        s0 = state[0]
        s1 = state[1]
        s2 = state[2]
        s3 = state[3]
    }

    /// Returns the next pseudo-random value in `[0, 1)`.
    ///
    /// This recurrence has a useful property: the sign bit of `s3` always
    /// cancels to 0, so the value is always in `[0, 2^31)`. Dividing by `2^31`
    /// therefore yields a uniform `[0, 1)`. (Dividing by `2^32` would squash
    /// every value into `[0, 0.5)` and collapse the cell/color distributions.)
    mutating func next() -> Double {
        let t = s0 ^ (s0 &<< 11)
        s0 = s1
        s1 = s2
        s2 = s3
        s3 = s3 ^ (s3 >> 19) ^ t ^ (t >> 8)
        return Double(UInt32(bitPattern: s3)) / 2_147_483_648  // 2^31
    }

    /// Draws two vivid, well-separated colors from the seed: a dominant `main`
    /// and a near-complementary `spot` accent. Both are saturated and a touch
    /// bright so they read clearly against either a light or dark surface (the
    /// transparent third region shows the surface through).
    mutating func palette() -> MosaicPalette {
        func wrap(_ hue: Double) -> Double {
            let f = hue.truncatingRemainder(dividingBy: 1)
            return f < 0 ? f + 1 : f
        }
        let baseHue = next()
        let mainHue = wrap(baseHue)
        let main = hsl(hue: mainHue, saturation: 0.6 + next() * 0.2, lightness: 0.5 + next() * 0.12)
        let spotHue = wrap(baseHue + 0.45 + (next() - 0.5) * 0.18)
        let spot = hsl(hue: spotHue, saturation: 0.62 + next() * 0.2, lightness: 0.55 + next() * 0.12)
        return MosaicPalette(main: main, spot: spot)
    }

    /// Builds an `size × size` cell grid (row-major) of values 0/1/2, mirrored
    /// left↔right. With the `[0, 1)` PRNG the probabilities are ~43% background
    /// (0), ~43% main (1), ~13% spot (2).
    mutating func grid(size: Int) -> [Int] {
        let dataWidth = (size + 1) / 2
        let mirrorWidth = size - dataWidth
        var cells: [Int] = []
        cells.reserveCapacity(size * size)
        for _ in 0..<size {
            var row: [Int] = []
            for _ in 0..<dataWidth { row.append(Int(next() * 2.3)) }
            for k in 0..<mirrorWidth { row.append(row[mirrorWidth - 1 - k]) }
            cells.append(contentsOf: row)
        }
        return cells
    }
}

/// A symmetric tiled-block identicon style.
public struct MosaicStyle: IdenticonStyle {
    /// The grid is `gridSize × gridSize` cells. Defaults to 8.
    public var gridSize: Int

    /// Creates the style. `gridSize` is clamped to at least 1.
    public init(gridSize: Int = 8) {
        self.gridSize = max(1, gridSize)
    }

    public func render(hash: String, config: IdenticonConfig, into renderer: IdenticonRenderer) {
        var rng = MosaicRNG(seed: hash)
        let palette = rng.palette()
        let cells = rng.grid(size: gridSize)

        // Full-bleed tiles: fractional cell size, no padding — adjacent edges are
        // computed identically so they abut with no seam. (config.padding is not
        // used by this style; the blocky look fills the frame.)
        let size = renderer.iconSize
        let cell = size / Double(gridSize)

        // Value-0 cells are left transparent so the icon adapts to its surface;
        // an explicit backColor (if set) fills them instead.
        if let background = config.backColor {
            renderer.setBackground(background)
        }

        // One pass per foreground value, so each color is a single grouped path.
        for value in [1, 2] {
            renderer.beginShape(value == 1 ? palette.main : palette.spot)
            for row in 0..<gridSize {
                for col in 0..<gridSize where cells[row * gridSize + col] == value {
                    let x = Double(col) * cell
                    let y = Double(row) * cell
                    renderer.addPolygon([
                        IdenticonPoint(x: x, y: y),
                        IdenticonPoint(x: x + cell, y: y),
                        IdenticonPoint(x: x + cell, y: y + cell),
                        IdenticonPoint(x: x, y: y + cell),
                    ])
                }
            }
            renderer.endShape()
        }

        renderer.finish()
    }
}

// swiftlint:enable identifier_name
