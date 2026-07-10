// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ContainerUI",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ContainerUI",
            path: "Sources/ContainerUI",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ContainerUITests",
            dependencies: ["ContainerUI"],
            path: "Tests/ContainerUITests"
        )
    ]
)
