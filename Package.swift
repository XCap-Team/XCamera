// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "XCamera",
    platforms: [.macOS(.v10_10), .iOS(.v10)],
    products: [
        .library(name: "XCamera", targets: ["XCamera"]),
    ],
    targets: [
        .target(name: "XCamera", path: "Sources"),
        .testTarget(name: "XCameraTests", dependencies: ["XCamera"]),
    ]
)
