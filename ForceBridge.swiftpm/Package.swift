// swift-tools-version: 5.9

// ForceBridge — пакет приложения Swift Playgrounds (.swiftpm).
// Открывается в Swift Playgrounds 4.6+ (iPad / Mac) и в Xcode 16+.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "ForceBridge",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "ForceBridge",
            targets: ["AppModule"],
            bundleIdentifier: "app.forcebridge.ForceBridge",
            teamIdentifier: "",
            displayVersion: "2.0",
            bundleVersion: "2",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
