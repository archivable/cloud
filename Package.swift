// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Archivable",
    platforms: [
        .iOS(.v16),
        .macOS(.v12),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "Archivable",
            targets: ["Archivable"]),
    ],
    targets: [
        .target(
            name: "Archivable",
            path: "Sources"),
        .testTarget(
            name: "Tests",
            dependencies: ["Archivable"],
            path: "Tests")
    ]
)
