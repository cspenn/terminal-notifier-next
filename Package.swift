// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "terminal-notifier-next",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "terminal-notifier-next", targets: ["TerminalNotifierApp"])
    ],
    targets: [
        .executableTarget(
            name: "TerminalNotifierApp",
            path: "Sources/TerminalNotifierApp"
        ),
        .testTarget(
            name: "TerminalNotifierTests",
            dependencies: ["TerminalNotifierApp"],
            path: "Tests/TerminalNotifierTests"
        )
    ]
)
