// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "paste-formatter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CleanPasteCore",
            targets: ["CleanPasteCore"]
        ),
        .executable(
            name: "CleanPaste",
            targets: ["CleanPaste"]
        )
    ],
    targets: [
        .target(
            name: "CleanPasteCore"
        ),
        .executableTarget(
            name: "CleanPaste",
            dependencies: ["CleanPasteCore"]
        ),
        .testTarget(
            name: "CleanPasteCoreTests",
            dependencies: ["CleanPasteCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
