// swift-tools-version: 6.2
// gaea-plugin-sam-audio: Meta's SAM-Audio base for Gaea — `audio.separate` by description (MES Audio 0.1 with RFC 0008).
// One worker executable over GaeaPluginKit; the model is the MLXEngine package `MLXSAMAudio` (xocialize/mlx-sam-audio-swift).
import PackageDescription

let kitPath = Context.environment["GAEA_PLUGIN_KIT_PATH"]

let package = Package(
    name: "gaea-plugin-sam-audio",
    platforms: [.macOS(.v26)], // mlx-engine-swift's MLXToolKit requires macOS 26
    dependencies: [
        kitPath.map { .package(path: $0) }
            ?? .package(url: "https://github.com/xocialize-code/gaea-plugin-kit.git", from: "0.12.0"),
        .package(url: "https://github.com/xocialize/mlx-sam-audio-swift.git", exact: "0.2.1"),
        .package(url: "https://github.com/xocialize/mlx-engine-swift.git", from: "0.77.0"), // contract 1.62.0: a described target + spans
        .package(url: "https://github.com/xocialize/mlx-swift", from: "0.32.4"),
    ],
    targets: [
        .target(
            name: "SAMAudioPlugin",
            dependencies: [
                .product(name: "GaeaPluginKit", package: "gaea-plugin-kit"),
                .product(name: "GaeaProtocol", package: "gaea-plugin-kit"),
                .product(name: "MLXSAMAudio", package: "mlx-sam-audio-swift"),
                .product(name: "MLXToolKit", package: "mlx-engine-swift"),
                .product(name: "MLX", package: "mlx-swift"),
            ]
        ),
        .executableTarget(
            name: "gaea-sam-audio-worker",
            dependencies: [
                "SAMAudioPlugin",
                .product(name: "GaeaPluginKit", package: "gaea-plugin-kit"),
            ]
        ),
        .executableTarget(
            name: "sam-audio-inproc",
            dependencies: [
                "SAMAudioPlugin",
                .product(name: "GaeaPluginKit", package: "gaea-plugin-kit"),
                .product(name: "GaeaProtocol", package: "gaea-plugin-kit"),
                .product(name: "MLXSAMAudio", package: "mlx-sam-audio-swift"),
                .product(name: "MLXToolKit", package: "mlx-engine-swift"),
                .product(name: "MLXServeCore", package: "mlx-engine-swift"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "SAMAudioPluginTests", dependencies: ["SAMAudioPlugin", .product(name: "GaeaProtocol", package: "gaea-plugin-kit")]),
    ]
)
