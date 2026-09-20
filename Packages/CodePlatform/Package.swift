// swift-tools-version: 6.0
import PackageDescription

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
