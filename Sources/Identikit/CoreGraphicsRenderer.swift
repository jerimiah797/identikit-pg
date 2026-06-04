//
// CoreGraphics renderer — draws the icon into a bitmap context and produces a
// `CGImage`, suitable for wrapping in `NSImage`/`UIImage` or a SwiftUI `Image`.
// Unlike the SVG renderer this is not held to byte-parity with Jdenticon; it
// reproduces the same geometry using the nonzero winding rule so reversed
// polygons and counter-clockwise circles punch holes.
//

#if canImport(CoreGraphics)
    import CoreGraphics
    import Foundation

    /// An ``IdenticonRenderer`` that rasterizes into a CoreGraphics bitmap.
    public final class CoreGraphicsRenderer: IdenticonRenderer {
        public let iconSize: Double

        private let scale: CGFloat
        private let context: CGContext
        private var currentColor = IdenticonColor(red: 0, green: 0, blue: 0)
        private var path = CGMutablePath()

        /// Creates a renderer backed by an sRGB bitmap of `iconSize * scale` pixels
        /// per side. Returns nil if the bitmap context can't be created.
        public init?(iconSize: Double, scale: CGFloat = 1) {
            self.iconSize = iconSize
            self.scale = scale

            let pixels = max(1, Int((iconSize * Double(scale)).rounded()))
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                let ctx = CGContext(
                    data: nil,
                    width: pixels,
                    height: pixels,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return nil }

            // Flip to an icon-space coordinate system: origin top-left, y downward.
            ctx.translateBy(x: 0, y: CGFloat(pixels))
            ctx.scaleBy(x: scale, y: -scale)
            context = ctx
        }

        public func setBackground(_ color: IdenticonColor) {
            guard color.alpha > 0 else { return }
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
        }

        public func beginShape(_ color: IdenticonColor) {
            currentColor = color
            path = CGMutablePath()
        }

        public func endShape() {
            guard !path.isEmpty else { return }
            context.addPath(path)
            context.setFillColor(currentColor.cgColor)
            context.fillPath(using: .winding)
        }

        public func addPolygon(_ points: [IdenticonPoint]) {
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.x, y: first.y))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            path.closeSubpath()
        }

        public func addCircle(_ corner: IdenticonPoint, diameter: Double, counterClockwise: Bool) {
            let radius = diameter / 2
            let center = CGPoint(x: corner.x + radius, y: corner.y + radius)
            path.addArc(
                center: center,
                radius: CGFloat(radius),
                startAngle: 0,
                endAngle: 2 * .pi,
                clockwise: counterClockwise
            )
            path.closeSubpath()
        }

        public func finish() {}

        /// The rendered bitmap. Valid once ``finish()`` has been called.
        public func makeImage() -> CGImage? {
            context.makeImage()
        }
    }

    extension IdenticonColor {
        /// A CoreGraphics color in sRGB with this color's components.
        var cgColor: CGColor {
            CGColor(
                srgbRed: CGFloat(red) / 255,
                green: CGFloat(green) / 255,
                blue: CGFloat(blue) / 255,
                alpha: CGFloat(alpha) / 255
            )
        }
    }
#endif
