// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodeCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeCore", targets: ["CodeCore"])
    ],
    targets: [
        .target(name: "CodeCore"),
        .testTarget(name: "CodeCoreTests", dependencies: ["CodeCore"])
    ]
)
