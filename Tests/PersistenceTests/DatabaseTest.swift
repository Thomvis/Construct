//
//  DatabaseTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
import Persistence
import GameModels
import Compendium

class DatabaseTest: XCTestCase {

//    func testInitialization() {
//        measure {
//            let exp = expectation(description: "task")
//            Task {
//                let _ = try! await Database(path: nil)
//                exp.fulfill()
//            }
//            wait(for: [exp], timeout: 60)
//        }
//    }

    func testAdventureTabModeDefaultsToSimpleEncounterForNewData() async throws {
        let database = try await Database(path: nil)
        let preferences: Preferences? = try database.keyValueStore.get(Preferences.key)
        XCTAssertEqual(preferences?.adventureTabMode, .simpleEncounter)
    }

    func testAdventureTabModeMigrationUsesCampaignBrowserWhenTopLevelItemsExist() async throws {
        let source = try await Database(path: nil)
        var preferences: Preferences = try source.keyValueStore.get(Preferences.key) ?? Preferences()
        preferences.adventureTabMode = nil
        try source.keyValueStore.put(preferences)

        let customNode = CampaignNode(
            id: CampaignNode.Id(rawValue: UUID()),
            title: "Custom group",
            contents: nil,
            special: nil,
            parentKeyPrefix: CampaignNode.root.keyPrefixForChildren.rawValue
        )
        try source.keyValueStore.put(customNode)

        let migrated = try await Database(path: nil, source: source)
        let migratedPreferences: Preferences? = try migrated.keyValueStore.get(Preferences.key)
        XCTAssertEqual(migratedPreferences?.adventureTabMode, .campaignBrowser)
    }

    func testPrepareForUseBootstrapsHomebrewOnlyWhenNoSelection() async throws {
        let database = try await Database(path: nil)

        let homebrewRealm: CompendiumRealm? = try database.keyValueStore.get(CompendiumRealm.key(for: CompendiumRealm.homebrew.id))
        let homebrewDocument: CompendiumSourceDocument? = try database.keyValueStore.get(CompendiumSourceDocument.homebrew.key)
        let srd2014Document: CompendiumSourceDocument? = try database.keyValueStore.get(CompendiumSourceDocument.srd5_1.key)
        let srd2024Document: CompendiumSourceDocument? = try database.keyValueStore.get(CompendiumSourceDocument.srd5_2.key)

        XCTAssertNotNil(homebrewRealm)
        XCTAssertNotNil(homebrewDocument)
        XCTAssertNil(srd2014Document)
        XCTAssertNil(srd2024Document)
    }

    func testApplyDefaultContentSelectionCreatesOnlySelectedDefaultDocument() async throws {
        let database = try await Database(path: nil)
        try await database.applyDefaultContentSelection(.rules2024Only)

        let persistedSelection: DefaultContentSelection? = try database.keyValueStore.get(DefaultContentSelection.key)
        let srd2014Document: CompendiumSourceDocument? = try database.keyValueStore.get(CompendiumSourceDocument.srd5_1.key)
        let srd2024Document: CompendiumSourceDocument? = try database.keyValueStore.get(CompendiumSourceDocument.srd5_2.key)

        XCTAssertEqual(persistedSelection, .rules2024Only)
        XCTAssertNil(srd2014Document)
        XCTAssertNotNil(srd2024Document)
    }

}
