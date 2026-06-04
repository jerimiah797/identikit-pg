//
// The shape-helper layer between a style and a renderer. Styles describe icons
// in terms of rectangles, triangles, rhombuses and circles; `Graphics` applies
// the current ``Transform`` and forwards primitive polygons/circles to the
// renderer. Ported from Jdenticon's `graphics.js`.
//

import Foundation

// Single-letter coordinate/dimension names (x, y, w, h, r) are the standard
// vocabulary for this geometry code and match the ported reference.
// swiftlint:disable identifier_name

/// Renders common primitives through the current transform onto a renderer.
final class Graphics {
    private let renderer: IdenticonRenderer

    /// The transform applied to every primitive added until it is replaced.
    var currentTransform: Transform = .none

    init(renderer: IdenticonRenderer) {
        self.renderer = renderer
    }

    /// Adds a polygon from a flat `[x0, y0, x1, y1, ...]` coordinate list.
    /// When `invert` is true the vertex order is reversed (to punch a hole).
    func addPolygon(_ points: [Double], invert: Bool = false) {
        let step = invert ? -2 : 2
        var transformed: [IdenticonPoint] = []
        var i = invert ? points.count - 2 : 0
        while i >= 0, i < points.count {
            transformed.append(currentTransform.point(points[i], points[i + 1]))
            i += step
        }
        renderer.addPolygon(transformed)
    }

    /// Adds a circle whose bounding box upper-left is `(x, y)` and side `size`.
    func addCircle(_ x: Double, _ y: Double, _ size: Double, invert: Bool = false) {
        let corner = currentTransform.point(x, y, size, size)
        renderer.addCircle(corner, diameter: size, counterClockwise: invert)
    }

    /// Adds an axis-aligned rectangle.
    func addRectangle(_ x: Double, _ y: Double, _ w: Double, _ h: Double, invert: Bool = false) {
        addPolygon([x, y, x + w, y, x + w, y + h, x, y + h], invert: invert)
    }

    /// Adds a right triangle in the bounding box `(x, y, w, h)`. `r` rotates it
    /// clockwise in quarter turns; `r = 0` puts the right angle at lower-left.
    func addTriangle(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Int, invert: Bool = false) {
        var points = [x + w, y, x + w, y + h, x, y + h, x, y]
        let drop = (((r % 4) + 4) % 4) * 2
        points.removeSubrange(drop..<drop + 2)
        addPolygon(points, invert: invert)
    }

    /// Adds a rhombus inscribed in the bounding box `(x, y, w, h)`.
    func addRhombus(_ x: Double, _ y: Double, _ w: Double, _ h: Double, invert: Bool = false) {
        addPolygon(
            [
                x + w / 2, y,
                x + w, y + h / 2,
                x + w / 2, y + h,
                x, y + h / 2,
            ], invert: invert)
    }
}

// swiftlint:enable identifier_name
