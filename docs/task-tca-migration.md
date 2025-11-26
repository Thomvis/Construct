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
- Converted EncounterDetail (including subviews: AddCombatant flow, CombatantDetail, running action bar, resource tracker, generate traits) to `@ObservableState`/`@Presents` + bindable stores; removed `WithViewStore`/`IfLetStore` usage there.
- CampaignBrowse migrated to observation/key-path scoping; Compendium import preferences, Combatant tags view, and MechMuse creature generation preview now compile with key-path-based sheets/navigation.
- Compendium documents/entry detail and parts of Compendium index are on key-path scoping; warning cleanup remains for remaining slash scopes/legacy navigation helpers.
- Migrated ReferenceItemView to observation: replaced `WithViewStore`/`IfLetStore` with `if let store.scope()` pattern.
- Migrated NumberPadFeature, NumberEntryFeature and views to `@Reducer` + `@ObservableState` + `@Bindable` stores.
- Migrated CampaignBrowseViewFeature's NodeEditView to observation; added `@Reducer` macro, `@ObservableState` to NodeEditState.
- Migrated CompendiumItemTransferFeature to `@Reducer` + `@ObservableState`; replaced binding state mutations from effects with explicit actions.
- Migrated CompendiumDocumentSelectionFeature to `@Reducer` + `@ObservableState`; removed `WithViewStore` wrappers.
- Migrated CompendiumDocumentsFeature to `@Reducer` + `@ObservableState`; replaced all `WithViewStore` in views.
- Migrated CompendiumIndexView to observation: removed all LocalState structs; replaced `WithViewStore` in main view, searchable modifier, item list, entry row, and filter button; added computed properties to State for view state.

## Status

All deprecated TCA APIs have been removed:
- ✅ No `WithViewStore` usages remain
- ✅ No `IfLetStore` usages remain
- ✅ No `ForEachStore` usages remain
- ✅ No `@PresentationState` usages remain (replaced with `@Presents`)
- ✅ Build succeeds with no deprecation warnings

Some reducers still use the old `struct X: Reducer` pattern without `@Reducer` macro, but these compile fine and can be migrated opportunistically.
