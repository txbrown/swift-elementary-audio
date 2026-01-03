import ProjectDescription

let project = Project(
    name: "ElementaryAudioExample",
    options: .options(
        defaultKnownRegions: ["en"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.10",
            "CLANG_CXX_LANGUAGE_STANDARD": "c++20",
            "CLANG_CXX_LIBRARY": "libc++",
            "OTHER_LDFLAGS": ["-lc++"],
            "SWIFT_OBJC_INTEROP_MODE": "objcxx",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    ),
    targets: [
        .target(
            name: "ElementaryAudioExample",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.example.elementaryaudio",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "NSMicrophoneUsageDescription": "Audio playback requires microphone access for monitoring.",
            ]),
            sources: ["Sources/**"],
            dependencies: [
                .external(name: "ElementaryAudio"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_OBJC_INTEROP_MODE": "objcxx",
                    "OTHER_SWIFT_FLAGS": ["-cxx-interoperability-mode=default"],
                ]
            )
        ),
    ]
)
