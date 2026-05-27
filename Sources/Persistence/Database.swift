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
            || needsHomebrewCompendiumMetadataBootstrap
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

    private var needsHomebrewCompendiumMetadataBootstrap: Bool {
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
        // migrate
        try migrator.migrate(self.queue)

        if needsHomebrewCompendiumMetadataBootstrap {
            try await ensureHomebrewCompendiumMetadata()
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

    public func suggestedDefaultContentSelection() throws -> Set<DefaultContentRuleset> {
        let selectionNeedingImport = try defaultContentSelectionNeedingImport()
        if !selectionNeedingImport.isEmpty {
            return selectionNeedingImport
        }

        let versions = try defaultContentImportJobs().versions
        if !versions.importedRulesets.isEmpty {
            return versions.importedRulesets
        }

        return [.rules2014]
    }

    public func defaultContentSelectionNeedingImport() throws -> Set<DefaultContentRuleset> {
        let sources = try defaultContentSourcesNeedingImport(selection: Set(DefaultContentRuleset.allCases))
        return Set(sources.map(\.ruleset))
    }

    public func applyDefaultContentSelection(_ selection: Set<DefaultContentRuleset>) async throws {
        guard !selection.isEmpty else {
            throw DefaultContentSelectionError.emptySelection
        }

        try await ensureHomebrewCompendiumMetadata()
        try await importDefaultCompendiumContentIfNeeded(selection: selection)
    }

    public struct DefaultContentDocumentStatus: Equatable, Sendable {
        public let importedRulesets: Set<DefaultContentRuleset>
        public let newRulesets: Set<DefaultContentRuleset>
        public let updatedRulesets: Set<DefaultContentRuleset>

        public init(
            importedRulesets: Set<DefaultContentRuleset>,
            newRulesets: Set<DefaultContentRuleset>,
            updatedRulesets: Set<DefaultContentRuleset>
        ) {
            self.importedRulesets = importedRulesets
            self.newRulesets = newRulesets
            self.updatedRulesets = updatedRulesets
        }

        public var hasAnyImportAvailable: Bool {
            !newRulesets.isEmpty || !updatedRulesets.isEmpty
        }

        public func isImported(_ ruleset: DefaultContentRuleset) -> Bool {
            importedRulesets.contains(ruleset)
        }

        public func isNewContent(_ ruleset: DefaultContentRuleset) -> Bool {
            newRulesets.contains(ruleset)
        }

        public func isUpdateAvailable(_ ruleset: DefaultContentRuleset) -> Bool {
            updatedRulesets.contains(ruleset)
        }
    }

    public func defaultContentDocumentStatus() throws -> DefaultContentDocumentStatus {
        let versions = try defaultContentImportJobs().versions
        return DefaultContentDocumentStatus(
            importedRulesets: versions.importedRulesets,
            newRulesets: versions.newRulesets,
            updatedRulesets: versions.updatedRulesets
        )
    }

    private func ensureHomebrewCompendiumMetadata() async throws {
        let metadata = CompendiumMetadata.live(self)
        try await metadata.ensureHomebrewMetadata()
    }

    private func importDefaultCompendiumContentIfNeeded(selection: Set<DefaultContentRuleset>) async throws {
        let metadata = CompendiumMetadata.live(self)
        for ruleset in selection {
            try await metadata.ensureEditionMetadata(ruleset.edition)
        }

        let sources = try defaultContentSourcesNeedingImport(selection: selection)

        guard !sources.isEmpty else { return }

        try await importDefaultCompendiumContent(sources: sources)
    }

    private func defaultContentSourcesNeedingImport(
        selection: Set<DefaultContentRuleset>
    ) throws -> Set<DefaultContentSource> {
        try DefaultContentVersions.sourcesNeedingImport(
            selection: selection,
            installed: defaultContentImportJobs().versions
        )
    }

    private struct DefaultContentImportJobs {
        var latestMonsters2014: CompendiumImportJob?
        var latestSpells2014: CompendiumImportJob?
        var latestMonsters2024: CompendiumImportJob?
        var latestSpells2024: CompendiumImportJob?

        var versions: DefaultContentVersions {
            DefaultContentVersions(
                monsters2014: latestMonsters2014?.sourceVersion,
                spells2014: latestSpells2014?.sourceVersion,
                monsters2024: latestMonsters2024?.sourceVersion,
                spells2024: latestSpells2024?.sourceVersion
            )
        }
    }

    private func defaultContentImportJobs() throws -> DefaultContentImportJobs {
        DefaultContentImportJobs(
            latestMonsters2014: try latestImportJob(sourceId: .defaultMonsters2014),
            latestSpells2014: try latestImportJob(sourceId: .defaultSpells2014),
            latestMonsters2024: try latestImportJob(sourceId: .defaultMonsters2024),
            latestSpells2024: try latestImportJob(sourceId: .defaultSpells2024)
        )
    }

    private func latestImportJob(sourceId: CompendiumImportSourceId) throws -> CompendiumImportJob? {
        let keyPrefix = CompendiumImportJob.keyPrefix + CompendiumImportJob.jobIdPrefix(sourceId: sourceId)
        let jobs: [CompendiumImportJob] = try keyValueStore.fetchAll(.keyPrefix(keyPrefix))
        return jobs
            .filter { $0.sourceId == sourceId }
            .max { $0.timestamp < $1.timestamp }
    }

    func importDefaultCompendiumContent(
        sources: Set<DefaultContentSource> = Set(DefaultContentSource.allCases)
    ) async throws {
        let compendium = DatabaseCompendium(databaseAccess: DatabaseQueueAccess(queue: queue), fallback: .empty)
        let metadata = CompendiumMetadata.live(self)
        let importer = CompendiumImporter(
            compendium: compendium,
            metadata: metadata
        )

        try await importer.importDefaultContent(sources: sources)
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
