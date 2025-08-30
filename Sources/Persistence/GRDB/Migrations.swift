//
//  Migrations.swift
//  Construct
//
//  Created by Thomas Visser on 02/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB
import Combine
import ComposableArchitecture
import Tagged
import GameModels
import Helpers
import Compendium

extension Database {
    enum Migration: String {
        case v1 = "v1"
        case v2 = "v2"
        case v3 = "v3-scratchPadEncounter"
        case v4 = "v4-encounter.ensureStableDiscriminators"
        case v5 = "v5-updatedOpen5eFixtures1"
        case v6 = "v6-runningEncounterTurn"
        case v7 = "v7-updatedOpen5eFixtures"
        case v8 = "v8-updatedOpen5eFixtures"
        case v9 = "v9-updatedOpen5eFixtures-reactions&legendary"
        case v10 = "v10-consistentCharacterKeys"
        case v11 = "v11-runningEncounterKeyFix"
        case v12 = "v12-statBlock-removeDefaultProficiencyOverrides"
        case v13 = "v13-keyvaluestore-indexes"
        case v14 = "v14-compendium-sources"
        case v15 = "v15-keyvaluestore-ftsDeleteSync"
    }

    static func migrator() throws -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration(Migration.v1.rawValue) { db in
            try db.create(table: "key_value") { t in
                t.column(DatabaseKeyValueStore.Record.Columns.key.name, .text).primaryKey()
                t.column(DatabaseKeyValueStore.Record.Columns.modified_at.name, .integer)
                t.column(DatabaseKeyValueStore.Record.Columns.value.name, .blob)
            }

            try db.create(virtualTable: "key_value_fts", using: FTS5()) { t in
                t.content = nil
                t.tokenizer = .unicode61()

                t.column(DatabaseKeyValueStore.FTSRecord.Columns.title.name)
                t.column(DatabaseKeyValueStore.FTSRecord.Columns.subtitle.name)
                t.column(DatabaseKeyValueStore.FTSRecord.Columns.body.name)
                t.column(DatabaseKeyValueStore.FTSRecord.Columns.title_suffixes.name)
            }

            // import of default content now happens outside of the migrations
        }

        migrator.registerMigration(Migration.v2) { db in
            // gave characters an id
            let characters = try DatabaseKeyValueStore.Record.filter(Column("key").like("\(CompendiumEntry.keyPrefix(for: .character))%")).fetchAll(db)
            for c in characters {
                guard var entry = try JSONSerialization.jsonObject(with: c.value, options: []) as? [String: Any],
                    var item = entry["item"] as? [String: Any] else { continue }

                let jsonData = try JSONEncoder().encode([UUID()])
                if item["id"] == nil {
                    item["id"] = (try JSONSerialization.jsonObject(with: jsonData, options: []) as! [Any]).first!

                    entry["item"] = item
                    let newData = try JSONSerialization.data(withJSONObject: entry, options: [])
                    try DatabaseKeyValueStore.Record(key: c.key, modifiedAt: c.modifiedAt, value: newData).save(db)
                }
            }

            // forgot to update possible references to these characters that are now broken
        }


        // Note after the fact: there's two issues with this migration:
        // - it also added ensureStableDiscriminators to RunningEncounters (now resolved with the where clause of for)
        // - it did not update encounters inside RunningEncounters (not fixed, damage has been done)
        migrator.registerMigration(Migration.v4) { db in
            let encounters = try DatabaseKeyValueStore.Record.filter(Column("key").like("\(Encounter.keyPrefix)%")).fetchAll(db)
            for e in encounters where !e.key.contains(".running.") {
                guard var encounter = try JSONSerialization.jsonObject(with: e.value, options: []) as? [String: Any] else { continue }

                if encounter["ensureStableDiscriminators"] == nil {
                    if e.key == Encounter.key(Encounter.scratchPadEncounterId).rawValue {
                        encounter["ensureStableDiscriminators"] = false
                    } else {
                        encounter["ensureStableDiscriminators"] = true
                    }

                    let newData = try JSONSerialization.data(withJSONObject: encounter, options: [])
                    try DatabaseKeyValueStore.Record(key: e.key, modifiedAt: e.modifiedAt, value: newData).save(db)
                }
            }
        }

