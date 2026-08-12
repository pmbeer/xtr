// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DartsAssistant",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DartsAssistant", targets: ["DartsAssistant"])
    ],
    targets: [
        .executableTarget(
            name: "DartsAssistant",
            path: "Sources/DartsAssistant",
            exclude: [
                "DartsAssistant.entitlements",
                "Info.plist"
            ]
        ),
        .testTarget(
            name: "DartsAssistantTests",
            dependencies: ["DartsAssistant"],
            path: "Tests/DartsAssistantTests"
        )
    ]
)
