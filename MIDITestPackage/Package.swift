// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MIDITestPackage",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MIDITestPackage",
            targets: ["MIDITestPackage"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/AudioKit/AudioKit", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "MIDITestPackage",
            dependencies: [
                .product(name: "AudioKit", package: "AudioKit")
            ]
        ),
        .testTarget(
            name: "MIDITestPackageTests",
            dependencies: ["MIDITestPackage"]
        )
    ]
)