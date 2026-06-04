//
// Geometry primitives: a plain point and the translate+rotate transform that
// places each symmetric copy of a shape. Ported from Jdenticon's `point.js`
// and `transform.js`.
//

import Foundation

// Single-letter coordinate names (x, y, w, h) are the standard vocabulary for
// this geometry code and match the ported reference.
// swiftlint:disable identifier_name

/// A 2D point in icon coordinate space (origin top-left, y grows downward).
public struct IdenticonPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Translates and rotates icon-space points into a placed cell. `rotation` is
/// in quarter turns clockwise: `0 = 0`, `1 = 0.5π`, `2 = π`, `3 = 1.5π`.
struct Transform {
    let x: Double
    let y: Double
    let size: Double
    let rotation: Int

    static let none = Transform(x: 0, y: 0, size: 0, rotation: 0)

    /// Transforms a point. `w`/`h` nudge the result to the upper-left corner of
    /// the transformed rectangle when a sized primitive (like a circle) is
    /// rotated — matching Jdenticon's `transformIconPoint`.
    func point(_ px: Double, _ py: Double, _ w: Double = 0, _ h: Double = 0) -> IdenticonPoint {
        let right = x + size
        let bottom = y + size
        switch rotation {
        case 1: return IdenticonPoint(x: right - py - h, y: y + px)
        case 2: return IdenticonPoint(x: right - px - w, y: bottom - py - h)
        case 3: return IdenticonPoint(x: x + py, y: bottom - px - w)
        default: return IdenticonPoint(x: x + px, y: y + py)
        }
    }
}

// swiftlint:enable identifier_name
