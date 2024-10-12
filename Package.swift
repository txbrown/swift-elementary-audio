// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "swift-elementary-audio",   
    products: [
        .library(name: "cxxElementaryAudio", targets: ["cxxElementaryAudio"]),
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
                "ElementaryAudio/runtime/elem/third-party/signalsmith-stretch/dsp/LICENSE.txt"
            ],
            sources: [
                "./ElementaryAudio/runtime",
                "SimpleMath.cpp",
                "CustomNode.cpp"
            ],
            cxxSettings: [
                .headerSearchPath("./ElementaryAudio/runtime"),
                .headerSearchPath("./include/"),
                .headerSearchPath("."),
                .unsafeFlags([
                    "-std=c++17",
                ])
            ]
        ),
        .executableTarget(
            name: "swift-elementary-audio",
            dependencies: ["cxxElementaryAudio"],
            path: "Sources/swift-elementary-audio",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
