import XCTest

final class ConstructUpgradeExperienceUITests: ConstructUITestCase {
    func testAppStore302DataUpgradesAndLaunches() throws {
        let fixturePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TestSupport/Resources/appstore-3.0.2-rich.sqlite")
            .path
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixturePath), "Missing fixture at \(fixturePath)")

        let app = XCUIApplication()
        app.launchEnvironment["CONSTRUCT_UI_TESTS"] = "1"
        app.launchEnvironment["CONSTRUCT_UI_TESTS_FORCE_WELCOME"] = "0"
        app.launchEnvironment["CONSTRUCT_UI_TEST_DATABASE_FIXTURE"] = fixturePath
        app.launch()

        let adventure: AdventurePage
        if app.staticTexts["Welcome to Construct"].waitForExistence(timeout: 5) {
            adventure = OnboardingPage(app: app).tapContinue(timeout: 30, openSampleEncounter: false)
        } else {
            adventure = AdventurePage(app: app).waitForVisible(timeout: 180)
        }
        applyDefaultContentUpdateIfNeeded(in: app)

        if !migratedEncounterIsVisible(in: app, timeout: 5) {
            let campaignBrowserIsVisible = app.buttons["New group"].waitForExistence(timeout: 2)
            if !campaignBrowserIsVisible {
                adventure
                    .openSettings()
                    .setAdventureTabMode("Campaign browser")
                    .doneToAdventure()
            }

            adventure
                .waitForCampaignBrowserVisible(timeout: 60)
            tapRow(named: "Legacy Campaign", in: app, timeout: 30)
            XCTAssertTrue(app.navigationBars["Legacy Campaign"].waitForExistence(timeout: 30), app.debugDescription)
            tapRow(named: "Upgrade Fixture Encounter", in: app, timeout: 30)
        }

        XCTAssertTrue(migratedEncounterIsVisible(in: app, timeout: 30), app.debugDescription)
    }

    private func migratedEncounterIsVisible(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        app.staticTexts["Mira Vale"].waitForExistence(timeout: timeout)
            && app.staticTexts["Clockwork Myrmidon"].waitForExistence(timeout: timeout)
    }

    private func applyDefaultContentUpdateIfNeeded(in app: XCUIApplication) {
        guard app.navigationBars["Rules content"].waitForExistence(timeout: 5) else { return }

        let continueButton = app.buttons["Continue"].firstMatch
        if !continueButton.waitForExistence(timeout: 2) || !continueButton.isEnabled {
            let card2014 = app.buttons["default-content-card-2014"].firstMatch
            XCTAssertTrue(card2014.waitForExistence(timeout: 10), "Expected 2014 default content card")
            card2014.tap()
        }

        let primaryButton = app.buttons["Continue"].firstMatch.exists
            ? app.buttons["Continue"].firstMatch
            : app.buttons["Update content"].firstMatch
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 10), "Expected default content primary button")
        XCTAssertTrue(primaryButton.isEnabled, "Default content primary button should be enabled")
        primaryButton.tap()

        let dismissed = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: dismissed, object: app.navigationBars["Rules content"])
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 60), .completed)
    }

    private func tapRow(named name: String, in app: XCUIApplication, timeout: TimeInterval) {
        let query = app.buttons.matching(identifier: name)
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: timeout), "Expected row \(name) to exist")

        if let button = query.allElementsBoundByIndex.first(where: \.isHittable) {
            button.tap()
        } else {
            query.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