        migrator.registerMigration(Migration.v5) { db in
            // re-import of default content now happens outside of the migrations
        }

        migrator.registerMigration(Migration.v6) { db in
            let encounters = try DatabaseKeyValueStore.Record.filter(Column("key").like("\(Encounter.keyPrefix)%")).fetchAll(db)

            let runs: [DatabaseKeyValueStore.Record] = try encounters.flatMap { encounter -> [DatabaseKeyValueStore.Record] in
                guard let e = try JSONSerialization.jsonObject(with: encounter.value, options: []) as? [String: Any],
                    let uuidString = e["id"] as? String,
                    let uuid = UUID(uuidString: uuidString) else { return [] }

                return try DatabaseKeyValueStore.Record.filter(Column("key").like("\(RunningEncounter.keyPrefix(for: uuid.tagged()))%")).fetchAll(db)
            }

            for runRecord in runs {
                guard var run = try JSONSerialization.jsonObject(with: runRecord.value, options: []) as? [String: Any] else { continue }

                // migrate turn
                if let round = run["round"] as? Int,
                    let combatantIdString = run["turn"] as? String,
                    let combatantId = UUID(uuidString: combatantIdString) {

                    let encodedTurn = try JSONEncoder().encode(RunningEncounter.Turn(round: round, combatantId: combatantId.tagged()))
                    let jsonTurn = try JSONSerialization.jsonObject(with: encodedTurn, options: [])
                    run["turn"] = jsonTurn
                    run["round"] = nil
                } else if run["turn"] == nil {
                    run["round"] = nil
                    run["turn"] = nil
                }

                // migrate log
                if let log = run["log"] as? [[String:Any]] {
                    run["log"] = try log.map { entry -> [String:Any] in
                        if let round = entry["round"] as? Int,
                            let combatantIdString = entry["turn"] as? String,
                            let combatantId = UUID(uuidString: combatantIdString) {

                            let encodedTurn = try JSONEncoder().encode(RunningEncounter.Turn(round: round, combatantId: combatantId.tagged()))
                            let jsonTurn = try JSONSerialization.jsonObject(with: encodedTurn, options: [])
                            return apply(entry) {
                                $0["turn"] = jsonTurn
                            }
                        } else {
                            return entry
                        }
                    }
                }

                let newData = try JSONSerialization.data(withJSONObject: run, options: [])
                try DatabaseKeyValueStore.Record(key: runRecord.key, modifiedAt: runRecord.modifiedAt, value: newData).save(db)
            }
        }

        migrator.registerMigration(Migration.v7) { db in
            // re-import of default content now happens outside of the migrations
        }

        migrator.registerMigration(Migration.v8) { db in
            // re-import of default content now happens outside of the migrations
        }

        migrator.registerMigration(Migration.v9) { db in
            // re-import of default content now happens outside of the migrations
        }

