//
// Regression test for the CoreGraphics renderer's circle path handling.
//
// `beginShape`/`endShape` accumulate every shape of one color into a single
// path and fill it once with the nonzero winding rule. `CGMutablePath` grows a
// straight line from its current point to an arc's start point, so a circle
// added after another shape in the same group used to stitch a stray spoke
// across the icon — the diagonal slivers seen in rasterized jdenticon avatars.
// `CoreGraphicsRenderer.addCircle` now moves to the arc's start first, breaking
// the subpath (as `SwiftUICanvasRenderer` and `addPolygon` already do).
//
// The trigger is jdenticon's four symmetric outer-cell circles drawn in one
// color group (this exact geometry is emitted by seed "burrows"). Rendered
// grouped, the icon must be pixel-identical to the same circles rendered in
// separate groups, where no shared path — and therefore no spoke — is possible.
//

#if canImport(CoreGraphics)
    import CoreGraphics
    import Testing

    @testable import Identikit

    @Suite("CoreGraphics circle spoke regression")
    struct CoreGraphicsSpokeTests {
        /// Copies a `CGImage` into a tightly packed RGBA8 buffer so two renders
        /// compare byte-for-byte regardless of the image's internal row stride.
        private func pixels(of image: CGImage) -> [UInt8] {
            let width = image.width, height = image.height
            var buffer = [UInt8](repeating: 0, count: width * height * 4)
            buffer.withUnsafeMutableBytes { raw in
                let ctx = CGContext(
                    data: raw.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            return buffer
        }

        private let fill = IdenticonColor(red: 132, green: 135, blue: 214)
        private let diameter = 8.666666666666668
        /// The four outer-cell circle corners jdenticon emits for seed "burrows".
        private let corners = [
            IdenticonPoint(x: 8.166666666666664, y: 8.166666666666664),
            IdenticonPoint(x: 47.166666666666664, y: 8.166666666666664),
            IdenticonPoint(x: 47.166666666666664, y: 47.166666666666664),
            IdenticonPoint(x: 8.166666666666664, y: 47.166666666666664),
        ]

        @Test("Circles in one color group render without a connecting spoke")
        func groupedCirclesMatchIsolated() throws {
            // Grouped: all four circles share one accumulating path (the case that
            // regressed). Isolated: each circle in its own group, so no shared path
            // and no possible spoke — the reference for "correct".
            let grouped = CoreGraphicsRenderer(iconSize: 64, scale: 1)!
            grouped.beginShape(fill)
            for corner in corners {
                grouped.addCircle(corner, diameter: diameter, counterClockwise: false)
            }
            grouped.endShape()
            grouped.finish()

            let isolated = CoreGraphicsRenderer(iconSize: 64, scale: 1)!
            for corner in corners {
                isolated.beginShape(fill)
                isolated.addCircle(corner, diameter: diameter, counterClockwise: false)
                isolated.endShape()
            }
            isolated.finish()

            let groupedPixels = try pixels(of: #require(grouped.makeImage()))
            let isolatedPixels = try pixels(of: #require(isolated.makeImage()))
            // Exact equality: with the fix these are identical; the spoke bug
            // diverges by ~800 px along the lines stitched between circles.
            #expect(groupedPixels == isolatedPixels)
        }

        @Test("The real jdenticon avatar rasterizes to a non-empty bitmap")
        func jdenticonBurrowsRasterizes() throws {
            let renderer = CoreGraphicsRenderer(iconSize: 64, scale: 2)!
            JdenticonStyle().render(
                hash: IdenticonHasher.resolve("burrows"),
                config: IdenticonConfig(), into: renderer)
            renderer.finish()
            let image = try #require(renderer.makeImage())
            #expect(image.width == 128)
        }
    }
#endif
