import Foundation
import XCTest

class ConstructUITestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CONSTRUCT_UI_TESTS"] = "1"
        app.launch()
        return app
    }

    func launchIntoAdventureBySkippingOnboarding() -> AdventurePage {
        let app = launchApp()
        return OnboardingPage(app: app)
            .waitForVisible()
            .tapContinue()
    }
}

struct OnboardingPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 120) -> Self {
        XCTAssertTrue(app.staticTexts["Welcome to Construct"].waitForExistence(timeout: timeout), "Expected onboarding screen")
        return self
    }

    @discardableResult
    func tapContinue(timeout: TimeInterval = 10) -> AdventurePage {
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: timeout))
        continueButton.tap()
        waitForDismiss()
        return AdventurePage(app: app).waitForVisible()
    }

    @discardableResult
    func tapOpenSampleEncounter(timeout: TimeInterval = 10) -> ScratchPadPage {
        let sampleButton = app.buttons["Open sample encounter"]
        XCTAssertTrue(sampleButton.waitForExistence(timeout: timeout))
        sampleButton.tap()
        waitForDismiss()
        return ScratchPadPage(app: app).waitForVisible()
    }

    private func waitForDismiss() {
        let welcomeTitle = app.staticTexts["Welcome to Construct"]
        if welcomeTitle.exists {
            let gone = NSPredicate(format: "exists == false")
            let waiter = XCTNSPredicateExpectation(predicate: gone, object: welcomeTitle)
            XCTAssertEqual(XCTWaiter().wait(for: [waiter], timeout: 30), .completed)
        }
    }
}

struct AdventurePage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 20) -> Self {
        XCTAssertTrue(app.navigationBars["Adventure"].waitForExistence(timeout: timeout), "Adventure should be visible")
        return self
    }

    @discardableResult
    func openScratchPad(timeout: TimeInterval = 20) -> ScratchPadPage {
        let scratchPadButton = app.buttons["Scratch pad"]
        XCTAssertTrue(scratchPadButton.waitForExistence(timeout: timeout), "Scratch pad entry should be visible")
        scratchPadButton.tap()
        return ScratchPadPage(app: app).waitForVisible()
    }

    @discardableResult
    func openSettings(timeout: TimeInterval = 10) -> SettingsPage {
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: timeout), "Settings button should be visible")
        settingsButton.tap()
        return SettingsPage(app: app).waitForVisible()
    }

    func createGroup(named name: String) {
        createItem(button: "New group", name: name)
    }

    func createEncounter(named name: String) {
        createItem(button: "New encounter", name: name)
    }

    @discardableResult
    func openItem(named name: String, timeout: TimeInterval = 10) -> Self {
        let button = app.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Expected item \(name) to exist")
        button.tap()
        return self
    }

    func longPressItem(named name: String) {
        let button = app.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Expected item \(name) to exist")
        button.press(forDuration: 1.0)
    }

    func tapContextAction(_ title: String) {
        let action = app.buttons[title]
        XCTAssertTrue(action.waitForExistence(timeout: 10), "Expected context action \(title)")
        action.tap()
    }

    func goBack(from navigationTitle: String) {
        XCTAssertTrue(app.navigationBars[navigationTitle].waitForExistence(timeout: 10), "Expected nav bar \(navigationTitle)")
        app.navigationBars[navigationTitle].buttons.element(boundBy: 0).tap()
    }

    private func createItem(button: String, name: String) {
        app.buttons[button].tap()
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(name)
        app.navigationBars.buttons["Done"].firstMatch.tap()
    }
}

