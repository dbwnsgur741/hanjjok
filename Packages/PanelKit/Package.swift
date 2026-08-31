// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PanelKit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PanelKit", targets: ["PanelKit"])],
    targets: [
        .target(name: "PanelKit"),
        .testTarget(name: "PanelKitTests", dependencies: ["PanelKit"]),
    ]
)
