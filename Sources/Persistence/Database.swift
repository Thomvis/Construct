//
//  Database.swift
//  Construct
//
//  Created by Thomas Visser on 02/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB
import Compendium
import Combine
import GameModels

public class Database {

    let queue: DatabaseQueue
    private let migrator: DatabaseMigrator
    private let importDefaultContent: Bool

    public let keyValueStore: KeyValueStore
    public let parseableManager: ParseableKeyValueRecordManager

    // If path is nil, an in-memory database is created
    public convenience init(
        path: String?,
        importDefaultContent: Bool = true
    ) async throws {
        let queue = try path.map { try DatabaseQueue(path: $0) } ?? DatabaseQueue()
        try await self.init(queue: queue, importDefaultContent: importDefaultContent)
    }

    /// Copies all content from `source` into this database
    public convenience init(
        path: String?,
        source: Database
    ) async throws {
        let queue = try path.map { try DatabaseQueue(path: $0) } ?? DatabaseQueue()

        try await withCheckedThrowingContinuation { continuation in
            do {
                try source.queue.backup(to: queue) { progress in
                    if progress.isCompleted {
                        continuation.resume()
                    }
                }
            } catch {
                continuation.resume(with: .failure(error))
            }
        }

        try await self.init(queue: queue, importDefaultContent: false)
    }

    private init(queue: DatabaseQueue, importDefaultContent: Bool) async throws {
        self.queue = queue
        self.migrator = try Self.migrator()
        self.importDefaultContent = importDefaultContent
        self.keyValueStore = KeyValueStore(queue)
        self.parseableManager = ParseableKeyValueRecordManager(queue)

        try await prepareForUse()
    }

    public var needsPrepareForUse: Bool {
        return needsMigrations
            || needsDefaultCompendiumContentImport
            || needsScratchPadEncounterCreation
            || needsParseableProcessing
    }

    private var needsMigrations: Bool {
        do {
            return !(try queue.read(migrator.hasCompletedMigrations))
        } catch {
            return false
        }
    }

    private var needsDefaultCompendiumContentImport: Bool {
        guard importDefaultContent else { return false }

        do {
            let registeredMigrations = Set(migrator.migrations)
            let appliedMigrations = try queue.read { db in
                try self.migrator.appliedMigrations(db)
            }
            let pendingMigrations = registeredMigrations.subtracting(appliedMigrations)
            let hasLegacyImport = !pendingMigrations.intersection(legacyDefaultContentImportingMigrations.map(\.rawValue)).isEmpty

            if hasLegacyImport {
                return true
            } else if let versions: DefaultContentVersions = try keyValueStore.get(DefaultContentVersions.key) {
                return versions != DefaultContentVersions.current
            } else {
                return false
            }
        } catch {
            return false
        }
    }

    private var needsParseableProcessing: Bool {
        do {
            guard let preferences: Preferences = try keyValueStore.get(Preferences.key) else { return true }
            return preferences.parseableManagerLastRunVersion != ParseableGameModels.combinedVersion
        } catch {
            return false
        }
    }

    private var needsScratchPadEncounterCreation: Bool {
        guard importDefaultContent else { return false }
        do {
            return try !keyValueStore.contains(Encounter.key(Encounter.scratchPadEncounterId))
        } catch {
            return false
        }
    }

    public func prepareForUse() async throws {
        let needsDefaultContentImport = self.needsDefaultCompendiumContentImport // store this before migrating because it affects hasLegacyImport

        // migrate
        try migrator.migrate(self.queue)

        // import default content
        if needsDefaultContentImport {
            let versions: DefaultContentVersions? = try keyValueStore.get(DefaultContentVersions.key)

            // compendium
            try await self.importDefaultCompendiumContent(
                monsters: versions?.monsters != DefaultContentVersions.current.monsters,
                spells: versions?.spells != DefaultContentVersions.current.spells
            )
            try keyValueStore.put(DefaultContentVersions.current)
        }

        // scratch pad
        if needsScratchPadEncounterCreation {
            let encounter = Encounter(id: Encounter.scratchPadEncounterId.rawValue, name: "Scratch pad", combatants: [])
            try keyValueStore.put(encounter)
            try keyValueStore.put(CampaignNode.scratchPadEncounter)
        }

        // process parseables
        if needsParseableProcessing {
            try parseableManager.run()
            var preferences: Preferences = try keyValueStore.get(Preferences.key) ?? Preferences()
            preferences.parseableManagerLastRunVersion = ParseableGameModels.combinedVersion
            try keyValueStore.put(preferences)
        }
    }

    public func close() throws {
        try queue.close()
    }

    func importDefaultCompendiumContent(monsters: Bool = true, spells: Bool = true) async throws {
        let compendium = DatabaseCompendium(database: self, fallback: .empty)
        try await compendium.importDefaultContent(monsters: monsters, spells: spells)
    }

}
