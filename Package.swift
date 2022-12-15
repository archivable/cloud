// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Cloud",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "Cloud",
            targets: ["Cloud"]),
    ],
    dependencies: [
        .package(url: "https://github.com/archivable/store.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Cloud",
            dependencies: [
                .product(name: "Store", package: "store")],
            path: "Sources"),
        .testTarget(
            name: "Tests",
            dependencies: ["Cloud"],
            path: "Tests")
    ]
)
