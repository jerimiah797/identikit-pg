//
// SVG-string renderer. Produces byte-for-byte the same markup as Jdenticon's
// `toSvg` (combining its `SvgRenderer` path-grouping with its `SvgWriter`
// string building): a header, an optional background rect, then one `<path>`
// per distinct color in first-seen order.
//

import Foundation

// swiftlint:disable identifier_name

/// An ``IdenticonRenderer`` that accumulates an SVG document string.
public final class SVGStringRenderer: IdenticonRenderer {
    public let iconSize: Double

    private let header: String
    private var backgroundMarkup = ""
    private var colorOrder: [String] = []
    private var pathByColor: [String: String] = [:]
    private var currentColorKey = ""

    /// Creates a renderer that emits an `iconSize`×`iconSize` SVG.
    public init(iconSize: Double) {
        self.iconSize = iconSize
        let dimension = jsNumber(iconSize)
        header =
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(dimension)\""
            + " height=\"\(dimension)\" viewBox=\"0 0 \(dimension) \(dimension)\">"
    }

    public func setBackground(_ color: IdenticonColor) {
        guard color.alpha > 0 else { return }
        let opacity = String(format: "%.2f", color.opacity)
        backgroundMarkup =
            "<rect width=\"100%\" height=\"100%\" fill=\"\(color.hex)\""
            + " opacity=\"\(opacity)\"/>"
    }

    public func beginShape(_ color: IdenticonColor) {
        let key = color.hex
        if pathByColor[key] == nil {
            pathByColor[key] = ""
            colorOrder.append(key)
        }
        currentColorKey = key
    }

    public func endShape() {}

    public func addPolygon(_ points: [IdenticonPoint]) {
        var data = ""
        for (i, point) in points.enumerated() {
            data += (i == 0 ? "M" : "L") + coordinate(point.x) + " " + coordinate(point.y)
        }
        pathByColor[currentColorKey, default: ""] += data + "Z"
    }

    public func addCircle(_ corner: IdenticonPoint, diameter: Double, counterClockwise: Bool) {
        let sweepFlag = counterClockwise ? "0" : "1"
        let radius = coordinate(diameter / 2)
        let diameterString = coordinate(diameter)
        let negativeDiameter = diameterString == "0" ? "0" : "-" + diameterString
        let arc = "a\(radius),\(radius) 0 1,\(sweepFlag) "
        let data =
            "M" + coordinate(corner.x) + " " + coordinate(corner.y + diameter / 2)
            + arc + diameterString + ",0"
            + arc + negativeDiameter + ",0"
        pathByColor[currentColorKey, default: ""] += data
    }

    public func finish() {}

    /// The rendered SVG document. Valid once ``finish()`` has been called.
    public var svg: String {
        var body = ""
        for key in colorOrder {
            body += "<path fill=\"\(key)\" d=\"\(pathByColor[key] ?? "")\"/>"
        }
        return header + backgroundMarkup + body + "</svg>"
    }

    /// Rounds a coordinate to one decimal and formats it as Jdenticon does
    /// (`((value * 10 + 0.5) | 0) / 10`, then JavaScript number-to-string).
    private func coordinate(_ value: Double) -> String {
        jsTenths(truncToInt(value * 10 + 0.5))
    }
}

// swiftlint:enable identifier_name
