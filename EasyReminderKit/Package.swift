// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EasyReminderKit",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "EasyReminderKit", targets: ["EasyReminderKit"]),
        .executable(name: "easyreminder", targets: ["EasyReminderCLI"]),
    ],
    targets: [
        .target(name: "EasyReminderKit", resources: [.process("Resources")]),
        .executableTarget(name: "EasyReminderCLI", dependencies: ["EasyReminderKit"]),
        .testTarget(name: "EasyReminderKitTests", dependencies: ["EasyReminderKit"]),
    ]
)
