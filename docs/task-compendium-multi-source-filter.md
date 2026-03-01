# Task: Compendium Multi-Source/Realm Filter

## Goal
Support selecting multiple compendium sources in filters with OR semantics, including selecting whole realms.

## Plan
- [x] Replace `CompendiumFilters.source` with scope-based source filtering.
- [x] Add `SecondaryIndexCondition.oneOf([String])` and query handling.
- [x] Translate source filter to list condition in `DatabaseCompendium`.
- [x] Add `CompendiumFilters.SourceScope` (`realm` + `document`) and persist it through filter flow.
- [x] Expand realm scopes to concrete document ids at persistence boundary (`DatabaseCompendium`) only.
- [x] Keep `CompendiumDocumentSelectionFeature` single-select only.
- [x] Add dedicated realm/document multi-select UI in `CompendiumFilterSheet`.
- [x] Wire filter sheet and index feature to multi-source values.
- [x] Update source-related call sites and tests.
- [x] Add new reducer tests for filter/index behavior.
- [x] Add realm-scope persistence tests (realm-only and realm+document).
- [x] Run targeted tests.

## Notes
- Empty selected scope list means no source restriction.
- Source scope expansion is performed when building `KeyValueStoreRequest`, not in UI state.
- Filter-sheet selection state stores selected realms/documents in sets; display and serialization order is derived from realm/document metadata ordering.
- Single selected document keeps existing add-flow behavior.
- Targeted validation run:
  - `UnitTests/CompendiumMultiSourceFilterReducerTest`
  - `PersistenceTests/KeyValueStoreTest`
  - `PersistenceTests/DatabaseCompendiumTest`
