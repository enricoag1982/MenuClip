// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MenuClip",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MenuClip", targets: ["MenuClip"]),
    ],
    targets: [
        // Models, history logic and file formats. No AppKit, so it is easy to test.
        .target(name: "MenuClipCore"),
        // The menu bar app itself.
        .executableTarget(name: "MenuClip", dependencies: ["MenuClipCore"]),
        .testTarget(name: "MenuClipCoreTests", dependencies: ["MenuClipCore"]),
    ]
)
