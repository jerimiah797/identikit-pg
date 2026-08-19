//
// RosetteStyle — the polar counterpart to the grid styles. `MosaicStyle` and
// `GitHubStyle` lay cells out on a square grid mirrored left↔right; a rosette
// lays them out on a *polar* grid — concentric bands cut into sectors — and
// repeats one wedge of that grid around the circle. So the icon is built the
// same way as its siblings, but its symmetry is rotational rather than a mirror
// line, and its silhouette is a disc rather than a square sprite.
//
// Colors come from Jdenticon's hue-derived `colorTheme`, so a rosette sits in
// the same color world as the default style (and honors `config.hues`).
//
// The algorithm is original to this module — a polar grid is a general idea, not
// a port of any upstream identicon. See Attribution.swift.
//

import Foundation

/// How many sectors make up one repeated wedge. Three is the smallest count that
/// lets a wedge hold a pattern — at one or two the bands degenerate into plain
/// annuli and every icon looks like a target.
let rosetteSectorsPerFold = 3

/// The rotational repeat counts a rosette can have. Below four the wedges read
/// as a coarse cross; above six they thin into slivers at avatar sizes.
let rosetteFoldChoices = [4, 5, 6]

/// The hub's radius as a fraction of the icon's radius. The bands divide the
/// remainder, so the hub always reads as a distinct center rather than the
/// innermost band collapsing to a point.
let rosetteHubFraction = 0.22

/// Palette entries that clash when they sit next to each other: the two light
/// theme colors (light gray, light color) and the two dark ones (dark gray, dark
/// color). `JdenticonStyle` groups them the same way when it picks its three
/// colors — bands are concentric, so neighbors that read as one lightness would
/// merge into a single thick ring.
let rosetteClashingColors = [[0, 4], [2, 3]]

/// Picks a band color that reads against the band outside it. A clash falls back
/// to palette index 1, the mid color, which is the same escape `JdenticonStyle`
/// uses; an exact repeat with no clash group just steps to the next entry.
func rosetteContrastingColor(_ candidate: Int, against neighbor: Int?, paletteSize: Int) -> Int {
    guard let neighbor, paletteSize > 1 else { return candidate }
    if rosetteClashingColors.contains(where: { $0.contains(candidate) && $0.contains(neighbor) }) {
        return 1 % paletteSize
    }
    if candidate == neighbor {
        return (candidate + 1) % paletteSize
    }
    return candidate
}

/// Which polar cells a rosette fills, and in what colors. Separated from
/// drawing so the pattern can be checked on its own.
struct RosetteLayout {
    /// Rotational repeats around the circle.
    let folds: Int
    /// Sectors in one repeated wedge.
    let sectorsPerFold: Int
    /// Palette index per band, outermost band first.
    let ringColors: [Int]
    /// `wedges[band][sectorWithinWedge]` — whether that cell is filled.
    let wedges: [[Bool]]
    /// Palette index of the center hub, or nil when the hub is left open.
    let hubColor: Int?

    /// Total sectors around the full circle.
    var sectors: Int { folds * sectorsPerFold }

    /// Whether the cell at `band` and absolute `sector` is filled. The wedge
    /// pattern repeats every ``sectorsPerFold`` sectors, which is exactly what
    /// gives the icon its ``folds``-fold rotational symmetry.
    func isFilled(band: Int, sector: Int) -> Bool {
        let wedge = wedges[band]
        return wedge[((sector % wedge.count) + wedge.count) % wedge.count]
    }
}

/// Reads the hash nibble at `index`, wrapping around the hash. Wrapping keeps
/// every `bandCount` well defined: `parseHex` reads past the end as 0, which
/// would silently fill whole bands once the indices ran off a 40-character
/// SHA-1 digest.
func rosetteNibble(_ hash: String, _ index: Int) -> Int {
    let count = hash.count
    guard count > 0 else { return 0 }
    return IdenticonHasher.parseHex(hash, ((index % count) + count) % count, 1)
}

/// Derives the pattern for `hash`: fold count, a color per band, the filled
/// cells of one wedge per band, and the hub.
func rosetteLayout(hash: String, bandCount: Int, paletteSize: Int) -> RosetteLayout {
    let folds = rosetteFoldChoices[rosetteNibble(hash, 0) % rosetteFoldChoices.count]
    let perFold = rosetteSectorsPerFold

    // A color per band, nudged off the band outside it so neighbors always read
    // as separate rings rather than merging into one thick one.
    var ringColors: [Int] = []
    for band in 0..<bandCount {
        let candidate = rosetteNibble(hash, 1 + band) % paletteSize
        ringColors.append(
            rosetteContrastingColor(candidate, against: ringColors.last, paletteSize: paletteSize))
    }

    // One nibble per unique cell; even fills. Empty bands are wanted — they are
    // the gaps that give the banding its rhythm.
    var wedges: [[Bool]] = []
    for band in 0..<bandCount {
        var wedge: [Bool] = []
        for sector in 0..<perFold {
            wedge.append(rosetteNibble(hash, 1 + bandCount + band * perFold + sector) % 2 == 0)
        }
        wedges.append(wedge)
    }

    // An all-empty pattern (1 in 8^bandCount seeds) would leave a bare hub or a
    // blank tile, so fall back to a solid outer band. Rare, but an identicon
    // that renders nothing is not an identicon. (`bandCount` of 0 leaves no band
    // to fall back to, and `allSatisfy` is vacuously true on an empty array.)
    if !wedges.isEmpty, wedges.allSatisfy({ !$0.contains(true) }) {
        wedges[0] = [Bool](repeating: true, count: perFold)
    }

    // Half the seeds get a solid hub, half stay open as a donut.
    let hubIndex = 1 + bandCount + bandCount * perFold
    var hubColor: Int?
    if rosetteNibble(hash, hubIndex) % 2 == 0 {
        let candidate = rosetteNibble(hash, hubIndex + 1) % paletteSize
        hubColor = rosetteContrastingColor(
            candidate, against: ringColors.last, paletteSize: paletteSize)
    }

    return RosetteLayout(
        folds: folds,
        sectorsPerFold: perFold,
        ringColors: ringColors,
        wedges: wedges,
        hubColor: hubColor
    )
}

