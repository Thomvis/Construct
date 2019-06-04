//
//  ParserCombinatorTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 02/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct

class ParserCombinatorTest: XCTestCase {

    func testWithRange() {
        XCTAssertEqual(char("a").withRange().run("a")?.1, 0...0)
        XCTAssertEqual(zip(char("a"), any(char("b")).withRange(), char("c")).run("abbbbc")?.1.1, 1...4)
    }

}
