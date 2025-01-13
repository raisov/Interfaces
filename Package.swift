// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Interfaces",
    platforms: [.macOS(.v11), .iOS(.v13)],
    products: [
        .library(
            name: "Interfaces",
            targets: ["Interfaces", "FunctionalType", "InterfaceType", "InterfaceFlags"]),
    ],
    dependencies: [
        .package(url: "https://github.com/raisov/Sockets.git", branch: "ex/swift5")
    ],
    targets: [
        .target(name: "FunctionalType"),
        .target(name: "InterfaceType"),
        .target(name: "InterfaceFlags"),
        .target(
            name: "Interfaces", dependencies: ["Sockets", "FunctionalType", "InterfaceType", "InterfaceFlags"]),

    ]
)
