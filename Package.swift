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
        .library(
            name: "EIntelligence",
            targets: ["EIntelligence"]
        ),
        .library(
            name: "EGate",
            targets: ["EGate"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads", from: "12.0.0"),
    ],
    targets: [
        .target(
            name: "EllevenLibs",
            path: "Sources/EllevenLibs"
        ),
        .target(
            name: "EAds",
            dependencies: [
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads", condition: .when(platforms: [.iOS])),
            ],
            path: "Sources/EAds"
        ),
        .target(
            name: "EStore",
            path: "Sources/EStore"
        ),
        .target(
            name: "EIntelligence",
            path: "Sources/EIntelligence"
        ),
        .target(
            name: "EGate",
            dependencies: ["EStore", "EAds"],
            path: "Sources/EGate"
        ),
        .testTarget(
            name: "EllevenLibsTests",
            dependencies: ["EllevenLibs"],
            path: "Tests/EllevenLibsTests"
        ),
    ]
)
