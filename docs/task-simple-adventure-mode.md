# Task: Adventure Simple Mode

## Goal
Introduce a simple mode for the Adventure tab:
- Adventure tab opens directly into scratch pad encounter
- Encounter page title is `Encounter` in simple mode
- Top-left `Settings` button opens normal settings
- Settings can switch between simple mode and normal mode (`Campaign browser`)
- New users default to simple mode
- Existing users only default to simple mode if they have not created any top-level campaign items

## Progress
- Added persisted preference `Preferences.AdventureTabMode` (`simpleEncounter` / `campaignBrowser`)
- Added migration in `Database.prepareForUse`:
  - If preference is unset, inspect root campaign nodes
  - If any non-special top-level node exists: use `campaignBrowser`
  - Otherwise: use `simpleEncounter`
- Added `SimpleAdventureFeature` and `SimpleAdventureView`:
  - Hosts scratch pad encounter directly
  - Shows top-left `Settings` button
  - Presents `SettingsContainerView`
- Updated `TabNavigationFeature` to switch Adventure tab content based on preferences
- Added settings control for adventure mode selection
- Added `EncounterDetailFeature.State.navigationTitleOverride` and used it to show `Encounter` in simple mode only
- Updated `AppFeature.Navigation` open-encounter routing to respect tab mode
- Updated compact/regular navigation state conversion to preserve encounter context
- Updated UI test support helpers to work with both Adventure list mode and direct Encounter mode
- Added persistence tests for adventure mode default/migration behavior
- Added TipKit-based discoverability tip for normal mode in simple mode:
  - Tip is anchored to the top-left `Settings` button
  - Trigger condition uses persisted `RunningEncounter` instances for the scratch pad encounter (`>= 3`)
  - Condition is evaluated on app launch through `SimpleAdventureFeature.onAppear`

## Remaining
- Run targeted tests/build and fix any compile/runtime regressions

## Verification
- `xcodebuild build -project App/Construct.xcodeproj -scheme Persistence -destination 'platform=iOS Simulator,id=EA0E0CB6-E385-4152-8D4D-1A424B1D33A6' -skipPackagePluginValidation -skipMacroValidation` ✅
- `xcodebuild test -project App/Construct.xcodeproj -scheme UnitTests -destination 'platform=iOS Simulator,id=EA0E0CB6-E385-4152-8D4D-1A424B1D33A6' -only-testing:UnitTests/SettingsViewTest -skipPackagePluginValidation -skipMacroValidation` ❌ (environment/linking issue in `HelpersTests`, unrelated to this change)
- `xcodebuild build -project App/Construct.xcodeproj -scheme Construct -destination 'platform=iOS Simulator,id=EA0E0CB6-E385-4152-8D4D-1A424B1D33A6' -skipPackagePluginValidation -skipMacroValidation` ❌ (environment/linking issue in `DiceRollerAppClip`, unrelated to this change)
