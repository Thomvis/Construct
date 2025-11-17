//
//  Open5eMonsterDataSourceReaderTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine
import SnapshotTesting
import Compendium
import GameModels
import ComposableArchitecture

class Open5eMonsterDataSourceReaderTest: XCTestCase {

    var dataSource: (any CompendiumDataSource<[Open5eAPIResult]>)!

    override func setUp() {
        dataSource = FileDataSource(path: defaultMonstersPath).decode(type: [O5e.Monster].self).toOpen5eAPIResults()
    }

    @MainActor
    func test() async throws {
        let sut = Open5eDataSourceReader(dataSource: dataSource, generateUUID: UUIDGenerator.fake().callAsFunction)

        let items = try await Array(sut.items(realmId: CompendiumRealm.core.id).compactMap { $0.item })
        assertSnapshot(of: items, as: .dump)
    }

    @MainActor
    func testMultipleMovements() async throws {
        let monster = """
                [{
                    "name": "Ankheg",
                    "size": "Large",
                    "type": "monstrosity",
                    "subtype": "",
                    "alignment": "unaligned",
                    "armor_class": 14,
                    "hit_points": 39,
                    "hit_dice": "6d10+6",
                    "speed": "30 ft., burrow 10 ft.",
                    "strength": 17,
                    "dexterity": 11,
                    "constitution": 13,
                    "intelligence": 1,
                    "wisdom": 13,
                    "charisma": 6,
                    "damage_vulnerabilities": "",
                    "damage_resistances": "",
                    "damage_immunities": "",
                    "condition_immunities": "",
                    "senses": "darkvision 60 ft., tremorsense 60 ft., passive Perception 11",
                    "languages": "",
                    "challenge_rating": "2",
                    "actions": [],
                    "speed_json": {
                        "walk": 30,
                        "burrow": 10
                    },
                    "armor_desc": "14 (natural armor), 11 while prone"
                }]
            """
        let sut = Open5eDataSourceReader(
            dataSource: StringDataSource(string: monster)
                .decode(type: [O5e.Monster].self)
                .toOpen5eAPIResults(),
            generateUUID: UUIDGenerator.fake().callAsFunction
        )

        let item = try await Array(sut.items(realmId: CompendiumRealm.core.id).compactMap { $0.item }).first as! Monster

        XCTAssertEqual(item.stats.movement![.walk], 30)
        XCTAssertEqual(item.stats.movement![.burrow], 10)
    }

}

struct StringDataSource: CompendiumDataSource {
    static var name: String = "StringDataSource"

    var bookmark: String { string }

    let string: String

    public func read() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(string.data(using: .utf8)!)
            continuation.finish()
        }
    }
}
