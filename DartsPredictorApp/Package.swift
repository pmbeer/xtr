// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DartsPredictor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DartsPredictor",
            path: "Sources/DartsPredictor"
        )
    ]
)