        migrator.registerMigration(Migration.v10) { db in
            // Most characters have a UUID in their key (current behavior), others have their title (old behavior)
            // Characters with a title key don't work well
            let store = DatabaseKeyValueStore(.direct(db))

            let characterRecords = try! DatabaseKeyValueStore.Record.filter(Column("key").like("\(CompendiumEntry.keyPrefix(for: .character))%")).fetchAll(db)

            var updates: [String:CompendiumEntry.Key] = [:] // fromKey -> toKey
            for r in characterRecords {
                guard let lastKeyComponent = r.key.components(separatedBy: CompendiumEntry.keySeparator).last else { continue }
                guard UUID(uuidString: lastKeyComponent) == nil else { continue }

                let entry = try DatabaseKeyValueStore.decoder.decode(CompendiumEntry.self, from: r.value)
                let newRecord = DatabaseKeyValueStore.Record(key: entry.key.rawValue, modifiedAt: r.modifiedAt, value: r.value)

                if try !newRecord.exists(db) {
                    try store.put(entry)
                }
                try r.delete(db)

                updates[r.key] = entry.key
            }

            // Update references
            // Adventuring Parties
            let groupRecords = try! DatabaseKeyValueStore.Record.filter(Column("key").like("\(CompendiumEntry.keyPrefix(for: .group))%")).fetchAll(db)

            for r in groupRecords {
                var entry = try DatabaseKeyValueStore.decoder.decode(CompendiumEntry.self, from: r.value)
                guard let group = entry.item as? CompendiumItemGroup else { continue }

                let newGroup = CompendiumItemGroup(
                    id: group.id,
                    title: group.title,
                    members: group.members.map {
                        CompendiumItemReference(
                            itemTitle: $0.itemTitle,
                            itemKey: updates[CompendiumEntry.key(for: $0.itemKey).rawValue].flatMap { .init(compendiumEntryKey: $0.rawValue) } ?? $0.itemKey
                        )
                    }
                )

                if newGroup != group {
                    entry.item = newGroup
                    let encodedEntry = try DatabaseKeyValueStore.encoder.encode(entry)
                    let newRecord = DatabaseKeyValueStore.Record(key: entry.key.rawValue, modifiedAt: r.modifiedAt, value: encodedEntry)
                    try newRecord.save(db)
                }
            }

            // Encounters
            func updateEncounter(_ encounter: Encounter) -> Encounter {
                var newEncounter = encounter

                // AdHocCombatant.original
                newEncounter.combatants = IdentifiedArray(uniqueElements: newEncounter.combatants.map { c in
                    if let adHoc = c.definition as? AdHocCombatantDefinition {
                        if let original = adHoc.original, let newKey = updates[CompendiumEntry.key(for: original.itemKey).rawValue] {
                            var newDefinition = adHoc
                            newDefinition.original = CompendiumItemReference(itemTitle: original.itemTitle, itemKey: CompendiumItemKey(compendiumEntryKey: newKey.rawValue) ?? original.itemKey)
                        }
                    }
                    return c
                })

                return newEncounter
            }

            let encounterRecords = try! DatabaseKeyValueStore.Record.filter(Column("key").like("\(Encounter.keyPrefix)%")).fetchAll(db)

            var encounterIds: [Encounter.Id] = []
            for r in encounterRecords {
                if r.key.contains(".running.") { continue }

                let encounter: Encounter
                do {
                    encounter = try DatabaseKeyValueStore.decoder.decode(Encounter.self, from: r.value)
                } catch {
                    print("Warning: Migration \"v10-consistentCharacterKeys\" failed for Encounter with key \(r.key), last modified: \(r.modifiedAt). Underlying decoding error: \(error)")
                    continue
                }

                encounterIds.append(encounter.id)

                let newEncounter = updateEncounter(encounter)

                if newEncounter != encounter {
                    let encodedEncounter = try DatabaseKeyValueStore.encoder.encode(newEncounter)
                    let newRecord = DatabaseKeyValueStore.Record(key: newEncounter.key.rawValue, modifiedAt: r.modifiedAt, value: encodedEncounter)
                    try newRecord.save(db)
                }
            }

            // Running Encounters
            for id in encounterIds {
                let reRecords = try! DatabaseKeyValueStore.Record.filter(Column("key").like("\(RunningEncounter.keyPrefix(for: id))%")).fetchAll(db)
                for r in reRecords {
                    let re: RunningEncounter
                    do {
                        re = try DatabaseKeyValueStore.decoder.decode(RunningEncounter.self, from: r.value)
                    } catch {
                        print("Warning: Migration \"v10-consistentCharacterKeys\" failed for RunningEncounter with key \(r.key), last modified: \(r.modifiedAt). Underlying decoding error: \(error)")
                        continue
                    }

                    var newRe = re
                    newRe.base = updateEncounter(newRe.base)
                    newRe.current = updateEncounter(newRe.current)

                    if newRe != re {
                        let encodedRe = try DatabaseKeyValueStore.encoder.encode(newRe)
                        let newRecord = DatabaseKeyValueStore.Record(key: newRe.key.rawValue, modifiedAt: r.modifiedAt, value: encodedRe)
                        try newRecord.save(db)
                    }
                }
            }
        }

