// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "EnglishX",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "EnglishX", targets: ["EnglishX"])],
    targets: [
        .executableTarget(name: "EnglishX", resources: [.process("Resources")]),
        .testTarget(name: "EnglishXTests", dependencies: ["EnglishX"])
    ]
)
