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

    var monsterDataSource: (any CompendiumDataSource<[Open5eAPIResult]>)!
    var spellDataSource: (any CompendiumDataSource<[Open5eAPIResult]>)!

    override func setUp() {
        monsterDataSource = FileDataSource(path: defaultMonstersPath).decode(type: [O5e.Monster].self).toOpen5eAPIResults()
        spellDataSource = FileDataSource(path: defaultSpellsPath).decode(type: [O5e.Spell].self).toOpen5eAPIResults()
    }

    // Temporary migration guard: snapshot the full default Open5e content before/after fixture updates.
    @MainActor
    func testDefaultContentSnapshot() async throws {
        let monsterReader = Open5eDataSourceReader(
            dataSource: monsterDataSource,
            generateUUID: UUIDGenerator.fake().callAsFunction
        )
        let spellReader = Open5eDataSourceReader(
            dataSource: spellDataSource,
            generateUUID: UUIDGenerator.fake().callAsFunction
        )

        let monsters = try await Array(monsterReader.items(realmId: CompendiumRealm.core.id).compactMap { $0.item as? Monster })
        let spells = try await Array(spellReader.items(realmId: CompendiumRealm.core.id).compactMap { $0.item as? Spell })

        let snapshot = DefaultContentSnapshot(monsters: monsters, spells: spells)
        assertSnapshot(of: snapshot, as: .dump, record: false)
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

private struct DefaultContentSnapshot {
    let monsters: [Monster]
    let spells: [Spell]
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
