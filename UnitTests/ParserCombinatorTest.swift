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

    func testMatches() {
        let text = "1 flew over 2 cuck00s n3st"
        XCTAssertEqual(
            digit().matches(in: text),
            [
                Located(value: "1", range: 0..<1),
                Located(value: "2", range: 12..<13),
                Located(value: "0", range: 18..<19),
                Located(value: "0", range: 19..<20),
                Located(value: "3", range: 23..<24),
            ]
        )
    }

    func testSkip() {
        var text = Remainder("abcdefg")

        let res1 = skip(until: char("a")).parse(&text)
        XCTAssertEqual(res1?.0, "a")
        XCTAssertEqual(res1?.1, "a")
        XCTAssertEqual(text.string(), "bcdefg")

        let res2 = skip(until: char("f")).parse(&text)
        XCTAssertEqual(res2?.0, "bcde")
        XCTAssertEqual(res2?.1, "f")
        XCTAssertEqual(text.string(), "g")
    }

    func testWord() {
        var text = Remainder("hello's world")

        let res1 = word().parse(&text)
        XCTAssertEqual(res1, "hello's")
        XCTAssertEqual(text.string(), " world")
    }

}
