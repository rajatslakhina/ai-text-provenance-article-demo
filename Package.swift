// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ProvenanceLedger",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ProvenanceLedger", targets: ["ProvenanceLedger"]),
    ],
    targets: [
        .target(name: "ProvenanceLedger"),
        .testTarget(name: "ProvenanceLedgerTests", dependencies: ["ProvenanceLedger"]),
    ]
)
