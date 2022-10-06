//
//  DDBCharacterSheetURLParserTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine
import Compendium

class DDBCharacterSheetURLParserTest: XCTestCase {

    func testProfileURL() {
        let res = DDBCharacterSheetURLParser.parse("https://www.dndbeyond.com/profile/McCalculator/characters/4295903")
        XCTAssertEqual(res, "4295903")
    }

    func testProfileURLWithoutHTTPS() {
        let res = DDBCharacterSheetURLParser.parse("www.dndbeyond.com/profile/McCalculator/characters/4295903")
        XCTAssertEqual(res, "4295903")
    }

    func testShareURL() {
        let res = DDBCharacterSheetURLParser.parse("https://ddb.ac/characters/4295903/m6dWjQ")
        XCTAssertEqual(res, "4295903")
    }

    func testShareURLWithoutHTTPS() {
        let res = DDBCharacterSheetURLParser.parse("ddb.ac/characters/4295903/m6dWjQ")
        XCTAssertEqual(res, "4295903")
    }

}
