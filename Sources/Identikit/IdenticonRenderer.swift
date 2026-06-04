//
// The renderer seam. A `IdenticonStyle` emits an icon purely as calls against
// this protocol; concrete renderers turn those calls into an SVG string, a
// CoreGraphics image, or anything else. This mirrors Jdenticon's `Renderer`
// interface so any style works with any backend.
//

import Foundation

/// A drawing backend for identicon shapes. Implementations are reference types
/// because a single render pass mutates them in place across many calls.
public protocol IdenticonRenderer: AnyObject {
    /// The icon's width and height in pixels.
    var iconSize: Double { get }

    /// Fills the background with the given color. Called at most once, before
    /// any shapes. Renderers may ignore a fully transparent color.
    func setBackground(_ color: IdenticonColor)

    /// Begins a shape of the given color. Followed by polygon/circle additions
    /// and a matching ``endShape()``. The same color may begin more than once.
    func beginShape(_ color: IdenticonColor)

    /// Ends the shape opened by the most recent ``beginShape(_:)``.
    func endShape()

    /// Adds a closed polygon. Winding order is significant: a reversed polygon
    /// punches a hole under the nonzero fill rule.
    func addPolygon(_ points: [IdenticonPoint])

    /// Adds a circle. `corner` is the upper-left of the bounding box.
    /// `counterClockwise` reverses the winding (used to punch holes).
    func addCircle(_ corner: IdenticonPoint, diameter: Double, counterClockwise: Bool)

    /// Signals that the icon is complete; renderers flush any buffered output.
    func finish()
}
