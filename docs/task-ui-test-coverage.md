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
4. Advance turn order.
5. Open running log and verify `Start of encounter`.
6. Stop run and verify return to Scratch pad.
7. Resume a previous run from `Run encounter` menu.

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

## Observations from code + axe exploration
- Key surfaces currently visible and automatable with accessibility:
1. Adventure/Scratch pad actions: `Reset…`, `Add combatants`, `Run encounter`.
2. Compendium surfaces: filter buttons (`Monsters`, `Characters`, `Spells`, `Adventuring Parties`), item rows, bottom toolbar popups.
3. Settings surfaces: `Mechanical Muse`, `OpenAI integration status`, `Send diagnostic reports`, legal/help entries.
4. Dice surfaces: `1d20`, `1d100`, `+1`, `+5`, `Roll`, `Clear`.

## Remaining Flows To Implement (Prioritized)

### P0 - Must cover next
1. **Running encounter lifecycle**
- Covered in `ConstructRunningEncounterUITests`: run start, spellcaster seed, initiative, turn progression, log open, stop, resume.
- Still to add:
- Deal damage to a monster
- Track spell slots for the monster
- Give a creature a hidden tag
- Roll for an attack for a creature

2. **Combatant operations during encounter**
- Running-mode follow-up:
- Add coverage for combatant operations while a run is active (running rows currently expose HP/initiative controls but no stable direct detail-open target in UI tests).
- Add context actions coverage: `Eliminate`, `Reset`, `Duplicate`, `Remove`.

3. **Compendium basics (read/search/filter/add/edit)**
- Switch to Compendium tab.
- Search for an item by name.
- Apply/remove filters (type + source where available).
- Open detail view of a monster/character/spell.
- Create at least one new homebrew item and edit it.

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

2. **Dice roller**
- Roll from preset buttons.
- Build expression and roll.
- Verify log entries append and `Clear` empties log.

### P2 - Useful but optional/late
1. **Scratch pad reset variants**
- `Reset… -> Clear monsters`.
- `Reset… -> Clear all`.
- Verify expected remaining combatants/party behavior.

2. **Settings behavior beyond tip jar**
- Toggle `Send diagnostic reports` and verify persistence across relaunch.
- Toggle `Mechanical Muse` and verify integration status state transitions for invalid key/empty key.

3. **Compendium import**
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
