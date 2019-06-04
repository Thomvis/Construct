//
//  Migrations.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 02/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB
import Combine

extension Database {
    private static let v1 = "v1"

    func migrator(_ queue: DatabaseQueue, importDefaultContent: Bool = true) throws -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        let appliedMigrations: Set<String>
        do {
            appliedMigrations = try migrator.appliedMigrations(in: queue)
        } catch {
            appliedMigrations = Set()
        }

        var didImportDefaultContent = false

        migrator.registerMigration(Self.v1) { db in
            try db.create(table: "key_value") { t in
                t.column("key", .text).primaryKey()
                t.column("modified_at", .integer)
                t.column("value", .blob)
            }

            try db.create(virtualTable: "key_value_fts", using: FTS5()) { t in
                t.content = nil
                t.tokenizer = .unicode61()

                t.column("title")
                t.column("subtitle")
                t.column("body")
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
                let encounter = Encounter(id: Encounter.scratchPadEncounterId, name: "Scratch pad", combatants: [])

                try self.keyValueStore.put(encounter, in: db)
                try self.keyValueStore.put(CampaignNode.scratchPadEncounter, in: db)
            }
        }

        migrator.registerMigration("v4-encounter.ensureStableDiscriminators") { db in
            let encounters = try KeyValueStore.Record.filter(Column("key").like("\(Encounter.keyValueStoreEntityKeyPrefix)%")).fetchAll(db)
            for e in encounters {
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

                return try KeyValueStore.Record.filter(Column("key").like("\(RunningEncounter.keyPrefix(for: uuid))%")).fetchAll(db)
            }

            for runRecord in runs {
                guard var run = try JSONSerialization.jsonObject(with: runRecord.value, options: []) as? [String: Any] else { continue }

                // migrate turn
                if let round = run["round"] as? Int,
                    let combatantIdString = run["turn"] as? String,
                    let combatantId = UUID(uuidString: combatantIdString) {

                    let encodedTurn = try JSONEncoder().encode(RunningEncounter.Turn(round: round, combatantId: combatantId))
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

                            let encodedTurn = try JSONEncoder().encode(RunningEncounter.Turn(round: round, combatantId: combatantId))
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