        // Before this, the prefix of Encounters and RunningEncounters would be identical
        // That was a mistake
        migrator.registerMigration(Migration.v11) { db in

            // Encounters and RunningEncounters
            let records = try! DatabaseKeyValueStore.Record.filter(Column("key").like("\(Encounter.keyPrefix)%")).fetchAll(db)
            for r in records where r.key.contains(".running.") {
                // records with old-style RunningEncounter keys

                do {
                    let re = try DatabaseKeyValueStore.decoder.decode(RunningEncounter.self, from: r.value)

                    let newRecord = DatabaseKeyValueStore.Record(key: re.key.rawValue, modifiedAt: r.modifiedAt, value: r.value)
                    try newRecord.save(db)
                } catch {
                    print("Warning: Migration \"v11-runningEncounterKeyFix\" failed for RunningEncounter with key \(r.key), last modified: \(r.modifiedAt). Underlying decoding error: \(error)")
                }

                // Remove since
                _ = try? r.delete(db)
            }
        }

        migrator.registerMigration(Migration.v12) { db in

            // update the compendium
            let itemRecords = try! DatabaseKeyValueStore.Record.filter(Column("key").like("\(CompendiumEntry.keyPrefix())%")).fetchAll(db)
            for var r in itemRecords {
                var entry = try DatabaseKeyValueStore.decoder.decode(CompendiumEntry.self, from: r.value)
                if var combatant = entry.item as? CompendiumCombatant {
                    combatant.stats.makeSkillAndSaveProficienciesRelative()
                    entry.item = combatant

                    if var character = combatant as? Character {
                        character.stats.level = character.level
                        combatant = character
                    }

                    r.value = try DatabaseKeyValueStore.encoder.encode(entry)
                    try r.save(db)
                }
            }

            // update combatants in all encounters
            let encounterRecords = try! DatabaseKeyValueStore.Record.filter(Column("key").like("\(Encounter.keyPrefix)%")).fetchAll(db)
            for var r in encounterRecords {
                var encounter = try DatabaseKeyValueStore.decoder.decode(Encounter.self, from: r.value)
                for cid in encounter.combatants.ids {
                    encounter.combatants[id: cid]?.definition.stats.makeSkillAndSaveProficienciesRelative()
                    let level = encounter.combatants[id: cid]?.definition.level
                    encounter.combatants[id: cid]?.definition.stats.level = level
                }
                r.value = try DatabaseKeyValueStore.encoder.encode(encounter)
                try r.save(db)
            }

            // update combatants in all running encounters
            let reRecords = try! DatabaseKeyValueStore.Record.filter(Column("key").like("\(RunningEncounter.keyPrefix)")).fetchAll(db)
            for var r in reRecords {
                var runningEncounter = try DatabaseKeyValueStore.decoder.decode(RunningEncounter.self, from: r.value)

                for cid in runningEncounter.base.combatants.ids {
                    runningEncounter.base.combatants[id: cid]?.definition.stats.makeSkillAndSaveProficienciesRelative()
                    let level = runningEncounter.base.combatants[id: cid]?.definition.level
                    runningEncounter.base.combatants[id: cid]?.definition.stats.level = level
                }

                for cid in runningEncounter.current.combatants.ids {
                    runningEncounter.current.combatants[id: cid]?.definition.stats.makeSkillAndSaveProficienciesRelative()
                    let level = runningEncounter.current.combatants[id: cid]?.definition.level
                    runningEncounter.current.combatants[id: cid]?.definition.stats.level = level
                }

                r.value = try DatabaseKeyValueStore.encoder.encode(runningEncounter)
                try r.save(db)
            }
        }

