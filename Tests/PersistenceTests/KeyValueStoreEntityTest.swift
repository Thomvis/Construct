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
            realm: .init(CompendiumRealm.core.id),
            stats: apply(.default) { $0.name = "ABC" },
            challengeRating: .half
        ), origin: .created(nil), document: .init(CompendiumSourceDocument.srd5_1))
        XCTAssertEqual(monster.key.rawValue, "compendium::monster::core::ABC")

        let character = CompendiumEntry(Character(
            id: Self.id1.tagged(),
            realm: .init(CompendiumRealm.homebrew.id),
            stats: .default
        ), origin: .created(nil), document: .init(CompendiumSourceDocument.srd5_1))
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

    func testDefaultContentImportSourceIdsKeepLegacy2014Bookmarks() {
        XCTAssertEqual(CompendiumImportSourceId.defaultMonsters2014.bookmark, "monsters")
        XCTAssertEqual(CompendiumImportSourceId.defaultSpells2014.bookmark, "spells")
        XCTAssertEqual(CompendiumImportSourceId.defaultMonsters2024.bookmark, "monsters-2024")
        XCTAssertEqual(CompendiumImportSourceId.defaultSpells2024.bookmark, "spells-2024")
    }

    func testDefaultContentSelectionKey() {
        XCTAssertEqual(DefaultContentSelection.none.key.rawValue, "Construct::DefaultContentSelection")
    }

    func testDefaultContentVersionsDecodesLegacyPayload() throws {
        let legacyPayload = """
        {
          "monsters": "2026.02.21",
          "spells": "2026.02.21"
        }
        """.data(using: .utf8)!

        let versions = try JSONDecoder().decode(DefaultContentVersions.self, from: legacyPayload)

        XCTAssertEqual(versions.monsters2014, "2026.02.21")
        XCTAssertEqual(versions.spells2014, "2026.02.21")
        XCTAssertNil(versions.monsters2024)
        XCTAssertNil(versions.spells2024)
    }

    func testDefaultContentVersionsComponentsNeedingImportRespectsSelection() {
        let installed = DefaultContentVersions(
            monsters2014: DefaultContentVersions.currentMonsters2014,
            spells2014: DefaultContentVersions.currentSpells2014,
            monsters2024: nil,
            spells2024: nil
        )

        let selected2014 = DefaultContentVersions.componentsNeedingImport(
            selection: .rules2014Only,
            installed: installed
        )
        let selected2024 = DefaultContentVersions.componentsNeedingImport(
            selection: .rules2024Only,
            installed: installed
        )

        XCTAssertEqual(selected2014, .none)
        XCTAssertEqual(selected2024.monsters2024, true)
        XCTAssertEqual(selected2024.spells2024, true)
        XCTAssertEqual(selected2024.monsters2014, false)
        XCTAssertEqual(selected2024.spells2014, false)
    }

    func testDefaultContentVersionsApplyingCurrentVersionsUpdatesOnlyImportedComponents() {
        let installed = DefaultContentVersions(
            monsters2014: "old2014m",
            spells2014: "old2014s",
            monsters2024: "old2024m",
            spells2024: "old2024s"
        )

        let updated = installed.applyingCurrentVersions(
            for: DefaultContentImportComponents(
                monsters2014: true,
                spells2014: true,
                monsters2024: false,
                spells2024: false
            )
        )

        XCTAssertEqual(updated.monsters2014, DefaultContentVersions.currentMonsters2014)
        XCTAssertEqual(updated.spells2014, DefaultContentVersions.currentSpells2014)
        XCTAssertEqual(updated.monsters2024, "old2024m")
        XCTAssertEqual(updated.spells2024, "old2024s")
    }

}
