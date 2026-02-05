# UI Tests Refactor

## Goal
Refactor UI tests into focused files with shared helpers/page objects, then run full UI suite and stabilize known flow bugs.

## Progress
- [x] Split tests into focused files:
  - `ConstructFirstLaunchUITests.swift`
  - `ConstructTipJarUITests.swift`
  - `ConstructCampaignBrowseUITests.swift`
  - `ConstructEncounterBuildingUITests.swift`
- [x] Added shared support and page objects in `ConstructUITestSupport.swift`
- [x] Wire new files into Xcode project target
- [x] Run full UI test target
- [x] Commit in sensible chunks
- [x] Fix known bugs noted by tests and update tests
- [x] Improve `Controlled by player` toggle automation by using container-scoped scrolling and a dedicated accessibility identifier

## Notes
- Keep first-launch suite focused on onboarding/sample encounter behavior only.
- Keep onboarding skip/wait logic centralized in shared helpers.
- Quick-create behavior is now mode-aware:
  - quick-create inside add-combatants keeps the sheet open after add
  - quick-create from the encounter action bar dismisses to scratch pad after add