/// Builds a closed polygon approximating one polar cell: the region between
/// `innerRadius` and `outerRadius`, swept from `startAngle` to `endAngle`.
///
/// The renderer seam speaks polygons and whole circles, not arcs, so both arcs
/// are tessellated. The segment count follows the arc's length in pixels, which
/// keeps small icons cheap and large ones smooth. Adjacent cells derive their
/// shared radii and angles from identical expressions, so they abut seamlessly.
func rosetteSector(
    center: IdenticonPoint,
    innerRadius: Double,
    outerRadius: Double,
    startAngle: Double,
    endAngle: Double
) -> [IdenticonPoint] {
    let sweep = endAngle - startAngle
    let segments = min(max(Int((sweep * outerRadius / 1.5).rounded(.up)), 2), 64)

    var points: [IdenticonPoint] = []
    points.reserveCapacity(segments * 2 + 2)

    func point(radius: Double, step: Int) -> IdenticonPoint {
        let angle = startAngle + sweep * Double(step) / Double(segments)
        return IdenticonPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    for step in 0...segments {
        points.append(point(radius: outerRadius, step: step))
    }
    if innerRadius <= 0 {
        // Degenerate inner edge: the cell is a pie wedge meeting at the center.
        points.append(center)
    } else {
        for step in stride(from: segments, through: 0, by: -1) {
            points.append(point(radius: innerRadius, step: step))
        }
    }
    return points
}

/// A radially symmetric identicon: concentric bands of sectors turning around a
/// central hub.
public struct RosetteStyle: IdenticonStyle {
    /// The number of concentric bands between the hub and the outer edge.
    /// Defaults to 3.
    public var bandCount: Int

    /// Creates the style. `bandCount` is clamped to at least 1.
    public init(bandCount: Int = 3) {
        self.bandCount = max(1, bandCount)
    }

    public func render(hash: String, config: IdenticonConfig, into renderer: IdenticonRenderer) {
        // Transparent by default so the icon works on white or black; an explicit
        // backColor (if set) fills the ground instead.
        if let background = config.backColor {
            renderer.setBackground(background)
        }

        // `bandCount` is a public var, so it can be assigned past the
        // initializer's clamp; re-clamp before it reaches the layout.
        let bandCount = max(1, bandCount)

        // Inscribe the disc in the padded square, snapping the padding to whole
        // pixels as JdenticonStyle and GitHubStyle do.
        let size = renderer.iconSize
        let padding = Double(truncToInt(0.5 + size * config.padding))
        let outerRadius = max(0, (size - padding * 2) / 2)
        let center = IdenticonPoint(x: size / 2, y: size / 2)
        let hubRadius = outerRadius * rosetteHubFraction
        let bandSpan = outerRadius - hubRadius

        // Same hue source as JdenticonStyle, then the shared five-color theme.
        let hue = Double(IdenticonHasher.parseHex(hash, -7)) / Double(0x0FFF_FFFF)
        let palette = colorTheme(hue: hue, config: config)
        let layout = rosetteLayout(hash: hash, bandCount: bandCount, paletteSize: palette.count)

        // Visit colors in outermost-to-innermost order (hub last) so the SVG
        // renderer's first-seen color ordering is stable across runs.
        var colorOrder: [Int] = []
        for index in layout.ringColors where !colorOrder.contains(index) {
            colorOrder.append(index)
        }
        if let hub = layout.hubColor, !colorOrder.contains(hub) {
            colorOrder.append(hub)
        }

        // One pass per color, so each color is a single grouped path — the same
        // grouping MosaicStyle uses.
        for colorIndex in colorOrder {
            renderer.beginShape(palette[colorIndex])

            for band in 0..<bandCount where layout.ringColors[band] == colorIndex {
                let bandOuter = outerRadius - bandSpan * Double(band) / Double(bandCount)
                let bandInner = outerRadius - bandSpan * Double(band + 1) / Double(bandCount)
                for sector in 0..<layout.sectors where layout.isFilled(band: band, sector: sector) {
                    let start = Double(sector) / Double(layout.sectors) * 2 * .pi
                    let end = Double(sector + 1) / Double(layout.sectors) * 2 * .pi
                    renderer.addPolygon(
                        rosetteSector(
                            center: center,
                            innerRadius: bandInner,
                            outerRadius: bandOuter,
                            startAngle: start,
                            endAngle: end
                        ))
                }
            }

            if layout.hubColor == colorIndex {
                renderer.addCircle(
                    IdenticonPoint(x: center.x - hubRadius, y: center.y - hubRadius),
                    diameter: hubRadius * 2,
                    counterClockwise: false
                )
            }

            renderer.endShape()
        }

        renderer.finish()
    }
}
