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
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/combine-schedulers", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.4"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.7.2"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-url-routing", from: "0.6.2"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.8.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.14.1"),
        .package(url: "https://github.com/pointfreeco/swift-clocks.git", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.14.0"),
        .package(url: "https://github.com/pointfreeco/swift-sharing.git", from: "2.0.0"),
        .package(url: "https://github.com/ajevans99/swift-json-schema", from: "0.10.0"),
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.4.7")
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
                "Helpers",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CasePathsCore", package: "swift-case-paths")
            ]
        ),
        .testTarget(
            name: "GameModelsTests",
            dependencies: [
                "GameModels",
                "TestSupport",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "CasePathsCore", package: "swift-case-paths")
            ]
        ),
        .target(
            name: "Helpers",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "CombineSchedulers", package: "combine-schedulers"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "Tagged", package: "swift-tagged"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "HelpersTests",
            dependencies: [
                "Helpers",
                "TestSupport",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "CasePathsCore", package: "swift-case-paths")
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
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Sharing", package: "swift-sharing")
            ]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: [
                "Persistence",
                "GameModels",
                "TestSupport",
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "CasePathsCore", package: "swift-case-paths"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "TestSupport",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
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
