// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Construct",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "Compendium", targets: ["Compendium"]),
        .library(name: "DiceRollerFeature", targets: ["DiceRollerFeature"]),
        .library(name: "DiceRollerInvocation", targets: ["DiceRollerInvocation"]),
        .library(name: "Dice", targets: ["Dice"]),
        .library(name: "GameModels", targets: ["GameModels"]),
        .library(name: "Helpers", targets: ["Helpers"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "SharedViews", targets: ["Helpers"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.36.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/swift-url-routing", from: "0.3.0"),
        .package(url: "https://github.com/Thomvis/GRDB.swift.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "Compendium",
            dependencies: [
                "GameModels"
            ],
            resources: [
                .copy("Fixtures/monsters.json"),
                .copy("Fixtures/spells.json")
            ]
        ),
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
        .testTarget(
            name: "GameModelsTests",
            dependencies: [
                "GameModels"
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
            name: "Persistence",
            dependencies: [
                "Compendium",
                "GameModels",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .target(
            name: "SharedViews",
            dependencies: []
        )
    ]
)
