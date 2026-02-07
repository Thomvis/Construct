import XCTest

final class ConstructCombatantOperationsUITests: ConstructUITestCase {

    func testOpenCombatantDetailAndApplyDamage() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let scratchPad = adventure.openScratchPad()

        let addCombatants = scratchPad.openAddCombatants()
        addCombatants
            .search("goblin")
            .quickAddCombatant(named: "Goblin", times: 1)
        let scratchPadWithGoblin = addCombatants.done()
        scratchPadWithGoblin.assertCombatantCount(containing: "Goblin", equals: 1)

        let detail = scratchPadWithGoblin
            .openCombatantDetail(containing: "Goblin")
            .applyDamage(2)

        let scratchPadAfterDamage = detail.doneToScratchPad()
        scratchPadAfterDamage.assertLabelContaining("HP: 5 of 7")
    }

    func testCombatantContextActionsInScratchPad() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let scratchPad = adventure.openScratchPad()

        let addCombatants = scratchPad.openAddCombatants()
        addCombatants
            .search("goblin")
            .quickAddCombatant(named: "Goblin", times: 1)
        let scratchPadWithGoblin = addCombatants.done()
        scratchPadWithGoblin.assertCombatantCount(containing: "Goblin", equals: 1)

        scratchPadWithGoblin.performCombatantContextAction(containing: "Goblin", action: "Duplicate")
        scratchPadWithGoblin.assertCombatantCount(containing: "Goblin", equals: 2)

        scratchPadWithGoblin.performCombatantContextAction(containing: "Goblin", action: "Eliminate")
        scratchPadWithGoblin.performCombatantContextAction(containing: "Goblin", action: "Reset")

        scratchPadWithGoblin.performCombatantContextAction(containing: "Goblin", action: "Remove")
        scratchPadWithGoblin.assertCombatantCount(containing: "Goblin", equals: 1)
    }
}
