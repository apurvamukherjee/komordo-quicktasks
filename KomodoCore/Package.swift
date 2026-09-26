// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KomodoCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KomodoCore", targets: ["KomodoCore"])
    ],
    targets: [
        .target(name: "KomodoCore"),
        .testTarget(name: "KomodoCoreTests", dependencies: ["KomodoCore"]),
    ],
    swiftLanguageModes: [.v6]
)
