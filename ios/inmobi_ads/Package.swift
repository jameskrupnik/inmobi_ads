// swift-tools-version: 5.9

import PackageDescription

// The Swift Package Manager twin of `../inmobi_ads.podspec`. Both build the
// same sources; keep the InMobi version range in step between them.
//
// InMobi ships the iOS SDK as an official Swift package wrapping a binary
// xcframework. That framework is *dynamic*, so the `-ObjC` linker flag
// InMobi's SPM README asks for is not needed here — it matters only when
// Objective-C categories live in a static library — and a dependency package
// could not set it anyway: SwiftPM refuses `unsafeFlags` from dependencies.
//
// `upToNextMinor` from 11.4.1, not `upToNextMajor`: the native code is written
// against the 11.4 API surface, and the CocoaPods spec pins the same range.
let package = Package(
    name: "inmobi_ads",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "inmobi-ads", targets: ["inmobi_ads"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(
            url: "https://github.com/InMobi/InMobiSDK-Swift-Package",
            .upToNextMinor(from: "11.4.1")
        ),
    ],
    targets: [
        .target(
            name: "inmobi_ads",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "InMobiSDK", package: "InMobiSDK-Swift-Package"),
            ]
        )
    ]
)
