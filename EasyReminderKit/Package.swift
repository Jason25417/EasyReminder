// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EasyReminderKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "EasyReminderKit", targets: ["EasyReminderKit"]),
        .executable(name: "easyreminder", targets: ["EasyReminderCLI"]),
    ],
    targets: [
        .target(name: "EasyReminderKit"),
        .executableTarget(name: "EasyReminderCLI", dependencies: ["EasyReminderKit"]),
        .testTarget(name: "EasyReminderKitTests", dependencies: ["EasyReminderKit"]),
    ]
)
