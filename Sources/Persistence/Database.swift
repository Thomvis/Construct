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
            || needsDefaultCompendiumMetadataBootstrap
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
            guard let selection = try keyValueStore.get(DefaultContentSelection.key), selection.hasAnySelection else {
                return false
            }

            let registeredMigrations = Set(migrator.migrations)
            let appliedMigrations = try queue.read { db in
                try self.migrator.appliedMigrations(db)
            }
            let pendingMigrations = registeredMigrations.subtracting(appliedMigrations)
            let hasLegacyImport = !pendingMigrations.intersection(legacyDefaultContentImportingMigrations.map(\.rawValue)).isEmpty

            if hasLegacyImport {
                return true
            } else {
                let versions: DefaultContentVersions? = try keyValueStore.get(DefaultContentVersions.key)
                return DefaultContentVersions.componentsNeedingImport(
                    selection: selection,
                    installed: versions
                ).needsAnyImport
            }
        } catch {
            return false
        }
    }

    private var needsDefaultCompendiumMetadataBootstrap: Bool {
        guard importDefaultContent else { return false }

        do {
            let hasHomebrewRealm = try keyValueStore.contains(CompendiumRealm.key(for: CompendiumRealm.homebrew.id))
            let hasHomebrewDocument = try keyValueStore.contains(CompendiumSourceDocument.homebrew.key)
            return !hasHomebrewRealm || !hasHomebrewDocument
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

        if needsDefaultCompendiumMetadataBootstrap {
            try await ensureHomebrewCompendiumMetadata()
        }

        // import default content
        if needsDefaultContentImport {
            if let selection: DefaultContentSelection = try keyValueStore.get(DefaultContentSelection.key),
               selection.hasAnySelection {
                try await importDefaultCompendiumContentIfNeeded(selection: selection)
            } else {
                assertionFailure("Expected default content selection when importing default content")
            }
        }

        // scratch pad
        if needsScratchPadEncounterCreation {
            let encounter = Encounter(id: Encounter.scratchPadEncounterId.rawValue, name: "Scratch pad", combatants: [])
            try keyValueStore.put(encounter)
            try keyValueStore.put(CampaignNode.scratchPadEncounter)
        }

        // preferences migrations
        try initializeAdventureTabModePreferenceIfNeeded()

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

    public func suggestedDefaultContentSelection() throws -> DefaultContentSelection {
        if let selection: DefaultContentSelection = try keyValueStore.get(DefaultContentSelection.key),
           selection.hasAnySelection {
            return selection
        }

        let status = try defaultContentDocumentStatus()
        if status.has2014Document || status.has2024Document {
            return DefaultContentSelection(
                include2014: status.has2014Document,
                include2024: status.has2024Document
            )
        }

        return .rules2014Only
    }

    public func applyDefaultContentSelection(_ selection: DefaultContentSelection) async throws {
        guard selection.hasAnySelection else {
            throw DefaultContentSelectionError.emptySelection
        }

        try keyValueStore.put(selection)
        try await ensureHomebrewCompendiumMetadata()
        try await importDefaultCompendiumContentIfNeeded(selection: selection)
    }

    public struct DefaultContentDocumentStatus: Equatable, Sendable {
        public let has2014Document: Bool
        public let has2024Document: Bool
        public let has2014UpdateAvailable: Bool
        public let has2024UpdateAvailable: Bool

        public init(
            has2014Document: Bool,
            has2024Document: Bool,
            has2014UpdateAvailable: Bool = false,
            has2024UpdateAvailable: Bool = false
        ) {
            self.has2014Document = has2014Document
            self.has2024Document = has2024Document
            self.has2014UpdateAvailable = has2014UpdateAvailable
            self.has2024UpdateAvailable = has2024UpdateAvailable
        }
    }

    public func defaultContentDocumentStatus() throws -> DefaultContentDocumentStatus {
        let documents: [CompendiumSourceDocument] = try keyValueStore.fetchAll(
            .keyPrefix(CompendiumSourceDocument.keyPrefix)
        )
        let has2014Document = documents.contains(where: { $0.id == CompendiumSourceDocument.srd5_1.id })
        let has2024Document = documents.contains(where: { $0.id == CompendiumSourceDocument.srd5_2.id })
        let versions: DefaultContentVersions = try keyValueStore.get(DefaultContentVersions.key) ?? .empty
        return DefaultContentDocumentStatus(
            has2014Document: has2014Document,
            has2024Document: has2024Document,
            has2014UpdateAvailable: has2014Document && versions.needs2014Update,
            has2024UpdateAvailable: has2024Document && versions.needs2024Update
        )
    }

    private func ensureHomebrewCompendiumMetadata() async throws {
        let metadata = CompendiumMetadata.live(self)
        try await metadata.ensureHomebrewMetadata()
    }

    private func importDefaultCompendiumContentIfNeeded(selection: DefaultContentSelection) async throws {
        let metadata = CompendiumMetadata.live(self)
        if selection.include2014 {
            try await metadata.ensureEditionMetadata(.rules2014)
        }
        if selection.include2024 {
            try await metadata.ensureEditionMetadata(.rules2024)
        }

        let versions: DefaultContentVersions = try keyValueStore.get(DefaultContentVersions.key) ?? .empty
        let importComponents = DefaultContentVersions.componentsNeedingImport(
            selection: selection,
            installed: versions
        )

        guard importComponents.needsAnyImport else { return }

        try await importDefaultCompendiumContent(components: importComponents)
        try keyValueStore.put(versions.applyingCurrentVersions(for: importComponents))
    }

    func importDefaultCompendiumContent(
        components: DefaultContentImportComponents
    ) async throws {
        try await importDefaultCompendiumContent(
            monsters2014: components.monsters2014,
            spells2014: components.spells2014,
            monsters2024: components.monsters2024,
            spells2024: components.spells2024
        )
    }

    func importDefaultCompendiumContent(
        monsters2014: Bool = true,
        spells2014: Bool = true,
        monsters2024: Bool = true,
        spells2024: Bool = true
    ) async throws {
        let compendium = DatabaseCompendium(databaseAccess: DatabaseQueueAccess(queue: queue), fallback: .empty)
        let metadata = CompendiumMetadata.live(self)
        let importer = CompendiumImporter(
            compendium: compendium,
            metadata: metadata
        )

        try await importer.importDefaultContent(
            monsters2014: monsters2014,
            spells2014: spells2014,
            monsters2024: monsters2024,
            spells2024: spells2024
        )
    }

    private func initializeAdventureTabModePreferenceIfNeeded() throws {
        var preferences: Preferences = try keyValueStore.get(Preferences.key) ?? Preferences()
        guard preferences.adventureTabMode == nil else { return }

        let rootNodes: [CampaignNode] = try keyValueStore.fetchAll(
            .keyPrefix(CampaignNode.root.keyPrefixForFetchingDirectChildren)
        )
        let hasUserTopLevelItems = rootNodes.contains { $0.special == nil }
        preferences.adventureTabMode = hasUserTopLevelItems ? .campaignBrowser : .simpleEncounter
        try keyValueStore.put(preferences)
    }

}

public enum DefaultContentSelectionError: Error {
    case emptySelection
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

public extension Database {
    static func live() async throws -> Database {
        let dbUrl = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")

        return try await Database(path: dbUrl.absoluteString)
    }
}

struct DatabaseDependencyKey: DependencyKey {
    public static var liveValue: Database {
        assertionFailure("Database dependency is not configured")
        return .uninitialized
    }
}

#if DEBUG
extension DatabaseDependencyKey: TestDependencyKey {
    static var testValue: Database { .uninitialized }
}
#endif

public extension DependencyValues {
    var database: Database {
        get { self[DatabaseDependencyKey.self] }
        set { self[DatabaseDependencyKey.self] = newValue }
    }
}
