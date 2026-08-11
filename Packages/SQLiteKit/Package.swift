// swift-tools-version: 6.0
import PackageDescription

// The SQLite layer shared by CodeStore (the disposable code index) and
// CodeLibrary (the user's irreplaceable data). Knows nothing about either.
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
