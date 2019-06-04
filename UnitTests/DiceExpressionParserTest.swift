//
//  DiceExpressionParserTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 23/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine

class DiceExpressionParserTest: XCTestCase {

    func test() {
        let sut = DiceExpressionParser.parse
        XCTAssertEqual(sut("1d6"), DiceExpression.dice(count: 1, die: .d6))
        XCTAssertEqual(sut("1d6 + 1"), 1.d(6) + 1)
        XCTAssertEqual(sut("1d6 + 1d4"), 1.d(6) + 1.d(4))
        XCTAssertEqual(sut("1d6 + 1d4 + 3"), 1.d(6) + 1.d(4) + 3)
    }

}
