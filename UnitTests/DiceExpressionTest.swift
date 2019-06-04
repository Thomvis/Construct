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

}
