import Foundation
import StoreKitTest
import XCTest

final class ConstructTipJarUITests: ConstructUITestCase {
    private var storeKitSession: SKTestSession?

    override func setUp() {
        super.setUp()

        let storeKitURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Construct.storekit")

        storeKitSession = try? SKTestSession(contentsOf: storeKitURL)
        storeKitSession?.disableDialogs = true
        storeKitSession?.askToBuyEnabled = false
        storeKitSession?.clearTransactions()
    }

    override func tearDown() {
        storeKitSession?.resetToDefaultState()
        storeKitSession = nil
        super.tearDown()
    }

    func testTipJarFlow() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let tipJar = adventure
            .openSettings()
            .openTipJar()

        tipJar.tapAnyPurchaseButton()

        let storeKitService = XCUIApplication(bundleIdentifier: "com.apple.StoreKitUIService")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        let serviceBuyButton = storeKitService.buttons["Buy"].firstMatch
        if serviceBuyButton.waitForExistence(timeout: 5) {
            serviceBuyButton.tap()
        }

        let serviceConfirmButton = storeKitService.buttons["Confirm"].firstMatch
        if serviceConfirmButton.waitForExistence(timeout: 5) {
            serviceConfirmButton.tap()
        }

        let springboardBuyButton = springboard.buttons["Buy"].firstMatch
        if springboardBuyButton.waitForExistence(timeout: 5) {
            springboardBuyButton.tap()
        }

        tipJar.assertThankYouVisible()
    }
}
