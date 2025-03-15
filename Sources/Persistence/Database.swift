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
import ComposableArchitecture

public class Database {

    let queue: DatabaseQueue
    private let migrator: DatabaseMigrator
    private let importDefaultContent: Bool

    public let keyValueStore: DatabaseKeyValueStore
    public let visitorManager: KeyValueStoreVisitorManager

    public static var uninitialized: Database {
        let db = try! Database(queue: DatabaseQueue(), importDefaultContent: false)
        try! db.migrator.migrate(db.queue)
        return db
    }

    public var access: DatabaseAccess {
        DatabaseQueueAccess(queue: queue)
    }

    // If path is nil, an in-memory database is created
    public convenience init(
        path: String?,
        importDefaultContent: Bool = true
    ) async throws {
        var conf = Configuration()
        conf.publicStatementArguments = true
        conf.prepareDatabase { db in
            db.trace { print($0) }
        }
        let queue = try path.map { try DatabaseQueue(path: $0, configuration: conf) } ?? DatabaseQueue()
        try self.init(queue: queue, importDefaultContent: importDefaultContent)
        try await prepareForUse()
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

        try self.init(queue: queue, importDefaultContent: false)
        try await prepareForUse()
    }

    private init(queue: DatabaseQueue, importDefaultContent: Bool) throws {
        self.queue = queue
        self.migrator = try Self.migrator()
        self.importDefaultContent = importDefaultContent
        self.keyValueStore = DatabaseKeyValueStore(DatabaseQueueAccess(queue: queue))
        self.visitorManager = KeyValueStoreVisitorManager(databaseQueue: queue)

        #if DEBUG
        print("Opened db at path: \(queue.path)")
        #endif
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
            try visitorManager.run(
                visitor: ParseableEntityVisitor.shared,
                conflictResolution: .overwrite
            )
            var preferences: Preferences = try keyValueStore.get(Preferences.key) ?? Preferences()
            preferences.parseableManagerLastRunVersion = ParseableGameModels.combinedVersion
            try keyValueStore.put(preferences)
        }
    }

    public func close() throws {
        try queue.close()
    }

    func importDefaultCompendiumContent(monsters: Bool = true, spells: Bool = true) async throws {
        let compendium = DatabaseCompendium(databaseAccess: DatabaseQueueAccess(queue: queue), fallback: .empty)
        let metadata = CompendiumMetadata.live(self)
        let importer = CompendiumImporter(
            compendium: compendium,
            metadata: metadata
        )

        try await metadata.importDefaultContent()
        try await importer.importDefaultContent(monsters: monsters, spells: spells)
    }

}

public protocol DatabaseAccess {
    func read<T>(_ value: (GRDB.Database) throws -> T) throws -> T
    func write<T>(_ updates: (GRDB.Database) throws -> T) throws -> T
    func observe<R>(_ observation: ValueObservation<R>) -> AsyncThrowingStream<R.Value, Error> where R: ValueReducer

    func inSavepoint(_ operations: (GRDB.Database) throws -> GRDB.Database.TransactionCompletion) throws
}

public struct DatabaseQueueAccess: DatabaseAccess {
    let queue: DatabaseQueue

    public func read<T>(_ value: (GRDB.Database) throws -> T) throws -> T {
        try queue.read(value)
    }

    public func write<T>(_ updates: (GRDB.Database) throws -> T) throws -> T {
        try queue.write(updates)
    }

    public func observe<R>(_ observation: ValueObservation<R>) -> AsyncThrowingStream<R.Value, Error> where R: ValueReducer {
        observation.values(in: queue).stream
    }

    public func inSavepoint(_ operations: (GRDB.Database) throws -> GRDB.Database.TransactionCompletion) throws {
        try queue.write { db in
            try db.inSavepoint {
                try operations(db)
            }
        }
    }
}

public struct DirectDatabaseAccess: DatabaseAccess {
    let db: GRDB.Database

    public func read<T>(_ value: (GRDB.Database) throws -> T) throws -> T {
        try value(db)
    }

    public func write<T>(_ updates: (GRDB.Database) throws -> T) throws -> T {
        try updates(db)
    }

    public func observe<R>(_ observation: ValueObservation<R>) -> AsyncThrowingStream<R.Value, Error> where R : ValueReducer {
        assertionFailure("DatabaseAccess.observe not supported on DirectDatabaseAccess")
        return .finished(throwing: DirectDatabaseAccessError.unsupportedOperation)
    }

    public func inSavepoint(_ operations: (GRDB.Database) throws -> GRDB.Database.TransactionCompletion) throws {
        try db.inSavepoint {
            try operations(db)
        }
    }
}

public extension DatabaseAccess where Self == DatabaseQueueAccess {
    static func queue(_ queue: DatabaseQueue) -> Self {
        DatabaseQueueAccess(queue: queue)
    }
}

public extension DatabaseAccess where Self == DirectDatabaseAccess {
    static func direct(_ db: GRDB.Database) -> Self {
        DirectDatabaseAccess(db: db)
    }
}

enum DirectDatabaseAccessError: Error {
    case unsupportedOperation
}

extension Database: DependencyKey {
    public static var liveValue: Database {
//        assertionFailure("Database dependency is not configured")
        return .uninitialized
    }
}

public extension DependencyValues {
    var database: Database {
        get { self[Database.self] }
        set { self[Database.self] = newValue }
    }
}
