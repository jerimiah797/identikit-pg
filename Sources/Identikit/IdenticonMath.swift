//
// Small numeric helpers that mirror the exact JavaScript semantics Jdenticon
// relies on. Faithfulness here is load-bearing: an off-by-one in truncation or
// number formatting changes every generated icon.
//

import Foundation

/// Mirrors the JavaScript bitwise-OR-zero idiom `value | 0`: coerces a `Double`
/// to an integer by truncating toward zero. Jdenticon uses this throughout to
/// snap measurements to whole pixels.
@inline(__always)
func truncToInt(_ value: Double) -> Int {
    guard value.isFinite else { return 0 }
    return Int(value)
}

/// Clamps a value to the `[0, 1]` range, matching Jdenticon's lightness clamp.
@inline(__always)
func clamp01(_ value: Double) -> Double {
    value < 0 ? 0 : value > 1 ? 1 : value
}

/// Formats a whole-or-fractional number the way JavaScript's `Number.toString`
/// would for the integer values Jdenticon produces (e.g. `100`, not `100.0`).
func jsNumber(_ value: Double) -> String {
    if value.isFinite, value == value.rounded(.towardZero), abs(value) < 1e15 {
        return String(Int(value))
    }
    return String(value)
}

/// Formats an integer count of tenths the way JavaScript renders `tenths / 10`
/// — `125 -> "12.5"`, `120 -> "12"`, `-5 -> "-0.5"`. Used by the SVG renderer to
/// reproduce Jdenticon's path coordinates byte-for-byte.
func jsTenths(_ tenths: Int) -> String {
    let whole = tenths / 10
    let frac = abs(tenths % 10)
    if frac == 0 { return String(whole) }
    if tenths < 0, whole == 0 { return "-0.\(frac)" }
    return "\(whole).\(frac)"
}
