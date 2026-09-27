// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VibeNotch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VibeNotch", targets: ["VibeNotch"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VibeNotch",
            dependencies: [],
            path: "Sources/VibeNotch"
        )
    ]
)
