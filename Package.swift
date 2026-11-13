// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VPlayer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "VPlayer",
            path: "Sources/VPlayer"
        )
    ],
    swiftLanguageVersions: [.v5]
)
