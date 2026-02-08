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

    @discardableResult
    func openCompendium(timeout: TimeInterval = 20) -> CompendiumPage {
        let tabButton = app.buttons["Compendium"].firstMatch
        if tabButton.waitForExistence(timeout: 2), tabButton.isHittable {
            tabButton.tap()
            if isCompendiumVisible(timeout: 3) {
                return CompendiumPage(app: app).waitForVisible(timeout: timeout)
            }
        }

        let tabBarButton = app.tabBars.buttons["Compendium"].firstMatch
        if tabBarButton.waitForExistence(timeout: 2), tabBarButton.isHittable {
            tabBarButton.tap()
            if isCompendiumVisible(timeout: 3) {
                return CompendiumPage(app: app).waitForVisible(timeout: timeout)
            }
        }

        // Custom tab bar is not always exposed as a semantic button in UI tests.
        let coordinateCandidates: [CGVector] = [
            .init(dx: 0.50, dy: 0.94),
            .init(dx: 0.50, dy: 0.90),
            .init(dx: 0.50, dy: 0.96),
        ]
        for candidate in coordinateCandidates {
            let tabCoordinate = app.coordinate(withNormalizedOffset: candidate)
            tabCoordinate.tap()
            if isCompendiumVisible(timeout: 3) {
                return CompendiumPage(app: app).waitForVisible(timeout: timeout)
            }
        }

        XCTFail("Expected to open Compendium tab")
        return CompendiumPage(app: app).waitForVisible(timeout: timeout)
    }

    @discardableResult
    func openDice(timeout: TimeInterval = 20) -> DicePage {
        let tabButton = app.buttons["Dice"].firstMatch
        if tabButton.waitForExistence(timeout: 2), tabButton.isHittable {
            tabButton.tap()
            if isDiceVisible(timeout: 3) {
                return DicePage(app: app).waitForVisible(timeout: timeout)
            }
        }

        let tabBarButton = app.tabBars.buttons["Dice"].firstMatch
        if tabBarButton.waitForExistence(timeout: 2), tabBarButton.isHittable {
            tabBarButton.tap()
            if isDiceVisible(timeout: 3) {
                return DicePage(app: app).waitForVisible(timeout: timeout)
            }
        }

        let coordinateCandidates: [CGVector] = [
            .init(dx: 0.83, dy: 0.94),
            .init(dx: 0.83, dy: 0.90),
            .init(dx: 0.83, dy: 0.96),
        ]
        for candidate in coordinateCandidates {
            let tabCoordinate = app.coordinate(withNormalizedOffset: candidate)
            tabCoordinate.tap()
            if isDiceVisible(timeout: 3) {
                return DicePage(app: app).waitForVisible(timeout: timeout)
            }
        }

        XCTFail("Expected to open Dice tab")
        return DicePage(app: app).waitForVisible(timeout: timeout)
    }

    private func isCompendiumVisible(timeout: TimeInterval) -> Bool {
        if app.buttons["Monsters"].waitForExistence(timeout: timeout) { return true }
        return app.searchFields.firstMatch.waitForExistence(timeout: 1)
    }

    private func isDiceVisible(timeout: TimeInterval) -> Bool {
        if app.buttons["1d20"].waitForExistence(timeout: timeout) { return true }
        if app.buttons["Roll"].waitForExistence(timeout: 1) { return true }
        return app.buttons["Re-roll"].waitForExistence(timeout: 1)
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

struct CompendiumPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 20) -> Self {
        if app.buttons["Monsters"].waitForExistence(timeout: timeout) { return self }
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: timeout), "Compendium should be visible")
        return self
    }

    @discardableResult
    func search(_ text: String) -> Self {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "Expected compendium search field")
        focusSearchField(searchField)
        searchField.typeText(text)
        return self
    }

    @discardableResult
    func clearSearch() -> Self {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "Expected compendium search field")
        let clearButton = searchField.buttons["Clear text"].firstMatch
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5), "Expected clear search button")
        clearButton.tap()
        return self
    }

    @discardableResult
    func tapTypeFilter(_ label: String) -> Self {
        let filterButton = app.buttons[label].firstMatch
        XCTAssertTrue(filterButton.waitForExistence(timeout: 10), "Expected type filter \(label)")
        filterButton.tap()
        return self
    }

    @discardableResult
    func openEntry(containing text: String) -> CompendiumDetailPage {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let entry = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "Expected compendium entry containing \(text)")
        entry.tap()
        return CompendiumDetailPage(app: app).waitForVisible()
    }

    @discardableResult
    func assertEntryVisible(containing text: String, timeout: TimeInterval = 15) -> Self {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let buttonMatch = app.buttons.matching(predicate).firstMatch
        if buttonMatch.waitForExistence(timeout: timeout) {
            return self
        }
        XCTAssertTrue(app.staticTexts.matching(predicate).firstMatch.waitForExistence(timeout: 2), "Expected entry containing \(text)")
        return self
    }

    @discardableResult
    func setSelecting(_ selecting: Bool) -> Self {
        let selectButton = app.buttons["Select"].firstMatch
        if selectButton.waitForExistence(timeout: 2) {
            let isSelected = selectButton.isSelected
            if selecting != isSelected {
                selectButton.tap()
            }
            return self
        }

        openSelectionMenu()

        let menuSelect = app.buttons["Select"].firstMatch
        if menuSelect.waitForExistence(timeout: 5) {
            menuSelect.tap()
            return self
        }

        let menuSelectItem = app.menuItems["Select"].firstMatch
        if menuSelectItem.waitForExistence(timeout: 5) {
            menuSelectItem.tap()
            return self
        }

        XCTFail("Expected Select control")
        return self
    }

    @discardableResult
    func selectEntry(containing text: String) -> Self {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)

        let cell = app.cells.matching(predicate).firstMatch
        if cell.waitForExistence(timeout: 10) {
            cell.tap()
            return self
        }

        let button = app.buttons.matching(predicate).firstMatch
        if button.waitForExistence(timeout: 10) {
            button.tap()
            return self
        }

        let label = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 10), "Expected selectable entry containing \(text)")
        let absolute = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: label.frame.midX, dy: label.frame.midY))
        absolute.tap()
        return self
    }

    @discardableResult
    func openSelectionAction(_ label: String) -> CompendiumTransferPage {
        openSelectionMenu()

        let actionButton = app.buttons[label].firstMatch
        if actionButton.waitForExistence(timeout: 5) {
            actionButton.tap()
        } else {
            let actionItem = app.menuItems[label].firstMatch
            XCTAssertTrue(actionItem.waitForExistence(timeout: 5), "Expected selection action \(label)")
            actionItem.tap()
        }

        return CompendiumTransferPage(app: app).waitForVisible()
    }

    @discardableResult
    func confirmDeleteSelected() -> Self {
        openSelectionMenu()
        let deleteAction = app.buttons["Delete selected..."].firstMatch
        if deleteAction.waitForExistence(timeout: 5) {
            deleteAction.tap()
        } else {
            let deleteItem = app.menuItems["Delete selected..."].firstMatch
            XCTAssertTrue(deleteItem.waitForExistence(timeout: 5), "Expected Delete selected action")
            deleteItem.tap()
        }

        let destructiveDelete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(destructiveDelete.waitForExistence(timeout: 10), "Expected delete confirmation")
        destructiveDelete.tap()
        return self
    }

    @discardableResult
    func openManageDocuments() -> CompendiumDocumentsPage {
        for _ in 0..<3 {
            openManageMenu()

            let documentsButton = app.buttons["Manage Documents"].firstMatch
            if documentsButton.waitForExistence(timeout: 2) {
                documentsButton.tap()
                return CompendiumDocumentsPage(app: app).waitForVisible()
            }

            let documentsItem = app.menuItems["Manage Documents"].firstMatch
            if documentsItem.waitForExistence(timeout: 2) {
                documentsItem.tap()
                return CompendiumDocumentsPage(app: app).waitForVisible()
            }

            let predicate = NSPredicate(format: "label CONTAINS[c] 'Manage Documents'")
            let documentsText = app.staticTexts.matching(predicate).firstMatch
            if documentsText.waitForExistence(timeout: 2) {
                documentsText.tap()
                return CompendiumDocumentsPage(app: app).waitForVisible()
            }
        }

        XCTFail("Expected Manage Documents action")
        return CompendiumDocumentsPage(app: app).waitForVisible()
    }

    @discardableResult
    func goBack() -> Self {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "Expected back button")
        backButton.tap()
        return self
    }

    @discardableResult
    func createMonster(named name: String) -> Self {
        openAddMenu()

        let newMonster = app.buttons["New monster"].firstMatch
        XCTAssertTrue(newMonster.waitForExistence(timeout: 10), "Expected New monster action")
        newMonster.tap()

        let creatureEdit = CreatureEditPage(app: app).waitForVisible().setName(name)
        _ = creatureEdit.tapAddToCompendiumDetail().goBackToCompendium()
        return waitForVisible()
    }

    private func openAddMenu() {
        let addPopUp = app.popUpButtons["Add"].firstMatch
        if addPopUp.exists && addPopUp.isHittable {
            addPopUp.tap()
            return
        }

        let addButton = app.buttons["Add"].firstMatch
        if addButton.exists && addButton.isHittable {
            addButton.tap()
            return
        }

        let addMenuCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.86))
        addMenuCoordinate.tap()
    }

    private func openManageMenu() {
        let manageButton = app.buttons["Manage"].firstMatch
        if manageButton.waitForExistence(timeout: 2), manageButton.isHittable {
            manageButton.tap()
            return
        }

        let popUpManage = app.popUpButtons["Manage"].firstMatch
        if popUpManage.waitForExistence(timeout: 2), popUpManage.isHittable {
            popUpManage.tap()
            return
        }

        let navButtons = app.navigationBars.buttons.allElementsBoundByIndex
        if let candidate = navButtons.first(where: { $0.exists && $0.isHittable && $0.label.contains("Manage") }) {
            candidate.tap()
            return
        }

        if let candidate = navButtons.first(where: { $0.exists && $0.isHittable && $0.label != "Select" }) {
            candidate.tap()
            return
        }

        if let candidate = navButtons.last(where: { $0.exists && $0.isHittable }) {
            candidate.tap()
            return
        }

        let topRight = app.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.08))
        topRight.tap()

        XCTFail("Expected Manage menu button")
    }

    private func openSelectionMenu() {
        let direct = app.buttons["ellipsis.circle.fill"].firstMatch
        if direct.waitForExistence(timeout: 1), direct.isHittable {
            direct.tap()
            return
        }

        let menuButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'ellipsis'"))
        if menuButtons.firstMatch.waitForExistence(timeout: 1) {
            for index in 0..<menuButtons.count {
                let button = menuButtons.element(boundBy: index)
                if button.exists && button.isHittable {
                    button.tap()
                    return
                }
            }
        }

        let fallback = app.coordinate(withNormalizedOffset: CGVector(dx: 0.91, dy: 0.86))
        fallback.tap()
    }

    private func focusSearchField(_ searchField: XCUIElement) {
        searchField.tap()
        if hasKeyboardFocus(searchField) || app.keyboards.firstMatch.exists { return }

        let absolute = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: searchField.frame.minX + 24, dy: searchField.frame.midY))
        absolute.tap()
        if hasKeyboardFocus(searchField) || app.keyboards.firstMatch.exists { return }

        searchField.doubleTap()
        XCTAssertTrue(hasKeyboardFocus(searchField) || app.keyboards.firstMatch.waitForExistence(timeout: 2), "Expected search field focus")
    }

    private func hasKeyboardFocus(_ element: XCUIElement) -> Bool {
        guard let hasFocus = element.value(forKey: "hasKeyboardFocus") as? Bool else { return false }
        return hasFocus
    }
}