struct ScratchPadPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 20) -> Self {
        XCTAssertTrue(app.navigationBars["Scratch pad"].waitForExistence(timeout: timeout), "Scratch pad should be visible")
        return self
    }

    func assertEmptyEncounterVisible() {
        XCTAssertTrue(app.staticTexts["Empty encounter"].waitForExistence(timeout: 10))
    }

    @discardableResult
    func openAddCombatants() -> AddCombatantsPage {
        let addCombatantsButton = app.buttons["Add combatants"]
        XCTAssertTrue(addCombatantsButton.waitForExistence(timeout: 10))
        addCombatantsButton.tap()
        return AddCombatantsPage(app: app).waitForVisible()
    }

    func openAddCombatantsContextMenu() {
        let addCombatantsButton = app.buttons["Add combatants"]
        XCTAssertTrue(addCombatantsButton.waitForExistence(timeout: 10))
        addCombatantsButton.press(forDuration: 1.0)
    }

    func openActionsSettings() -> EncounterSettingsPage {
        let actionsButton = app.buttons["Actions"]
        XCTAssertTrue(actionsButton.waitForExistence(timeout: 10))
        actionsButton.tap()

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()

        return EncounterSettingsPage(app: app)
    }

    func duplicateCombatant(named name: String) {
        let combatant = app.cells.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(combatant.waitForExistence(timeout: 10), "Expected combatant \(name)")
        combatant.press(forDuration: 1.0)
        app.buttons["Duplicate"].tap()
    }

    func assertDifficultyLabel(_ text: String) {
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 10), "Expected difficulty label \(text)")
    }
}

struct AddCombatantsPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: timeout), "Add combatants search should be visible")
        return self
    }

    @discardableResult
    func search(_ text: String) -> Self {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText(text)
        return self
    }

    @discardableResult
    func clearSearch() -> Self {
        let searchField = app.searchFields.firstMatch
        let clearButton = searchField.buttons["Clear text"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.tap()
        return self
    }

    func quickAddCombatant(named name: String, times: Int) {
        let row = app.cells.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "Expected compendium row for \(name)")
        let addButton = row.buttons["plus.circle"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        for _ in 0..<times {
            addButton.tap()
        }
    }

    func openCombatantDetail(named name: String) -> AddCombatantDetailPage {
        let row = app.cells.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "Expected compendium row for \(name)")
        row.tap()
        return AddCombatantDetailPage(app: app)
    }

    func tapQuickCreate() -> CreatureEditPage {
        let quickCreateButton = app.buttons["Quick create"]
        XCTAssertTrue(quickCreateButton.waitForExistence(timeout: 10))
        quickCreateButton.tap()
        return CreatureEditPage(app: app).waitForVisible()
    }

    func filterCharactersIfPresent() {
        let charactersFilter = app.buttons["Characters"]
        if charactersFilter.exists {
            charactersFilter.tap()
        }
    }

    func addFromList(named name: String) {
        let row = app.cells.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "Expected list row \(name)")
        XCTAssertGreaterThan(row.buttons.count, 0)
        row.buttons.element(boundBy: row.buttons.count - 1).tap()
    }

    @discardableResult
    func done() -> ScratchPadPage {
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()
        return ScratchPadPage(app: app).waitForVisible()
    }
}

struct AddCombatantDetailPage {
    let app: XCUIApplication

    func setQuantity(_ quantity: Int) {
        let quantityStepper = app.steppers.matching(NSPredicate(format: "label BEGINSWITH 'Quantity'"))
            .firstMatch
        XCTAssertTrue(quantityStepper.waitForExistence(timeout: 10))

        guard quantity > 1 else { return }
        for _ in 0..<(quantity - 1) {
            quantityStepper.buttons["Increment"].tap()
        }
    }

    func enableRollForHP() {
        let rollForHpButton = app.segmentedControls.buttons["Roll for HP"]
        XCTAssertTrue(rollForHpButton.waitForExistence(timeout: 10))
        rollForHpButton.tap()
    }

