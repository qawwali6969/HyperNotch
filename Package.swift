// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HyperNotch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HyperNotch", targets: ["HyperNotch"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HyperNotch",
            dependencies: [],
            path: "Sources/HyperNotch"
        )
    ]
)
