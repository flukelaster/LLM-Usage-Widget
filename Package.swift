// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UsageWidget",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "UsageWidget",
            path: "Sources/UsageWidget"
        )
        // NOTE: The Command-Line-Tools-only toolchain ships neither XCTest nor swift-testing
        // (both come with full Xcode), so a test target can't run via `swift test` here. The
        // logic test suite lives in Diagnostics/SelfChecks.swift and runs via `UsageWidget --check`.
        // Add an XCTest/Testing target once full Xcode is installed if desired.
    ]
)
