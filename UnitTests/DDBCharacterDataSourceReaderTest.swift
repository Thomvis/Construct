//
//  DndBeyondCharacterDataSourceReaderTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine

class DndBeyondCharacterDataSourceReaderTest: XCTestCase {

    func testSarovin() {
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ddb_sarovin", ofType: "json")!)
        let sut = DDBCharacterDataSourceReader(dataSource: dataSource)
        let job = sut.read()

        let e = expectation(description: "Receive at least one item")
        _ = job.items.prefix(1).sink(receiveCompletion: { completion in
            switch completion {
            case .failure(let e): XCTFail(e.localizedDescription)
            case .finished: break
            }
        }) { item in
            let char = item as! Character
            XCTAssertEqual(char.level, 3)

            XCTAssertEqual(char.stats.name, "Sarovin a'Ryr")
            XCTAssertEqual(char.stats.size, .medium)
            XCTAssertEqual(char.stats.type, "Aasimar")
            XCTAssertEqual(char.stats.subtype, "Scourge")
            XCTAssertEqual(char.stats.alignment, .lawfulNeutral)

            XCTAssertEqual(char.stats.armorClass, 13)
            XCTAssertEqual(char.stats.hitPointDice, 3.d(8) + 6)
            XCTAssertEqual(char.stats.hitPoints, 24)
            XCTAssertEqual(char.stats.movement, [.walk: 30])
            XCTAssertEqual(char.stats.abilityScores, AbilityScores(strength: 10, dexterity: 13, constitution: 15, intelligence: 8, wisdom: 12, charisma: 17))

            // FIXME: add other fields

            e.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testRiverine() {
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ddb_riverine", ofType: "json")!)
        let sut = DDBCharacterDataSourceReader(dataSource: dataSource)
        let job = sut.read()

        let e = expectation(description: "Receive at least one item")
        _ = job.items.prefix(1).sink(receiveCompletion: { completion in
            switch completion {
            case .failure(let e): XCTFail(e.localizedDescription)
            case .finished: break
            }
        }) { item in
            let char = item as! Character
            XCTAssertEqual(char.level, 3)

            XCTAssertEqual(char.stats.name, "Riverine")
            XCTAssertEqual(char.stats.size, .medium)
            XCTAssertEqual(char.stats.type, "Genasi")
            XCTAssertEqual(char.stats.subtype, "Water")
            XCTAssertEqual(char.stats.alignment, .neutralGood)

            XCTAssertEqual(char.stats.armorClass, 15)
            XCTAssertEqual(char.stats.hitPointDice, 3.d(8) + 3)
            XCTAssertEqual(char.stats.hitPoints, 21)
            XCTAssertEqual(char.stats.movement, [.walk: 30, .swim: 30])
            XCTAssertEqual(char.stats.abilityScores, AbilityScores(strength: 10, dexterity: 14, constitution: 12, intelligence: 14, wisdom: 16, charisma: 8))

            // FIXME: add other fields

            e.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testMisty() {
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ddb_misty", ofType: "json")!)
        let sut = DDBCharacterDataSourceReader(dataSource: dataSource)
        let job = sut.read()

        let e = expectation(description: "Receive at least one item")
        _ = job.items.prefix(1).sink(receiveCompletion: { completion in
            switch completion {
            case .failure(let e): XCTFail(e.localizedDescription)
            case .finished: break
            }
        }) { item in
            let char = item as! Character
            XCTAssertEqual(char.level, 4)

            XCTAssertEqual(char.stats.name, "Misty Mountain")
            XCTAssertEqual(char.stats.size, .medium)
            XCTAssertEqual(char.stats.type, "Tabaxi")
            XCTAssertEqual(char.stats.subtype, nil)
            XCTAssertEqual(char.stats.alignment, Alignment.neutralGood)

            XCTAssertEqual(char.stats.armorClass, 14)
            XCTAssertEqual(char.stats.hitPointDice, 4.d(8) + 4)
            XCTAssertEqual(char.stats.hitPoints, 26)
            XCTAssertEqual(char.stats.movement, [.walk: 30])
            XCTAssertEqual(char.stats.abilityScores, AbilityScores(strength: 12, dexterity: 17, constitution: 13, intelligence: 9, wisdom: 14, charisma: 13))

            // FIXME: add other fields

            e.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testIshmadon() {
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ddb_ishmadon", ofType: "json")!)
        let sut = DDBCharacterDataSourceReader(dataSource: dataSource)
        let job = sut.read()

        let e = expectation(description: "Receive at least one item")
        _ = job.items.prefix(1).sink(receiveCompletion: { completion in
            switch completion {
            case .failure(let e): XCTFail(e.localizedDescription)
            case .finished: break
            }
        }) { item in
            let char = item as! Character
            XCTAssertEqual(char.level, 4)

            XCTAssertEqual(char.stats.name, "Ishmadon Molari")
            XCTAssertEqual(char.stats.size, .medium)
            XCTAssertEqual(char.stats.type, "Dragonborn")
            XCTAssertEqual(char.stats.subtype, nil)
            XCTAssertEqual(char.stats.alignment, Alignment.chaoticGood)

            XCTAssertEqual(char.stats.armorClass, 15)
            XCTAssertEqual(char.stats.hitPointDice, 4.d(8) + 4)
            XCTAssertEqual(char.stats.hitPoints, 25)
            XCTAssertEqual(char.stats.movement, [.walk: 30])
            XCTAssertEqual(char.stats.abilityScores, AbilityScores(strength: 12, dexterity: 14, constitution: 13, intelligence: 8, wisdom: 12, charisma: 17))

            // FIXME: add other fields

            e.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testThrall() {
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ddb_thrall", ofType: "json")!)
        let sut = DDBCharacterDataSourceReader(dataSource: dataSource)
        let job = sut.read()

        let e = expectation(description: "Receive at least one item")
        _ = job.items.prefix(1).sink(receiveCompletion: { completion in
            switch completion {
            case .failure(let e): XCTFail(e.localizedDescription)
            case .finished: break
            }
        }) { item in
            let char = item as! Character
            XCTAssertEqual(char.level, 3)

            XCTAssertEqual(char.stats.name, "Thrall 'Anak")
            XCTAssertEqual(char.stats.size, .medium)
            XCTAssertEqual(char.stats.type, "Half-Orc")
            XCTAssertEqual(char.stats.subtype, nil)
            XCTAssertEqual(char.stats.alignment, nil)

            XCTAssertEqual(char.stats.armorClass, 16)
            XCTAssertEqual(char.stats.hitPointDice, 3.d(10) + 6)
            XCTAssertEqual(char.stats.hitPoints, 24)
            XCTAssertEqual(char.stats.movement, [.walk: 30])
            XCTAssertEqual(char.stats.abilityScores, AbilityScores(strength: 17, dexterity: 14, constitution: 14, intelligence: 12, wisdom: 10, charisma: 8))

            // FIXME: add other fields

            e.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testBass() {
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ddb_bass", ofType: "json")!)
        let sut = DDBCharacterDataSourceReader(dataSource: dataSource)
        let job = sut.read()

        let e = expectation(description: "Receive at least one item")
        _ = job.items.prefix(1).sink(receiveCompletion: { completion in
            switch completion {
            case .failure(let e): XCTFail(e.localizedDescription)
            case .finished: break
            }
        }) { item in
            let char = item as! Character
            XCTAssertEqual(char.level, 3)

            XCTAssertEqual(char.stats.name, "Bass")
            XCTAssertEqual(char.stats.size, .medium)
            XCTAssertEqual(char.stats.type, "Tiefling")
            XCTAssertEqual(char.stats.subtype, nil)
            XCTAssertEqual(char.stats.alignment, .chaoticNeutral)

            XCTAssertEqual(char.stats.armorClass, 12)
            XCTAssertEqual(char.stats.hitPointDice, 3.d(8) + 6)
            XCTAssertEqual(char.stats.hitPoints, 18)
            XCTAssertEqual(char.stats.movement, [.walk: 30])
            XCTAssertEqual(char.stats.abilityScores, AbilityScores(strength: 8, dexterity: 13, constitution: 14, intelligence: 13, wisdom: 10, charisma: 17))

            // FIXME: add other fields

            e.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

}
