# UI Test Coverage Plan

## Goal
Verify core app behavior after the large refactor by growing UI test coverage around the highest-value user journeys.

## Current Coverage (Implemented)

### 1) First launch / onboarding
- File: `App/UITests/ConstructFirstLaunchUITests.swift`
- Covered scenarios:
1. First launch shows onboarding and tapping **Open sample encounter** opens Scratch pad with sample combatants.
2. First launch onboarding **Continue** path opens an empty app and shows empty Scratch pad state.

### 2) Tip jar
- File: `App/UITests/ConstructTipJarUITests.swift`
- Covered scenarios:
1. Navigate `Adventure -> Settings -> Tip jar`.
2. Execute a StoreKit purchase flow.
3. Verify post-purchase thank-you state.

### 3) Adventure management (campaign browse)
- File: `App/UITests/ConstructCampaignBrowseUITests.swift`
- Covered scenarios:
1. Create group and navigate into it.
2. Create encounter in group and encounter in root.
3. Move root encounter into group.
4. Create and rename a second group.
5. Move second group into first group.
6. Remove an encounter and remove the parent group.

### 4) Encounter building
- File: `App/UITests/ConstructEncounterBuildingUITests.swift`
- Covered scenarios:
1. Start from empty Scratch pad encounter.
2. Add goblins via quick add.
3. Add wolves via detail flow with quantity + roll HP.
4. Quick-create monster combatant (`Goblin sniper`).
5. Quick-create character (`Sarovin`) with level and player-controlled toggle.
6. Exit add-combatants and verify encounter state + challenge meter behavior.
7. Duplicate combatant and verify updated challenge text (`Deadly for Sarovin`).

### 5) Running encounter lifecycle (initial coverage)
- File: `App/UITests/ConstructRunningEncounterUITests.swift`
- Covered scenarios:
1. Add a spellcasting monster (`Acolyte`) from add-combatants.
2. Start run from Scratch pad.
3. Roll initiative and start turn progression.
4. Open combatant detail during running encounter.
5. Apply damage to running combatant.
6. Add `Hidden` tag in running detail.
7. Add limited resource (`Spell Slots`) in running detail.
8. Tap a weapon-attack action and verify action-resolution UI appears.
9. Verify side effects in running detail (`Hidden` tag and `Spell Slots` resource are visible).
10. Run combatant context actions while running: `Eliminate`, `Reset`, `Duplicate`, `Remove`.
11. Verify running-mode side effects for context actions (eliminate availability toggles, combatant count transitions `1 -> 2 -> 1`).
12. Advance turn order and verify round progression to `Round 2`.
13. Open running log and verify `Start of encounter` and entries containing `Acolyte`.
14. Stop run and verify return to Scratch pad.
15. Resume a previous run from `Run encounter` menu.

### 6) Combatant operations (context actions)
- File: `App/UITests/ConstructCombatantOperationsUITests.swift`
- Covered scenarios:
1. Add a goblin to Scratch pad from add-combatants.
2. Open combatant detail from Scratch pad row tap.
3. Apply damage from combatant detail and dismiss back to Scratch pad.
4. Add `Hidden` tag from combatant detail.
5. Add limited resource (`Spell Slots`, 2 uses) from combatant detail.
6. Verify detail shows `Hidden` and `Spell Slots`.
7. Dismiss detail and verify row updates (`HP: 5 of 7`, `Hidden`).
8. Long-press combatant and `Duplicate`.
9. Long-press combatant and `Eliminate`.
10. Long-press combatant and `Reset`.
11. Long-press combatant and `Remove`.
12. Verify combatant count transitions (`1 -> 2 -> 1`).

### 7) Compendium basics (read/search/filter/add/edit)
- File: `App/UITests/ConstructCompendiumBasicsUITests.swift`
- Covered scenarios:
1. Navigate from Adventure to Compendium.
2. Apply the `Monsters` type filter.
3. Search for `Acolyte` and open detail.
4. Create a copy via detail menu (`Edit a copy`) and give it a new name.
5. Open the created copy detail.
6. Open `Edit` for the created copy and save from the editor.
7. Navigate back to index and reopen the created copy entry.

