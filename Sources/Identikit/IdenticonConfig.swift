//
// Style configuration. Defaults match Jdenticon's defaults exactly so the
// out-of-the-box look is identical. Mirrors the resolved configuration in
// Jdenticon's `configuration.js`.
//

import Foundation

/// Tunable parameters for identicon generation: padding, saturation, lightness
/// ranges, an optional background, and an optional hue restriction.
public struct IdenticonConfig: Sendable {
    /// Padding as a fraction of icon size on each side. Default `0.08`.
    public var padding: Double
    /// Saturation of the colored palette entries, `0...1`. Default `0.5`.
    public var colorSaturation: Double
    /// Saturation of the grayscale palette entries, `0...1`. Default `0`.
    public var grayscaleSaturation: Double
    /// Lightness range for colored entries. Default `0.4...0.8`.
    public var colorLightness: ClosedRange<Double>
    /// Lightness range for grayscale entries. Default `0.3...0.9`.
    public var grayscaleLightness: ClosedRange<Double>
    /// Optional background fill. Nil (the default) leaves the icon transparent.
    public var backColor: IdenticonColor?
    /// Optional hue restriction in degrees. The computed hue is replaced by the
    /// nearest configured hue. Nil/empty (the default) imposes no restriction.
    public var hues: [Double]?

    /// Creates a configuration. All parameters default to Jdenticon's defaults.
    public init(
        padding: Double = 0.08,
        colorSaturation: Double = 0.5,
        grayscaleSaturation: Double = 0,
        colorLightness: ClosedRange<Double> = 0.4...0.8,
        grayscaleLightness: ClosedRange<Double> = 0.3...0.9,
        backColor: IdenticonColor? = nil,
        hues: [Double]? = nil
    ) {
        self.padding = padding
        self.colorSaturation = colorSaturation
        self.grayscaleSaturation = grayscaleSaturation
        self.colorLightness = colorLightness
        self.grayscaleLightness = grayscaleLightness
        self.backColor = backColor
        self.hues = hues
    }

    /// Maps a normalized position to a clamped colored-lightness value.
    func colorLightnessValue(_ value: Double) -> Double {
        clamp01(colorLightness.lowerBound + value * (colorLightness.upperBound - colorLightness.lowerBound))
    }

    /// Maps a normalized position to a clamped grayscale-lightness value.
    func grayscaleLightnessValue(_ value: Double) -> Double {
        clamp01(grayscaleLightness.lowerBound + value * (grayscaleLightness.upperBound - grayscaleLightness.lowerBound))
    }

    /// Applies the optional hue restriction. Mirrors Jdenticon's `hue`
    /// function: pick the nearest configured hue, then fold degrees into
    /// `[0, 1)` turns.
    func resolvedHue(_ original: Double) -> Double {
        guard let hues, !hues.isEmpty else { return original }
        let index = truncToInt(0.999 * original * Double(hues.count))
        let degrees = hues[min(max(index, 0), hues.count - 1)]
        let turn = degrees / 360
        return ((turn.truncatingRemainder(dividingBy: 1)) + 1).truncatingRemainder(dividingBy: 1)
    }
}
