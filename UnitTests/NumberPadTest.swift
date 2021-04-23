//
//  NumberPadTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 23/04/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct

class NumberPadTest: XCTestCase {
    func testInit() {
        XCTAssertEqual(NumberPadViewState(value: 1).value, 1)
        XCTAssertEqual(NumberPadViewState(value: 9).value, 9)
        XCTAssertEqual(NumberPadViewState(value: 12).value, 12)
        XCTAssertEqual(NumberPadViewState(value: 123).value, 123)
    }
}