    @discardableResult
    func tapAdd(quantity: Int) -> AddCombatantsPage {
        let addButton = app.buttons["Add \(quantity)"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()
        return AddCombatantsPage(app: app)
    }
}

struct CreatureEditPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(app.textFields["Name"].firstMatch.waitForExistence(timeout: timeout), "Creature edit form should be visible")
        return self
    }

    @discardableResult
    func chooseCreatureType(_ type: String) -> Self {
        let creatureTypeButton = app.buttons.matching(NSPredicate(format: "label == 'monster' OR label == 'combatant' OR label == 'character'"))
            .firstMatch
        XCTAssertTrue(creatureTypeButton.waitForExistence(timeout: 10))
        creatureTypeButton.tap()

        let option = app.buttons[type].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        return self
    }

    @discardableResult
    func setName(_ name: String) -> Self {
        let nameField = app.textFields["Name"].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(name)
        return self
    }

    @discardableResult
    func setLevel(_ level: Int) -> Self {
        let levelStepper = app.steppers.matching(NSPredicate(format: "label BEGINSWITH 'Level'"))
            .firstMatch
        XCTAssertTrue(levelStepper.waitForExistence(timeout: 10))
        guard level > 0 else { return self }

        for _ in 0..<level {
            levelStepper.buttons["Increment"].tap()
        }

        return self
    }

    @discardableResult
    func setControlledByPlayer(_ enabled: Bool) -> Self {
        let label = app.staticTexts["Controlled by player"]
        scrollToElement(label)
        XCTAssertTrue(label.waitForExistence(timeout: 10), "Expected Controlled by player row")

        let switchElement: XCUIElement
        let identifiedSwitch = app.switches["controlledByPlayerToggle"]
        if identifiedSwitch.exists {
            switchElement = identifiedSwitch
        } else {
            switchElement = app.switches["Controlled by player"].firstMatch
        }

        if switchElement.exists {
            setSwitch(switchElement, enabled: enabled)
        } else {
            let row = app.otherElements.containing(.staticText, identifier: "Controlled by player").firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            setSwitch(row, enabled: enabled)
        }

        return self
    }

    @discardableResult
    func tapAdd() -> AddCombatantsPage {
        let addButton = app.navigationBars.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()
        return AddCombatantsPage(app: app)
    }

    private func setSwitch(_ element: XCUIElement, enabled: Bool) {
        for _ in 0..<4 {
            if switchValue(of: element) == enabled { return }
            element.tap()
            if switchValue(of: element) == enabled { return }

            let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
            coordinate.tap()
            if switchValue(of: element) == enabled { return }
        }

        XCTAssertEqual(switchValue(of: element), enabled, "Failed to set switch state to \(enabled)")
    }

    private func switchValue(of element: XCUIElement) -> Bool {
        guard let value = element.value else { return false }

        if let stringValue = value as? String {
            return stringValue == "1" || stringValue.lowercased() == "on"
        }
        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        return false
    }

    private func scrollToElement(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists { break }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
    }
}

struct EncounterSettingsPage {
    let app: XCUIApplication

    func chooseSelectCombatantsParty() {
        let selectCombatantsButton = app.segmentedControls.buttons["Select combatants"]
        XCTAssertTrue(selectCombatantsButton.waitForExistence(timeout: 10))
        selectCombatantsButton.tap()
    }

    func assertCombatantVisible(_ name: String) {
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10), "Expected combatant \(name) in settings")
    }

    func done() -> ScratchPadPage {
        let doneButton = app.navigationBars.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()
        return ScratchPadPage(app: app).waitForVisible()
    }
}

struct SettingsPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: timeout), "Settings screen should be visible")
        return self
    }

    func openTipJar() -> TipJarPage {
        let tipJarCell = app.cells.containing(.staticText, identifier: "Tip jar").firstMatch
        XCTAssertTrue(tipJarCell.waitForExistence(timeout: 10))
        tipJarCell.tap()
        return TipJarPage(app: app).waitForVisible()
    }
}

struct TipJarPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(app.navigationBars["Tip Jar"].waitForExistence(timeout: timeout), "Tip Jar should be visible")
        XCTAssertTrue(app.staticTexts["Toss a coin to your Construct..."].waitForExistence(timeout: timeout))
        return self
    }

    func tapAnyPurchaseButton() {
        let purchaseButtonPredicate = NSPredicate(format: "label CONTAINS '0.99' OR label CONTAINS '4.99' OR label CONTAINS '9.99' OR label == 'Buy' OR label == 'Purchase'")
        let purchaseButton = app.buttons.matching(purchaseButtonPredicate).firstMatch
        XCTAssertTrue(purchaseButton.waitForExistence(timeout: 10), "Expected tip purchase button")
        purchaseButton.tap()
    }

    func assertThankYouVisible() {
        let thankYouText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Thank you'"))
            .firstMatch
        XCTAssertTrue(thankYouText.waitForExistence(timeout: 15), "Expected thank you text after purchase")
    }
}
