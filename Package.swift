// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Construct",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(name: "Compendium", targets: ["Compendium"]),
        .library(name: "DiceRollerFeature", targets: ["DiceRollerFeature"]),
        .library(name: "DiceRollerInvocation", targets: ["DiceRollerInvocation"]),
        .library(name: "Dice", targets: ["Dice"]),
        .library(name: "GameModels", targets: ["GameModels"]),
        .library(name: "Helpers", targets: ["Helpers"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "PersistenceTestSupport", targets: ["PersistenceTestSupport"]),
        .library(name: "SharedViews", targets: ["Helpers"]),
        .executable(name: "db-tool", targets: ["DatabaseInitTool"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.36.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/swift-url-routing", from: "0.3.0"),
        .package(url: "https://github.com/Thomvis/GRDB.swift.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", exact: "0.0.1"), // pinned to 0.0.1 because versions after that require the Swift Standard Library version 5.7, which was not part of the macOS SDK in Xcode 14
        .package(url: "https://github.com/pointfreeco/swiftui-navigation", from: "0.4.2")
    ],
    targets: [
        .target(
            name: "Compendium",
            dependencies: [
                "GameModels",

                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
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
                .product(name: "SwiftUINavigation", package: "swiftui-navigation")
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
            name: "PersistenceTestSupport",
            resources: [
                .copy("Resources/initial.sqlite")
            ]
        ),
        .target(
            name: "SharedViews",
            dependencies: []
        ),
        .executableTarget(
            name: "DatabaseInitTool",
            dependencies: [
                "Persistence"
            ]
        )
    ]
)
