// swift-tools-version: 6.0
import PackageDescription

// AppKit and Carbon glue. Depends on CodeCore only — never on CodeStore or the
// UI package. See docs/ARCHITECTURE.md §3.
let package = Package(
    name: "CodePlatform",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodePlatform", targets: ["CodePlatform"])
    ],
    dependencies: [
        .package(path: "../CodeCore")
    ],
    targets: [
        .target(
            name: "CodePlatform",
            dependencies: [.product(name: "CodeCore", package: "CodeCore")]
        ),
        .testTarget(name: "CodePlatformTests", dependencies: ["CodePlatform"])
    ]
)
