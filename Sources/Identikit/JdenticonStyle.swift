//
// JdenticonStyle — a faithful Swift port of Jdenticon's icon generator and
// shape tables (`iconGenerator.js` + `shapes.js`). See Attribution.swift for
// provenance (Jdenticon v3.3.0, MIT, Daniel Mester Pirttijärvi).
//
// The icon is a 4×4 cell grid drawn with octagonal symmetry: a "sides" group of
// 8 positions, a "corners" group of 4, and a "center" group of 4. The hash
// selects each group's shape variant, rotation, and color.
//

import Foundation

// Single-letter shape-math names (g, i, k, m, w, h) match the ported reference
// (`iconGenerator.js` / `shapes.js`) and standard geometry notation.
// swiftlint:disable identifier_name

/// The Jdenticon visual style: organic, octagonally-symmetric icons.
public struct JdenticonStyle: IdenticonStyle {
    public init() {}

    public func render(hash: String, config: IdenticonConfig, into renderer: IdenticonRenderer) {
        if let background = config.backColor {
            renderer.setBackground(background)
        }

        var size = renderer.iconSize
        let padding = truncToInt(0.5 + size * config.padding)
        size -= Double(padding) * 2

        let graphics = Graphics(renderer: renderer)

        // Cell size and centering offset, snapped to whole pixels.
        let cell = Double(truncToInt(size / 4))
        let origin = Double(truncToInt(Double(padding) + size / 2 - cell * 2))

        // Five candidate colors from the hash-derived hue.
        let hue = Double(IdenticonHasher.parseHex(hash, -7)) / Double(0x0FFF_FFFF)
        let availableColors = colorTheme(hue: hue, config: config)

        // Pick three palette indices, avoiding low-contrast gray/color clashes.
        var selected: [Int] = []
        func isDuplicate(_ values: [Int], _ index: Int) -> Bool {
            guard values.contains(index) else { return false }
            return values.contains { selected.contains($0) }
        }
        for i in 0..<3 {
            var index = IdenticonHasher.parseHex(hash, 8 + i, 1) % availableColors.count
            if isDuplicate([0, 4], index) || isDuplicate([2, 3], index) {
                index = 1
            }
            selected.append(index)
        }

        func renderShape(
            colorIndex: Int,
            shape: ShapeRenderer,
            shapeHashIndex: Int,
            rotationHashIndex: Int?,
            positions: [(Int, Int)]
        ) {
            let shapeIndex = IdenticonHasher.parseHex(hash, shapeHashIndex, 1)
            var rotation = rotationHashIndex.map { IdenticonHasher.parseHex(hash, $0, 1) } ?? 0

            renderer.beginShape(availableColors[selected[colorIndex]])
            for (i, position) in positions.enumerated() {
                graphics.currentTransform = Transform(
                    x: origin + Double(position.0) * cell,
                    y: origin + Double(position.1) * cell,
                    size: cell,
                    rotation: rotation % 4
                )
                shape(shapeIndex, graphics, cell, i)
                rotation += 1
            }
            renderer.endShape()
        }

        let sides: [(Int, Int)] = [(1, 0), (2, 0), (2, 3), (1, 3), (0, 1), (3, 1), (3, 2), (0, 2)]
        let corners: [(Int, Int)] = [(0, 0), (3, 0), (3, 3), (0, 3)]
        let center: [(Int, Int)] = [(1, 1), (2, 1), (2, 2), (1, 2)]
        renderShape(colorIndex: 0, shape: outerShape, shapeHashIndex: 2, rotationHashIndex: 3, positions: sides)
        renderShape(colorIndex: 1, shape: outerShape, shapeHashIndex: 4, rotationHashIndex: 5, positions: corners)
        renderShape(colorIndex: 2, shape: centerShape, shapeHashIndex: 1, rotationHashIndex: nil, positions: center)

        renderer.finish()
    }
}

/// Draws one variant of a shape into `g`. `cell` is the cell side length and
/// `positionIndex` is the index of this copy within its symmetry group.
typealias ShapeRenderer = (_ index: Int, _ g: Graphics, _ cell: Double, _ positionIndex: Int) -> Void