struct CompendiumDetailPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 10) -> Self {
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: timeout), "Expected compendium detail navigation bar")
        return self
    }

    @discardableResult
    func openMenuAction(_ label: String) -> CreatureEditPage {
        let moreButton = app.buttons["More"].firstMatch
        if moreButton.waitForExistence(timeout: 2), moreButton.isHittable {
            moreButton.tap()
        } else {
            let menuButton = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'ellipsis'"))
                .firstMatch
            if menuButton.exists && menuButton.isHittable {
                menuButton.tap()
            } else {
                let navBarButtons = app.navigationBars.buttons.allElementsBoundByIndex
                let fallback = navBarButtons.last(where: { $0.exists && $0.isHittable })
                XCTAssertNotNil(fallback, "Expected a tappable detail menu button")
                fallback?.tap()
            }
        }

        let actionButton = app.buttons[label].firstMatch
        if actionButton.waitForExistence(timeout: 5) {
            actionButton.tap()
        } else {
            let actionMenuItem = app.menuItems[label].firstMatch
            XCTAssertTrue(actionMenuItem.waitForExistence(timeout: 5), "Expected menu action \(label)")
            actionMenuItem.tap()
        }

        return CreatureEditPage(app: app).waitForVisible()
    }

    @discardableResult
    func goBackToCompendium() -> CompendiumPage {
        for _ in 0..<4 {
            if app.buttons["Monsters"].exists || app.searchFields.firstMatch.exists {
                return CompendiumPage(app: app).waitForVisible(timeout: 5)
            }

            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Expected back button from detail")
            backButton.tap()
        }

        XCTFail("Expected to navigate back to Compendium index")
        return CompendiumPage(app: app).waitForVisible()
    }
}

