// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "Archivable",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8)
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
