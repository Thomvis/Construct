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
- [ ] Wire new files into Xcode project target
- [ ] Run full UI test target
- [ ] Commit in sensible chunks
- [ ] Fix known bugs noted by tests and update tests

## Notes
- Keep first-launch suite focused on onboarding/sample encounter behavior only.
- Keep onboarding skip/wait logic centralized in shared helpers.
