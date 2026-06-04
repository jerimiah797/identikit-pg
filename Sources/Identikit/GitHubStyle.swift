//
// GitHubStyle — the familiar 5×5 identicon: a single saturated foreground color
// on a transparent ground, with a margin. The cell grid is mirrored left↔right,
// so each icon is a small symmetric sprite. Leaving the ground transparent lets
// the icon sit on white or black; pass an explicit `backColor` for an opaque
// tile. A third counterpoint to the other styles (multi-shape vector /
// multi-color full-bleed pixels), it exercises the seam with yet another shape
// of algorithm.
//
// The 5×5-mirrored-single-color identicon is a widely-used general technique
// (popularized by GitHub; see Attribution.swift). This is an independent
// implementation seeded from the caller's hash.
//

import Foundation

// Single-letter loop/coordinate names match standard grid/geometry notation.
// swiftlint:disable identifier_name

/// Builds an `size × size` on/off cell grid (row-major), mirrored left↔right.
/// Each unique cell (left half plus the center column) is decided by a hash
/// nibble: even is "on" (foreground), odd is "off" (background).
func gitHubGrid(hash: String, size: Int) -> [Bool] {
    let half = (size + 1) / 2
    var cells = [Bool](repeating: false, count: size * size)
    for col in 0..<half {
        for row in 0..<size {
            let nibble = IdenticonHasher.parseHex(hash, col * size + row, 1)
            let on = nibble % 2 == 0
            cells[row * size + col] = on
            cells[row * size + (size - 1 - col)] = on
        }
    }
    return cells
}

/// The classic GitHub-style identicon: one color on a light background.
public struct GitHubStyle: IdenticonStyle {
    /// The grid is `gridSize × gridSize` cells. Defaults to 5.
    public var gridSize: Int

    /// Creates the style. `gridSize` is clamped to at least 1.
    public init(gridSize: Int = 5) {
        self.gridSize = max(1, gridSize)
    }

    public func render(hash: String, config: IdenticonConfig, into renderer: IdenticonRenderer) {
        // Foreground hue from the hash (same source as JdenticonStyle), at a
        // fixed saturation/lightness for the steady GitHub-like look.
        let hue = Double(IdenticonHasher.parseHex(hash, -7)) / Double(0x0FFF_FFFF)
        let foreground = hsl(hue: hue, saturation: 0.55, lightness: 0.58)
        let cells = gitHubGrid(hash: hash, size: gridSize)

        // Inset, pixel-snapped grid so the icon keeps its signature margin.
        let size = renderer.iconSize
        let padding = Double(truncToInt(0.5 + size * config.padding))
        let area = size - padding * 2
        let cell = Double(truncToInt(area / Double(gridSize)))
        let origin = Double(truncToInt(padding + (area - cell * Double(gridSize)) / 2))

        // Transparent by default so the icon works on white or black; an explicit
        // backColor (if set) fills the ground instead.
        if let background = config.backColor {
            renderer.setBackground(background)
        }
        renderer.beginShape(foreground)
        for row in 0..<gridSize {
            for col in 0..<gridSize where cells[row * gridSize + col] {
                let x = origin + Double(col) * cell
                let y = origin + Double(row) * cell
                renderer.addPolygon([
                    IdenticonPoint(x: x, y: y),
                    IdenticonPoint(x: x + cell, y: y),
                    IdenticonPoint(x: x + cell, y: y + cell),
                    IdenticonPoint(x: x, y: y + cell),
                ])
            }
        }
        renderer.endShape()
        renderer.finish()
    }
}

// swiftlint:enable identifier_name
