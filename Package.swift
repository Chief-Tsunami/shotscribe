// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "shotscribe",
    platforms: [.macOS(.v13)],
    products: [
        // The reusable core — pure logic, no UI. Shared by the CLI, and (next
        // slices) the MCP server, the menu-bar app, and the widget.
        .library(name: "ShotScribeCore", targets: ["ShotScribeCore"]),
        // The dogfoodable command-line tool.
        .executable(name: "shotscribe", targets: ["shotscribe"]),
    ],
    targets: [
        .target(name: "ShotScribeCore"),
        .executableTarget(
            name: "shotscribe",
            dependencies: ["ShotScribeCore"]
        ),
        .testTarget(
            name: "ShotScribeCoreTests",
            dependencies: ["ShotScribeCore"]
        ),
    ]
)
