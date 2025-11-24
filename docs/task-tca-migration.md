# TCA migration

- Goal: finish migrating from TCA 0.58 → 1.23 using the official migration guides; chip away module by module while keeping builds green.

## Guide highlights

- 1.4: annotate reducers with `@Reducer` (adds `@CasePathable`); prefer case key paths over `/Action.case`; introduce `IdentifiedAction` and `store.receive(\.path…)` syntax; `TaskResult` slated for removal.
- 1.5: use key-path scoping `store.scope(state: \.child, action: \.child)`; navigation modifiers take a single scoped `store:` argument.
- 1.6: `TestStore.receive` supports payload assertions via case key paths.
- 1.7: mark state with `@ObservableState`; replace `WithViewStore`/`IfLetStore`/`ForEachStore`/navigation helpers with observation + SwiftUI tools; use `@Presents` instead of `@PresentationState`; favor `Store.scope` + `if let`/`ForEach`.
- 1.8: `@Reducer` can synthesize reducer requirements; enum reducers simplify destinations/paths.
- 1.9: `TestStore.send(\.casePath, payload)` plus `Reducer.dependency(_:)`.
- 1.10: `@Shared`/state sharing and persistence.
- 1.11: mutate shared state from async contexts via `$shared.withLock` (now `@MainActor`).
- 1.14: `Store` is `@MainActor`; mark helper properties if needed.
- 1.18: root store deinit cancels in-flight effects; fire-and-forget work should hop to `Task`.

## Progress

- Reviewed migration guides (1.4–1.19) and outlined required updates.
- Migrated DiceRollerFeature (and AppClip host) to `@Reducer`, `@ObservableState`, case key-path scoping, and observation-based views; updated ResultDetailView API to decouple state from store.
- Ran `xcodebuild build -project App/Construct.xcodeproj -scheme Construct -destination "platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2"` (passes with many legacy deprecation warnings elsewhere).
- Updated ActionResolutionFeature to `@Reducer` + observable state, replaced bindings with explicit actions, and converted ActionResolutionView to observation without `WithViewStore`.
- Removed `WithPerceptionTracking` from dice views; views now rely on `@Bindable` stores.
- Converted column/tab navigation and floating dice roller to `@Reducer` + observation; modernized Construct app root to key-path scoping, `@Presents` alerts, and observation-based navigation; build succeeds after changes.
- Modernized ReferenceView feature to `@Reducer` with `IdentifiedAction` scoping; reworked ColumnNavigationFeature reducer for the new builder; App Clip now uses bindable store/tasks instead of `WithViewStore` and binding reducer.
- Converted EncounterDetail, Compendium documents, Compendium entry detail, and parts of Compendium index/Campaign browse to key-path scoping with `@CasePathable` sheets/destinations; ongoing warning cleanup remains, especially for Compendium index sheets/destinations, Combatant detail, and ReferenceItem.

## Next steps

- Continue migrating remaining features (ActionResolution, Compendium, Encounter, etc.) off `/CasePath` and closure-based scoping to case key paths.
- Replace `WithViewStore`/`IfLetStore`/`ForEachStore` and navigation helpers across the app with observation-based patterns and SwiftUI navigation + `@Presents`.
- Tackle binding/presentation patterns (`@Presents`, `alert`/`sheet` modifiers) and reduce warning surface; revisit AppClip once broader patterns settle.
- Pick up pending warning cleanup:
  - `CompendiumIndexView`: sheets and navigation already using single-`store` sheet modifier; ensure reducer enums stay `@CasePathable` and finish any lingering slash scopes in `CompendiumIndexFeature`/`CompendiumEntryDetailViewState`.
  - `CampaignBrowseView`: convert navigationDestination and sheets to key-path scoping (or slash as stopgap) aligned with the `@CasePathable` Destination/Sheet enums.
  - `CombatantDetailViewState`, `CompendiumEntryDetailViewState`: replace slash `Scope`/`ifLet` with case key paths.
  - ReferenceItem deferred: move to case key-path scoping once other warnings are cleared.
