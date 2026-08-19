//
// Identikit
//
// The `JdenticonStyle` shape/color algorithm in this module is a faithful Swift
// port of Jdenticon (https://github.com/dmester/jdenticon) v3.3.0, which is
// distributed under the MIT License:
//
//     MIT License
//     Copyright (c) 2014-2024 Daniel Mester Pirttijärvi
//
//     Permission is hereby granted, free of charge, to any person obtaining a
//     copy of this software and associated documentation files (the
//     "Software"), to deal in the Software without restriction, including
//     without limitation the rights to use, copy, modify, merge, publish,
//     distribute, sublicense, and/or sell copies of the Software, and to permit
//     persons to whom the Software is furnished to do so, subject to the
//     following conditions:
//
//     The above copyright notice and this permission notice shall be included
//     in all copies or substantial portions of the Software.
//
//     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
//
// Only the `JdenticonStyle` family (the generator + shape tables + color theme)
// carries this provenance; the renderer protocols and Swift packaging are
// original to Burrows. If this module is spun out into its own repository, ship
// the full MIT text in a top-level LICENSE/THIRD_PARTY notice.

import Foundation

// `MosaicStyle`'s symmetric pixel-grid technique is inspired by the MIT-licensed
// "blockies" identicon algorithm (Alex Van de Sande and contributors). It is a
// clean reimplementation rather than a port — the PRNG normalization, palette,
// and seeding differ — so no upstream code is copied; the credit is courtesy.
//
// `RosetteStyle` carries no upstream provenance: a polar grid of concentric
// bands is a general construction, not a port of any existing identicon. It
// shares only this module's own color theme with `JdenticonStyle`.

/// Attribution metadata for the third-party algorithms bundled in this module.
public enum IdenticonAttribution {
    /// Human-readable provenance string for the bundled `JdenticonStyle`.
    public static let jdenticon =
        "JdenticonStyle is ported from Jdenticon v3.3.0 (MIT), "
        + "Copyright (c) 2014-2024 Daniel Mester Pirttijärvi."

    /// Human-readable provenance string for the bundled `MosaicStyle`.
    public static let mosaic =
        "MosaicStyle's symmetric pixel-grid technique is inspired by the "
        + "MIT-licensed \"blockies\" identicon algorithm."

    /// Human-readable provenance string for the bundled `GitHubStyle`.
    public static let github =
        "GitHubStyle implements the widely-used 5×5 mirrored single-color "
        + "identicon technique popularized by GitHub."

    /// Human-readable provenance string for the bundled `RosetteStyle`.
    public static let rosette =
        "RosetteStyle is original to Identikit — a polar grid of concentric "
        + "bands with no third-party algorithm behind it."
}
