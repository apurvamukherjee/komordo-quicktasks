// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KomodoCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KomodoCore", targets: ["KomodoCore"])
    ],
    dependencies: [
        // SQLite with migrations and exact SQL (ARCHITECTURE §2); about 3 MB in the app.
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.9.0")
    ],
    targets: [
        .target(name: "KomodoCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "KomodoCoreTests", dependencies: ["KomodoCore"]),
    ],
    swiftLanguageModes: [.v6]
)