struct CompendiumDocumentsPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 20) -> Self {
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: timeout), "Expected Documents sheet")
        return self
    }

    @discardableResult
    func addRealm(named name: String) -> Self {
        let addRealmButton = app.buttons["Add realm"].firstMatch
        XCTAssertTrue(addRealmButton.waitForExistence(timeout: 10), "Expected Add realm button")
        if addRealmButton.isHittable {
            addRealmButton.tap()
        } else {
            addRealmButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        let editRealm = EditRealmPage(app: app).waitForVisible()
        _ = editRealm.setName(name).tapDone()
        return waitForVisible()
    }

    @discardableResult
    func addDocument(named name: String, realm realmName: String) -> Self {
        let openedFromRealmMenu = openAddDocumentFromRealmMenu(named: realmName)
        if !openedFromRealmMenu {
            let addDocumentButton = app.buttons["Add document"].firstMatch
            XCTAssertTrue(addDocumentButton.waitForExistence(timeout: 10), "Expected Add document button")
            if addDocumentButton.isHittable {
                addDocumentButton.tap()
            } else {
                addDocumentButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }

        let editDocument = CompendiumDocumentEditPage(app: app).waitForVisible()
        _ = editDocument.setName(name)
        if !openedFromRealmMenu {
            _ = editDocument.selectRealm(named: realmName)
        }
        _ = editDocument.tapDone()
        return waitForVisible()
    }

    @discardableResult
    func openDocument(named name: String) -> CompendiumDocumentEditPage {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", name)
        let button = app.buttons.matching(predicate).firstMatch
        if button.waitForExistence(timeout: 10) {
            button.tap()
            return CompendiumDocumentEditPage(app: app).waitForVisible()
        }

        let label = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 10), "Expected document row containing \(name)")
        let absolute = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: label.frame.midX, dy: label.frame.midY))
        absolute.tap()
        return CompendiumDocumentEditPage(app: app).waitForVisible()
    }

    @discardableResult
    func openFirstDocument() -> CompendiumDocumentEditPage {
        if app.buttons["Edit realm"].firstMatch.exists || app.buttons["Remove empty realm"].firstMatch.exists {
            let outside = app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.10))
            outside.tap()
        }

        let candidates = app.buttons.allElementsBoundByIndex.filter { button in
            guard button.exists, button.isHittable else { return false }
            let label = button.label
            guard label.contains(",") else { return false }
            return button.frame.midY > 120 && button.frame.midY < 760
        }

        guard let first = candidates.first else {
            XCTFail("Expected at least one document row")
            return CompendiumDocumentEditPage(app: app).waitForVisible()
        }
        first.tap()
        return CompendiumDocumentEditPage(app: app).waitForVisible()
    }

    @discardableResult
    func doneToCompendium() -> CompendiumPage {
        let doneButton = app.navigationBars["Documents"].buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Expected Done button on Documents sheet")
        doneButton.tap()
        return CompendiumPage(app: app).waitForVisible()
    }

    private func openAddDocumentFromRealmMenu(named realmName: String) -> Bool {
        let realmLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", realmName)).firstMatch
        guard realmLabel.waitForExistence(timeout: 4) else { return false }

        let rowY = realmLabel.frame.midY
        let ellipsisButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'ellipsis'"))
            .allElementsBoundByIndex
            .filter { $0.exists && abs($0.frame.midY - rowY) < 40 }
            .sorted { abs($0.frame.midY - rowY) < abs($1.frame.midY - rowY) }

        if let menuButton = ellipsisButtons.first {
            if menuButton.isHittable {
                menuButton.tap()
            } else {
                menuButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        } else {
            let absolute = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: app.frame.width * 0.92, dy: rowY))
            absolute.tap()
        }

        let addDocumentButton = app.buttons["Add document"].firstMatch
        if addDocumentButton.waitForExistence(timeout: 3) {
            addDocumentButton.tap()
            return true
        }

        let addDocumentItem = app.menuItems["Add document"].firstMatch
        if addDocumentItem.waitForExistence(timeout: 3) {
            addDocumentItem.tap()
            return true
        }

        return false
    }
}

