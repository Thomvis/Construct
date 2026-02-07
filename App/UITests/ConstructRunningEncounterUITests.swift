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

        let runningAfterCombatantOps = runningEncounter
            .openCombatantDetail(containing: "Acolyte")
            .applyDamage(2)
            .addTag(named: "Hidden")
            .addLimitedResource(named: "Spell Slots", uses: 2)
            .openAttackResolution(containing: "Weapon Attack")
        runningAfterCombatantOps.assertAttackResolutionVisible()

        let runningAfterDetail = runningAfterCombatantOps
            .dismissAttackResolution()
            .doneToRunningEncounter()
            .nextTurn()

        let log = runningAfterDetail.openLog()
        log.assertStartOfEncounterVisible()
        let runningAfterLog = log.done()

        let stoppedScratchPad = runningAfterLog.stopRun()
        stoppedScratchPad.assertRunEncounterVisible()

        _ = stoppedScratchPad.resumeRunningEncounterFromMenu()
            .waitForVisible()
    }
}
