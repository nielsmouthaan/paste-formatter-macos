// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "paste-formatter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PasteFormatterCore",
            targets: ["PasteFormatterCore"]
        ),
        .library(
            name: "PasteFormatterUI",
            targets: ["PasteFormatterUI"]
        ),
        .executable(
            name: "PasteFormatter",
            targets: ["PasteFormatter"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0")
    ],
    targets: [
        .target(
            name: "PasteFormatterCore",
            path: "Sources/PasteFormatterCore"
        ),
        .target(
            name: "PasteFormatterUI",
            path: "Sources/PasteFormatterUI",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "PasteFormatter",
            dependencies: [
                "PasteFormatterCore",
                "PasteFormatterUI",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/PasteFormatter"
        ),
        .testTarget(
            name: "PasteFormatterCoreTests",
            dependencies: ["PasteFormatterCore"],
            path: "Tests/PasteFormatterCoreTests"
        ),
        .testTarget(
            name: "PasteFormatterTests",
            dependencies: ["PasteFormatter"],
            path: "Tests/PasteFormatterTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
