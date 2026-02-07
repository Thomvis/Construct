import XCTest

final class ConstructCombatantOperationsUITests: ConstructUITestCase {

    func testCombatantDetailAndContextActionsInScratchPad() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let scratchPad = adventure.openScratchPad()

        let addCombatants = scratchPad.openAddCombatants()
        addCombatants
            .search("goblin")
            .quickAddCombatant(named: "Goblin", times: 1)
        let scratchPadWithGoblin = addCombatants.done()
        scratchPadWithGoblin.assertCombatantCount(containing: "Goblin", equals: 1)

        let detailAfterEdits = scratchPadWithGoblin
            .openCombatantDetail(containing: "Goblin")
            .applyDamage(2)
            .addTag(named: "Hidden")
            .addLimitedResource(named: "Spell Slots", uses: 2)

        detailAfterEdits.assertTagVisible("Hidden")
        detailAfterEdits.assertResourceVisible(containing: "Spell Slots")

        let scratchPadAfterDetail = detailAfterEdits.doneToScratchPad()
        scratchPadAfterDetail.assertLabelContaining("HP: 5 of 7")
        scratchPadAfterDetail.assertLabelContaining("Hidden")

        scratchPadAfterDetail.performCombatantContextAction(containing: "Goblin", action: "Duplicate")
        scratchPadAfterDetail.assertCombatantCount(containing: "Goblin", equals: 2)

        scratchPadAfterDetail.performCombatantContextAction(containing: "Goblin", action: "Eliminate")
        scratchPadAfterDetail.performCombatantContextAction(containing: "Goblin", action: "Reset")

        scratchPadAfterDetail.performCombatantContextAction(containing: "Goblin", action: "Remove")
        scratchPadAfterDetail.assertCombatantCount(containing: "Goblin", equals: 1)
    }
}
