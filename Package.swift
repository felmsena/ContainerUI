// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ContainerUI",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ContainerUI",
            path: "Sources/ContainerUI"
        ),
        .testTarget(
            name: "ContainerUITests",
            dependencies: ["ContainerUI"],
            path: "Tests/ContainerUITests"
        )
    ]
)
