// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swifter-protomaps",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "SwifterProtomaps", targets: ["SwifterProtomaps"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/sfomuseum/swifter.git", branch:"main"),
        .package(url: "https://github.com/sfomuseum/swift-pmtiles.git", branch:"main"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwifterProtomaps",
            dependencies: [
                .product(name: "Swifter", package: "swifter"),
                .product(name: "PMTiles", package: "swift-pmtiles"),
                .product(name: "Logging", package: "swift-log")
            ]),
        .testTarget(
            name: "SwifterProtomapsTests",
            dependencies: ["SwifterProtomaps"]),
        .executableTarget(
            name: "swifter-protomaps-server",
            dependencies: [
                "SwifterProtomaps",
                .product(name: "Swifter", package: "swifter"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "PMTiles", package: "swift-pmtiles"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Scripts"
    )
    ]
)
