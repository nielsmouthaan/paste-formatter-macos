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
        .executable(
            name: "PasteFormatter",
            targets: ["PasteFormatter"]
        )
    ],
    targets: [
        .target(
            name: "PasteFormatterCore",
            path: "Sources/PasteFormatterCore"
        ),
        .executableTarget(
            name: "PasteFormatter",
            dependencies: ["PasteFormatterCore"],
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
