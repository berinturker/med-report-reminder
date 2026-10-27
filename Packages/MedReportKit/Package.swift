// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MedReportKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MedReportKit", targets: ["MedReportKit"]),
    ],
    targets: [
        .target(name: "MedReportKit"),
        .testTarget(name: "MedReportKitTests", dependencies: ["MedReportKit"]),
    ]
)
