import XCTest

final class ConstructDiceUITests: ConstructUITestCase {

    func testDiceRollerFlow() {
        let adventure = launchIntoAdventureBySkippingOnboarding()
        let dice = adventure
            .openDice()
            .waitForVisible()
            .clearLogIfPresent()
            .clearExpressionIfPresent()

        dice
            .tapPreset("1d20")
            .roll()
            .assertClearLogVisible()
            .tapEditIfPresent()
            .tapPreset("+5")
            .roll()
            .assertClearLogVisible()
            .clearLogIfPresent()
    }
}