        migrator.registerMigration(Migration.v13.rawValue) { db in
            try db.create(table: DatabaseKeyValueStore.SecondaryIndexRecord.databaseTableName) { t in
                t.column(DatabaseKeyValueStore.SecondaryIndexRecord.Columns.idx.name, .integer)
                    .notNull()
                    .indexed()
                t.column(DatabaseKeyValueStore.SecondaryIndexRecord.Columns.value.name, .text)
                    .notNull()
                    .indexed()
                t.column(DatabaseKeyValueStore.SecondaryIndexRecord.Columns.recordKey.name, .text)
                    .notNull()
                    .indexed()
                    .references(
                        DatabaseKeyValueStore.Record.databaseTableName,
                        column: DatabaseKeyValueStore.Record.Columns.key.name,
                        onDelete: .cascade
                    )

                t.primaryKey([
                    DatabaseKeyValueStore.SecondaryIndexRecord.Columns.idx.name,
                    DatabaseKeyValueStore.SecondaryIndexRecord.Columns.recordKey.name
                ], onConflict: .replace)
            }

            let records = try! DatabaseKeyValueStore.Record.filter(Column("key").like("\(CompendiumEntry.keyPrefix)%")).fetchAll(db)
            for r in records {
                let entry = try DatabaseKeyValueStore.decoder.decode(CompendiumEntry.self, from: r.value)

                let values = entry.secondaryIndexValues
                if !values.isEmpty {
                    try DatabaseKeyValueStore.saveSecondaryIndexValues(values, recordKey: r.key, in: db)
                }
            }
        }

        migrator.registerMigration(Migration.v14.rawValue) { db in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let fixtures: [any KeyValueStoreEntity] = [
                CompendiumRealm.core,
                CompendiumRealm.homebrew,
                CompendiumSourceDocument.srd5_1,
                CompendiumSourceDocument.homebrew
            ]

            var jobs: [CompendiumImportSourceId: CompendiumImportJob] = [:]
            var documents = IdentifiedArrayOf<CompendiumSourceDocument>()

            // update the compendium
            let entryRecords = try! DatabaseKeyValueStore.Record.filter(Column("key").like("\(CompendiumEntry.keyPrefix())%")).fetchAll(db)
            for var r in entryRecords {
                // Read legacy source
                guard var entryJSON = try? JSONSerialization.jsonObject(with: r.value, options: []) as? [String: Any] else {
                    assertionFailure("Could not migrate \(r.key): failed to read entry")
                    continue
                }

                // Migrate source
                let origin: CompendiumEntry.Origin
                let newDocument: CompendiumSourceDocument
                if let legacySourceValue = entryJSON["source"] as? [String: String] {
                    guard let legacySourceData = try? JSONSerialization.data(withJSONObject: legacySourceValue),
                          let legacySource = try? decoder.decode(LegacyModels.CompendiumEntry_Source.self, from: legacySourceData) else {
                        assertionFailure("Could not migrate \(r.key): failed to read leagacy Source")
                        continue
                    }

                    let (source, document, job) = CompendiumEntry.migrate(source: legacySource)
                    origin = source

                    // add new documents
                    newDocument = document
                    if fixtures.allSatisfy({ $0.rawKey != newDocument.rawKey }) && !documents.contains(newDocument) {
                        documents.append(newDocument)
                    }

                    // add jobs
                    if var job {
                        if r.modifiedAt < job.timestamp {
                            job.timestamp = r.modifiedAt
                        }
                        jobs[job.sourceId] = job
                    }
                } else {
                    origin = .created(nil)
                    newDocument = CompendiumSourceDocument.homebrew
                }

                // Write new source & document reference to entry
                guard let originData = try? encoder.encode(origin),
                      let originJSON = try? JSONSerialization.jsonObject(with: originData) as? [String: Any],
                      let documentReferenceData = try? encoder.encode(CompendiumEntry.CompendiumSourceDocumentReference(newDocument)),
                      let documentReferenceJSON = try? JSONSerialization.jsonObject(with: documentReferenceData) as? [String: Any] else {
                    assertionFailure("Could not migrate \(r.key): failed to convert new origin & document to JSON")
                    continue
                }

                entryJSON[CompendiumEntry.CodingKeys.origin.stringValue] = originJSON
                entryJSON[CompendiumEntry.CodingKeys.document.stringValue] = documentReferenceJSON

                guard let entryData = try? JSONSerialization.data(withJSONObject: entryJSON) else {
                    assertionFailure("Could not migrate \(r.key): failed to write new origin & document JSON to the entry")
                    continue
                }

                r.value = entryData

                do {
                    // save migrated record
                    try r.save(db)

                    // update secondary index values (now containing the document id)
                    let entry = try DatabaseKeyValueStore.decoder.decode(CompendiumEntry.self, from: r.value)

                    let values = entry.secondaryIndexValues
                    try DatabaseKeyValueStore.saveSecondaryIndexValues(values, recordKey: r.key, in: db)
                } catch {
                    assertionFailure("Could not migrate \(r.key): failed to save updated record to the db")
                    continue
                }
            }

            let store = DatabaseKeyValueStore(.direct(db))
            for doc in documents {
                do {
                    try store.put(doc, at: doc.key.rawValue)
                } catch {
                    assertionFailure("Could not save document \(doc.key)")
                }
            }

            for job in jobs.values {
                do {
                    try store.put(job, at: job.key.rawValue)
                } catch {
                    assertionFailure("Could not save job \(job.key)")
                }
            }
        }

