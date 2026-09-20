// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SQLiteKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SQLiteKit", targets: ["SQLiteKit"])
    ],
    targets: [
        .target(name: "SQLiteKit", linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "SQLiteKitTests", dependencies: ["SQLiteKit"])
    ]
)
