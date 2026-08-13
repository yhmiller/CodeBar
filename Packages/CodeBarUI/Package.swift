// swift-tools-version: 6.0
import PackageDescription

// Deliberately does not depend on CodeStore or CodeLibrary: the UI sees storage
// only through the protocols in CodeCore. See docs/ARCHITECTURE.md §3.
let package = Package(
    name: "CodeBarUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeBarUI", targets: ["CodeBarUI"])
    ],
    dependencies: [
        .package(path: "../CodeCore"),
        // Test-only. Renders a view and diffs it against a stored reference,
        // which is the class of bug the view-model tests cannot see.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.4")
    ],
    targets: [
        // Deliberately no `resources:`. The semantic colours were an `.xcassets`
        // here first; `swift build` copies a catalogue in without running
        // `actool`, so nothing resolved under `make check` while the app — built
        // by `xcodebuild` — looked fine. They are defined in code instead, in
        // DesignSystem/Palette.swift.
        .target(
            name: "CodeBarUI",
            dependencies: [.product(name: "CodeCore", package: "CodeCore")]
        ),
        .testTarget(
            name: "CodeBarUITests",
            dependencies: [
                "CodeBarUI",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ]
        )
    ]
)
