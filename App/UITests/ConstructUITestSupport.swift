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
        let addCombatantsControl = addCombatantsButtonControl()
        XCTAssertTrue(addCombatantsControl.waitForExistence(timeout: 10))
        addCombatantsControl.tap()
        return AddCombatantsPage(app: app).waitForVisible()
    }

    @discardableResult
    func openCombatantDetail(containing nameFragment: String) -> CombatantDetailPage {
        let namePredicate = NSPredicate(format: "label CONTAINS[c] %@", nameFragment)
        let labels = app.staticTexts.matching(namePredicate)
        XCTAssertTrue(labels.firstMatch.waitForExistence(timeout: 10), "Expected combatant matching \(nameFragment)")

        let detail = CombatantDetailPage(app: app)

        for _ in 0..<5 {
            if detail.isVisible {
                return detail
            }

            let label = labels.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) ?? labels.firstMatch
            XCTAssertTrue(label.exists, "Expected combatant label matching \(nameFragment)")

            // XCUIElement.tap() on StaticText does not always trigger the row's onTapGesture.
            // Tap absolute coordinates to activate the row reliably.
            let absolute = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: label.frame.midX, dy: label.frame.midY))
            absolute.tap()

            if detail.waitForVisible(timeout: 2, failOnTimeout: false).isVisible {
                return detail
            }
        }

        XCTFail("Expected combatant detail for \(nameFragment) to open")
        return detail
    }

    func assertRunEncounterVisible(timeout: TimeInterval = 10) {
        XCTAssertTrue(runEncounterButtonControl().waitForExistence(timeout: timeout), "Run encounter control should be visible")
    }

    @discardableResult
    func tapRunEncounter(timeout: TimeInterval = 10) -> RunningEncounterPage {
        let runEncounterControl = runEncounterButtonControl()
        XCTAssertTrue(runEncounterControl.waitForExistence(timeout: timeout), "Run encounter control should be visible")
        runEncounterControl.tap()
        return RunningEncounterPage(app: app).waitForVisible()
    }

    @discardableResult
    func resumeRunningEncounterFromMenu(timeout: TimeInterval = 10) -> RunningEncounterPage {
        let runEncounterControl = runEncounterButtonControl()
        XCTAssertTrue(runEncounterControl.waitForExistence(timeout: timeout), "Run encounter control should be visible")
        runEncounterControl.press(forDuration: 1.2)

        let resumePredicate = NSPredicate(format: "label BEGINSWITH 'Resume run '")
        let resumeButton = app.buttons.matching(resumePredicate).firstMatch
        if resumeButton.waitForExistence(timeout: 5) {
            resumeButton.tap()
            return RunningEncounterPage(app: app).waitForVisible()
        }

        let resumeMenuItem = app.menuItems.matching(resumePredicate).firstMatch
        XCTAssertTrue(resumeMenuItem.waitForExistence(timeout: 5), "Expected Resume run action")
        resumeMenuItem.tap()
        return RunningEncounterPage(app: app).waitForVisible()
    }

    func openAddCombatantsContextMenu() {
        let addCombatantsButton = addCombatantsButtonControl()
        XCTAssertTrue(addCombatantsButton.waitForExistence(timeout: 10))

        func quickCreateMenuIsVisible() -> Bool {
            app.buttons["Quick create"].firstMatch.exists || app.menuItems["Quick create"].firstMatch.exists
        }

        if quickCreateMenuIsVisible() { return }

        let center = addCombatantsButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let absoluteCenter = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: addCombatantsButton.frame.midX, dy: addCombatantsButton.frame.midY))

        for _ in 0..<2 {
            center.press(forDuration: 1.5)
            if quickCreateMenuIsVisible() { return }
            absoluteCenter.press(forDuration: 1.5)
            if quickCreateMenuIsVisible() { return }
            absoluteCenter.press(
                forDuration: 1.2,
                thenDragTo: absoluteCenter.withOffset(CGVector(dx: 1, dy: 1))
            )
            if quickCreateMenuIsVisible() { return }
        }

        XCTFail("Expected Add combatants context menu to appear")
    }

    func tapQuickCreateFromAddCombatantsContextMenu() {
        let quickCreateButton = app.buttons["Quick create"].firstMatch
        if quickCreateButton.waitForExistence(timeout: 5) {
            quickCreateButton.tap()
            return
        }

        let quickCreateMenuItem = app.menuItems["Quick create"].firstMatch
        XCTAssertTrue(quickCreateMenuItem.waitForExistence(timeout: 5), "Expected quick create context action")
        quickCreateMenuItem.tap()
    }

    private func addCombatantsButtonControl() -> XCUIElement {
        let popUpButton = app.popUpButtons["Add combatants"].firstMatch
        if popUpButton.exists {
            return popUpButton
        }

        return app.buttons["Add combatants"].firstMatch
    }

    private func runEncounterButtonControl() -> XCUIElement {
        let popUpButton = app.popUpButtons["Run encounter"].firstMatch
        if popUpButton.exists {
            return popUpButton
        }

        return app.buttons["Run encounter"].firstMatch
    }

    func openActionsSettings() -> EncounterSettingsPage {
        let actionsButton = app.navigationBars["Scratch pad"].buttons["Actions"].firstMatch
        XCTAssertTrue(actionsButton.waitForExistence(timeout: 10))
        XCTAssertTrue(actionsButton.isHittable, "Scratch pad actions button should be hittable")
        actionsButton.tap()

        let settingsButton = app.buttons["Settings"].firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            return EncounterSettingsPage(app: app)
        }

        let settingsMenuItem = app.menuItems["Settings"].firstMatch
        if settingsMenuItem.waitForExistence(timeout: 5) {
            settingsMenuItem.tap()
            return EncounterSettingsPage(app: app)
        }

        let settingsStaticText = app.staticTexts["Settings"].firstMatch
        XCTAssertTrue(settingsStaticText.waitForExistence(timeout: 5), "Expected Settings action in menu")
        settingsStaticText.tap()

        return EncounterSettingsPage(app: app)
    }

    func duplicateCombatant(named name: String) {
        let combatant = app.cells.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(combatant.waitForExistence(timeout: 10), "Expected combatant \(name)")
        combatant.press(forDuration: 1.0)
        app.buttons["Duplicate"].tap()
    }

    func performCombatantContextAction(containing nameFragment: String, action: String) {
        let namePredicate = NSPredicate(format: "label CONTAINS[c] %@", nameFragment)
        let combatantLabel = app.staticTexts.matching(namePredicate).firstMatch
        XCTAssertTrue(combatantLabel.waitForExistence(timeout: 10), "Expected combatant matching \(nameFragment)")

        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: combatantLabel.frame.midX, dy: combatantLabel.frame.midY))
        center.press(forDuration: 1.0)

        let actionButton = app.buttons[action].firstMatch
        if actionButton.waitForExistence(timeout: 5) {
            actionButton.tap()
            return
        }

        let actionMenuItem = app.menuItems[action].firstMatch
        XCTAssertTrue(actionMenuItem.waitForExistence(timeout: 5), "Expected context action \(action)")
        actionMenuItem.tap()
    }

    func assertCombatantCount(containing nameFragment: String, equals expected: Int) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", nameFragment)
        let labels = app.staticTexts.matching(predicate)
        XCTAssertEqual(labels.count, expected, "Expected \(expected) combatants matching \(nameFragment)")
    }

    func assertDifficultyLabel(_ text: String) {
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 10), "Expected difficulty label \(text)")
    }

    func assertCombatantVisible(_ name: String) {
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10), "Expected combatant \(name)")
    }

    func assertLabelContaining(_ textFragment: String, timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", textFragment)
        if app.staticTexts.matching(predicate).firstMatch.waitForExistence(timeout: timeout) {
            return
        }
        XCTAssertTrue(app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: 2), "Expected label containing \(textFragment)")
    }
}

