import XCTest

final class ConstructCampaignBrowseUITests: ConstructUITestCase {

    func testCampaignBrowseFlow() {
        let app = launchApp()
        let adventure = OnboardingPage(app: app)
            .waitForVisible()
            .tapContinue()

        adventure.createGroup(named: "Group One")
        adventure.openItem(named: "Group One")
        XCTAssertTrue(app.navigationBars["Group One"].waitForExistence(timeout: 10))

        adventure.createEncounter(named: "Encounter A")
        XCTAssertTrue(app.buttons["Encounter A"].waitForExistence(timeout: 10))

        adventure.goBack(from: "Group One")
        adventure.waitForVisible()

        adventure.createEncounter(named: "Encounter Root")
        adventure.longPressItem(named: "Encounter Root")
        adventure.tapContextAction("Move")

        let moveDestinationButtons = app.buttons.matching(identifier: "Group One").allElementsBoundByIndex
        let moveIntoGroupOne = moveDestinationButtons.first { $0.isHittable }
        XCTAssertNotNil(moveIntoGroupOne, "Expected to find hittable Group One destination")
        moveIntoGroupOne?.tap()

        let moveHereButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move ' AND label ENDSWITH ' here'"))
            .allElementsBoundByIndex
        let moveHereButton = moveHereButtons.first { $0.isHittable }
        XCTAssertNotNil(moveHereButton, "Expected move confirmation button")
        moveHereButton?.tap()

        adventure.waitForVisible()

        adventure.createGroup(named: "Group Two")
        adventure.longPressItem(named: "Group Two")
        adventure.tapContextAction("Rename")

        let renameField = app.textFields.firstMatch
        XCTAssertTrue(renameField.waitForExistence(timeout: 10))
        renameField.tap()
        if let currentValue = renameField.value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            renameField.typeText(deleteString)
        }
        renameField.typeText("Group Renamed")
        app.navigationBars.buttons["Done"].firstMatch.tap()

        adventure.longPressItem(named: "Group Renamed")
        adventure.tapContextAction("Move")

        let moveGroupDestinationButtons = app.buttons.matching(identifier: "Group One").allElementsBoundByIndex
        let moveGroupIntoGroupOne = moveGroupDestinationButtons.first { $0.isHittable }
        XCTAssertNotNil(moveGroupIntoGroupOne, "Expected to find hittable Group One destination")
        moveGroupIntoGroupOne?.tap()

        let moveGroupHereButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move ' AND label ENDSWITH ' here'"))
            .allElementsBoundByIndex
        let moveGroupHereButton = moveGroupHereButtons.first { $0.isHittable }
        XCTAssertNotNil(moveGroupHereButton, "Expected move confirmation button")
        moveGroupHereButton?.tap()

        adventure.openItem(named: "Group One")
        XCTAssertTrue(app.navigationBars["Group One"].waitForExistence(timeout: 10))

        let encounterA = app.buttons["Encounter A"]
        XCTAssertTrue(encounterA.waitForExistence(timeout: 10))
        encounterA.press(forDuration: 1.0)
        app.buttons["Remove"].tap()

        adventure.goBack(from: "Group One")
        adventure.waitForVisible()

        let groupOneRoot = app.buttons["Group One"]
        XCTAssertTrue(groupOneRoot.waitForExistence(timeout: 10))
        groupOneRoot.press(forDuration: 1.0)
        app.buttons["Remove"].tap()

        XCTAssertFalse(groupOneRoot.waitForExistence(timeout: 5))
    }
}
