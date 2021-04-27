// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "Archivable",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7)
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
            path: "Tests"),
    ]
)
