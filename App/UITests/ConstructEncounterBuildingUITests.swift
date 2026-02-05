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
        _ = goblinSniperEdit
            .setName("Goblin sniper")
            .tapAdd()

        // Known bug: Quick create dismisses add combatants.
        XCTAssertTrue(addCombatants.app.buttons["Add combatants"].waitForExistence(timeout: 10))

        scratchPad.openAddCombatantsContextMenu()
        addCombatants.app.buttons["Quick create"].tap()

        let sarovinEdit = CreatureEditPage(app: addCombatants.app)
            .waitForVisible()
            .chooseCreatureType("character")
            .setName("Sarovin")
            .setLevel(2)
            .setControlledByPlayer(true)

        _ = sarovinEdit.tapAdd()

        // Known bug: Quick create for character does not add and does not dismiss.
        let doneButton = addCombatants.app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()

        _ = scratchPad.openAddCombatants()
        addCombatants.filterCharactersIfPresent()
        addCombatants.addFromList(named: "Sarovin")
        _ = addCombatants.done()

        scratchPad.assertDifficultyLabel("Hard for 3 level 2 characters")

        let encounterSettings = scratchPad.openActionsSettings()
        encounterSettings.chooseSelectCombatantsParty()
        encounterSettings.assertCombatantVisible("Sarovin")
        _ = encounterSettings.done()

        scratchPad.duplicateCombatant(named: "Goblin 1")
        scratchPad.assertDifficultyLabel("Deadly for Sarovin")
    }
}
