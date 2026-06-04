//
// Tests for GitHubStyle: the on/off grid is mirrored, generation is
// deterministic, distinct inputs differ, the icon is a single foreground color
// on a background, and it works with both renderers.
//

import Foundation
import Testing

@testable import Identikit

@Suite("GitHub grid")
struct GitHubGridTests {
    @Test("grid is mirrored left-to-right")
    func gridIsHorizontallySymmetric() {
        let size = 5
        let cells = gitHubGrid(hash: IdenticonHasher.resolve("Alice"), size: size)
        #expect(cells.count == size * size)
        for row in 0..<size {
            for col in 0..<size {
                #expect(cells[row * size + col] == cells[row * size + (size - 1 - col)])
            }
        }
    }

    @Test("grid is deterministic for a given hash")
    func gridDeterministic() {
        let hash = IdenticonHasher.resolve("burrows")
        let first = gitHubGrid(hash: hash, size: 5)
        let second = gitHubGrid(hash: hash, size: 5)
        #expect(first == second)
    }
}

@Suite("GitHub style")
struct GitHubStyleTests {
    @Test("Generation is deterministic")
    func deterministic() {
        let first = Identicon.svg(for: "burrows", size: 90, style: GitHubStyle())
        let second = Identicon.svg(for: "burrows", size: 90, style: GitHubStyle())
        #expect(first == second)
    }

    @Test("Different inputs produce different icons")
    func distinctInputs() {
        let alice = Identicon.svg(for: "Alice", size: 90, style: GitHubStyle())
        let bob = Identicon.svg(for: "Bob", size: 90, style: GitHubStyle())
        #expect(alice != bob)
    }

    @Test("Uses a single foreground color on a transparent ground")
    func singleForeground() {
        let svg = Identicon.svg(for: "Alice", size: 90, style: GitHubStyle())
        #expect(svg.hasPrefix("<svg "))
        #expect(!svg.contains("<rect "))  // transparent by default
        // Exactly one foreground <path> element.
        let paths = svg.components(separatedBy: "<path ").count - 1
        #expect(paths == 1)
    }

    @Test("Different grid sizes produce different icons")
    func gridSizeMatters() {
        let five = Identicon.svg(for: "burrows", size: 90, style: GitHubStyle(gridSize: 5))
        let seven = Identicon.svg(for: "burrows", size: 90, style: GitHubStyle(gridSize: 7))
        #expect(five != seven)
    }

    @Test("Works with the CoreGraphics renderer too")
    func worksWithCoreGraphics() throws {
        #if canImport(CoreGraphics)
            let image = try #require(Identicon.cgImage(for: "burrows", size: 64, style: GitHubStyle()))
            #expect(image.width == 64)
            #expect(image.height == 64)
        #endif
    }
}
