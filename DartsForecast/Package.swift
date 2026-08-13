// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DartsForecast",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DartsForecast", targets: ["DartsForecast"])
    ],
    targets: [
        .executableTarget(
            name: "DartsForecast",
            path: "Sources/DartsForecast",
            exclude: [
                "Info.plist",
                "DartsForecast.entitlements"
            ],
            resources: [.process("Resources")]
        )
    ]
)
