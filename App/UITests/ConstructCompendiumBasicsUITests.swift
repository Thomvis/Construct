import XCTest

final class ConstructCompendiumBasicsUITests: ConstructUITestCase {

    func testCompendiumBasicsFlow() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let compendium = adventure.openCompendium()

        compendium
            .tapTypeFilter("Monsters")
            .search("acolyte")

        let acolyteDetail = compendium.openEntry(containing: "Acolyte")

        let createdName = "Acolyte UI Test Monster"

        let detailAfterCreate = acolyteDetail
            .openMenuAction("Edit a copy")
            .setName(createdName)
            .tapAddToCompendiumDetail()

        let detailAfterEdit = detailAfterCreate
            .openMenuAction("Edit")
            .tapDone()

        _ = detailAfterEdit.goBackToCompendium()
        _ = compendium.openEntry(containing: createdName)
    }
}
