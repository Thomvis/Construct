// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Construct",
    platforms: [
        .iOS(.v17),
        .macOS(.v12)
    ],
    products: [
        .library(name: "ActionResolutionFeature", targets: ["ActionResolutionFeature"]),
        .library(name: "Compendium", targets: ["Compendium"]),
        .library(name: "DiceRollerFeature", targets: ["DiceRollerFeature"]),
        .library(name: "DiceRollerInvocation", targets: ["DiceRollerInvocation"]),
        .library(name: "Dice", targets: ["Dice"]),
        .library(name: "GameModels", targets: ["GameModels"]),
        .library(name: "Helpers", targets: ["Helpers"]),
        .library(name: "MechMuse", targets: ["MechMuse"]),
        .library(name: "Open5eAPI", targets: ["Open5eAPI"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "TestSupport", targets: ["TestSupport"]),
        .library(name: "SharedViews", targets: ["Helpers"]),
        .executable(name: "db-tool", targets: ["DatabaseInitTool"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.49.2"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/swift-url-routing", from: "0.5.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.3"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.0.4"),
        .package(url: "https://github.com/pointfreeco/swiftui-navigation", from: "0.4.2"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.11.2"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.0"),
        .package(url: "https://github.com/pointfreeco/swift-clocks.git", from: "0.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.14.0"),
        .package(url: "https://github.com/ajevans99/swift-json-schema", from: "0.9.0"),
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.4.6")
    ],
    targets: [
        .target(
            name: "ActionResolutionFeature",
            dependencies: [
                "Dice",
                "DiceRollerFeature",
                "GameModels",
                "MechMuse",

                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
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
        .testTarget(
            name: "CompendiumTests",
            dependencies: [
                "Compendium"
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
                "GameModels",
                "TestSupport",
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing")
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
        .testTarget(
            name: "HelpersTests",
            dependencies: [
                "Helpers",
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ]
        ),
        .target(
            name: "MechMuse",
            dependencies: [
                "GameModels",
                "Helpers",
                "Persistence",

                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "JSONSchemaBuilder", package: "swift-json-schema"),
                .product(name: "OpenAI", package: "openai")
            ]
        ),
        .target(
            name: "Open5eAPI",
            dependencies: [
                "Helpers",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
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
        .testTarget(
            name: "PersistenceTests",
            dependencies: [
                "Persistence",
                "GameModels",
                "TestSupport",
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing")
            ]
        ),
        .target(
            name: "TestSupport",
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
    ],
    swiftLanguageModes: [.v5]
)