// The 14-way shape dispatch below is a verbatim port; its breadth and length
// are inherent to the shape table.
// swiftlint:disable cyclomatic_complexity function_body_length

/// The 14 center-shape variants. Ported verbatim from Jdenticon's `centerShape`.
func centerShape(_ rawIndex: Int, _ g: Graphics, _ cell: Double, _ positionIndex: Int) {
    switch rawIndex % 14 {
    case 0:
        let k = cell * 0.42
        g.addPolygon([0, 0, cell, 0, cell, cell - k * 2, cell - k, cell, 0, cell])
    case 1:
        let w = Double(truncToInt(cell * 0.5))
        let h = Double(truncToInt(cell * 0.8))
        g.addTriangle(cell - w, 0, w, h, 2)
    case 2:
        let w = Double(truncToInt(cell / 3))
        g.addRectangle(w, w, cell - w, cell - w)
    case 3:
        var inner = cell * 0.1
        let outer: Double = cell < 6 ? 1 : cell < 8 ? 2 : Double(truncToInt(cell * 0.25))
        inner = inner > 1 ? Double(truncToInt(inner)) : inner > 0.5 ? 1 : inner
        g.addRectangle(outer, outer, cell - inner - outer, cell - inner - outer)
    case 4:
        let m = Double(truncToInt(cell * 0.15))
        let w = Double(truncToInt(cell * 0.5))
        g.addCircle(cell - w - m, cell - w - m, w)
    case 5:
        let inner = cell * 0.1
        var outer = inner * 4
        if outer > 3 { outer = Double(truncToInt(outer)) }
        g.addRectangle(0, 0, cell, cell)
        g.addPolygon(
            [
                outer, outer,
                cell - inner, outer,
                outer + (cell - outer - inner) / 2, cell - inner,
            ], invert: true)
    case 6:
        g.addPolygon([
            0, 0,
            cell, 0,
            cell, cell * 0.7,
            cell * 0.4, cell * 0.4,
            cell * 0.7, cell,
            0, cell,
        ])
    case 7:
        g.addTriangle(cell / 2, cell / 2, cell / 2, cell / 2, 3)
    case 8:
        g.addRectangle(0, 0, cell, cell / 2)
        g.addRectangle(0, cell / 2, cell / 2, cell / 2)
        g.addTriangle(cell / 2, cell / 2, cell / 2, cell / 2, 1)
    case 9:
        var inner = cell * 0.14
        let outer: Double = cell < 4 ? 1 : cell < 6 ? 2 : Double(truncToInt(cell * 0.35))
        inner = cell < 8 ? inner : Double(truncToInt(inner))
        g.addRectangle(0, 0, cell, cell)
        g.addRectangle(outer, outer, cell - outer - inner, cell - outer - inner, invert: true)
    case 10:
        let inner = cell * 0.12
        let outer = inner * 3
        g.addRectangle(0, 0, cell, cell)
        g.addCircle(outer, outer, cell - inner - outer, invert: true)
    case 11:
        g.addTriangle(cell / 2, cell / 2, cell / 2, cell / 2, 3)
    case 12:
        let m = cell * 0.25
        g.addRectangle(0, 0, cell, cell)
        g.addRhombus(m, m, cell - m, cell - m, invert: true)
    default:  // 13 — a large circle, drawn only in the first position
        if positionIndex == 0 {
            let m = cell * 0.4
            let w = cell * 1.2
            g.addCircle(m, m, w)
        }
    }
}

// swiftlint:enable cyclomatic_complexity function_body_length

/// The 4 corner/side-shape variants. Ported verbatim from Jdenticon's
/// `outerShape`.
func outerShape(_ rawIndex: Int, _ g: Graphics, _ cell: Double, _ positionIndex: Int) {
    switch rawIndex % 4 {
    case 0:
        g.addTriangle(0, 0, cell, cell, 0)
    case 1:
        g.addTriangle(0, cell / 2, cell, cell / 2, 0)
    case 2:
        g.addRhombus(0, 0, cell, cell)
    default:  // 3
        let m = cell / 6
        g.addCircle(m, m, cell - 2 * m)
    }
}

// swiftlint:enable identifier_name
