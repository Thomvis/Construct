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

extension Database {
    private static let v1 = "v1"

    func migrator(_ queue: DatabaseQueue, importDefaultContent: Bool = true) throws -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        var didImportDefaultContent = false

        migrator.registerMigration(Self.v1) { db in
            try db.create(table: "key_value") { t in
                t.column(KeyValueStore.Record.Columns.key.name, .text).primaryKey()
                t.column(KeyValueStore.Record.Columns.modified_at.name, .integer)
                t.column(KeyValueStore.Record.Columns.value.name, .blob)
            }

            try db.create(virtualTable: "key_value_fts", using: FTS5()) { t in
                t.content = nil
                t.tokenizer = .unicode61()

                t.column(KeyValueStore.FTSRecord.Columns.title.name)
                t.column(KeyValueStore.FTSRecord.Columns.subtitle.name)
                t.column(KeyValueStore.FTSRecord.Columns.body.name)
                t.column(KeyValueStore.FTSRecord.Columns.title_suffixes.name)
            }

            // Import default data
            if importDefaultContent && !didImportDefaultContent {
                try Compendium(self).importDefaultContent(db)
                didImportDefaultContent = true
            }
        }

        migrator.registerMigration("v2") { db in
            // gave characters an id
            let characters = try KeyValueStore.Record.filter(Column("key").like("\(CompendiumItemKey.prefix(for: .character))%")).fetchAll(db)
            for c in characters {
                guard var entry = try JSONSerialization.jsonObject(with: c.value, options: []) as? [String: Any],
                    var item = entry["item"] as? [String: Any] else { continue }

                let jsonData = try JSONEncoder().encode([UUID()])
                if item["id"] == nil {
                    item["id"] = (try JSONSerialization.jsonObject(with: jsonData, options: []) as! [Any]).first!

                    entry["item"] = item
                    let newData = try JSONSerialization.data(withJSONObject: entry, options: [])
                    try KeyValueStore.Record(key: c.key, modifiedAt: c.modifiedAt, value: newData).save(db)
                }
            }

            // forgot to update possible references to these characters that are now broken
        }

        if importDefaultContent {
            migrator.registerMigration("v3-scratchPadEncounter") { db in
                let encounter = Encounter(id: Encounter.scratchPadEncounterId.rawValue, name: "Scratch pad", combatants: [])

                try self.keyValueStore.put(encounter, in: db)
                try self.keyValueStore.put(CampaignNode.scratchPadEncounter, in: db)
            }
        }

        // Note after the fact: there's two issues with this migration:
        // - it also added ensureStableDiscriminators to RunningEncounters (now resolved with the where clause of for)
        // - it did not update encounters inside RunningEncounters (not fixed, damage has been done)
        migrator.registerMigration("v4-encounter.ensureStableDiscriminators") { db in
            let encounters = try KeyValueStore.Record.filter(Column("key").like("\(Encounter.keyValueStoreEntityKeyPrefix)%")).fetchAll(db)
            for e in encounters where !e.key.contains(".running.") {
                guard var encounter = try JSONSerialization.jsonObject(with: e.value, options: []) as? [String: Any] else { continue }

                if encounter["ensureStableDiscriminators"] == nil {
                    if e.key == Encounter.key(Encounter.scratchPadEncounterId) {
                        encounter["ensureStableDiscriminators"] = false
                    } else {
                        encounter["ensureStableDiscriminators"] = true
                    }

                    let newData = try JSONSerialization.data(withJSONObject: encounter, options: [])
                    try KeyValueStore.Record(key: e.key, modifiedAt: e.modifiedAt, value: newData).save(db)
                }
            }
        }

        migrator.registerMigration("v5-updatedOpen5eFixtures1") { db in
            if importDefaultContent && !didImportDefaultContent {
                // v1 was applied before, let's re-import defaults
                try Compendium(self).importDefaultContent(db)
                didImportDefaultContent = true
            }
        }

