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

        runningAfterDetail.assertCombatantCount(containing: "Acolyte", equals: 1)
        runningAfterDetail.assertCombatantContextAction(containing: "Acolyte", action: "Eliminate", isVisible: true)
        _ = runningAfterDetail.performCombatantContextAction(containing: "Acolyte", action: "Eliminate")
        runningAfterDetail.assertCombatantContextAction(containing: "Acolyte", action: "Eliminate", isVisible: false)
        _ = runningAfterDetail.performCombatantContextAction(containing: "Acolyte", action: "Reset")
        runningAfterDetail.assertCombatantContextAction(containing: "Acolyte", action: "Eliminate", isVisible: true)
        _ = runningAfterDetail.performCombatantContextAction(containing: "Acolyte", action: "Duplicate")
        runningAfterDetail.assertCombatantCount(containing: "Acolyte", equals: 2)
        _ = runningAfterDetail.performCombatantContextAction(containing: "Acolyte", action: "Remove")
        runningAfterDetail.assertCombatantCount(containing: "Acolyte", equals: 1)

        let runningAfterTurnAdvance = runningAfterDetail
            .rollInitiativeIfNeeded()
            .startIfNeeded()
            .nextTurn()
        runningAfterTurnAdvance.assertRoundVisible(2)

        let log = runningAfterTurnAdvance.openLog()
        log.assertStartOfEncounterVisible()
        log.assertLogContains("Acolyte")
        let runningAfterLog = log.done()

        let stoppedScratchPad = runningAfterLog.stopRun()
        stoppedScratchPad.assertRunEncounterVisible()

        _ = stoppedScratchPad.resumeRunningEncounterFromMenu()
            .waitForVisible()
    }
}
