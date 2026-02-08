import XCTest

final class ConstructCompendiumManagementUITests: ConstructUITestCase {

    func testCompendiumManagementSmokeFlow() {
        let suffix = "\(Int(Date().timeIntervalSince1970))"
        let copiedName = "Acolyte Smoke \(suffix)"

        let adventure = launchIntoAdventureBySkippingOnboarding()
        let compendium = adventure.openCompendium()

        compendium
            .tapTypeFilter("Monsters")
            .search("acolyte")

        let detailAfterCopy = compendium
            .openEntry(containing: "Acolyte")
            .openMenuAction("Edit a copy")
            .setName(copiedName)
            .tapAddToCompendiumDetail()

        _ = detailAfterCopy
            .openTransferMenuAction("Move...")
            .selectDestinationDocument(named: "SRD 5.1")
            .confirmTransfer(action: "Move")

        let documents = compendium.openManageDocuments()
        let documentItems = documents
            .openDocument(named: "SRD 5.1")
            .openItems()

        documentItems.assertEntryVisible(containing: copiedName)
    }
}
