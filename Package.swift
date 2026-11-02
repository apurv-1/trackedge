// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrackEdge",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TrackEdge", targets: ["TrackEdge"]),
    ],
    targets: [
        // Thin C bridge to the private MultitouchSupport framework, loaded with dlopen.
        .target(name: "CMultitouch"),
        // Pure gesture logic: touches in, actions out. No AppKit, fully unit tested.
        .target(name: "TrackEdgeCore"),
        .executableTarget(
            name: "TrackEdge",
            dependencies: ["CMultitouch", "TrackEdgeCore"]
        ),
        .testTarget(name: "TrackEdgeCoreTests", dependencies: ["TrackEdgeCore"]),
    ]
)
