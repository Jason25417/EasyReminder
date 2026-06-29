// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EasyReminderKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EasyReminderKit", targets: ["EasyReminderKit"]),
    ],
    targets: [
        .target(name: "EasyReminderKit"),
    ]
)
