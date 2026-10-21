// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PositiveFingerCore",
    platforms: [.macOS(.v12)],
    products: [.library(name: "PositiveFingerCore", targets: ["PositiveFingerCore"])],
    targets: [
        .target(name: "PositiveFingerCore", path: "PositiveFinger",
                exclude: ["ContentView.swift", "PositiveFingerApp.swift", "PositiveFingerHomeView.swift", "Assets.xcassets", "Preview Content", "PositiveFinger.entitlements"],
                sources: ["PositiveEngine.swift", "PositivePointManager.swift"]),
        .testTarget(name: "PositiveFingerCoreTests", dependencies: ["PositiveFingerCore"])
    ]
)
