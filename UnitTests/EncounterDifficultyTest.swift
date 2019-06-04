//
//  EncounterDifficultyTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 24/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
@testable import Construct
import XCTest

class EncounterDifficultyTest: XCTestCase {

    func test1() {
        let sut = EncounterDifficulty(party: [1, 1, 1], monsters: [.oneQuarter])
        XCTAssertEqual(sut.partyThresholds.easy, 75)
        XCTAssertEqual(sut.partyThresholds.medium, 150)
        XCTAssertEqual(sut.partyThresholds.hard, 225)
        XCTAssertEqual(sut.partyThresholds.deadly, 300)

        XCTAssertEqual(sut.adjustedXp, 50)
        XCTAssertEqual(sut.category, nil)
    }


    func test2() {
        let sut = EncounterDifficulty(party: [1, 1, 1], monsters: [.oneQuarter, .oneQuarter])
        XCTAssertEqual(sut.partyThresholds.easy, 75)
        XCTAssertEqual(sut.partyThresholds.medium, 150)
        XCTAssertEqual(sut.partyThresholds.hard, 225)
        XCTAssertEqual(sut.partyThresholds.deadly, 300)

        XCTAssertEqual(sut.adjustedXp, 150)
        XCTAssertEqual(sut.category, .medium)
    }

    func testHetrogenousParty() {
        let sut = EncounterDifficulty(party: [1, 1, 1, 3, 3], monsters: [.init(integer: 1), .init(integer: 3)])
        XCTAssertEqual(sut.partyThresholds.easy, 225)
        XCTAssertEqual(sut.partyThresholds.medium, 450)
        XCTAssertEqual(sut.partyThresholds.hard, 675)
        XCTAssertEqual(sut.partyThresholds.deadly, 1100)

        XCTAssertEqual(sut.adjustedXp, 1350)
        XCTAssertEqual(sut.category, .deadly)
    }

    func testSmallParty() {
        let sut = EncounterDifficulty(party: [3, 3], monsters: [.init(integer: 1)])

        XCTAssertEqual(sut.partyThresholds.easy, 150)
        XCTAssertEqual(sut.partyThresholds.medium, 300)
        XCTAssertEqual(sut.partyThresholds.hard, 450)
        XCTAssertEqual(sut.partyThresholds.deadly, 800)

        XCTAssertEqual(sut.adjustedXp, 300)
        XCTAssertEqual(sut.category, .medium)
    }

    func testLargeParty() {
        let sut = EncounterDifficulty(party: [1, 1, 1, 1, 1, 1], monsters: [.init(integer: 4)])

        XCTAssertEqual(sut.partyThresholds.easy, 150)
        XCTAssertEqual(sut.partyThresholds.medium, 300)
        XCTAssertEqual(sut.partyThresholds.hard, 450)
        XCTAssertEqual(sut.partyThresholds.deadly, 600)

        XCTAssertEqual(sut.adjustedXp, 550)
        XCTAssertEqual(sut.category, .hard)
    }

}
