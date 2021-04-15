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
            XCTAssertEqual(last.stats.movement, [MovementMode.walk: 40, MovementMode.burrow: 30, MovementMode.fly: 80, MovementMode.swim: 40])
            XCTAssertEqual(last.stats.armorClass, 18)
            XCTAssertEqual(last.stats.armor.count, 1)
            XCTAssertEqual(last.stats.armor[0].name, "natural armor")

            XCTAssertEqual(last.stats.savingThrows.count, 4)
            XCTAssertEqual(last.stats.skills.count, 2)

            XCTAssertEqual(last.stats.features.count, 2)
            XCTAssertEqual(last.stats.actions.count, 6)

            XCTAssertEqual(last.stats.legendary?.description, nil)
            XCTAssertEqual(last.stats.legendary?.actions.count, 3)

            e.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

}