struct EditRealmPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 10) -> Self {
        let addTitle = app.navigationBars["Add realm"].firstMatch
        if addTitle.waitForExistence(timeout: timeout) { return self }
        let editTitle = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS[c] 'Edit'")).firstMatch
        XCTAssertTrue(editTitle.waitForExistence(timeout: timeout), "Expected realm editor")
        return self
    }

    @discardableResult
    func setName(_ name: String) -> Self {
        let field = app.textFields["Realm name"].firstMatch.exists ? app.textFields["Realm name"].firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Expected realm name field")
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != "Realm name" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(name)
        return self
    }

    @discardableResult
    func tapDone() -> CompendiumDocumentsPage {
        let doneButton = app.navigationBars.buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Expected Done in realm editor")
        doneButton.tap()
        return CompendiumDocumentsPage(app: app).waitForVisible()
    }
}

struct CompendiumDocumentEditPage {
    let app: XCUIApplication

    var isRealmSelectionVisible: Bool {
        app.buttons["Select"].firstMatch.exists || app.staticTexts["Realm"].firstMatch.exists
    }

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 10) -> Self {
        let addTitle = app.navigationBars["Add document"].firstMatch
        if addTitle.waitForExistence(timeout: timeout) { return self }
        let editTitle = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS[c] 'Edit'")).firstMatch
        if editTitle.waitForExistence(timeout: 1) { return self }

        let cancelButton = app.navigationBars.buttons["Cancel"].firstMatch
        let doneButton = app.navigationBars.buttons["Done"].firstMatch
        if cancelButton.waitForExistence(timeout: timeout), doneButton.exists {
            return self
        }

        XCTAssertTrue(false, "Expected document editor")
        return self
    }

    @discardableResult
    func setName(_ name: String) -> Self {
        let field = app.textFields["Document name"].firstMatch.exists ? app.textFields["Document name"].firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Expected document name field")
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != "Document name" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(name)
        return self
    }

    @discardableResult
    func selectRealm(named realmName: String) -> Self {
        let selectButtons = app.buttons.matching(NSPredicate(format: "label == 'Select'"))
            .allElementsBoundByIndex
            .filter { $0.exists && $0.frame.midY > 150 }
            .sorted { $0.frame.midY < $1.frame.midY }

        if let selectButton = selectButtons.first {
            if selectButton.isHittable {
                selectButton.tap()
            } else {
                selectButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        } else {
            let realmLabel = app.staticTexts["Realm"].firstMatch
            XCTAssertTrue(realmLabel.waitForExistence(timeout: 10), "Expected Realm field")
            let absolute = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: realmLabel.frame.maxX + 140, dy: realmLabel.frame.midY))
            absolute.tap()
        }

        let predicate = NSPredicate(format: "label CONTAINS[c] %@", realmName)
        let realmButton = app.buttons.matching(predicate).firstMatch
        if realmButton.waitForExistence(timeout: 5) {
            realmButton.tap()
        } else {
            let realmText = app.staticTexts.matching(predicate).firstMatch
            XCTAssertTrue(realmText.waitForExistence(timeout: 5), "Expected realm option \(realmName)")
            realmText.tap()
        }
        return self
    }

    @discardableResult
    func tapDone() -> CompendiumDocumentsPage {
        let doneButton = app.navigationBars.buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Expected Done in document editor")
        doneButton.tap()
        return CompendiumDocumentsPage(app: app).waitForVisible()
    }

    @discardableResult
    func openItems() -> CompendiumPage {
        let button = app.buttons["View items in document"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Expected View items in document")
        button.tap()
        return CompendiumPage(app: app).waitForVisible()
    }
}

