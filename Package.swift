// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "lupita",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LupitaCore", targets: ["LupitaCore"]),
        .executable(name: "lupita", targets: ["lupita"]),
        .executable(name: "LupitaApp", targets: ["LupitaApp"]),
    ],
    targets: [
        .target(name: "LupitaCore"),
        .executableTarget(name: "lupita", dependencies: ["LupitaCore"]),
        .executableTarget(name: "LupitaApp", dependencies: ["LupitaCore"]),
        .testTarget(name: "LupitaCoreTests", dependencies: ["LupitaCore"]),
    ]
)
