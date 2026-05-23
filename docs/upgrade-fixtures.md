# Upgrade Fixtures

Upgrade fixtures are historical app databases that should be opened by the
current app and test suite. They are intended to catch real compatibility issues
that unit-only migration tests can miss.

## App Store 3.0.2 Rich Fixture

- Fixture: `Sources/TestSupport/Resources/appstore-3.0.2-rich.sqlite`
- Generator: `scripts/generate-appstore-3.0.2-fixture.sh`
- Old-version tool source: `scripts/fixtures/appstore-3.0.2-db-tool-main.swift`

The fixture is generated from the `3.0.2` git tag and contains a mix of default
content, homebrew compendium data, a campaign browser hierarchy, an encounter,
a running encounter, log entries, preferences, and import metadata.

## Regenerating

Run:

```sh
scripts/generate-appstore-3.0.2-fixture.sh
```

The script creates a temporary worktree at tag `3.0.2`, patches only the
temporary generator target needed to run on the current toolchain, and replaces
`Sources/TestSupport/Resources/appstore-3.0.2-rich.sqlite`.

Regenerate when the fixture definition itself needs to cover a new historical
state. Do not regenerate merely because current migrations changed; the point is
for the database to remain an old app-store-era input.

## Validation

Run the persistence upgrade test:

```sh
xcodebuild test -project App/Construct.xcodeproj -scheme UnitTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:PersistenceTests/DatabaseUpgradeFixtureTest -skipPackagePluginValidation -skipMacroValidation
```

Run the UI upgrade smoke test:

```sh
xcodebuild test -project App/Construct.xcodeproj -scheme Construct -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:ConstructUITests/ConstructUpgradeExperienceUITests/testAppStore302DataUpgradesAndLaunches -skipPackagePluginValidation -skipMacroValidation
```

CI runs the full `ConstructUITests` target, so this upgrade smoke test is covered
there as long as the target remains included.
