//
//  KeyValueStoreEntityTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 15/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Persistence
import GameModels
import Compendium
import Helpers

class KeyValueStoreEntityTest: XCTestCase {
    static let id1 = UUID(uuidString: "4E7A5EC2-2C3F-49CB-8B0B-063B32DAB616")!
    static let id2 = UUID(uuidString: "8B4E835F-A058-4619-92A1-3A83F362BE6A")!

    func testEnsureUniquePrefixes() {
        for i1 in keyValueStoreEntities.indices {
            let p1 = keyValueStoreEntities[i1]
            for i2 in keyValueStoreEntities.indices {
                guard i1 != i2 else { continue }
                let p2 = keyValueStoreEntities[i2]
                XCTAssertFalse(p1.keyPrefix.hasPrefix(p2.keyPrefix), "\(p2) is a prefix of \(p1)")
            }
        }
    }

    func testEncounterKey() {
        let e = Encounter(id: Self.id1, name: "", combatants: [])
        XCTAssertEqual(e.key.rawValue, "encounter_\(Self.id1)")
    }

    func testRunningEncounterKey() {
        let e = Encounter(id: Self.id1, name: "", combatants: [])
        let re = RunningEncounter(
            id: Self.id2.tagged(),
            base: e,
            current: e
        )
        XCTAssertEqual(re.key.rawValue, "runningEncounter.encounter_\(Self.id1).\(Self.id2)")
    }

    func testCompendiumEntryKey() {
        let monster = CompendiumEntry(Monster(
            realm: .core,
            stats: apply(.default) { $0.name = "ABC" },
            challengeRating: .half
        ))
        XCTAssertEqual(monster.key.rawValue, "compendium::monster::core::ABC")

        let character = CompendiumEntry(Character(
            id: Self.id1.tagged(),
            realm: .homebrew,
            stats: .default
        ))
        XCTAssertEqual(character.key.rawValue, "compendium::character::homebrew::\(Self.id1)")
    }

    func testCampaignNodeKey() {
        let rootNode = CampaignNode(id: Self.id1.tagged(), title: "", contents: nil, special: nil)
        XCTAssertEqual(rootNode.key.rawValue, "cn_/.\(Self.id1)")

        let topLevelNode = CampaignNode(id: Self.id1.tagged(), title: "", contents: nil, special: nil, parentKeyPrefix: CampaignNode.root.keyPrefixForChildren.rawValue)
        XCTAssertEqual(topLevelNode.key.rawValue, "cn_\(CampaignNode.root.id.rawValue)/.\(Self.id1)")
    }

    func testPreferencesKey() {
        XCTAssertEqual(Preferences().key.rawValue, "Construct::Preferences")
    }

    func testDefaultContentVersionsKey() {
        XCTAssertEqual(DefaultContentVersions.current.key.rawValue, "Construct::DefaultContentVersions")
    }

}
