//
//  DiceExpressionTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 01/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import CustomDump
import Dice

class DiceExpressionTest: XCTestCase {

    func testAppendDiceToZero() {
        XCTAssertEqual(DiceExpression.number(0).appending(.dice(count: 1, die: .d4)), .dice(count: 1, die: .d4))
    }

    func testAppendFlipNumberToNegative() {
        XCTAssertEqual(DiceExpression.number(1).appending(.number(-2)), .number(-1))
    }

    func testAppendFlipNumberToPositive() {
        XCTAssertEqual(DiceExpression.number(-1).appending(.number(2)), .number(1))
    }

    func testAppendFlipModifierToNegative() {
        XCTAssertEqual((1.d(20) + 1).appending(.number(-2)), (1.d(20) - 1))
    }

    func testAppendFlipModifierToPositive() {
        XCTAssertEqual((1.d(20) - 1).appending(.number(2)), (1.d(20) + 1))
    }

    func testAppendFlipNestedModifierToNegative() {
        XCTAssertEqual((1.d(20) + 1 + 1).appending(.number(-2)), (1.d(20) + 1 - 1))
    }

    func testAppendFlipNestedModifierToPositive() {
        XCTAssertEqual((1.d(20) + 1 - 1).appending(.number(2)), (1.d(20) + 1 + 1))
    }

    func testAppendFlipDiceToNegative() {
        XCTAssertEqual(1.d(20).appending((-2).d(20)), (-1).d(20))
    }

    func testAppendFlipDiceToPositive() {
        XCTAssertEqual((-1).d(20).appending(2.d(20)), 1.d(20))
    }

    func testAppendFlipSecondDiceToNegative() {
        XCTAssertEqual((1.d(20) + 1.d(4)).appending((-2).d(4)), 1.d(20) - 1.d(4))
    }

    func testAppendFlipSecondDiceToPositive() {
        XCTAssertEqual((1.d(20) - 1.d(4)).appending(2.d(4)), 1.d(20) + 1.d(4))
    }

    func testAppendNegativeThenPositive() {
        XCTAssertEqual(1.d(12).appending((-1).d(10))?.appending(1.d(6)), 1.d(12) - 1.d(10) + 1.d(6))
    }

    func testAppendingZeroingNestedNumber() {
        XCTAssertEqual((1.d(12) + 1).appending(.number(-1)), 1.d(12))
    }

    func testAppendingZeroingNestedDice() {
        XCTAssertEqual((1.d(4) + 1.d(12)).appending((-1).d(12)), 1.d(4))
    }

    func testCodable() {
        let expression: DiceExpression = .compound(.dice(count: 2, die: Die(color: .red, sides: 20)), .add, .number(3))
        let data = try! JSONEncoder().encode(expression)
        let outcome = try! JSONDecoder().decode(DiceExpression.self, from: data)
        XCTAssertEqual(expression, outcome)
    }

    func testProbabilityDistributionForTwoD6() {
        let distribution = 2.d(6).probabilityDistribution

        expectNoDifference(distribution.outcomes.map(\.value), Array(2...12))
        XCTAssertEqual(distribution.probability(of: 2), 1.0 / 36.0, accuracy: 0.000_000_000_1)
        XCTAssertEqual(distribution.probability(of: 7), 6.0 / 36.0, accuracy: 0.000_000_000_1)
        XCTAssertEqual(distribution.probability(of: 12), 1.0 / 36.0, accuracy: 0.000_000_000_1)
    }

    func testProbabilityDistributionWithModifier() {
        let distribution = (2.d(6) + 3).probabilityDistribution

        expectNoDifference(distribution.outcomes.map(\.value), Array(5...15))
        XCTAssertEqual(distribution.probability(of: 10), 6.0 / 36.0, accuracy: 0.000_000_000_1)
    }

    func testProbabilityDistributionSubtractsDice() {
        let distribution = (1.d(4) - 1.d(4)).probabilityDistribution

        expectNoDifference(distribution.outcomes.map(\.value), Array(-3...3))
        XCTAssertEqual(distribution.probability(of: -3), 1.0 / 16.0, accuracy: 0.000_000_000_1)
        XCTAssertEqual(distribution.probability(of: 0), 4.0 / 16.0, accuracy: 0.000_000_000_1)
        XCTAssertEqual(distribution.probability(of: 3), 1.0 / 16.0, accuracy: 0.000_000_000_1)
    }

    func testCumulativeProbabilityDisplayModes() {
        let distribution = 1.d(4).probabilityDistribution
        let atLeast = distribution.outcomes(displayMode: .atLeast)
        let atMost = distribution.outcomes(displayMode: .atMost)

        expectNoDifference(atLeast.map(\.value), [1, 2, 3, 4])
        XCTAssertEqual(atLeast[0].probability, 1.0, accuracy: 0.000_000_000_1)
        XCTAssertEqual(atLeast[2].probability, 0.5, accuracy: 0.000_000_000_1)
        XCTAssertEqual(atLeast[3].probability, 0.25, accuracy: 0.000_000_000_1)

        expectNoDifference(atMost.map(\.value), [1, 2, 3, 4])
        XCTAssertEqual(atMost[0].probability, 0.25, accuracy: 0.000_000_000_1)
        XCTAssertEqual(atMost[1].probability, 0.5, accuracy: 0.000_000_000_1)
        XCTAssertEqual(atMost[3].probability, 1.0, accuracy: 0.000_000_000_1)
    }

    func testCumulativeProbabilityAtMost() {
        let distribution = 2.d(6).probabilityDistribution

        XCTAssertEqual(distribution.cumulativeProbability(atMost: 1), 0, accuracy: 0.000_000_000_1)
        XCTAssertEqual(distribution.cumulativeProbability(atMost: 2), 1.0 / 36.0, accuracy: 0.000_000_000_1)
        XCTAssertEqual(distribution.cumulativeProbability(atMost: 7), 21.0 / 36.0, accuracy: 0.000_000_000_1)
        XCTAssertEqual(distribution.cumulativeProbability(atMost: 12), 1, accuracy: 0.000_000_000_1)
    }

}
