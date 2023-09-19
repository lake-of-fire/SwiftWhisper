// swift-tools-version:5.5
import PackageDescription

var exclude: [String] = []

#if os(Linux)
// Linux doesn't support CoreML, and will attempt to import the coreml source directory
exclude.append("coreml")
#endif

let package = Package(
    name: "SwiftWhisper",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v13),
    ],
    products: [
        .library(name: "SwiftWhisper", targets: ["SwiftWhisper", "SwiftWhisperStream"])
    ],
    dependencies: [
        .package(url: "https://github.com/ctreffs/SwiftSDL2.git", from: "1.4.0")
    ],
    targets: [
        .target(name: "SwiftWhisper", dependencies: [.target(name: "whisper_cpp")]),
        .target(name: "SwiftWhisperStream", dependencies: [.target(name: "whisper_cpp"), .target(name: "LibWhisper")]),
        .target(name: "LibWhisper", dependencies: [
            .target(name: "whisper_cpp"),
            .product(name: "SDL", package: "SwiftSDL2"),
        ]),
        .target(name: "whisper_cpp",
                exclude: exclude,
                cSettings: [
                    .define("GGML_USE_ACCELERATE", .when(platforms: [.macOS, .macCatalyst, .iOS])),
                    .define("WHISPER_USE_COREML", .when(platforms: [.macOS, .macCatalyst, .iOS])),
                    .define("WHISPER_COREML_ALLOW_FALLBACK", .when(platforms: [.macOS, .macCatalyst, .iOS])),
                    .unsafeFlags(["-O3"])
                ]),
        .testTarget(name: "WhisperTests", dependencies: [.target(name: "SwiftWhisper")], resources: [.copy("TestResources/")])
    ],
    cxxLanguageStandard: CXXLanguageStandard.cxx20
)
