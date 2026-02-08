import XCTest

final class ConstructScratchPadAndSettingsUITests: ConstructUITestCase {

    func testScratchPadResetVariantsAndDiagnosticToggle() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let scratchPad = adventure.openScratchPad()

        let addCombatants = scratchPad.openAddCombatants()
        addCombatants
            .search("goblin")
            .quickAddCombatant(named: "Goblin", times: 2)
        _ = addCombatants.done()

        scratchPad
            .resetEncounter(option: "Clear monsters")
            .assertEmptyEncounterVisible()

        let addCombatantsAgain = scratchPad.openAddCombatants()
        addCombatantsAgain
            .search("goblin")
            .quickAddCombatant(named: "Goblin", times: 1)
        _ = addCombatantsAgain.done()

        scratchPad
            .resetEncounter(option: "Clear all")
            .assertEmptyEncounterVisible()

        let settings = scratchPad
            .goBackToAdventure()
            .openSettings()

        _ = settings
            .setDiagnosticReports(enabled: true)
            .assertDiagnosticReports(enabled: true)
            .setDiagnosticReports(enabled: false)
            .assertDiagnosticReports(enabled: false)
            .doneToAdventure()
    }
}
