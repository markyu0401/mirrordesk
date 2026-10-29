// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MirrorDesk",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MirrorDesk", targets: ["MirrorDesk"])
    ],
    targets: [
        .executableTarget(
            name: "MirrorDesk",
            path: "Sources/MirrorDesk"
        ),
        .testTarget(
            name: "MirrorDeskTests",
            dependencies: ["MirrorDesk"],
            path: "Tests/MirrorDeskTests"
        )
    ]
)
