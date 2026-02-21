<img src="https://github.com/Thomvis/Construct/raw/main/assets/logo.png" height="25" /> Construct: D&D companion app in SwiftUI
===

![](https://github.com/Thomvis/Construct/workflows/Construct%20CI/badge.svg?branch=main) [![](https://img.shields.io/badge/TestFlight-join-blue.svg)](https://testflight.apple.com/join/tvK1gYv9)

| <img src="https://github.com/Thomvis/Construct/raw/main/assets/screenshot1.png" width="200" /> | <img src="https://github.com/Thomvis/Construct/raw/main/assets/screenshot2.png" width="200" /> | <img src="https://github.com/Thomvis/Construct/raw/main/assets/screenshot3.png" width="200" /> |  <img src="https://github.com/Thomvis/Construct/raw/main/assets/screenshot4.png" width="200" /> |
|---|---|---|---|

## Project Goals
This project aims to be...
- 🐉 an easy to use companion app for Dungeon Masters running [5th edition D&D](https://en.wikipedia.org/wiki/Dungeons_%26_Dragons)
- 🎓 a resource for developers learning [SwiftUI](https://developer.apple.com/xcode/swiftui/) and [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)

### For Dungeon Masters
The easiest way to use the app is by downloading it from the App Store.

<a href="https://apps.apple.com/app/construct-for-d-d-5e/id1490015210"><img src="https://signal.org/external/images/app-store-download-badge.svg" /></a>

You can find an overview of Construct's features at [construct5e.app](https://www.construct5e.app).

### For developers
Download the project, open `Construct.xcodeproj` and run `Construct`.

#### Architecture overview
Construct is built using SwiftUI and a reducer-based architecture implemented using [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) framework. The entire app's state is represented by the [AppState struct](https://github.com/Thomvis/Construct/blob/main/App/App/App/AppState.swift), a deeply nested data structure containing the top-level screens and any screen, sheet or popover opened from there. The app uses state-driven navigation patterns to keep navigation in sync with app state.

All data in the app is stored locally in an sqlite database using [GRDB](http://groue.github.io/GRDB.swift/). Construct defines a simple [key-value store](https://github.com/Thomvis/Construct/blob/main/Sources/Persistence/KeyValueStore.swift) on top of GRDB. All entities are serialized using Swift's Codable, can optionally support full-text search and are [automatically](https://github.com/Thomvis/Construct/blob/main/App/App/App/EntityChangeObserver.swift) saved in the database when they change in the app state.

The D&D domain calls for some interesting parsing solution. Construct contains a small [parser combinator framework](https://github.com/Thomvis/Construct/blob/main/Sources/Helpers/ParserCombinator.swift) and defines a couple of [interesting](https://github.com/Thomvis/Construct/blob/main/Sources/GameModels/CreatureActionParser.swift) [parsers](https://github.com/Thomvis/Construct/blob/main/Sources/Dice/DiceExpressionParser.swift).

I hope to write posts detailing some of the interesting parts of the app in the future.
