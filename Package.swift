// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ProjectOne",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "ProjectOneLibrary",
            targets: ["ProjectOne"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.2.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "8.53.2"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.25.6"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.13.0"),
        .package(url: "https://github.com/huggingface/swift-transformers.git", from: "0.1.22"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.3"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
        .package(url: "https://github.com/1024jp/GzipSwift", from: "6.0.1"),
        .package(url: "https://github.com/johnmai-dev/Jinja", from: "1.2.1")
    ],
    targets: [
        .target(
            name: "ProjectOne",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Sentry", package: "sentry-cocoa"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXFFT", package: "mlx-swift"),
                .product(name: "MLXLinalg", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "Transformers", package: "swift-transformers"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Numerics", package: "swift-numerics"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Gzip", package: "GzipSwift"),
                .product(name: "Jinja", package: "Jinja")
            ],
            path: "ProjectOne",
            swiftSettings: [
                .enableUpcomingFeature("DisableOutwardActorInference"),
                .unsafeFlags(["-Xfrontend", "-warn-concurrency"])
            ]
        )
    ]
)
