//
// The style seam. A style turns a hash into shape + color drawing calls against
// a renderer. `JdenticonStyle` is the first implementation; alternative styles
// (GitHub-blocky, Ethereum blockies, ...) can slot in later and automatically
// work with every renderer.
//

import Foundation

/// A visual identicon algorithm: hash in, renderer calls out.
public protocol IdenticonStyle: Sendable {
    /// Renders the icon for `hash` into `renderer` using `config`. The icon size
    /// is taken from ``IdenticonRenderer/iconSize``.
    func render(hash: String, config: IdenticonConfig, into renderer: IdenticonRenderer)
}