struct CompendiumTransferPage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 10) -> Self {
        let move = app.navigationBars["Move"].firstMatch
        if move.waitForExistence(timeout: timeout) { return self }
        XCTAssertTrue(app.navigationBars["Copy"].firstMatch.waitForExistence(timeout: timeout), "Expected transfer sheet")
        return self
    }

    @discardableResult
    func selectDestinationDocument(named documentName: String) -> Self {
        let selectButton = app.buttons["Select"].firstMatch
        if selectButton.exists && selectButton.isHittable {
            selectButton.tap()
        } else {
            let destinationLabel = app.staticTexts["Destination"].firstMatch
            XCTAssertTrue(destinationLabel.waitForExistence(timeout: 10), "Expected Destination field")
            let absolute = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: destinationLabel.frame.maxX + 140, dy: destinationLabel.frame.midY))
            absolute.tap()
        }

        let predicate = NSPredicate(format: "label CONTAINS[c] %@", documentName)
        let destinationButton = app.buttons.matching(predicate).firstMatch
        if destinationButton.waitForExistence(timeout: 5) {
            destinationButton.tap()
        } else {
            let destinationText = app.staticTexts.matching(predicate).firstMatch
            XCTAssertTrue(destinationText.waitForExistence(timeout: 5), "Expected destination \(documentName)")
            destinationText.tap()
        }
        return self
    }

    @discardableResult
    func confirmTransfer(action: String) -> CompendiumPage {
        let predicate = NSPredicate(format: "label BEGINSWITH[c] %@", action)
        let button = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Expected transfer button for \(action)")
        button.tap()
        return CompendiumPage(app: app).waitForVisible(timeout: 20)
    }

    @discardableResult
    func cancel() -> CompendiumPage {
        let cancelButton = app.navigationBars.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10), "Expected Cancel in transfer sheet")
        cancelButton.tap()
        return CompendiumPage(app: app).waitForVisible()
    }
}

