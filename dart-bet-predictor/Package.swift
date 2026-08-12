// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DartBetPredictor",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DartBetPredictor", targets: ["DartBetPredictor"])
    ],
    targets: [
        .executableTarget(
            name: "DartBetPredictor",
            path: "Sources/DartBetPredictor",
            resources: [.process("Resources")]
        )
    ]
)
