import XCTest

final class ConstructEncounterBuildingUITests: ConstructUITestCase {

    func testEncounterBuildingFlow() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let scratchPad = adventure.openScratchPad()

        scratchPad.assertEmptyEncounterVisible()

        let addCombatants = scratchPad.openAddCombatants()

        addCombatants
            .search("goblin")
            .quickAddCombatant(named: "Goblin", times: 2)

        addCombatants
            .clearSearch()
            .search("wolf")
            .openCombatantDetail(named: "Wolf")
            .setQuantity(3)

        AddCombatantDetailPage(app: addCombatants.app).enableRollForHP()
        _ = AddCombatantDetailPage(app: addCombatants.app).tapAdd(quantity: 3)

        let backButton = addCombatants.app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 10))
        backButton.tap()

        let goblinSniperEdit = addCombatants.tapQuickCreate()
        let addCombatantsAfterGoblinQuickCreate = goblinSniperEdit
            .setName("Goblin sniper")
            .tapAdd()

        let sarovinEdit = addCombatantsAfterGoblinQuickCreate
            .waitForVisible()
            .tapQuickCreate()
            .chooseCreatureType("character")
            .setName("Sarovin")
            .setLevel(2)
            .setControlledByPlayer(true)

        let addCombatantsAfterSarovinQuickCreate = sarovinEdit.tapAdd()
        _ = addCombatantsAfterSarovinQuickCreate.waitForVisible()
        _ = addCombatantsAfterSarovinQuickCreate.done()

        _ = scratchPad.waitForVisible()
        scratchPad.assertCombatantVisible("Sarovin")

        scratchPad.assertDifficultyLabel("Hard for 3 level 2 characters")

        let encounterSettings = scratchPad.openActionsSettings()
        encounterSettings.chooseSelectCombatantsParty()
        encounterSettings.assertCombatantVisible("Sarovin")
        _ = encounterSettings.done()

        scratchPad.duplicateCombatant(named: "Goblin 1")
        scratchPad.assertDifficultyLabel("Deadly for Sarovin")
    }
}
