// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "outRage",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "OutRageKit", targets: ["OutRageKit"]),
        .executable(name: "outrage", targets: ["OutRageCLI"]),
        .executable(name: "outrage-host", targets: ["OutRageHost"])
    ],
    targets: [
        .target(name: "OutRageKit"),
        .executableTarget(
            name: "OutRageCLI",
            dependencies: ["OutRageKit"]
        ),
        .executableTarget(
            name: "OutRageHost",
            dependencies: ["OutRageKit"]
        ),
        .testTarget(
            name: "OutRageKitTests",
            dependencies: ["OutRageKit"]
        )
    ]
)
