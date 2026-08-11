// swift-tools-version: 6.0
import PackageDescription

// Deliberately does not depend on CodeStore: the UI sees storage only through
// the CodeRepository protocol in CodeCore. See docs/ARCHITECTURE.md §3.
let package = Package(
    name: "CodeBarUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeBarUI", targets: ["CodeBarUI"])
    ],
    dependencies: [
        .package(path: "../CodeCore")
    ],
    targets: [
        .target(
            name: "CodeBarUI",
            dependencies: [.product(name: "CodeCore", package: "CodeCore")]
        ),
        .testTarget(name: "CodeBarUITests", dependencies: ["CodeBarUI"])
    ]
)
