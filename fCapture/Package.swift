// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "fCapture",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "fCapture",
            targets: ["fCapture"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "fCapture",
            path: ".",
            exclude: ["ScreenCaptureView.swift"],
            sources: ["ScreenCaptureApp.swift", "ScreenCapture.swift", "ScrollCapture.swift"],
            resources: [.copy(".fCapture.json"), .copy("defaultSetting.json"), .copy("defaultScreen.json"), .copy("defaultRegion.json"), .copy("defaultWindow.json"), .copy("Usage.txt"), .copy("default.yml")]
        ),
    ]
)