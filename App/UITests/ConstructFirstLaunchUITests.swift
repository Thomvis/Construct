import XCTest

final class ConstructFirstLaunchUITests: ConstructUITestCase {

    func testFirstLaunchShowsDefaultContentCards() {
        let app = launchApp()
        _ = OnboardingPage(app: app).waitForVisible()

        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 10))
        nextButton.tap()

        XCTAssertTrue(app.buttons["default-content-card-2014"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["default-content-card-2024"].waitForExistence(timeout: 10))
    }

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