struct RunningEncounterPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 20) -> Self {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.buttons["Roll initiative..."].exists
                || app.buttons["Start"].exists
                || app.buttons["Next turn"].exists {
                return self
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        XCTFail("Expected running encounter controls to appear")
        return self
    }

    @discardableResult
    func rollInitiativeIfNeeded() -> Self {
        let rollInitiativeButton = app.buttons["Roll initiative..."].firstMatch
        if rollInitiativeButton.waitForExistence(timeout: 2) {
            rollInitiativeButton.tap()
            let rollButton = app.buttons["Roll"].firstMatch
            XCTAssertTrue(rollButton.waitForExistence(timeout: 5), "Expected initiative roll confirmation button")
            rollButton.tap()
        }
        return self
    }

    @discardableResult
    func startIfNeeded() -> Self {
        let startButton = app.buttons["Start"].firstMatch
        if startButton.waitForExistence(timeout: 3) {
            startButton.tap()
        }
        XCTAssertTrue(app.buttons["Next turn"].waitForExistence(timeout: 10), "Expected Next turn button")
        return self
    }

    @discardableResult
    func nextTurn() -> Self {
        let nextTurnButton = app.buttons["Next turn"].firstMatch
        XCTAssertTrue(nextTurnButton.waitForExistence(timeout: 10), "Expected Next turn button")
        nextTurnButton.tap()
        return self
    }

