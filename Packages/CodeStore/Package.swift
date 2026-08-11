// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodeStore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeStore", targets: ["CodeStore"])
    ],
    dependencies: [
        .package(path: "../CodeCore")
    ],
    targets: [
        .target(
            name: "CodeStore",
            dependencies: [.product(name: "CodeCore", package: "CodeCore")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(name: "CodeStoreTests", dependencies: ["CodeStore"])
    ]
)
