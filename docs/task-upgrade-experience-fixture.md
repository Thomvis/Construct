# Upgrade Experience Fixture

## Goal
- Create a reusable app data fixture from version 3.0.2, the App Store release.
- Use it to test the real upgrade path in the current app.
- Keep first-use UI tests intact while allowing upgrade UI tests to opt out of the forced welcome sheet.

## Progress
- Inspected persistence setup: durable app state is stored in `db.sqlite`.
- Confirmed tag `3.0.2` exists and has migrations through `v16`; current code adds `v17`.
- Found current UI tests launch with a per-session temp database.
- Documented the fixture workflow in `docs/upgrade-fixtures.md`.
- Added `scripts/generate-appstore-3.0.2-fixture.sh`, which checks out tag `3.0.2` in a temporary worktree and regenerates the fixture with the old app code.
- Stored the generated fixture at `Sources/TestSupport/Resources/appstore-3.0.2-rich.sqlite`.
- Added a persistence upgrade test that opens the old database with the current `Database`, verifies migrations/default content/homebrew/campaign data/running encounter data, and decodes every key-value record.
- Added a UI upgrade test that launches the app against the fixture, handles the rules-content update prompt, opens the migrated campaign encounter, and verifies upgraded content appears.
- Fixed legacy decoding for `CombatantResource`, which version 3.0.2 encoded with `title` while current code expects `_title`.

## Validation
- Passed: `xcodebuild test -project App/Construct.xcodeproj -scheme UnitTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:PersistenceTests/DatabaseUpgradeFixtureTest -skipPackagePluginValidation -skipMacroValidation`
- Passed: `xcodebuild test -project App/Construct.xcodeproj -scheme Construct -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:ConstructUITests/ConstructUpgradeExperienceUITests/testAppStore302DataUpgradesAndLaunches -skipPackagePluginValidation -skipMacroValidation`
