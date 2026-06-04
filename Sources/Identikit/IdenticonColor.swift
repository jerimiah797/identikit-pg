//
// A renderer-agnostic color value. Channels are stored as Jdenticon computes
// them — integers in `[0, 255]` after the `decToHex` clamp — so the SVG
// renderer can reproduce the exact `#rrggbb` strings while a CoreGraphics
// renderer can use the same components as floats.
//

import Foundation

// swiftlint:disable identifier_name

/// An 8-bit-per-channel RGBA color used by identicon renderers.
public struct IdenticonColor: Equatable, Sendable {
    /// Red channel, `0...255`.
    public var red: Int
    /// Green channel, `0...255`.
    public var green: Int
    /// Blue channel, `0...255`.
    public var blue: Int
    /// Alpha channel, `0...255`. Defaults to fully opaque.
    public var alpha: Int

    /// Creates a color, clamping every channel to `0...255`.
    public init(red: Int, green: Int, blue: Int, alpha: Int = 255) {
        self.red = min(255, max(0, red))
        self.green = min(255, max(0, green))
        self.blue = min(255, max(0, blue))
        self.alpha = min(255, max(0, alpha))
    }

    /// The opaque hex representation, `#rrggbb` — the form Jdenticon uses as a
    /// fill color and as the grouping key for same-colored paths.
    public var hex: String {
        "#" + Self.hexByte(red) + Self.hexByte(green) + Self.hexByte(blue)
    }

    /// Alpha as a `0...1` opacity, for renderers that take a separate opacity.
    public var opacity: Double { Double(alpha) / 255 }

    private static func hexByte(_ value: Int) -> String {
        let v = min(255, max(0, value))
        return v < 16 ? "0" + String(v, radix: 16) : String(v, radix: 16)
    }
}

/// Clamps a `Double` channel to an integer in `0...255`, matching Jdenticon's
/// `decToHex` (`value | 0`, then clamp below 0 to 0 and at/above 256 to 255).
@inline(__always)
func clampChannel(_ value: Double) -> Int {
    let v = truncToInt(value)
    return v < 0 ? 0 : v > 255 ? 255 : v
}

// swiftlint:enable identifier_name
