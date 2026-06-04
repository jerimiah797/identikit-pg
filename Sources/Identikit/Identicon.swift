//
// Top-level facade composing the two seams — a ``IdenticonStyle`` (hash →
// shapes) and a ``IdenticonRenderer`` (shapes → output). Convenience entry
// points cover the common cases (SVG string, CoreGraphics image) while leaving
// the seams open for custom styles and backends.
//

import Foundation

#if canImport(CoreGraphics)
    import CoreGraphics
#endif

/// Entry points for generating identicons.
public enum Identicon {
    /// Renders an identicon for `value` as an SVG string. `value` is hashed
    /// (SHA-1) unless it is already a valid 11+ character hex hash.
    public static func svg(
        for value: String,
        size: Double,
        config: IdenticonConfig = IdenticonConfig(),
        style: some IdenticonStyle = JdenticonStyle()
    ) -> String {
        svg(forHash: IdenticonHasher.resolve(value), size: size, config: config, style: style)
    }

    /// Renders an identicon for a precomputed hash as an SVG string.
    public static func svg(
        forHash hash: String,
        size: Double,
        config: IdenticonConfig = IdenticonConfig(),
        style: some IdenticonStyle = JdenticonStyle()
    ) -> String {
        let renderer = SVGStringRenderer(iconSize: size)
        style.render(hash: hash, config: config, into: renderer)
        return renderer.svg
    }

    #if canImport(CoreGraphics)
        /// Renders an identicon for `value` as a `CGImage` at `size * scale` pixels
        /// per side. `value` is hashed unless it is already a valid hash.
        public static func cgImage(
            for value: String,
            size: Double,
            scale: CGFloat = 1,
            config: IdenticonConfig = IdenticonConfig(),
            style: some IdenticonStyle = JdenticonStyle()
        ) -> CGImage? {
            guard let renderer = CoreGraphicsRenderer(iconSize: size, scale: scale) else { return nil }
            style.render(hash: IdenticonHasher.resolve(value), config: config, into: renderer)
            return renderer.makeImage()
        }
    #endif
}
