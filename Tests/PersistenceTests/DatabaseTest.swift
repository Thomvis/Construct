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

}
