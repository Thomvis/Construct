//
//  FractionTest.swift
//
//
//  Created by Thomas Visser on 18/08/2023.
//

import Foundation
import XCTest
import Helpers

final class FractionTest: XCTestCase {
    func testString() {
        XCTAssertEqual(Fraction(rawValue: "1/4"), .oneQuarter)
        XCTAssertEqual(Fraction(rawValue: "0.125"), .oneEighth)
    }
}
