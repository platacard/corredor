// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Corredor",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "Corredor",
            targets: ["Corredor"]
        )
    ],
    targets: [
        .target(
            name: "Corredor",
            path: "Sources/Corredor"
        ),
        .testTarget(
            name: "CorredorTests",
            dependencies: ["Corredor"],
            path: "Tests/Corredor"
        )
    ]
)
