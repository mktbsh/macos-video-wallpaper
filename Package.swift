// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VideoWallpaperDevTools",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/csjones/lefthook-plugin.git", exact: "2.1.4"),
    ],
    targets: [
        .executableTarget(
            name: "VideoWallpaperDevTools",
            path: "Tooling/VideoWallpaperDevTools"
        ),
    ]
)