    func assertCombatantVisible(containing nameFragment: String, timeout: TimeInterval = 10) {
        let namePredicate = NSPredicate(format: "label CONTAINS[c] %@", nameFragment)
        XCTAssertTrue(app.staticTexts.matching(namePredicate).firstMatch.waitForExistence(timeout: timeout), "Expected combatant matching \(nameFragment)")
    }

    @discardableResult
    func openLog() -> RunningEncounterLogPage {
        openRunningMenu()

        let showLogButton = app.buttons["Show log"].firstMatch
        if showLogButton.waitForExistence(timeout: 5) {
            showLogButton.tap()
            return RunningEncounterLogPage(app: app).waitForVisible()
        }

        let showLogMenuItem = app.menuItems["Show log"].firstMatch
        XCTAssertTrue(showLogMenuItem.waitForExistence(timeout: 5), "Expected Show log action")
        showLogMenuItem.tap()
        return RunningEncounterLogPage(app: app).waitForVisible()
    }

    @discardableResult
    func stopRun() -> ScratchPadPage {
        openRunningMenu()

        let stopRunButton = app.buttons["Stop run"].firstMatch
        if stopRunButton.waitForExistence(timeout: 5) {
            stopRunButton.tap()
            return ScratchPadPage(app: app).waitForVisible()
        }

        let stopRunMenuItem = app.menuItems["Stop run"].firstMatch
        XCTAssertTrue(stopRunMenuItem.waitForExistence(timeout: 5), "Expected Stop run action")
        stopRunMenuItem.tap()
        return ScratchPadPage(app: app).waitForVisible()
    }

    private func openRunningMenu() {
        let roundButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Round'")).firstMatch
        if roundButton.waitForExistence(timeout: 5) {
            roundButton.tap()
            return
        }

        let turnButton = app.buttons.matching(NSPredicate(format: "label CONTAINS \"turn\"")).firstMatch
        XCTAssertTrue(turnButton.waitForExistence(timeout: 10), "Expected running encounter menu button")
        turnButton.tap()
    }
}

struct RunningEncounterLogPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(app.navigationBars["Running Encounter Log"].waitForExistence(timeout: timeout), "Running Encounter Log should be visible")
        return self
    }

    func assertStartOfEncounterVisible(timeout: TimeInterval = 10) {
        XCTAssertTrue(app.staticTexts["Start of encounter"].waitForExistence(timeout: timeout), "Expected Start of encounter row")
    }

    @discardableResult
    func done() -> RunningEncounterPage {
        let doneButton = app.navigationBars.buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Expected Done button on running log")
        doneButton.tap()
        return RunningEncounterPage(app: app).waitForVisible()
    }
}

struct CombatantDetailPage {
    let app: XCUIApplication

