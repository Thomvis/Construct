// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Construct",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "DiceRollerFeature", targets: ["DiceRollerFeature"]),
        .library(name: "DiceRollerInvocation", targets: ["DiceRollerInvocation"]),
        .library(name: "Dice", targets: ["Dice"]),
        .library(name: "GameModels", targets: ["GameModels"]),
        .library(name: "Helpers", targets: ["Helpers"]),
        .library(name: "SharedViews", targets: ["Helpers"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.36.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/swift-url-routing", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "DiceRollerFeature",
            dependencies: [
                "Dice",
                "GameModels",
                "Helpers",
                "SharedViews",

                .product(name: "Tagged", package: "swift-tagged"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "DiceRollerInvocation",
            dependencies: [
                "Dice",

                .product(name: "URLRouting", package: "swift-url-routing"),
            ]
        ),
        .target(
            name: "Dice",
            dependencies: [
                "Helpers"
            ]
        ),
        .target(
            name: "GameModels",
            dependencies: [
                "Dice",
                "Helpers"
            ]
        ),
        .target(
            name: "Helpers",
            dependencies: [
                .product(name: "Tagged", package: "swift-tagged"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "SharedViews",
            dependencies: []
        )
    ]
)