struct DicePage {
    let app: XCUIApplication

    @discardableResult
    func waitForVisible(timeout: TimeInterval = 20) -> Self {
        if app.buttons["1d20"].waitForExistence(timeout: timeout) { return self }
        if app.buttons["Roll"].waitForExistence(timeout: timeout) { return self }
        XCTAssertTrue(app.buttons["Re-roll"].waitForExistence(timeout: timeout), "Dice roller should be visible")
        return self
    }

    @discardableResult
    func clearLogIfPresent() -> Self {
        let clearLogButton = app.buttons["Clear log"].firstMatch
        if clearLogButton.waitForExistence(timeout: 1) {
            tapPossiblyNonHittable(clearLogButton)
        }
        return self
    }

    @discardableResult
    func tapEditIfPresent() -> Self {
        let editButton = app.buttons["Edit"].firstMatch
        if editButton.waitForExistence(timeout: 2) {
            editButton.tap()
        }
        return self
    }

    @discardableResult
    func clearExpressionIfPresent() -> Self {
        let clearButton = app.buttons["Clear"].firstMatch
        if clearButton.waitForExistence(timeout: 2), clearButton.isHittable {
            clearButton.tap()
        }
        return self
    }

    @discardableResult
    func tapPreset(_ label: String) -> Self {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Expected dice preset \(label)")
        button.tap()
        return self
    }

    @discardableResult
    func roll() -> Self {
        let rollButton = app.buttons["Roll"].firstMatch
        XCTAssertTrue(rollButton.waitForExistence(timeout: 10), "Expected Roll button")
        rollButton.tap()
        XCTAssertTrue(app.buttons["Re-roll"].waitForExistence(timeout: 10), "Expected Re-roll after rolling")
        return self
    }

