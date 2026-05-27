//
//  DatabaseTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
import GRDB
@testable import Persistence
import GameModels
import Compendium
import Tagged

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
        try await database.applyDefaultContentSelection([.rules2024])

        let monsters2014Jobs = try importJobs(in: database.keyValueStore, sourceId: .defaultMonsters2014)
        let spells2014Jobs = try importJobs(in: database.keyValueStore, sourceId: .defaultSpells2014)
        let monsters2024Jobs = try importJobs(in: database.keyValueStore, sourceId: .defaultMonsters2024)
        let spells2024Jobs = try importJobs(in: database.keyValueStore, sourceId: .defaultSpells2024)
        let srd2014Document: CompendiumSourceDocument? = try database.keyValueStore.get(CompendiumSourceDocument.srd5_1.key)
        let srd2024Document: CompendiumSourceDocument? = try database.keyValueStore.get(CompendiumSourceDocument.srd5_2.key)

        XCTAssertTrue(monsters2014Jobs.isEmpty)
        XCTAssertTrue(spells2014Jobs.isEmpty)
        XCTAssertEqual(monsters2024Jobs.count, 1)
        XCTAssertEqual(monsters2024Jobs.first?.sourceVersion, DefaultContentVersions.currentMonsters2024)
        XCTAssertEqual(spells2024Jobs.count, 1)
        XCTAssertEqual(spells2024Jobs.first?.sourceVersion, DefaultContentVersions.currentSpells2024)
        XCTAssertNil(srd2014Document)
        XCTAssertNotNil(srd2024Document)
    }

    func testDefaultContentDocumentStatusUsesDefaultImportJobs() async throws {
        let database = try await Database(path: nil, importDefaultContent: false)
        try database.keyValueStore.put(CompendiumImportJob(
            sourceId: .defaultMonsters2014,
            sourceVersion: DefaultContentVersions.currentMonsters2014,
            documentId: CompendiumSourceDocument.srd5_1.id
        ))
        try database.keyValueStore.put(CompendiumImportJob(
            sourceId: .defaultSpells2014,
            sourceVersion: DefaultContentVersions.currentSpells2014,
            documentId: CompendiumSourceDocument.srd5_1.id
        ))
        try database.keyValueStore.put(CompendiumImportJob(
            sourceId: .defaultMonsters2024,
            sourceVersion: "old",
            documentId: CompendiumSourceDocument.srd5_2.id
        ))
        try database.keyValueStore.put(CompendiumImportJob(
            sourceId: .defaultSpells2024,
            sourceVersion: DefaultContentVersions.currentSpells2024,
            documentId: CompendiumSourceDocument.srd5_2.id
        ))

        let status = try database.defaultContentDocumentStatus()

        XCTAssertEqual(status.importedRulesets, [.rules2014, .rules2024])
        XCTAssertEqual(status.newRulesets, [])
        XCTAssertEqual(status.updatedRulesets, [.rules2024])
    }

    func testDefaultContentVersionsMigrationCreatesDefaultImportJobs() throws {
        let queue = try DatabaseQueue()
        let migrator = try Database.migrator()
        try migrator.migrate(queue, upTo: Database.Migration.v17.rawValue)

        try queue.write { db in
            let store = DatabaseKeyValueStore(.direct(db))
            try store.put(
                DefaultContentVersions(
                    monsters2014: DefaultContentVersions.currentMonsters2014,
                    spells2014: DefaultContentVersions.currentSpells2014,
                    monsters2024: nil,
                    spells2024: nil
                ),
                at: "Construct::DefaultContentVersions"
            )
        }

        try migrator.migrate(queue)

        let store = DatabaseKeyValueStore(DatabaseQueueAccess(queue: queue))
        XCTAssertEqual(
            try importJobs(in: store, sourceId: .defaultMonsters2014).first?.sourceVersion,
            DefaultContentVersions.currentMonsters2014
        )
        XCTAssertEqual(
            try importJobs(in: store, sourceId: .defaultSpells2014).first?.sourceVersion,
            DefaultContentVersions.currentSpells2014
        )
        XCTAssertTrue(try importJobs(in: store, sourceId: .defaultMonsters2024).isEmpty)
        XCTAssertTrue(try importJobs(in: store, sourceId: .defaultSpells2024).isEmpty)
        XCTAssertFalse(try store.contains("Construct::DefaultContentVersions"))
    }

    func testDefaultContentRealmAndDocumentIdMigration() throws {
        let queue = try DatabaseQueue()
        let migrator = try Database.migrator()
        try migrator.migrate(queue, upTo: Database.Migration.v16.rawValue)

        let legacyCoreRealmId = CompendiumRealm.Id("core")
        let legacySrd5_1DocumentId = CompendiumSourceDocument.Id("srd")

        let legacySrd5_1Document = CompendiumSourceDocument(
            id: legacySrd5_1DocumentId,
            displayName: CompendiumSourceDocument.srd5_1.displayName,
            realmId: legacyCoreRealmId
        )
        let legacyCustomDocument = CompendiumSourceDocument(
            id: "custom",
            displayName: "Custom",
            realmId: legacyCoreRealmId
        )

        var mummyStats = StatBlock.default
        mummyStats.name = "Legacy Mummy"
        let legacyMummy = Monster(
            realm: .init(legacyCoreRealmId),
            stats: mummyStats,
            challengeRating: .half
        )
        let legacyMummyReference = CompendiumItemReference(
            itemTitle: legacyMummy.title,
            itemKey: legacyMummy.key
        )
        let legacyMummyEntry = CompendiumEntry(
            legacyMummy,
            origin: .created(legacyMummyReference),
            document: .init(legacySrd5_1Document)
        )

        var ghostStats = StatBlock.default
        ghostStats.name = "Legacy Ghost"
        let legacyGhost = Monster(
            realm: .init(legacyCoreRealmId),
            stats: ghostStats,
            challengeRating: .half
        )
        let legacyGhostEntry = CompendiumEntry(
            legacyGhost,
            origin: .created(nil),
            document: .init(legacyCustomDocument)
        )

        let encounter = Encounter(
            name: "Legacy encounter",
            combatants: [
                Combatant(
                    adHoc: AdHocCombatantDefinition(
                        id: UUID().tagged(),
                        stats: mummyStats,
                        original: legacyMummyReference
                    )
                )
            ]
        )
        let importJob = CompendiumImportJob(
            sourceId: CompendiumImportSourceId(type: "test", bookmark: "legacy-srd"),
            sourceVersion: nil,
            documentId: legacySrd5_1DocumentId,
            uuid: UUID(uuidString: "01D595EF-9075-42FE-B22C-BF5C2B5EBB2D")!
        )

        try queue.write { db in
            let store = DatabaseKeyValueStore(.direct(db))
            try store.put(CompendiumRealm(id: legacyCoreRealmId, displayName: "Core 5e (2014)"))
            try store.put(legacySrd5_1Document)
            try store.put(legacyCustomDocument)
            try store.put(legacyMummyEntry)
            try store.put(legacyGhostEntry)
            try store.put(encounter)
            try store.put(importJob)
        }

        try migrator.migrate(queue)

        let store = DatabaseKeyValueStore(DatabaseQueueAccess(queue: queue))
        let legacyCoreRealm: CompendiumRealm? = try store.get(CompendiumRealm.key(for: legacyCoreRealmId))
        let migratedCoreRealm: CompendiumRealm? = try store.get(CompendiumRealm.core.key)
        XCTAssertNil(legacyCoreRealm)
        XCTAssertEqual(migratedCoreRealm, CompendiumRealm.core)

        let legacySrd5_1: CompendiumSourceDocument? = try store.get(CompendiumSourceDocument.key(forRealmId: legacyCoreRealmId, documentId: legacySrd5_1DocumentId))
        let migratedSrd5_1: CompendiumSourceDocument? = try store.get(CompendiumSourceDocument.srd5_1.key)
        let migratedCustomDocument: CompendiumSourceDocument? = try store.get(CompendiumSourceDocument.key(forRealmId: CompendiumRealm.core.id, documentId: legacyCustomDocument.id))
        XCTAssertNil(legacySrd5_1)
        XCTAssertEqual(migratedSrd5_1, CompendiumSourceDocument.srd5_1)
        XCTAssertEqual(migratedCustomDocument?.realmId, CompendiumRealm.core.id)

        let migratedMummyKey = CompendiumItemKey(
            type: .monster,
            realm: .init(CompendiumRealm.core.id),
            identifier: legacyMummy.key.identifier
        )
        let migratedGhostKey = CompendiumItemKey(
            type: .monster,
            realm: .init(CompendiumRealm.core.id),
            identifier: legacyGhost.key.identifier
        )

        let legacyMummyResult: CompendiumEntry? = try store.get(CompendiumEntry.key(for: legacyMummy.key))
        let legacyGhostResult: CompendiumEntry? = try store.get(CompendiumEntry.key(for: legacyGhost.key))
        let migratedMummyEntry: CompendiumEntry? = try store.get(CompendiumEntry.key(for: migratedMummyKey))
        let migratedGhostEntry: CompendiumEntry? = try store.get(CompendiumEntry.key(for: migratedGhostKey))
        XCTAssertNil(legacyMummyResult)
        XCTAssertNil(legacyGhostResult)
        XCTAssertEqual(migratedMummyEntry?.item.realm.value, CompendiumRealm.core.id)
        XCTAssertEqual(migratedMummyEntry?.document.id, CompendiumSourceDocument.srd5_1.id)
        XCTAssertEqual(
            migratedMummyEntry?.origin,
            .created(CompendiumItemReference(itemTitle: legacyMummy.title, itemKey: migratedMummyKey))
        )
        XCTAssertEqual(migratedGhostEntry?.item.realm.value, CompendiumRealm.core.id)
        XCTAssertEqual(migratedGhostEntry?.document.id, legacyCustomDocument.id)

        let migratedMummySecondaryIndexes = try store.secondaryIndexValues(for: CompendiumEntry.key(for: migratedMummyKey).rawValue)
        XCTAssertEqual(
            migratedMummySecondaryIndexes?[SecondaryIndexes.compendiumEntrySourceDocumentId],
            CompendiumSourceDocument.srd5_1.id.rawValue
        )

        let migratedEncounter: Encounter? = try store.get(encounter.key)
        let migratedOriginal = (migratedEncounter?.combatants.first?.definition as? AdHocCombatantDefinition)?.original
        XCTAssertEqual(migratedOriginal?.itemKey, migratedMummyKey)

        let migratedImportJob: CompendiumImportJob? = try store.get(importJob.key)
        XCTAssertEqual(migratedImportJob?.documentId, CompendiumSourceDocument.srd5_1.id)
    }

}

private func importJobs(
    in keyValueStore: KeyValueStore,
    sourceId: CompendiumImportSourceId
) throws -> [CompendiumImportJob] {
    let keyPrefix = CompendiumImportJob.keyPrefix + CompendiumImportJob.jobIdPrefix(sourceId: sourceId)
    let jobs: [CompendiumImportJob] = try keyValueStore.fetchAll(.keyPrefix(keyPrefix))
    return jobs.filter { $0.sourceId == sourceId }
}
