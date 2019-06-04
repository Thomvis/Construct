//
//  ImprovedInitiativeDataSourceReaderTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 20/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//
import Foundation
import XCTest
@testable import Construct
import Combine
import SnapshotTesting

class ImprovedInitiativeDataSourceReaderTest: XCTestCase {

    var dataSource: CompendiumDataSource!

    override func setUp() {
        dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ii_mm", ofType: "json")!)
    }

    func test() {
        let sut = ImprovedInitiativeDataSourceReader(dataSource: dataSource)
        let job = sut.read()

        let e = expectation(description: "Receive items")
        _ = job.items.collect().sink(receiveCompletion: { c in
            if case .failure(let e) = c {
                XCTFail(e.localizedDescription)
            }
        }) { items in
            XCTAssertEqual(items.count, 1)

            // Some (random) checks
            let last = try! XCTUnwrap(items.last) as! Monster
            XCTAssertEqual(last.stats.name, "Adult White Dragon")
            XCTAssertEqual(last.stats.size, .huge)
            XCTAssertEqual(last.stats.type, "dragon")
            XCTAssertEqual(last.stats.subtype, nil)
            XCTAssertEqual(last.stats.alignment, .chaoticEvil)
            XCTAssertEqual(last.stats.hitPoints, 200)
            XCTAssertEqual(last.stats.hitPointDice, 16.d(12) + 96)
            XCTAssertEqual(last.stats.armorClass, 18)
            XCTAssertEqual(last.stats.armor.count, 1)
            XCTAssertEqual(last.stats.armor[0].name, "natural armor")

            XCTAssertEqual(last.stats.savingThrows.count, 4)
            XCTAssertEqual(last.stats.skills.count, 2)

            e.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testTypeComponentParser() {
        let largePlantUnaligned = TypeComponent.parser.run("Large plant,  unaligned")
        XCTAssertEqual(largePlantUnaligned?.0, .large)
        XCTAssertEqual(largePlantUnaligned?.1, "plant")
        XCTAssertEqual(largePlantUnaligned?.2, nil)
        XCTAssertEqual(largePlantUnaligned?.3, Alignment.unaligned)

        let mediumDragonUnaligned = TypeComponent.parser.run("Medium dragon, unaligned")
        XCTAssertEqual(mediumDragonUnaligned?.0, .medium)
        XCTAssertEqual(mediumDragonUnaligned?.1, "dragon")
        XCTAssertEqual(mediumDragonUnaligned?.2, nil)
        XCTAssertEqual(mediumDragonUnaligned?.3, Alignment.unaligned)

        let mediumHumanoidGnollChaoticNeutral = TypeComponent.parser.run("M humanoid (gnoll), chaotic neutral")
        XCTAssertEqual(mediumHumanoidGnollChaoticNeutral?.0, .medium)
        XCTAssertEqual(mediumHumanoidGnollChaoticNeutral?.1, "humanoid")
        XCTAssertEqual(mediumHumanoidGnollChaoticNeutral?.2, "gnoll")
        XCTAssertEqual(mediumHumanoidGnollChaoticNeutral?.3, Alignment.chaoticNeutral)

        let largeBeastNeutral = TypeComponent.parser.run("Large beast, monster manual, neutral")
        XCTAssertEqual(largeBeastNeutral?.0, .large)
        XCTAssertEqual(largeBeastNeutral?.1, "beast")
        XCTAssertEqual(largeBeastNeutral?.2, nil)
        XCTAssertEqual(largeBeastNeutral?.3, Alignment.neutral)

    }

}
