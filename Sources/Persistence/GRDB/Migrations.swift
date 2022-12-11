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
    }

    static func migrator() throws -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration(Migration.v1.rawValue) { db in
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

            // import of default content now happens outside of the migrations
        }

        migrator.registerMigration(Migration.v2) { db in
            // gave characters an id
            let characters = try KeyValueStore.Record.filter(Column("key").like("\(CompendiumEntry.keyPrefix(for: .character))%")).fetchAll(db)
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


        // Note after the fact: there's two issues with this migration:
        // - it also added ensureStableDiscriminators to RunningEncounters (now resolved with the where clause of for)
        // - it did not update encounters inside RunningEncounters (not fixed, damage has been done)
        migrator.registerMigration(Migration.v4) { db in
            let encounters = try KeyValueStore.Record.filter(Column("key").like("\(Encounter.keyPrefix)%")).fetchAll(db)
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

        migrator.registerMigration(Migration.v5) { db in
            // re-import of default content now happens outside of the migrations
        }

        migrator.registerMigration(Migration.v6) { db in
            let encounters = try KeyValueStore.Record.filter(Column("key").like("\(Encounter.keyPrefix)%")).fetchAll(db)

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

            let characterRecords = try! KeyValueStore.Record.filter(Column("key").like("\(CompendiumEntry.keyPrefix(for: .character))%")).fetchAll(db)

            var updates: [String:String] = [:] // fromKey -> toKey
            for r in characterRecords {
                guard let lastKeyComponent = r.key.components(separatedBy: CompendiumEntry.keySeparator).last else { continue }
                guard UUID(uuidString: lastKeyComponent) == nil else { continue }

                let entry = try KeyValueStore.decoder.decode(CompendiumEntry.self, from: r.value)
                let newRecord = KeyValueStore.Record(key: entry.key, modifiedAt: r.modifiedAt, value: r.value)

                if try !newRecord.exists(db) {
                    try DatabaseCompendium.put(entry, in: db)
                }
                try r.delete(db)

                updates[r.key] = entry.key
            }

            // Update references
            // Adventuring Parties
            let groupRecords = try! KeyValueStore.Record.filter(Column("key").like("\(CompendiumEntry.keyPrefix(for: .group))%")).fetchAll(db)

            for r in groupRecords {
                var entry = try KeyValueStore.decoder.decode(CompendiumEntry.self, from: r.value)
                guard let group = entry.item as? CompendiumItemGroup else { continue }

                let newGroup = CompendiumItemGroup(
                    id: group.id,
                    title: group.title,
                    members: group.members.map {
                        CompendiumItemReference(
                            itemTitle: $0.itemTitle,
                            itemKey: updates[CompendiumEntry.key(for: $0.itemKey)].flatMap(CompendiumItemKey.init(compendiumEntryKey:)) ?? $0.itemKey
                        )
                    }
                )

                if newGroup != group {
                    entry.item = newGroup
                    let encodedEntry = try KeyValueStore.encoder.encode(entry)
                    let newRecord = KeyValueStore.Record(key: entry.key, modifiedAt: r.modifiedAt, value: encodedEntry)
                    try newRecord.save(db)
                }
            }

            // Encounters
            func updateEncounter(_ encounter: Encounter) -> Encounter {
                var newEncounter = encounter

                // AdHocCombatant.original
                newEncounter.combatants = IdentifiedArray(uniqueElements: newEncounter.combatants.map { c in
                    if let adHoc = c.definition as? AdHocCombatantDefinition {
                        if let original = adHoc.original, let newKey = updates[CompendiumEntry.key(for: original.itemKey)] {
                            var newDefinition = adHoc
                            newDefinition.original = CompendiumItemReference(itemTitle: original.itemTitle, itemKey: CompendiumItemKey(compendiumEntryKey: newKey) ?? original.itemKey)
                        }
                    }
                    return c
                })

                return newEncounter
            }

            let encounterRecords = try! KeyValueStore.Record.filter(Column("key").like("\(Encounter.keyPrefix)%")).fetchAll(db)

            var encounterIds: [Encounter.Id] = []
            for r in encounterRecords {
                if r.key.contains(".running.") { continue }

                let encounter: Encounter
                do {
                    encounter = try KeyValueStore.decoder.decode(Encounter.self, from: r.value)
                } catch {
                    print("Warning: Migration \"v10-consistentCharacterKeys\" failed for Encounter with key \(r.key), last modified: \(r.modifiedAt). Underlying decoding error: \(error)")
                    continue
                }

                encounterIds.append(encounter.id)

                let newEncounter = updateEncounter(encounter)

                if newEncounter != encounter {
                    let encodedEncounter = try KeyValueStore.encoder.encode(newEncounter)
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
                        re = try KeyValueStore.decoder.decode(RunningEncounter.self, from: r.value)
                    } catch {
                        print("Warning: Migration \"v10-consistentCharacterKeys\" failed for RunningEncounter with key \(r.key), last modified: \(r.modifiedAt). Underlying decoding error: \(error)")
                        continue
                    }

                    var newRe = re
                    newRe.base = updateEncounter(newRe.base)
                    newRe.current = updateEncounter(newRe.current)

                    if newRe != re {
                        let encodedRe = try KeyValueStore.encoder.encode(newRe)
                        let newRecord = KeyValueStore.Record(key: newRe.key, modifiedAt: r.modifiedAt, value: encodedRe)
                        try newRecord.save(db)
                    }
                }
            }
        }

        // Before this, the prefix of Encounters and RunningEncounters would be identical
        // That was a mistake
        migrator.registerMigration(Migration.v11) { db in

            // Encounters and RunningEncounters
            let records = try! KeyValueStore.Record.filter(Column("key").like("\(Encounter.keyPrefix)%")).fetchAll(db)
            for r in records where r.key.contains(".running.") {
                // records with old-style RunningEncounter keys

                do {
                    let re = try KeyValueStore.decoder.decode(RunningEncounter.self, from: r.value)

                    let newRecord = KeyValueStore.Record(key: re.key, modifiedAt: r.modifiedAt, value: r.value)
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
            let itemRecords = try! KeyValueStore.Record.filter(Column("key").like("\(CompendiumEntry.keyPrefix())%")).fetchAll(db)
            for var r in itemRecords {
                var entry = try KeyValueStore.decoder.decode(CompendiumEntry.self, from: r.value)
                if var combatant = entry.item as? CompendiumCombatant {
                    combatant.stats.makeSkillAndSaveProficienciesRelative()
                    entry.item = combatant

                    if var character = combatant as? Character {
                        character.stats.level = character.level
                        combatant = character
                    }

                    r.value = try KeyValueStore.encoder.encode(entry)
                    try r.save(db)
                }
            }

            // update combatants in all encounters
            let encounterRecords = try! KeyValueStore.Record.filter(Column("key").like("\(Encounter.keyPrefix)%")).fetchAll(db)
            for var r in encounterRecords {
                var encounter = try KeyValueStore.decoder.decode(Encounter.self, from: r.value)
                for cid in encounter.combatants.ids {
                    encounter.combatants[id: cid]?.definition.stats.makeSkillAndSaveProficienciesRelative()
                    let level = encounter.combatants[id: cid]?.definition.level
                    encounter.combatants[id: cid]?.definition.stats.level = level
                }
                r.value = try KeyValueStore.encoder.encode(encounter)
                try r.save(db)
            }

            // update combatants in all running encounters
            let reRecords = try! KeyValueStore.Record.filter(Column("key").like("\(RunningEncounter.keyPrefix)")).fetchAll(db)
            for var r in reRecords {
                var runningEncounter = try KeyValueStore.decoder.decode(RunningEncounter.self, from: r.value)

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

                r.value = try KeyValueStore.encoder.encode(runningEncounter)
                try r.save(db)
            }
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