        migrator.registerMigration("v6-runningEncounterTurn") { db in
            let encounters = try KeyValueStore.Record.filter(Column("key").like("\(Encounter.keyValueStoreEntityKeyPrefix)%")).fetchAll(db)

            let runs: [KeyValueStore.Record] = try encounters.flatMap { encounter -> [KeyValueStore.Record] in
                guard let e = try JSONSerialization.jsonObject(with: encounter.value, options: []) as? [String: Any],
                    let uuidString = e["id"] as? String,
                    let uuid = UUID(uuidString: uuidString) else { return [] }

                return try KeyValueStore.Record.filter(Column("key").like("\(RunningEncounter.keyPrefix(for: uuid.tagged()))%")).fetchAll(db)
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
                try KeyValueStore.Record(key: runRecord.key, modifiedAt: runRecord.modifiedAt, value: newData).save(db)
            }
        }

        migrator.registerMigration("v7-updatedOpen5eFixtures") { db in
            if importDefaultContent && !didImportDefaultContent {
                // v1 was applied before, let's re-import defaults
                try Compendium(self).importDefaultContent(db)
                didImportDefaultContent = true
            }
        }

        migrator.registerMigration("v8-updatedOpen5eFixtures") { db in
            if importDefaultContent && !didImportDefaultContent {
                // v1 or v7 was applied before, let's re-import defaults
                try Compendium(self).importDefaultContent(db)
                didImportDefaultContent = true
            }
        }

        migrator.registerMigration("v9-updatedOpen5eFixtures-reactions&legendary") { db in
            if importDefaultContent && !didImportDefaultContent {
                // v1, v7 or v8 was applied before, let's re-import defaults
                try Compendium(self).importDefaultContent(db)
                didImportDefaultContent = true
            }
        }

        migrator.registerMigration("v10-consistentCharacterKeys") { db in
            // Most characters have a UUID in their key (current behavior), others have their title (old behavior)
            // Characters with a title key don't work well

            let characterRecords = try! KeyValueStore.Record.filter(Column("key").like("\(CompendiumItemKey.prefix(for: .character))%")).fetchAll(db)

            var updates: [String:String] = [:] // fromKey -> toKey
            for r in characterRecords {
                guard let lastKeyComponent = r.key.components(separatedBy: CompendiumItemKey.separator).last else { continue }
                guard UUID(uuidString: lastKeyComponent) == nil else { continue }

                let entry = try self.keyValueStore.decoder.decode(CompendiumEntry.self, from: r.value)
                let newRecord = KeyValueStore.Record(key: entry.key, modifiedAt: r.modifiedAt, value: r.value)

                if try !newRecord.exists(db) {
                    try Compendium(self).put(entry, in: db)
                }
                try r.delete(db)

                updates[r.key] = entry.key
            }

            // Update references
            // Adventuring Parties
            let groupRecords = try! KeyValueStore.Record.filter(Column("key").like("\(CompendiumItemKey.prefix(for: .group))%")).fetchAll(db)

            for r in groupRecords {
                var entry = try self.keyValueStore.decoder.decode(CompendiumEntry.self, from: r.value)
                guard let group = entry.item as? CompendiumItemGroup else { continue }

                let newGroup = CompendiumItemGroup(
                    id: group.id,
                    title: group.title,
                    members: group.members.map {
                        CompendiumItemReference(
                            itemTitle: $0.itemTitle,
                            itemKey: updates[$0.itemKey.rawValue].flatMap(CompendiumItemKey.init) ?? $0.itemKey
                        )
                    }
                )

                if newGroup != group {
                    entry.item = newGroup
                    let encodedEntry = try self.keyValueStore.encoder.encode(entry)
                    let newRecord = KeyValueStore.Record(key: entry.key, modifiedAt: r.modifiedAt, value: encodedEntry)
                    try newRecord.save(db)
                }
            }

            // Encounters
            func updateEncounter(_ encounter: Encounter) -> Encounter {
                var newEncounter = encounter

                // AdHocCombatant.original
                newEncounter.combatants = IdentifiedArray(newEncounter.combatants.map { c in
                    if let adHoc = c.definition as? AdHocCombatantDefinition {
                        if let original = adHoc.original, let newKey = updates[original.itemKey.rawValue] {
                            var newDefinition = adHoc
                            newDefinition.original = CompendiumItemReference(itemTitle: original.itemTitle, itemKey: CompendiumItemKey(rawValue: newKey) ?? original.itemKey)
                        }
                    }
                    return c
                })

                return newEncounter
            }

            let encounterRecords = try! KeyValueStore.Record.filter(Column("key").like("\(Encounter.keyValueStoreEntityKeyPrefix)%")).fetchAll(db)

            var encounterIds: [Encounter.Id] = []
            for r in encounterRecords {
                if r.key.contains(".running.") { continue }

                let encounter: Encounter
                do {
                    encounter = try self.keyValueStore.decoder.decode(Encounter.self, from: r.value)
                } catch {
                    print("Warning: Migration \"v10-consistentCharacterKeys\" failed for Encounter with key \(r.key), last modified: \(r.modifiedAt). Underlying decoding error: \(error)")
                    continue
                }

                encounterIds.append(encounter.id)

                let newEncounter = updateEncounter(encounter)

                if newEncounter != encounter {
                    let encodedEncounter = try self.keyValueStore.encoder.encode(newEncounter)
                    let newRecord = KeyValueStore.Record(key: newEncounter.key, modifiedAt: r.modifiedAt, value: encodedEncounter)
                    try newRecord.save(db)
                }
            }

            // Running Encounters
            for id in encounterIds {
                let reRecords = try! KeyValueStore.Record.filter(Column("key").like("\(RunningEncounter.keyPrefix(for: id))%")).fetchAll(db)
                for r in reRecords {
                    let re: RunningEncounter
                    do {
                        re = try self.keyValueStore.decoder.decode(RunningEncounter.self, from: r.value)
                    } catch {
                        print("Warning: Migration \"v10-consistentCharacterKeys\" failed for RunningEncounter with key \(r.key), last modified: \(r.modifiedAt). Underlying decoding error: \(error)")
                        continue
                    }

                    var newRe = re
                    newRe.base = updateEncounter(newRe.base)
                    newRe.current = updateEncounter(newRe.current)

                    if newRe != re {
                        let encodedRe = try self.keyValueStore.encoder.encode(newRe)
                        let newRecord = KeyValueStore.Record(key: newRe.key, modifiedAt: r.modifiedAt, value: encodedRe)
                        try newRecord.save(db)
                    }
                }
            }
        }

