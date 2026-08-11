// swift-tools-version: 6.0
import PackageDescription

// The user's irreplaceable data. Mirrors CodeStore's shape — an actor over
// SQLite with a migration ladder — with the opposite lifecycle: CodeStore is
// replaced wholesale by a yearly release, this survives every one of them.
let package = Package(
    name: "CodeLibrary",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeLibrary", targets: ["CodeLibrary"])
    ],
    dependencies: [
        .package(path: "../CodeCore"),
        .package(path: "../SQLiteKit")
    ],
    targets: [
        .target(
            name: "CodeLibrary",
            dependencies: [
                .product(name: "CodeCore", package: "CodeCore"),
                .product(name: "SQLiteKit", package: "SQLiteKit")
            ]
        ),
        .testTarget(name: "CodeLibraryTests", dependencies: ["CodeLibrary"])
    ]
)
