// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ContainerUI",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", .upToNextMinor(from: "1.11.2"))
    ],
    targets: [
        .executableTarget(
            name: "ContainerUI",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")],
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
