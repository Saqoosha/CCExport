// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CCExport",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CCExportCore", targets: ["CCExportCore"]),
        .executable(name: "ccexport", targets: ["ccexport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "CCExportCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .executableTarget(
            name: "ccexport",
            dependencies: ["CCExportCore"]
        ),
    ]
)
