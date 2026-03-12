// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EllevenLibs",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "EllevenLibs",
            targets: ["EllevenLibs"]
        ),
    ],
    targets: [
        .target(
            name: "EllevenLibs",
            path: "Sources/EllevenLibs"
        ),
        .testTarget(
            name: "EllevenLibsTests",
            dependencies: ["EllevenLibs"],
            path: "Tests/EllevenLibsTests"
        ),
    ]
)
