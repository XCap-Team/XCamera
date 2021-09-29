// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "XCamera",
    platforms: [.macOS(.v10_11), .iOS(.v10)],
    products: [
        .library(name: "XCamera", targets: ["XCamera"]),
        .library(name: "XRecorder", targets: ["XRecorder"])
    ],
    targets: [
        .target(name: "XCamera"),
        .testTarget(name: "XCameraTests", dependencies: ["XCamera"]),
        
        .target(name: "XRecorder", dependencies: ["XCamera"]),
        .testTarget(name: "XRecorderTests", dependencies: ["XRecorder"]),
    ]
)
