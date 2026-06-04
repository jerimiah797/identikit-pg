//
// A SwiftUI-native renderer and view. `SwiftUICanvasRenderer` draws an icon into
// a SwiftUI `Canvas` `GraphicsContext` — vector, so it stays crisp at any size —
// and `IdenticonView` wraps it as a drop-in `View`. Both are gated on SwiftUI so
// the core stays usable in non-UI contexts; SwiftUI is a system framework, so
// this adds no third-party dependency.
//

#if canImport(SwiftUI)
    import SwiftUI

    /// An ``IdenticonRenderer`` that accumulates SwiftUI `Path`s per color and draws
    /// them into a `GraphicsContext`. Holes work via the nonzero fill rule, exactly
    /// as in the SVG renderer.
    public final class SwiftUICanvasRenderer: IdenticonRenderer {
        public let iconSize: Double

        private var background: IdenticonColor?
        private var shapes: [(color: IdenticonColor, path: Path)] = []
        private var currentColor = IdenticonColor(red: 0, green: 0, blue: 0)
        private var currentPath = Path()

        public init(iconSize: Double) {
            self.iconSize = iconSize
        }

        public func setBackground(_ color: IdenticonColor) {
            background = color
        }

        public func beginShape(_ color: IdenticonColor) {
            currentColor = color
            currentPath = Path()
        }

        public func endShape() {
            if !currentPath.isEmpty {
                shapes.append((currentColor, currentPath))
            }
        }

        public func addPolygon(_ points: [IdenticonPoint]) {
            guard let first = points.first else { return }
            currentPath.move(to: CGPoint(x: first.x, y: first.y))
            for point in points.dropFirst() {
                currentPath.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            currentPath.closeSubpath()
        }

        public func addCircle(_ corner: IdenticonPoint, diameter: Double, counterClockwise: Bool) {
            let radius = diameter / 2
            let center = CGPoint(x: corner.x + radius, y: corner.y + radius)
            currentPath.move(to: CGPoint(x: center.x + radius, y: center.y))
            currentPath.addArc(
                center: center,
                radius: radius,
                startAngle: .zero,
                endAngle: .degrees(360),
                clockwise: counterClockwise
            )
            currentPath.closeSubpath()
        }

        public func finish() {}

        /// Number of accumulated color groups (for testing).
        var shapeCount: Int { shapes.count }

        /// Draws the accumulated background and shapes into `context`.
        public func draw(into context: GraphicsContext) {
            if let background, background.alpha > 0 {
                let frame = CGRect(x: 0, y: 0, width: iconSize, height: iconSize)
                context.fill(Path(frame), with: .color(background.color))
            }
            for shape in shapes {
                context.fill(shape.path, with: .color(shape.color.color))
            }
        }
    }

    extension IdenticonColor {
        /// A SwiftUI `Color` with this color's sRGB components.
        public var color: Color {
            Color(
                .sRGB,
                red: Double(red) / 255,
                green: Double(green) / 255,
                blue: Double(blue) / 255,
                opacity: Double(alpha) / 255
            )
        }
    }

    /// A drop-in SwiftUI view that renders an identicon for a seed, crisp at any
    /// size. Pass a `style` to switch the look and a `config` to set a background
    /// (transparent by default).
    public struct IdenticonView: View {
        private let hash: String
        private let style: any IdenticonStyle
        private let config: IdenticonConfig

        /// Renders the icon for `seed` (hashed unless it is already a valid hash).
        public init(
            seed: String,
            style: any IdenticonStyle = JdenticonStyle(),
            config: IdenticonConfig = IdenticonConfig()
        ) {
            self.init(hash: IdenticonHasher.resolve(seed), style: style, config: config)
        }

        /// Renders the icon for a precomputed hash.
        public init(
            hash: String,
            style: any IdenticonStyle = JdenticonStyle(),
            config: IdenticonConfig = IdenticonConfig()
        ) {
            self.hash = hash
            self.style = style
            self.config = config
        }

        public var body: some View {
            Canvas { context, size in
                let dimension = min(size.width, size.height)
                var context = context
                context.translateBy(x: (size.width - dimension) / 2, y: (size.height - dimension) / 2)
                let renderer = SwiftUICanvasRenderer(iconSize: Double(dimension))
                style.render(hash: hash, config: config, into: renderer)
                renderer.draw(into: context)
            }
        }
    }
#endif
