// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Solituder",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "SolituderKit",
            targets: ["SolituderKit"]
        )
    ],
    targets: [
        .target(
            name: "SolituderKit"
        ),
        .testTarget(
            name: "SolituderKitTests",
            dependencies: ["SolituderKit"]
        )
    ]
)
