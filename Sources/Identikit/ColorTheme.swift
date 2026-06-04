//
// Color derivation, ported from Jdenticon's `color.js` + `colorTheme.js`.
// A single hue (from the hash) plus the configured saturation/lightness ranges
// produce a five-color palette. `correctedHsl` applies per-hue perceptual
// lightness correction so colors read as equally bright.
//

import Foundation

// Single-letter math names (h, and the m1/m2 HSL intermediates) match the
// ported reference and standard color-conversion notation.
// swiftlint:disable identifier_name

/// Converts one channel of an HSL color to a clamped 8-bit value. Mirrors
/// Jdenticon's `hueToRgb`.
private func hueToChannel(_ m1: Double, _ m2: Double, _ hue: Double) -> Int {
    var h = hue
    if h < 0 { h += 6 } else if h > 6 { h -= 6 }
    let factor: Double =
        h < 1 ? m1 + (m2 - m1) * h : h < 3 ? m2 : h < 4 ? m1 + (m2 - m1) * (4 - h) : m1
    return clampChannel(255 * factor)
}

/// Converts an HSL color (each component in `[0, 1]`) to an `IdenticonColor`.
/// Mirrors Jdenticon's `hsl`, including the grayscale fast path.
func hsl(hue: Double, saturation: Double, lightness: Double) -> IdenticonColor {
    if saturation == 0 {
        let v = clampChannel(lightness * 255)
        return IdenticonColor(red: v, green: v, blue: v)
    }
    let m2 =
        lightness <= 0.5
        ? lightness * (saturation + 1)
        : lightness + saturation - lightness * saturation
    let m1 = lightness * 2 - m2
    return IdenticonColor(
        red: hueToChannel(m1, m2, hue * 6 + 2),
        green: hueToChannel(m1, m2, hue * 6),
        blue: hueToChannel(m1, m2, hue * 6 - 2)
    )
}

/// HSL → RGB with per-hue lightness correction. Mirrors Jdenticon's
/// `correctedHsl`. The corrector array is the perceived middle lightness for
/// each sextant of the hue wheel and must be reproduced exactly.
func correctedHsl(hue: Double, saturation: Double, lightness: Double) -> IdenticonColor {
    let correctors: [Double] = [0.55, 0.5, 0.5, 0.46, 0.6, 0.55, 0.55]
    let corrector = correctors[truncToInt(hue * 6 + 0.5)]
    let corrected =
        lightness < 0.5
        ? lightness * corrector * 2
        : corrector + (lightness - 0.5) * (1 - corrector) * 2
    return hsl(hue: hue, saturation: saturation, lightness: corrected)
}

/// Builds the five identicon color candidates for a hue. Mirrors Jdenticon's
/// `colorTheme`: dark gray, mid color, light gray, light color, dark color.
func colorTheme(hue rawHue: Double, config: IdenticonConfig) -> [IdenticonColor] {
    let hue = config.resolvedHue(rawHue)
    let cs = config.colorSaturation
    let gs = config.grayscaleSaturation
    // Order: dark gray, mid color, light gray, light color, dark color.
    return [
        correctedHsl(hue: hue, saturation: gs, lightness: config.grayscaleLightnessValue(0)),
        correctedHsl(hue: hue, saturation: cs, lightness: config.colorLightnessValue(0.5)),
        correctedHsl(hue: hue, saturation: gs, lightness: config.grayscaleLightnessValue(1)),
        correctedHsl(hue: hue, saturation: cs, lightness: config.colorLightnessValue(1)),
        correctedHsl(hue: hue, saturation: cs, lightness: config.colorLightnessValue(0)),
    ]
}

// swiftlint:enable identifier_name
