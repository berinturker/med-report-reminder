// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IlacRaporKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "IlacRaporKit", targets: ["IlacRaporKit"]),
    ],
    targets: [
        .target(name: "IlacRaporKit"),
        .testTarget(name: "IlacRaporKitTests", dependencies: ["IlacRaporKit"]),
    ]
)
