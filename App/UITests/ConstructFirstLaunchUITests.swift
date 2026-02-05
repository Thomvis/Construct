import XCTest

final class ConstructFirstLaunchUITests: ConstructUITestCase {

    func testFirstLaunchSampleEncounterLoadsIntoScratchPad() {
        let app = launchApp()
        _ = OnboardingPage(app: app)
            .waitForVisible()
            .tapOpenSampleEncounter()
        XCTAssertTrue(app.staticTexts["Ennan Yarfall"].waitForExistence(timeout: 30), "Expected sample encounter combatant to appear")
    }

    func testFirstLaunchContinueShowsEmptyScratchPad() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let scratchPad = adventure.openScratchPad()

        scratchPad.assertEmptyEncounterVisible()
    }
}
