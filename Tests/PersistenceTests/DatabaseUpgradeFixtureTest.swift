import Foundation
import XCTest
import GRDB
@testable import Persistence
import GameModels
import Compendium
import TestSupport

final class DatabaseUpgradeFixtureTest: XCTestCase {
    func testAppStore302RichFixtureUpgrades() async throws {
        let fixturePath = try XCTUnwrap(InitialDatabase.appStore302RichPath)
        let migratedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("appstore-3.0.2-rich-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        try FileManager.default.copyItem(atPath: fixturePath, toPath: migratedURL.path)
        defer { try? FileManager.default.removeItem(at: migratedURL) }

        let database = try await Database(path: migratedURL.path)
        defer { try? database.close() }

        XCTAssertFalse(database.needsPrepareForUse)

        let store = database.keyValueStore
        let preferences: Preferences = try XCTUnwrap(try store.get(Preferences.key))
        XCTAssertEqual(preferences.didShowWelcomeSheet, true)
        XCTAssertEqual(preferences.adventureTabMode, .campaignBrowser)
        XCTAssertEqual(preferences.parseableManagerLastRunVersion, ParseableGameModels.combinedVersion)

        let legacyCoreRealm: CompendiumRealm? = try store.get(CompendiumRealm.key(for: "core"))
        let migratedCoreRealm: CompendiumRealm? = try store.get(CompendiumRealm.core.key)
        let migratedSrdDocument: CompendiumSourceDocument? = try store.get(CompendiumSourceDocument.srd5_1.key)
        XCTAssertNil(legacyCoreRealm)
        XCTAssertEqual(migratedCoreRealm, CompendiumRealm.core)
        XCTAssertEqual(migratedSrdDocument, CompendiumSourceDocument.srd5_1)

        let homebrewDocument: CompendiumSourceDocument = try XCTUnwrap(try store.get(
            CompendiumSourceDocument.key(for: .init(
                realmId: CompendiumRealm.homebrew.id,
                documentId: "upgrade-lab"
            ))
        ))
        XCTAssertEqual(homebrewDocument.displayName, "Upgrade Lab Homebrew")

        let myrmidonKey = CompendiumItemKey(
            type: .monster,
            realm: .init(CompendiumRealm.homebrew.id),
            identifier: "Clockwork Myrmidon"
        )
        let myrmidonEntry: CompendiumEntry = try XCTUnwrap(try store.get(CompendiumEntry.key(for: myrmidonKey)))
        XCTAssertEqual(myrmidonEntry.document.id, "upgrade-lab")
        XCTAssertEqual((myrmidonEntry.item as? Monster)?.stats.name, "Clockwork Myrmidon")
        XCTAssertNotNil((myrmidonEntry.item as? Monster)?.stats.actions.first?.result)

        let spellKey = CompendiumItemKey(
            type: .spell,
            realm: .init(CompendiumRealm.homebrew.id),
            identifier: "Searing Ledger"
        )
        let spellEntry: CompendiumEntry = try XCTUnwrap(try store.get(CompendiumEntry.key(for: spellKey)))
        XCTAssertEqual((spellEntry.item as? Spell)?.description.result?.value?.diceExpressions.count, 1)

        let encounter: Encounter = try XCTUnwrap(try store.get(Encounter.key(uuid("10000000-0000-0000-0000-000000000501").tagged())))
        XCTAssertEqual(encounter.name, "Upgrade Fixture Encounter")
        XCTAssertEqual(encounter.combatants.count, 3)
        XCTAssertNotNil(encounter.runningEncounterKey)

        let running: RunningEncounter = try XCTUnwrap(try encounter.runningEncounterKey.flatMap {
            try store.get($0)
        })
        XCTAssertEqual(running.turn?.round, 2)
        XCTAssertEqual(running.log.count, 2)

        let campaignBrowser = CampaignBrowser(store: store)
        let legacyCampaign = try XCTUnwrap(try campaignBrowser.nodes(in: .root).first { $0.title == "Legacy Campaign" })
        let legacyCampaignChildren = try campaignBrowser.nodes(in: legacyCampaign)
        XCTAssertEqual(legacyCampaignChildren.map(\.title).sorted(), ["Session zero notes", "Upgrade Fixture Encounter"])

        XCTAssertGreaterThan(try store.count(.keyPrefix(CompendiumEntry.keyPrefix(for: .monster))), 300)
        XCTAssertGreaterThan(try store.count(.keyPrefix(CompendiumEntry.keyPrefix(for: .spell))), 300)

        let failedDecodes = try failedEntityDecodeCount(in: database)
        XCTAssertEqual(failedDecodes, 0)
    }

    private func uuid(_ value: String) -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            XCTFail("Invalid UUID: \(value)")
            return UUID()
        }
        return uuid
    }

    private func failedEntityDecodeCount(in database: Persistence.Database) throws -> Int {
        try database.queue.read { db in
            let records = try DatabaseKeyValueStore.Record.fetchAll(db)
            return records.reduce(into: 0) { count, record in
                guard let entityType = keyValueStoreEntities.first(where: { entityType in
                    record.key.hasPrefix(entityType.keyPrefix)
                }) else {
                    return
                }

                do {
                    _ = try DatabaseKeyValueStore.decoder.decode(entityType, from: record.value)
                } catch {
                    count += 1
                }
            }
        }
    }
}