        migrator.registerMigration(Migration.v15.rawValue) { db in
            try db.execute(literal: """
                CREATE TRIGGER key_value_fts_delete_sync 
                AFTER DELETE ON key_value
                FOR EACH ROW
                BEGIN
                    DELETE FROM key_value_fts WHERE rowid = OLD.rowid;
                END
            """)
        }

        return migrator
    }
}

let legacyDefaultContentImportingMigrations: [Database.Migration] = [.v1, .v5, .v7, .v8, .v9]

extension DatabaseMigrator {
    mutating func registerMigration(
        _ identifier: Database.Migration,
        foreignKeyChecks: ForeignKeyChecks = .deferred,
        migrate: @escaping (GRDB.Database) throws -> Void
    ) {
        registerMigration(identifier.rawValue, foreignKeyChecks: foreignKeyChecks, migrate: migrate)
    }
}

extension CompendiumEntry {
    static func migrate(source: LegacyModels.CompendiumEntry_Source) -> (CompendiumEntry.Origin, CompendiumSourceDocument, CompendiumImportJob?) {
        if source.displayName == "Open Game Content (SRD 5.1)" {
            return (.imported(nil), CompendiumSourceDocument.srd5_1, nil)
        } else if let bookmark = source.bookmark {
            var sourceBookmark: String?
            var documentName: String?
            switch source.sourceName {
            case "FileDataSource":
                let values = NSURL.resourceValues(forKeys: [URLResourceKey.nameKey], fromBookmarkData: bookmark)
                sourceBookmark = values?[.nameKey] as? String
                documentName = sourceBookmark
            default:
                sourceBookmark = String(data: bookmark, encoding: .utf8)
                if let sourceBookmark, let url = URLComponents(string: sourceBookmark) {
                    documentName = (url.path as NSString).lastPathComponent
                }
            }

            let id = CompendiumImportSourceId(
                type: source.sourceName,
                bookmark: sourceBookmark.map { "migrated/\($0)" } ?? "migration_failed"
            )
            let document = documentName
                .map { $0 as NSString }
                .map { $0.deletingPathExtension }
                .map { String($0.prefix(20)) }
                .map { name in
                    CompendiumSourceDocument(
                        id: .init(name),
                        displayName: name,
                        realmId: CompendiumRealm.core.id
                    )
                } ?? CompendiumSourceDocument.unspecifiedCore

            let job = CompendiumImportJob(
                sourceId: id,
                sourceVersion: nil,
                documentId: document.id
            )
            return (.imported(job.id), document, job)
        } else {
            return (.created(nil), CompendiumSourceDocument.homebrew, nil)
        }
    }

}

extension LegacyModels {
    public struct CompendiumEntry_Source: Codable, Equatable {
        public var readerName: String

        public var sourceName: String
        public var bookmark: Data?

        public var displayName: String?

        public init(readerName: String, sourceName: String, bookmark: Data? = nil, displayName: String? = nil) {
            self.readerName = readerName
            self.sourceName = sourceName
            self.bookmark = bookmark
            self.displayName = displayName
        }
    }
}
