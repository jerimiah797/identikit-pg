//
// Smoke tests for the SwiftUI Canvas renderer: each style should accumulate
// drawable shapes through it without crashing.
//

#if canImport(SwiftUI)
    import Testing

    @testable import Identikit

    @Suite("SwiftUI Canvas renderer")
    struct SwiftUICanvasRendererTests {
        @Test("Every style produces drawable shapes")
        func stylesProduceShapes() {
            let styles: [any IdenticonStyle] = [JdenticonStyle(), MosaicStyle(), GitHubStyle()]
            for style in styles {
                let renderer = SwiftUICanvasRenderer(iconSize: 96)
                style.render(hash: IdenticonHasher.resolve("burrows"), config: IdenticonConfig(), into: renderer)
                #expect(renderer.shapeCount > 0)
            }
        }
    }
#endif
