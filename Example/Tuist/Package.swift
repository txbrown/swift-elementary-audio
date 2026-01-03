// swift-tools-version: 5.10
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings

let packageSettings = PackageSettings(
    productTypes: [
        "ElementaryAudio": .framework,
        "cxxElementaryAudio": .framework,
    ]
)
#endif

let package = Package(
    name: "Dependencies",
    dependencies: [
        .package(path: "../.."),
    ]
)
