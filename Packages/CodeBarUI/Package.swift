// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodeBarUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeBarUI", targets: ["CodeBarUI"])
    ],
    dependencies: [
        .package(path: "../CodeCore"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.4")
    ],
    targets: [
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
