import XCTest

final class ConstructCompendiumManagementUITests: ConstructUITestCase {

    func testCompendiumManagementFlow() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let compendium = adventure.openCompendium()

        let documents = compendium.openManageDocuments()
        let documentItems = documents
            .openFirstDocument()
            .openItems()

        documentItems.assertEntryVisible(containing: "Acolyte")
        _ = documentItems.goBack()

        _ = CompendiumDocumentsPage(app: compendium.app).doneToCompendium()
    }
}