        // Before this, the prefix of Encounters and RunningEncounters would be identical
        // That was a mistake
        migrator.registerMigration("v11-runningEncounterKeyFix") { db in

            // Encounters and RunningEncounters
            let records = try! KeyValueStore.Record.filter(Column("key").like("\(Encounter.keyValueStoreEntityKeyPrefix)%")).fetchAll(db)
            for r in records where r.key.contains(".running.") {
                // records with old-style RunningEncounter keys

                do {
                    let re = try self.keyValueStore.decoder.decode(RunningEncounter.self, from: r.value)

                    let newRecord = KeyValueStore.Record(key: re.key, modifiedAt: r.modifiedAt, value: r.value)
                    try newRecord.save(db)
                } catch let error as DecodingError {
                    print("Warning: Migration \"v11-runningEncounterKeyFix\" failed for RunningEncounter with key \(r.key), last modified: \(r.modifiedAt). Underlying decoding error: \(error)")
                }

                // Remove since
                _ = try? r.delete(db)
            }
        }

        return migrator
    }
}

extension Compendium {
    func importDefaultContent(_ db: GRDB.Database) throws {
        if let monstersPath = Bundle.main.path(forResource: "monsters", ofType: "json") {
            var task = CompendiumImportTask(reader: Open5eMonsterDataSourceReader(dataSource: FileDataSource(path: monstersPath)), overwriteExisting: true, db: db)
            task.source.displayName = "Open Game Content (SRD 5.1)"
            var cancellables: [AnyCancellable] = []

            CompendiumImporter(compendium: self).run(task).sink(receiveCompletion: { _ in
                cancellables.removeAll()
            }, receiveValue: { _ in }).store(in: &cancellables)
        }

        if let spellsPath = Bundle.main.path(forResource: "spells", ofType: "json") {
            var task = CompendiumImportTask(reader: Open5eSpellDataSourceReader(dataSource: FileDataSource(path: spellsPath)), overwriteExisting: true, db: db)
            task.source.displayName = "Open Game Content (SRD 5.1)"
            var cancellables: [AnyCancellable] = []

            CompendiumImporter(compendium: self).run(task).sink(receiveCompletion: { _ in
                cancellables.removeAll()
            }, receiveValue: { _ in }).store(in: &cancellables)
        }
    }
}
