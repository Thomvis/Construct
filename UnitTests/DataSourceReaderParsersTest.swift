//
//  DataSourceReaderParsersTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 11/04/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine

class DataSourceReaderParsersTest: XCTestCase {

    func testMovementParser() {
        let parser = DataSourceReaderParsers.movementDictParser

        XCTAssertEqual(parser.run("30 ft."), [.walk: 30])
        XCTAssertEqual(parser.run("30  ft."), [.walk: 30])
        XCTAssertEqual(parser.run("40 ft., burrow 40 ft., fly 80 ft."), [.walk: 40, .burrow: 40, .fly: 80])
        XCTAssertEqual(parser.run("30 ft. swim"), [.swim: 30])
        XCTAssertEqual(parser.run("30 ft. swim, 20 ft. fly"), [.swim: 30, .fly: 20])

        XCTAssertEqual(parser.run("30 ft"), [:])
        XCTAssertEqual(parser.run("30 ft "), [:])
        XCTAssertEqual(parser.run("30 ft.,burrow 40"), [:])
        XCTAssertEqual(parser.run("30,burrow 40"), [:])
    }

    func testAcParser() {
        let parser = DataSourceReaderParsers.acParser

        XCTAssert(parser.run("12 (natural armor)")! == (12, "natural armor"))
        XCTAssert(parser.run("12  (natural armor)")! == (12, "natural armor"))
        XCTAssert(parser.run("12")! == (12, nil))

        XCTAssertNil(parser.run(" 12"))
        XCTAssertNil(parser.run("natural armor"))
        XCTAssertNil(parser.run("(natural armor)"))
    }

    func testHpParser() {
        let parser = DataSourceReaderParsers.hpParser

        XCTAssert(parser.run("1 (1d6)")! == (1, 1.d(6)))
        XCTAssert(parser.run("2  (1d6)")! == (2, 1.d(6)))
        XCTAssert(parser.run("3")! == (3, nil))
        XCTAssert(parser.run("1 (")! == (1, nil))
        XCTAssert(parser.run("1 (1d6")! == (1, nil))

        XCTAssertNil(parser.run(" 1"))
        XCTAssertNil(parser.run("(1d6)"))
    }

    func testTypeParser() {
        let parser = DataSourceReaderParsers.typeParser

        let largePlantUnaligned = parser.run("Large plant,  unaligned")
        XCTAssertEqual(largePlantUnaligned?.0, .large)
        XCTAssertEqual(largePlantUnaligned?.1, "plant")
        XCTAssertEqual(largePlantUnaligned?.2, nil)
        XCTAssertEqual(largePlantUnaligned?.3, Alignment.unaligned)

        let mediumDragonUnaligned = parser.run("Medium dragon, unaligned")
        XCTAssertEqual(mediumDragonUnaligned?.0, .medium)
        XCTAssertEqual(mediumDragonUnaligned?.1, "dragon")
        XCTAssertEqual(mediumDragonUnaligned?.2, nil)
        XCTAssertEqual(mediumDragonUnaligned?.3, Alignment.unaligned)

        let mediumHumanoidGnollChaoticNeutral = parser.run("M humanoid (gnoll), chaotic neutral")
        XCTAssertEqual(mediumHumanoidGnollChaoticNeutral?.0, .medium)
        XCTAssertEqual(mediumHumanoidGnollChaoticNeutral?.1, "humanoid")
        XCTAssertEqual(mediumHumanoidGnollChaoticNeutral?.2, "gnoll")
        XCTAssertEqual(mediumHumanoidGnollChaoticNeutral?.3, Alignment.chaoticNeutral)

        let largeBeastNeutral = parser.run("Large beast, monster manual, neutral")
        XCTAssertEqual(largeBeastNeutral?.0, .large)
        XCTAssertEqual(largeBeastNeutral?.1, "beast")
        XCTAssertEqual(largeBeastNeutral?.2, nil)
        XCTAssertEqual(largeBeastNeutral?.3, Alignment.neutral)

        let dragon = parser.run("dragon, monster manual")
        XCTAssertEqual(dragon?.0, nil)
        XCTAssertEqual(dragon?.1, "dragon")
        XCTAssertEqual(dragon?.2, nil)
        XCTAssertEqual(dragon?.3, nil)
    }

}
