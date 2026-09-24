// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MouseFix",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MouseFix",
            path: "Sources/MouseFix"
        )
    ]
)
