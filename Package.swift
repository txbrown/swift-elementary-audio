// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "swift-elementary-audio",
    platforms: [
        .macOS(.v14),
        .iOS(.v15),
    ],
    products: [
        .library(name: "cxxElementaryAudio", targets: ["cxxElementaryAudio"]),
        .library(name: "ElementaryAudio", targets: ["ElementaryAudio"]),
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
            ],
            sources: [
                "./ElementaryAudio/runtime",
                "CustomNode.cpp",
            ],
            cxxSettings: [
                .headerSearchPath("./ElementaryAudio/runtime"),
                .headerSearchPath("./include/"),
                .headerSearchPath("."),
                .unsafeFlags([
                    "-std=c++20",
                ]),
                .define("SWIFT_BRIDGING_ENABLED", to: "1"),
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
    ],
    cxxLanguageStandard: .cxx20
)
