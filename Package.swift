// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "EnumCaseNameCheck",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax", branch: "0.50600.1")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax")
            ]
        )
    ]
)