    var isVisible: Bool {
        let hpButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Hit Points'")).firstMatch
        return hpButton.exists && app.buttons["Manage"].firstMatch.exists
    }

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 10, failOnTimeout: Bool = true) -> Self {
        let hpButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Hit Points'")).firstMatch
        let visible = hpButton.waitForExistence(timeout: timeout)
        if failOnTimeout {
            XCTAssertTrue(visible, "Expected combatant detail to be visible")
        }
        return self
    }

    @discardableResult
    func applyDamage(_ amount: Int) -> Self {
        let hpButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Hit Points'")).firstMatch
        XCTAssertTrue(hpButton.waitForExistence(timeout: 10), "Expected Hit Points button")
        hpButton.tap()

        enterManualNumber(amount)

        let hitButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Hit'")).firstMatch
        XCTAssertTrue(hitButton.waitForExistence(timeout: 5), "Expected Hit button")
        hitButton.tap()

        return self
    }

    @discardableResult
    func addTag(named tag: String) -> Self {
        let manageButton = app.buttons["Manage"].firstMatch
        XCTAssertTrue(manageButton.waitForExistence(timeout: 10), "Expected Manage tags button")
        manageButton.tap()

        let tagButton = app.buttons[tag].firstMatch
        if tagButton.waitForExistence(timeout: 5) {
            tagButton.tap()
        } else {
            let tagText = app.staticTexts[tag].firstMatch
            XCTAssertTrue(tagText.waitForExistence(timeout: 10), "Expected tag option \(tag)")
            tagText.tap()
        }

        // Create flow opens tag-edit with Done; edit flow may skip this.
        let tagEditDone = app.navigationBars.buttons["Done"].firstMatch
        if tagEditDone.waitForExistence(timeout: 2) && tagEditDone.isHittable {
            tagEditDone.tap()
        }

        // Back from manage-tags destination to combatant detail.
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists && backButton.isHittable {
            backButton.tap()
        }

        return waitForVisible()
    }

    @discardableResult
    func addLimitedResource(named name: String, uses: Int) -> Self {
        let addResourceButton = app.buttons["Add limited resource"].firstMatch
        scrollToElement(addResourceButton)
        XCTAssertTrue(addResourceButton.waitForExistence(timeout: 10), "Expected Add limited resource button")
        addResourceButton.tap()

        let nameField = app.textFields["Name"].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "Expected resource name field")
        nameField.tap()
        nameField.typeText(name)

        if uses > 1 {
            let stepper = app.steppers.firstMatch
            XCTAssertTrue(stepper.waitForExistence(timeout: 5), "Expected resource uses stepper")
            for _ in 0..<(uses - 1) {
                stepper.buttons["Increment"].tap()
            }
        }

        dismissKeyboardIfVisible()

        let doneButton = app.buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Expected resource editor Done button")
        doneButton.tap()

        return self
    }

    func assertTagVisible(_ tag: String, timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", tag)
        XCTAssertTrue(app.staticTexts.matching(predicate).firstMatch.waitForExistence(timeout: timeout), "Expected tag \(tag)")
    }

    func assertResourceVisible(containing text: String, timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        if app.staticTexts.matching(predicate).firstMatch.waitForExistence(timeout: timeout) {
            return
        }
        XCTAssertTrue(app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: 2), "Expected resource containing \(text)")
    }

    @discardableResult
    func doneToScratchPad() -> ScratchPadPage {
        let doneButton = app.buttons["Done"].firstMatch
        if doneButton.exists && doneButton.isHittable {
            doneButton.tap()
            return ScratchPadPage(app: app).waitForVisible()
        }

        // Combatant detail is often presented as a swipe-dismissable sheet without a dedicated Done button.
        for _ in 0..<3 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            start.press(forDuration: 0.01, thenDragTo: end)

            let scratchPad = ScratchPadPage(app: app)
            if app.navigationBars["Scratch pad"].waitForExistence(timeout: 1.5) {
                return scratchPad.waitForVisible()
            }
        }

        XCTFail("Expected combatant detail to dismiss to Scratch pad")
        return ScratchPadPage(app: app).waitForVisible()
    }

    private func enterManualNumber(_ number: Int) {
        let deleteButton = app.buttons["delete.left"].firstMatch
        if deleteButton.waitForExistence(timeout: 1) {
            for _ in 0..<4 {
                deleteButton.tap()
            }
        }

        for character in String(number) {
            let digitButton = app.buttons[String(character)].firstMatch
            XCTAssertTrue(digitButton.waitForExistence(timeout: 5), "Expected digit button \(character)")
            digitButton.tap()
        }
    }

    private func scrollToElement(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }

            let container = app.scrollViews.firstMatch
            if container.exists {
                let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
                let end = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
                start.press(forDuration: 0.01, thenDragTo: end)
            } else {
                app.swipeUp()
            }
        }
    }

    private func dismissKeyboardIfVisible() {
        guard app.keyboards.firstMatch.exists else { return }

        let done = app.keyboards.buttons["Done"].firstMatch
        if done.exists {
            done.tap()
            return
        }

        let `return` = app.keyboards.buttons["Return"].firstMatch
        if `return`.exists {
            `return`.tap()
            return
        }

        let header = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        header.tap()
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
        // If we're on a combatant detail push, navigate back to the add-combatants list.
        for _ in 0..<2 {
            let backToAddCombatant = app.buttons["Add Combatant"].firstMatch
            if backToAddCombatant.exists && backToAddCombatant.isHittable {
                backToAddCombatant.tap()
            }
        }

        // If we're still on creature edit, cancel back to add-combatants list.
        let cancelButton = app.navigationBars.buttons["Cancel"].firstMatch
        if cancelButton.exists && cancelButton.isHittable {
            cancelButton.tap()
        }

        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            for _ in 0..<3 {
                let closeButton = app.buttons["close"].firstMatch
                if closeButton.exists {
                    if closeButton.isHittable {
                        closeButton.tap()
                    } else {
                        closeButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    }
                } else {
                    // Some add-combatants presentations expose only an unlabeled close affordance in
                    // the lower-right corner of the search row.
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.83, dy: 0.80)).tap()
                }

                let gone = NSPredicate(format: "exists == false")
                let waiter = XCTNSPredicateExpectation(predicate: gone, object: searchField)
                if XCTWaiter().wait(for: [waiter], timeout: 1.5) == .completed {
                    return waitForDismissalToScratchPad()
                }
            }

            for backLabel in ["Scratch pad", "Adventure"] {
                let backButton = app.buttons[backLabel].firstMatch
                if backButton.exists && backButton.isHittable {
                    backButton.tap()
                    return waitForDismissalToScratchPad()
                }
            }

            let nonDismissLabels = Set(["Done", "Edit", "Actions", ""])
            let navBarButtons = app.navigationBars.buttons.allElementsBoundByIndex
            if let hittableDismissButton = navBarButtons.first(where: {
                $0.exists && $0.isHittable && !nonDismissLabels.contains($0.label)
            }) {
                hittableDismissButton.tap()
                return waitForDismissalToScratchPad()
            }

            let addCombatantNavBar = app.navigationBars["Add Combatant"].firstMatch
            let addCombatantDone = addCombatantNavBar.buttons["Done"].firstMatch
            if addCombatantDone.exists && addCombatantDone.isHittable {
                addCombatantDone.tap()
                return waitForDismissalToScratchPad()
            }

            let navBarDoneButtons = app.navigationBars.buttons.matching(NSPredicate(format: "label == 'Done'"))
            if tapFirstHittable(from: navBarDoneButtons, timeout: 5) {
                return waitForDismissalToScratchPad()
            }

            let doneButtons = app.buttons.matching(NSPredicate(format: "label == 'Done'"))
            if tapFirstHittable(from: doneButtons, timeout: 2) {
                return waitForDismissalToScratchPad()
            }
        }

        let container = app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch : app
        let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.01, thenDragTo: end)
        return waitForDismissalToScratchPad()
    }

    private func waitForDismissalToScratchPad() -> ScratchPadPage {
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            let gone = NSPredicate(format: "exists == false")
            let waiter = XCTNSPredicateExpectation(predicate: gone, object: searchField)
            _ = XCTWaiter().wait(for: [waiter], timeout: 8)
        }
        return ScratchPadPage(app: app).waitForVisible()
    }

    private func tapFirstHittable(from query: XCUIElementQuery, timeout: TimeInterval) -> Bool {
        guard query.firstMatch.waitForExistence(timeout: timeout) else { return false }
        for index in 0..<query.count {
            let button = query.element(boundBy: index)
            if button.exists && button.isHittable {
                button.tap()
                return true
            }
        }
        return false
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
        dismissKeyboardIfVisible()

        let label = app.staticTexts["Controlled by player"]
        scrollToElement(label, requireHittable: true)
        XCTAssertTrue(label.waitForExistence(timeout: 10), "Expected Controlled by player row")

        let identifiedSwitch = app.switches["controlledByPlayerToggle"].firstMatch
        if identifiedSwitch.waitForExistence(timeout: 2) {
            scrollToElement(identifiedSwitch, requireHittable: true)
            setSwitch(identifiedSwitch, enabled: enabled)
            return self
        }

        let labeledSwitch = app.switches["Controlled by player"].firstMatch
        if labeledSwitch.exists {
            scrollToElement(labeledSwitch, requireHittable: true)
            setSwitch(labeledSwitch, enabled: enabled)
            return self
        }

        let row = app.cells.containing(.staticText, identifier: "Controlled by player").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        scrollToElement(row, requireHittable: true)

        let rowSwitch = row.switches.firstMatch
        if rowSwitch.exists {
            setSwitch(rowSwitch, enabled: enabled)
        } else {
            for _ in 0..<5 {
                if switchValue(of: row) == enabled { return self }
                let toggleCoordinate = row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
                toggleCoordinate.tap()
            }
            XCTAssertEqual(switchValue(of: row), enabled, "Failed to set switch state to \(enabled)")
        }

        return self
    }

    @discardableResult
    func tapAdd() -> AddCombatantsPage {
        let addButtons = app.navigationBars.buttons.matching(NSPredicate(format: "label == 'Add'"))
        XCTAssertTrue(addButtons.firstMatch.waitForExistence(timeout: 10), "Expected Add button in creature editor")

        var tapped = false
        for index in 0..<addButtons.count {
            let button = addButtons.element(boundBy: index)
            if button.exists && button.isHittable {
                button.tap()
                tapped = true
                break
            }
        }
        if !tapped {
            addButtons.firstMatch.tap()
        }

        let nameField = app.textFields["Name"].firstMatch
        if nameField.exists {
            let gone = NSPredicate(format: "exists == false")
            let waiter = XCTNSPredicateExpectation(predicate: gone, object: nameField)
            XCTAssertEqual(XCTWaiter().wait(for: [waiter], timeout: 10), .completed, "Creature edit view should dismiss after tapping Add")
        }
        return AddCombatantsPage(app: app)
    }

    private func setSwitch(_ element: XCUIElement, enabled: Bool) {
        for _ in 0..<5 {
            if switchValue(of: element) == enabled { return }
            if element.isHittable {
                element.tap()
            } else {
                let center = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                center.tap()
            }
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

    private func scrollToElement(_ element: XCUIElement, requireHittable: Bool = false) {
        for _ in 0..<10 {
            if element.exists && (!requireHittable || element.isHittable) { return }
            dismissKeyboardIfVisible()

            let container = scrollContainer()
            let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let end = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
    }

    private func scrollContainer() -> XCUIElement {
        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 1) {
            return table
        }

        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            return scrollView
        }

        return app
    }

    private func dismissKeyboardIfVisible() {
        guard app.keyboards.firstMatch.exists else { return }

        let done = app.keyboards.buttons["Done"].firstMatch
        if done.exists {
            done.tap()
            return
        }

        let `return` = app.keyboards.buttons["Return"].firstMatch
        if `return`.exists {
            `return`.tap()
            return
        }

        let navBar = app.navigationBars.firstMatch
        if navBar.exists {
            navBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap()
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
