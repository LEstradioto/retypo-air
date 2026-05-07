// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RetypoAir",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "RetypoAir", targets: ["RetypoAir"])
    ],
    targets: [
        .executableTarget(
            name: "RetypoAir",
            path: "Sources/RetypoAir"
        ),
        .testTarget(
            name: "RetypoAirTests",
            dependencies: ["RetypoAir"],
            path: "Tests/RetypoAirTests"
        )
    ]
)