### 8) Dice roller basics
- File: `App/UITests/ConstructDiceUITests.swift`
- Covered scenarios:
1. Navigate from Adventure to Dice tab.
2. Start from a clean visible state (`Clear log` if present, clear expression if present).
3. Roll a baseline expression from preset (`1d20`) and verify log visibility.
4. Enter expression edit mode and extend expression with modifier preset (`+5`).
5. Roll edited expression and verify log remains populated.
6. Known gap: deterministic verification that `Clear log` fully empties log is still flaky in UI tests and tracked as follow-up.

## Observations from code + axe exploration
- Key surfaces currently visible and automatable with accessibility:
1. Adventure/Scratch pad actions: `Reset…`, `Add combatants`, `Run encounter`.
2. Compendium surfaces: filter buttons (`Monsters`, `Characters`, `Spells`, `Adventuring Parties`), item rows, bottom toolbar popups.
3. Settings surfaces: `Mechanical Muse`, `OpenAI integration status`, `Send diagnostic reports`, legal/help entries.
4. Dice surfaces: `1d20`, `1d100`, `+1`, `+5`, `Roll`, `Clear`.

## Remaining Flows To Implement (Prioritized)

### P0 - Must cover next
1. **Running encounter lifecycle**
- Covered in `ConstructRunningEncounterUITests`: run start, spellcaster seed, initiative, running-detail edits (damage/tag/resource), attack roll opening, turn progression, log open, stop, resume.
- Still to add:
- Verify resulting state after action resolution (e.g. persisted log/event side-effects)

2. **Combatant operations during encounter**
- Running-mode follow-up:
- Covered in `ConstructRunningEncounterUITests`: context actions in active run (`Eliminate`, `Reset`, `Duplicate`, `Remove`) and state transitions.

### P1 - High value, after P0
1. **Compendium management actions**
- Selection mode in index.
- Move selected / copy selected / delete selected.
- Transfer sheet destination + conflict resolution.
- Open `Manage Documents`.
- Basic document CRUD and selection behavior.
- Add realm + document
- Move document from one realm to another
- Check an item in the document to see if it has updated

### P2 - Useful but optional/late
1. **Scratch pad reset variants**
- `Reset… -> Clear monsters`.
- `Reset… -> Clear all`.
- Verify expected remaining combatants/party behavior.

2. **Dice clear-log determinism**
- Add a stable assertion that `Clear log` empties the feed (currently flaky due hittability/visibility timing).

3. **Settings behavior beyond tip jar**
- Toggle `Send diagnostic reports` and verify persistence across relaunch.
- Toggle `Mechanical Muse` and verify integration status state transitions for invalid key/empty key.

4. **Compendium import**
- Import flow smoke test (prefer local fixture path if deterministic).

### P3 - Nice to have
1. **External link smoke tests**
- Help center / privacy / terms / OGL / acknowledgements navigation smoke checks.

## Proposed implementation order
1. Running encounter lifecycle.
2. Combatant operations in running/building mode.
3. Compendium basics (search/filter/detail/create-edit).
4. Dice roller.
5. Compendium transfer and documents management.
6. Scratch pad reset variants.
7. Settings persistence checks.
8. Compendium import.
9. External link smoke tests.

## Notes for stability
- Prefer explicit page objects per surface (`Adventure`, `ScratchPad`, `RunningEncounter`, `Compendium`, `Settings`, `Dice`).
- Avoid global `app.swipe*`; swipe within specific containers (`tables.firstMatch` / `scrollViews.firstMatch`) to reduce keyboard interference.
- Favor semantic waits on stable labels/state text instead of generic sleeps.
- For modal/menu actions, assert both visibility and dismissal conditions to avoid false positives.
