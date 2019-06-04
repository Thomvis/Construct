//
//  RolledDiceExpressionTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 30/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct

class RolledDiceExpressionTest: XCTestCase {

    func testRoll() {
        var rng = EverIncreasingRandomNumberGenerator()
        XCTAssertEqual(10.d(20).roll(rng: &rng).total, 55)
    }

    func testSubtractDice() {
        var rng = EverIncreasingRandomNumberGenerator()
        let sut = (1.d(20) - 1.d(4)).roll(rng: &rng)
        XCTAssertEqual(sut.total, -1)
    }

    func testNegativeDice() {
        var rng = EverIncreasingRandomNumberGenerator()
        let sut = (-1).d(20).roll(rng: &rng)
        XCTAssertEqual(sut.total, -1)
    }

    func testReroll() {
        var rng = EverIncreasingRandomNumberGenerator()
        var sut = 10.d(20).roll(rng: &rng)
        sut.rerollDice(0, rng: &rng)
        XCTAssertEqual(sut.total, 65)
    }
}

struct EverIncreasingRandomNumberGenerator: RandomNumberGenerator {

    var n: UInt64 = 0

    public mutating func next() -> UInt64 {
        defer { n += 1 }
        return n
    }

}
