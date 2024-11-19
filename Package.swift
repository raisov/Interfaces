// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Interfaces",
    platforms: [.macOS(.v11), .iOS(.v13)],
    products: [
        .library(
            name: "Interfaces",
            targets: ["Interfaces"]),
    ],
    dependencies: [
        .package(path: "../simplenet/Sockets/")
    ],
    targets: [
        .target(
            name: "Interfaces", dependencies: ["Sockets"]),

    ]
)
