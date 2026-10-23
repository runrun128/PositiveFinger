// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PositiveFingerCore",
    platforms: [.macOS(.v12)],
    products: [.library(name: "PositiveFingerCore", targets: ["PositiveFingerCore"])],
    targets: [
        .target(name: "PositiveFingerCore", path: "PositiveFinger",
                exclude: ["PositiveCloud.swift", "AppInfo.plist", "AppIcon60x60@2x.png", "AppIcon60x60@3x.png", "ContentView.swift", "PositiveFingerApp.swift", "PositiveFingerHomeView.swift", "Assets.xcassets", "Preview Content", "PositiveFinger.entitlements"],
                sources: ["PositiveEngine.swift", "PositiveActivityStore.swift", "PositiveKeyboardTracker.swift"]),
        .testTarget(name: "PositiveFingerCoreTests", dependencies: ["PositiveFingerCore"])
    ]
)
