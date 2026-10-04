// swift-tools-version: 5.9
import PackageDescription

// The package and product name follow the Capacitor CLI convention (fixName of
// the npm name), so a generated CapApp-SPM package can reference it.
let package = Package(
    name: "WwConsultingCapacitorNativeTabBar",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "WwConsultingCapacitorNativeTabBar",
            targets: ["NativeTabBarPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "NativeTabBarPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/NativeTabBarPlugin")
    ]
)
