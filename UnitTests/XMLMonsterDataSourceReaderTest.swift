//
//  XMLMonsterDataSourceReaderTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 09/04/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine

class XMLMonsterDataSourceReaderTest: XCTestCase {

    func test() {
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "compendium", ofType: "xml")!)
        let sut = XMLMonsterDataSourceReader(dataSource: dataSource)
        let job = sut.read()

        let e = expectation(description: "Receive items")
        _ = job.output.compactMap { $0.item }.collect().sink(receiveCompletion: { c in
            if case .failure(let e) = c {
                XCTFail(e.localizedDescription)
            }
        }) { items in
            XCTAssertEqual(items.count, 2)

            // Some (random) checks
            let dragon = try! XCTUnwrap(items.first) as! Monster
            XCTAssertEqual(dragon.stats.name, "Adult White Dragon")
            XCTAssertEqual(dragon.stats.size, .huge)
            XCTAssertEqual(dragon.stats.type, "dragon")
            XCTAssertEqual(dragon.stats.subtype, nil)
            XCTAssertEqual(dragon.stats.alignment, .chaoticEvil)
            XCTAssertEqual(dragon.stats.hitPoints, 200)
            XCTAssertEqual(dragon.stats.hitPointDice, 16.d(12) + 96)
            XCTAssertEqual(dragon.stats.movement, [MovementMode.walk: 40, MovementMode.burrow: 30, MovementMode.fly: 80, MovementMode.swim: 40])
            XCTAssertEqual(dragon.stats.armorClass, 18)
            XCTAssertEqual(dragon.stats.armor.count, 1)
            XCTAssertEqual(dragon.stats.armor[0].name, "natural armor")

            XCTAssertEqual(dragon.stats.savingThrows.count, 4)
            XCTAssertEqual(dragon.stats.skills.count, 2)

            XCTAssertEqual(dragon.stats.features.count, 2)
            XCTAssertEqual(dragon.stats.actions.count, 6)

            XCTAssertEqual(dragon.stats.legendary?.description, nil)
            XCTAssertEqual(dragon.stats.legendary?.actions.count, 3)

            let bugbear = try! XCTUnwrap(items.last) as! Monster
            XCTAssertEqual(bugbear.stats.legendary, nil)

            e.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testIncorrectFormat() {
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ii_mm", ofType: "json")!)
        let sut = XMLMonsterDataSourceReader(dataSource: dataSource)
        let job = sut.read()

        let e = expectation(description: "Receive items")
        _ = job.output.compactMap { $0.item }.collect().sink(receiveCompletion: { c in
            guard case .failure(.incompatibleDataSource) = c else { XCTFail(); return }
            e.fulfill()
        }, receiveValue: { _ in })

        waitForExpectations(timeout: 2.0, handler: nil)
    }

}
