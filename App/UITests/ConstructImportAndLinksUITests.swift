import XCTest

final class ConstructImportAndLinksUITests: ConstructUITestCase {

    func testImportSheetSmokeFlow() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let compendium = adventure.openCompendium()
        _ = compendium
            .openImport()
            .cancel()
    }

    func testExternalHelpCenterLinkSmokeFlow() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let settings = adventure.openSettings()
        _ = settings
            .openExternalLink(named: "Help center")
            .done()
            .doneToAdventure()
    }
}
