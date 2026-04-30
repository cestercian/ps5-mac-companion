// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DualSenseMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DualSenseMac", targets: ["DualSenseMac"])
    ],
    targets: [
        .executableTarget(
            name: "DualSenseMac",
            path: "Sources/DualSenseMac",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("GameController"),
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