    @discardableResult
    func assertClearLogVisible(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(app.buttons["Clear log"].waitForExistence(timeout: timeout), "Expected non-empty dice log")
        return self
    }

    @discardableResult
    func clearLog() -> Self {
        let clearLogButton = app.buttons["Clear log"].firstMatch
        XCTAssertTrue(clearLogButton.waitForExistence(timeout: 10), "Expected Clear log button")
        tapPossiblyNonHittable(clearLogButton)
        return self
    }

    @discardableResult
    func assertClearLogHidden(timeout: TimeInterval = 5) -> Self {
        XCTAssertFalse(app.buttons["Clear log"].waitForExistence(timeout: timeout), "Expected dice log to be cleared")
        return self
    }

    @discardableResult
    func assertExpressionVisible(_ expressionFragment: String, timeout: TimeInterval = 10) -> Self {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", expressionFragment)
        if app.staticTexts.matching(predicate).firstMatch.waitForExistence(timeout: timeout) {
            return self
        }
        XCTAssertTrue(app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: 2), "Expected dice expression containing \(expressionFragment)")
        return self
    }

    private func tapPossiblyNonHittable(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
            return
        }

        let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.tap()
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

    func assertRoundVisible(_ round: Int, timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", "Round \(round)")
        XCTAssertTrue(app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: timeout), "Expected running encounter to show Round \(round)")
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

    func assertCombatantVisible(containing nameFragment: String, timeout: TimeInterval = 10) {
        let namePredicate = NSPredicate(format: "label CONTAINS[c] %@", nameFragment)
        XCTAssertTrue(app.staticTexts.matching(namePredicate).firstMatch.waitForExistence(timeout: timeout), "Expected combatant matching \(nameFragment)")
    }

    func assertCombatantCount(containing nameFragment: String, equals expected: Int) {
        let matchingCells = combatantCells(containing: nameFragment)
        XCTAssertEqual(matchingCells.count, expected, "Expected \(expected) combatants matching \(nameFragment) while running")
    }

    @discardableResult
    func performCombatantContextAction(containing nameFragment: String, action: String) -> Self {
        openCombatantContextMenu(containing: nameFragment)
        tapContextAction(action)
        return self
    }

    @discardableResult
    func assertCombatantContextAction(containing nameFragment: String, action: String, isVisible: Bool) -> Self {
        openCombatantContextMenu(containing: nameFragment)
        let actionExists = app.buttons[action].firstMatch.exists || app.menuItems[action].firstMatch.exists
        if isVisible {
            XCTAssertTrue(actionExists, "Expected context action \(action) for \(nameFragment)")
        } else {
            XCTAssertFalse(actionExists, "Expected context action \(action) to be absent for \(nameFragment)")
        }
        dismissContextMenu()
        return self
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

    private func openCombatantContextMenu(containing nameFragment: String) {
        let matchingCells = combatantCells(containing: nameFragment)
        guard let targetCell = matchingCells.first else {
            XCTFail("Expected combatant cell matching \(nameFragment)")
            return
        }

        let absolute = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: targetCell.frame.midX, dy: targetCell.frame.midY))
        absolute.press(forDuration: 1.0)
    }

    private func tapContextAction(_ action: String) {
        let actionButton = app.buttons[action].firstMatch
        if actionButton.waitForExistence(timeout: 5) {
            actionButton.tap()
            return
        }

        let actionMenuItem = app.menuItems[action].firstMatch
        XCTAssertTrue(actionMenuItem.waitForExistence(timeout: 5), "Expected context action \(action)")
        actionMenuItem.tap()
    }

    private func dismissContextMenu() {
        let dismissButton = app.buttons["Dismiss context menu"].firstMatch
        if dismissButton.exists && dismissButton.isHittable {
            dismissButton.tap()
            return
        }

        let outside = app.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.10))
        outside.tap()
    }

    private func combatantCells(containing nameFragment: String) -> [XCUIElement] {
        let lower = nameFragment.lowercased()
        return app.cells.allElementsBoundByIndex.filter { cell in
            guard cell.exists else { return false }
            guard cell.frame.midY > 120, cell.frame.midY < 760 else { return false }
            return cell.staticTexts.allElementsBoundByIndex.contains { label in
                label.exists && label.label.lowercased().contains(lower)
            }
        }
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

    func assertLogContains(_ textFragment: String, timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", textFragment)
        if app.staticTexts.matching(predicate).firstMatch.waitForExistence(timeout: timeout) {
            return
        }
        XCTAssertTrue(app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: 2), "Expected running log entry containing \(textFragment)")
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

    @discardableResult
    func openAttackResolution(containing actionTextFragment: String) -> Self {
        let actionPredicate = NSPredicate(format: "label CONTAINS[c] %@", actionTextFragment)
        let actionText = app.staticTexts.matching(actionPredicate).firstMatch
        scrollToElement(actionText)
        XCTAssertTrue(actionText.waitForExistence(timeout: 10), "Expected action text containing \(actionTextFragment)")

        let absolute = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: actionText.frame.midX, dy: actionText.frame.midY))
        absolute.tap()
        return self
    }

    func assertAttackResolutionVisible(timeout: TimeInterval = 10) {
        let melee = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Weapon Attack'")).firstMatch
        XCTAssertTrue(melee.waitForExistence(timeout: timeout), "Expected attack resolution to be visible")
    }

    @discardableResult
    func dismissAttackResolution() -> Self {
        // Action resolution is displayed as an overlay/popover; tap outside it.
        let outside = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.08))
        outside.tap()
        return waitForVisible()
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

    @discardableResult
    func doneToRunningEncounter() -> RunningEncounterPage {
        let doneButton = app.buttons["Done"].firstMatch
        if doneButton.waitForExistence(timeout: 5), doneButton.isHittable {
            doneButton.tap()
            return RunningEncounterPage(app: app).waitForVisible()
        }

        for _ in 0..<3 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            start.press(forDuration: 0.01, thenDragTo: end)
            if app.buttons["Next turn"].waitForExistence(timeout: 1.5) {
                return RunningEncounterPage(app: app).waitForVisible()
            }
        }

        XCTFail("Expected combatant detail to dismiss to running encounter")
        return RunningEncounterPage(app: app).waitForVisible()
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
        focusTextField(nameField)

        if let currentValue = nameField.value as? String, !currentValue.isEmpty, currentValue != "Name" {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            nameField.typeText(deleteString)
        }

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

    @discardableResult
    func tapAddToCompendiumDetail() -> CompendiumDetailPage {
        let addButton = app.navigationBars.buttons["Add"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Expected Add button in creature editor")
        addButton.tap()

        let nameField = app.textFields["Name"].firstMatch
        if nameField.exists {
            let gone = NSPredicate(format: "exists == false")
            let waiter = XCTNSPredicateExpectation(predicate: gone, object: nameField)
            _ = XCTWaiter().wait(for: [waiter], timeout: 10)
        }

        return CompendiumDetailPage(app: app).waitForVisible()
    }

    @discardableResult
    func tapDone() -> CompendiumDetailPage {
        let doneButtons = app.navigationBars.buttons.matching(NSPredicate(format: "label == 'Done'"))
        XCTAssertTrue(doneButtons.firstMatch.waitForExistence(timeout: 10), "Expected Done button in creature editor")

        var tapped = false
        for index in 0..<doneButtons.count {
            let button = doneButtons.element(boundBy: index)
            if button.exists && button.isHittable {
                button.tap()
                tapped = true
                break
            }
        }
        if !tapped {
            doneButtons.firstMatch.tap()
        }

        return CompendiumDetailPage(app: app).waitForVisible()
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

    private func focusTextField(_ field: XCUIElement) {
        field.tap()
        if hasKeyboardFocus(field) || app.keyboards.firstMatch.exists { return }

        let absolute = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: field.frame.minX + 18, dy: field.frame.midY))
        absolute.tap()
        if hasKeyboardFocus(field) || app.keyboards.firstMatch.exists { return }

        field.doubleTap()
        XCTAssertTrue(hasKeyboardFocus(field) || app.keyboards.firstMatch.waitForExistence(timeout: 2), "Expected text field focus")
    }

    private func hasKeyboardFocus(_ element: XCUIElement) -> Bool {
        guard let hasFocus = element.value(forKey: "hasKeyboardFocus") as? Bool else { return false }
        return hasFocus
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
