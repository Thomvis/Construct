# Agent Guide

## Purpose
Agents act as senior Swift collaborators. Keep responses concise,
clarify uncertainty before coding, and align suggestions with the rules linked below.

## Repository Overview
- This project is a D&D companion app built with Swift and SwiftUI.
- The app is built using the Composable Architecture.
- The app is available in the App Store and is Open Source on GitHub.
- The project is moving towards a more modular architecture, using Swift Packages for new features.
- Core domain/parsing/data modules live in `Sources/` (e.g. `GameModels`, `Compendium`, `Persistence`, `Helpers`).
- The iOS app target and UI integration live under `App/App/`.
- Parsing of imported compendium content uses versioned `Parseable` wrappers so parser/model updates can trigger recomputation.

## Commands
- Prefer targeted test runs while iterating (example: `-only-testing:UnitTests/CreatureActionParserTest`).
- Use simulator IDs from `xcodebuildmcp simulator list-sims --enabled` to avoid device-name/OS mismatches.
- Use `rg` for codebase search and file discovery (`rg`, `rg --files`) before making changes.
- `xcodebuild build -project App/Construct.xcodeproj -scheme Construct -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2' | xcpretty`
  To validate changes. Pick another listed simulator if that one isn’t available.
- When running xcodebuild in this repo, include `-skipPackagePluginValidation -skipMacroValidation` to avoid Swift macro/plugin validation failures.
- `xcodebuildmcp` CLI is available and useful for simulator/test workflows. Prefer absolute project paths:
  - `xcodebuildmcp project-discovery list-schemes --project-path /Users/thomasvisser/Projects/Playgrounds/SwiftUI/Construct/App/Construct.xcodeproj`
  - `xcodebuildmcp simulator list-sims --enabled`
  - `xcodebuildmcp simulator test-sim --project-path /Users/thomasvisser/Projects/Playgrounds/SwiftUI/Construct/App/Construct.xcodeproj --scheme Construct --simulator-id EA0E0CB6-E385-4152-8D4D-1A424B1D33A6 --extra-args=-skipPackagePluginValidation --extra-args=-skipMacroValidation`
- `xcodebuildmcp` CLI parsing gotcha: for any `extra-args` value that starts with `-`, pass it as `--extra-args=<value>` (with `=`), otherwise it is parsed as flags and fails.
- If you need to debug what `xcodebuildmcp` is invoking, run with `--log-level debug` to see the exact underlying `/usr/bin/xcrun xcodebuild ...` command.

## Code Style
- Follow existing Swift naming and formatting conventions in surrounding files.
- Prefer small, composable parsing functions and keep parser/model changes additive when possible.
- Keep test expectations explicit with `expectNoDifference` and snapshots for parser behavior changes.
- Follow existing code style.

## Architecture & Patterns
- Feature/state logic is primarily TCA-based with reducer-driven composition.
- `Parseable<Input, Result>` + `DomainParser`/`DomainModel` versioning is used to cache and invalidate derived parsed data.
- For new behavior in parsed models, prefer additive fields over breaking schema changes.
- The project is built using the Composable Architecture.

## Workflow
- Ask for clarification when requirements are ambiguous; surface 2–3 options when trade-offs matter
- Update documentation and related rules when introducing new patterns or services
- Run tests to validate your changes before committing.
- If the compiler fails with "the compiler is unable to type-check this expression in reasonable time" (this happens frequently in view bodies and reducers):
  - this usually happens because types in the expression are not lining up.
  - to discover the actual error, temporarily comment out or break out part of the offending expression "binary search-style" until the compiler can type-check.

## Testing
- Run the tests with this command: `xcodebuild test -project App/Construct.xcodeproj -scheme Construct -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2' -skipPackagePluginValidation -skipMacroValidation | xcpretty`
- Equivalent `xcodebuildmcp` test command:
  - `xcodebuildmcp simulator test-sim --project-path /Users/thomasvisser/Projects/Playgrounds/SwiftUI/Construct/App/Construct.xcodeproj --scheme Construct --simulator-id EA0E0CB6-E385-4152-8D4D-1A424B1D33A6 --extra-args=-skipPackagePluginValidation --extra-args=-skipMacroValidation`
- When to prefer `xcodebuildmcp` over raw `xcodebuild`:
  - You want structured test summaries and easy simulator targeting by `simulator-id`.
  - You want one toolchain for build/test plus simulator inspection/automation (`snapshot-ui`, `screenshot`, `tap`, `swipe`).
  - You want the exact underlying command logged (`--log-level debug`) for reproducibility.

## Environment
- Use Xcode tooling (`xcodebuild`/`xcodebuildmcp`) for build and test; this repository is not `swift build` first.
- Dependencies are managed through SwiftPM and integrated into the Xcode project/workspace.
- If default simulator destinations are unavailable locally, pick an enabled simulator from the current machine.
- Requires SwiftUI, GRDB, and Point-Free Composable Architecture libraries
- Use xcodebuild to build the project (not swift build, since this is an iOS project).

## Special Notes
- Do not mutate files outside the workspace root without explicit approval
- Avoid destructive git operations unless the user requests them directly
- When unsure or need to make a significant decision ASK the user for guidance
- Commit only things you modified yourself, someone else might be modyfing other files.
- The project is actively being migrated to a newer version of the Composable Architecture.
- Changes should, if possible, contribute to moving code from App/App to Swift Packages in Sources/.
  (It's not a goal on its own.)
- A clean build takes a long time, so do not do this unless the user approves it.

## Large Tasks
- For large tasks, we keep a Markdown file with notes and progress. Task files follow this pattern: `docs/task-X.md`, where X is the task name. Load the appropriate file when continuing with a task (creating if needed) and make sure to update the file with the progress of the task as you work on it.
