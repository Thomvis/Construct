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
        runningAfterCombatantOps.assertTagVisible("Hidden")
        runningAfterCombatantOps.assertResourceVisible(containing: "Spell Slots")

        let attackResolution = runningAfterCombatantOps
            .openAttackResolution(containing: "Weapon Attack")
        attackResolution.assertAttackResolutionVisible()

        let runningAfterDetail = attackResolution
            .dismissAttackResolution()
            .doneToRunningEncounter()
            .nextTurn()
        runningAfterDetail.assertRoundVisible(2)

        let log = runningAfterDetail.openLog()
        log.assertStartOfEncounterVisible()
        log.assertLogContains("Acolyte")
        let runningAfterLog = log.done()

        let stoppedScratchPad = runningAfterLog.stopRun()
        stoppedScratchPad.assertRunEncounterVisible()

        _ = stoppedScratchPad.resumeRunningEncounterFromMenu()
            .waitForVisible()
    }
}
