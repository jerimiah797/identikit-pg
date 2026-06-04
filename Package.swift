// swift-tools-version: 6.0
//
// Identikit — a small, dependency-free identicon generator for Apple platforms,
// with pluggable styles and renderers.
//

import PackageDescription

let package = Package(
    name: "Identikit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "Identikit", targets: ["Identikit"]),
    ],
    targets: [
        .target(name: "Identikit"),
        .testTarget(
            name: "IdentikitTests",
            dependencies: ["Identikit"],
            resources: [
                .copy("Fixtures/goldens.json"),
                .copy("Fixtures/prng-golden.json"),
            ]
        ),
    ]
)
