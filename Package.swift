// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SileroVAD",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SileroVAD",
            targets: ["SileroVAD"]
        ),
    ],
    targets: [
        .target(
            name: "SileroVAD",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "SileroVADTests",
            dependencies: ["SileroVAD"]
        ),
    ]
)
