# Default Content Selection (Lazy 2014/2024)

## Goal
Implement user-driven default SRD selection with lazy realm/document creation for 2014/2024, while keeping homebrew always available.

## Progress
- [x] Add `DefaultContentSelection` model and persistence wiring
- [x] Make database default import selection-aware and lazy
- [x] Split metadata bootstrap APIs (`homebrew` vs edition metadata)
- [x] Add reusable `DefaultContentSelectionFeature` + `DefaultContentSelectionView`
- [x] Integrate chooser into welcome flow (new users)
- [x] Integrate one-time upgrade prompt (existing users without selection)
- [x] Add settings entry + add-only behavior
- [x] Split welcome into two pages (benefits + content import)
- [x] Add sample encounter toggle to shared default-content chooser
- [x] Default sample toggle on for launch flows; off in settings
- [x] Make sample restore write to scratch pad when empty, else create unique top-level encounter
- [x] Refine launch default-content visual hierarchy and button emphasis
- [x] Add per-edition freshness labels ("Latest content loaded" / "Update available")
- [x] Update/apply tests (persistence, reducer/view, UI tests)

## Decisions
- `core/srd5_1` and `core2024/srd5_2` are created lazily only when selected/imported.
- `homebrew` realm/document are always bootstrapped at startup.
- New users start with no preselection.
- Existing users without persisted selection are prompted once and preselection is derived from loaded docs; fallback is 2014.
- At least one edition must be selected.
- Settings behavior is add-only (deselecting does not delete existing content).

## Notes
- Keep migration behavior intact.
- Avoid mutating unrelated files.
- New reusable files were added under `App/App/App/DefaultContentSelection/` to match the project’s existing Xcode group path layout.
- Follow-up refactor: app-level sheet presentation now uses `@Presents destination` with a dedicated `WelcomeFeature` reducer and separate alert state.
- Welcome content-import page is scrollable to avoid overflow on smaller devices.
- Welcome and launch-required sheets are not swipe-dismissible.

## Validation
- Latest focused unit tests passed:
  - `UnitTests/SettingsViewTest`
  - `UnitTests/AppDefaultContentSelectionTest`
  - `UnitTests/DefaultContentSelectionFeatureTest`
- Previously run persistence tests (earlier iteration):
  - `PersistenceTests/DatabaseTest`
  - `PersistenceTests/KeyValueStoreEntityTest`
- UI tests now pass in this environment:
  - `ConstructUITests` full target: 15 tests passed on iPhone 17 Pro (iOS 26.2)
  - Fixed stale helpers for add-combatants sheet dismissal, scratch pad reset menu actions, campaign browser mode selection, and optional compendium type chips.
