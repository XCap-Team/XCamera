// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XCamera",
    platforms: [.macOS(.v10_10)],
    products: [
        .library(name: "XCamera", targets: ["XCamera"]),
    ],
    targets: [
        .target(name: "XCamera", path: "Sources"),
        .testTarget(name: "XCameraTests", dependencies: ["XCamera"]),
    ]
)
