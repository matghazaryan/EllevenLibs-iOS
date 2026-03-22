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
        .library(
            name: "EAds",
            targets: ["EAds"]
        ),
        .library(
            name: "EStore",
            targets: ["EStore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "EllevenLibs",
            path: "Sources/EllevenLibs"
        ),
        .target(
            name: "EAds",
            dependencies: [
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
            ],
            path: "Sources/EAds"
        ),
        .target(
            name: "EStore",
            path: "Sources/EStore"
        ),
        .testTarget(
            name: "EllevenLibsTests",
            dependencies: ["EllevenLibs"],
            path: "Tests/EllevenLibsTests"
        ),
    ]
)
