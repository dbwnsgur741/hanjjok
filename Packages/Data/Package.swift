// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.macOS(.v14)],
    products: [.library(name: "Data", targets: ["Data"])],
    dependencies: [
        .package(path: "../Domain"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    ],
    targets: [
        .target(name: "Data", dependencies: [
            "Domain",
            .product(name: "GRDB", package: "GRDB.swift"),
        ]),
        .testTarget(name: "DataTests", dependencies: ["Data"]),
    ]
)
