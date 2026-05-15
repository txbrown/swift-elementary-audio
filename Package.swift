// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "swift-elementary-audio",
    platforms: [
        .macOS("13.3"), // C++ interop requires >=13.3; no enum case available
        .iOS("16.4"),   // C++ interop requires >=16.4; no enum case available
    ],
    products: [
        .library(name: "cxxElementaryAudio", targets: ["cxxElementaryAudio"]),
        .library(name: "ElementaryAudio", targets: ["ElementaryAudio"]),
        .library(name: "ElementaryFlow", targets: ["ElementaryFlow"]),
    ],
    dependencies: [
        .package(path: "Vendor/Flow"),
    ],
    targets: [
        .target(
            name: "cxxElementaryAudio",
            path: "Sources/cxxElementaryAudio",
            exclude: [
                "./ElementaryAudio/wasm",
                "./ElementaryAudio/cli",
                "./ElementaryAudio/runtime/CMakeLists.txt",
                "ElementaryAudio/runtime/elem/third-party/signalsmith-stretch/LICENSE.txt",
                "./ElementaryAudio/runtime/elem/third-party/signalsmith-stretch/README.md",
                "ElementaryAudio/runtime/elem/third-party/signalsmith-stretch/dsp/README.md",
                "ElementaryAudio/runtime/elem/third-party/signalsmith-stretch/dsp/LICENSE.txt",
                // choc is header-only — exclude the entire directory from compilation
                // (headers are still found via headerSearchPath)
                "ElementaryAudio/runtime/elem/third-party/choc",
            ],
            sources: [
                "./ElementaryAudio/runtime",
                "CustomNode.cpp",
            ],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("./ElementaryAudio/runtime"),
                .headerSearchPath("."),
                .define("SWIFT_BRIDGING_ENABLED", to: "1"),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
        .target(
            name: "ElementaryAudio",
            dependencies: ["cxxElementaryAudio"],
            path: "Sources/ElementaryAudio",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "swift-elementary-audio",
            dependencies: ["ElementaryAudio"],
            path: "Sources/swift-elementary-audio",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .target(
            name: "ElementaryFlow",
            dependencies: [
                "ElementaryAudio",
                .product(name: "Flow", package: "Flow"),
            ],
            path: "Sources/ElementaryFlow",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "ElementaryPlayground",
            dependencies: ["ElementaryFlow"],
            path: "Sources/ElementaryPlayground",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "ElementaryAudioTests",
            dependencies: ["ElementaryAudio"],
            path: "Tests/ElementaryAudioTests",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
