// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftWhisperKitMLX",
    platforms: [ .iOS(.v17), .macOS(.v14) ],
    products: [ .library(name: "SwiftWhisperKitMLX", targets: ["SwiftWhisperKitMLX"]) ],
    dependencies: [
        // Pin to a specific MLX release for reproducibility and stability
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.24.0")
    ],
    targets: [
        .target(
            name: "SwiftWhisperKitMLX",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift")
            ],
            path: "Sources",
            swiftSettings: [
                // Enable modern C++ interop for MLX compatibility
                .interoperabilityMode(.Cxx)
            ]
        ),
        .testTarget(
            name: "SwiftWhisperKitMLXTests",
            dependencies: ["SwiftWhisperKitMLX"],
            path: "Tests"
        )
    ]
)
