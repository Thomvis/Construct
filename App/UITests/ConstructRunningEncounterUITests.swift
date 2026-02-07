import XCTest

final class ConstructRunningEncounterUITests: ConstructUITestCase {

    func testRunningEncounterLifecycle() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let scratchPad = adventure.openScratchPad()

        let addCombatants = scratchPad.openAddCombatants()
        addCombatants
            .search("acolyte")
            .quickAddCombatant(named: "Acolyte", times: 1)
        let scratchPadWithAcolyte = addCombatants.done()
        scratchPadWithAcolyte.assertCombatantVisible("Acolyte")

        let runningEncounter = scratchPadWithAcolyte
            .tapRunEncounter()
            .rollInitiativeIfNeeded()
            .startIfNeeded()
            .nextTurn()

        let log = runningEncounter.openLog()
        log.assertStartOfEncounterVisible()
        let runningAfterLog = log.done()

        let stoppedScratchPad = runningAfterLog.stopRun()
        stoppedScratchPad.assertRunEncounterVisible()

        _ = stoppedScratchPad.resumeRunningEncounterFromMenu()
            .waitForVisible()
    }
}
