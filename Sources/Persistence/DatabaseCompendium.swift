//
//  Compendium.swift
//  Construct
//
//  Created by Thomas Visser on 19/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import GRDB
import GameModels
import Helpers
import Compendium

public class DatabaseCompendium: Compendium {

    private let keyValueStore: KeyValueStore
    public let fallback: ExternalCompendium

    public init(databaseAccess: DatabaseAccess, fallback: ExternalCompendium = .empty) {
        self.keyValueStore = DatabaseKeyValueStore(databaseAccess)
        self.fallback = fallback
    }

    public func get(_ key: CompendiumItemKey) throws -> CompendiumEntry? {
        try keyValueStore.get(key)
    }

    public func get(_ key: CompendiumItemKey, crashReporter: CrashReporter) throws -> CompendiumEntry? {
        try keyValueStore.get(key, crashReporter: crashReporter)
    }

    public func put(_ entry: CompendiumEntry) throws {
        try keyValueStore.put(entry, fts: entry.ftsDocument, secondaryIndexValues: entry.secondaryIndexValues)
    }

    public func contains(_ key: GameModels.CompendiumItemKey) throws -> Bool {
        try keyValueStore.contains(CompendiumEntry.key(for: key))
    }

    public func fetch(_ request: CompendiumFetchRequest) throws -> [CompendiumEntry] {
        try keyValueStore.fetchAll(toKeyValueStoreRequest(request))
    }

    public func fetchCatching(_ request: CompendiumFetchRequest) throws -> [Result<CompendiumEntry, any Error>] {
        try keyValueStore.fetchAllCatching(toKeyValueStoreRequest(request))
    }

    public func fetchKeys(_ request: CompendiumFetchRequest) throws -> [CompendiumItemKey] {
        let keys = try keyValueStore.fetchKeys(toKeyValueStoreRequest(request))
        return keys.compactMap {
            let res = CompendiumItemKey(compendiumEntryKey: $0)
            assert(res != nil)
            return res
        }
    }

    public func count(_ request: CompendiumFetchRequest) throws -> Int {
        try keyValueStore.count(toKeyValueStoreRequest(request))
    }

    public func resolve(annotation: CompendiumItemReferenceTextAnnotation) -> ReferenceResolveResult {
        let internalResults = try? fetch(CompendiumFetchRequest(search: annotation.text, filters: .init(types: annotation.type.map { [$0] }), order: .title, range: nil))

        if let exactMatch = internalResults?.first(where: { $0.item.title.caseInsensitiveCompare(annotation.text) == .orderedSame }) {
            return .internal(CompendiumItemReference(itemTitle: exactMatch.item.title, itemKey: exactMatch.item.key))
        }

        // Prefer results with a shorter title, so that "shield" does not match "fire shield" before "shield"
        if let first = internalResults?.sorted(by: { $0.item.title.count < $1.item.title.count }).first {
            return .internal(CompendiumItemReference(itemTitle: first.item.title, itemKey: first.item.key))
        }

        if let external = fallback.url(for: annotation) {
            return .external(external)
        }

        return .notFound
    }

    fileprivate func toKeyValueStoreRequest(_ request: CompendiumFetchRequest) throws -> KeyValueStoreRequest {
        try Self.toKeyValueStoreRequest(request, using: keyValueStore)
    }

    fileprivate static func toKeyValueStoreRequest(
        _ request: CompendiumFetchRequest,
        using keyValueStore: KeyValueStore
    ) throws -> KeyValueStoreRequest {
        let sourceDocuments: [CompendiumSourceDocument]
        if request.filters?.containsRealmSourceScope == true {
            sourceDocuments = try keyValueStore.fetchAll(.keyPrefix(CompendiumSourceDocument.keyPrefix))
        } else {
            sourceDocuments = []
        }

        let keyPrefixes = request.filters?.types.map { $0.map { CompendiumEntry.keyPrefix(for: $0) } } ?? [CompendiumEntry.keyPrefix]

        // Ensure we order on title, either as first or fallback order
        let effectiveOrder: [SecondaryIndexOrder]
        if let order = request.order, order.key == .title {
            effectiveOrder = [SecondaryIndexOrder(order)]
        } else {
            effectiveOrder = request.order.map(SecondaryIndexOrder.init).nonNilArray + [SecondaryIndexOrder(.title)]
        }

        return KeyValueStoreRequest(
            keyPrefixes: keyPrefixes,
            fullTextSearch: request.search,
            filters: request.filters?.secondaryIndexFilters(sourceDocuments: sourceDocuments) ?? [],
            order: effectiveOrder,
            range: request.range
        )
    }
}

public extension CompendiumItemField {
    static func challengeRatingIndexValue(from fraction: Fraction) -> String {
        fraction.double
            .formatted(.number.precision(
                .integerAndFractionLength(integerLimits: 3...3, fractionLimits: 0...3)
            ))
    }
}

extension CompendiumEntry: FTSDocumentConvertible, SecondaryIndexValueRepresentable {
    public var ftsDocument: FTSDocument {
        Persistence.FTSDocument(title: item.title, subtitle: nil, body: nil)
    }

    public var secondaryIndexValues: [Int: String] {
        var values: [Int: String] = [
            SecondaryIndexes.compendiumEntryTitle: item.title,
            SecondaryIndexes.compendiumEntrySourceDocumentKey: CompendiumSourceDocument
                .key(for: sourceDocumentKey)
                .rawValue
        ]
        if let monster = item as? Monster {
            // format the CR so that it sorts correctly, examples:
            // CR 1/4 = 000.25
            // CR 1   = 001
            // CR 10  = 010
            let cr = CompendiumItemField.challengeRatingIndexValue(from: monster.challengeRating)
            values[SecondaryIndexes.compendiumEntryMonsterChallengeRating] = cr

            if let type = monster.stats.type?.result?.value?.rawValue {
                values[SecondaryIndexes.compendiumEntryMonsterType] = type
            }
        } else if let spell = item as? Spell {
            let levelString = spell.level.map { "\($0)" } ?? "0"
            values[SecondaryIndexes.compendiumEntrySpellLevel] = levelString
            // use title as tie breaker?
        }
        return values
    }

}

public extension KeyValueStore {
    func get(_ itemKey: CompendiumItemKey) throws -> CompendiumEntry? {
        return try get(CompendiumEntry.key(for: itemKey))
    }

    @discardableResult
    func remove(_ itemKey: CompendiumItemKey) throws -> Bool {
        try remove(CompendiumEntry.key(for: itemKey))
    }

    func get(_ itemKey: CompendiumItemKey, crashReporter: CrashReporter) throws -> CompendiumEntry? {
        try get(CompendiumEntry.key(for: itemKey), crashReporter: crashReporter)
    }
}

extension SecondaryIndexOrder {
    init(_ order: Order) {
        switch order.key {
        case .title: self.index = SecondaryIndexes.compendiumEntryTitle
        case .monsterChallengeRating: self.index = SecondaryIndexes.compendiumEntryMonsterChallengeRating
        case .spellLevel: self.index = SecondaryIndexes.compendiumEntrySpellLevel
        }
        self.ascending = order.ascending
    }
}

extension CompendiumFilters {
    func secondaryIndexFilters(sourceDocuments: [CompendiumSourceDocument]) -> [SecondaryIndexFilter] {
        var result = Array(builder: {
            if let minMonsterChallengeRating {
                SecondaryIndexFilter(
                    index: SecondaryIndexes.compendiumEntryMonsterChallengeRating,
                    condition: .greaterThanOrEqualTo(CompendiumItemField.challengeRatingIndexValue(from: minMonsterChallengeRating))
                )
            }

            if let maxMonsterChallengeRating {
                SecondaryIndexFilter(
                    index: SecondaryIndexes.compendiumEntryMonsterChallengeRating,
                    condition: .lessThanOrEqualTo(CompendiumItemField.challengeRatingIndexValue(from: maxMonsterChallengeRating))
                )
            }

            if let monsterType {
                SecondaryIndexFilter(
                    index: SecondaryIndexes.compendiumEntryMonsterType,
                    condition: .equals(monsterType.rawValue)
                )
            }
        })

        if let sources = resolvedSources(sourceDocuments: sourceDocuments) {
            result.append(
                SecondaryIndexFilter(
                    index: SecondaryIndexes.compendiumEntrySourceDocumentKey,
                    condition: .oneOf(sources.map {
                        CompendiumSourceDocument.key(for: $0.documentKey).rawValue
                    })
                )
            )
        }

        return result
    }

    fileprivate func resolvedSources(sourceDocuments: [CompendiumSourceDocument]) -> [Source]? {
        guard let sourceScopes else {
            return nil
        }

        let selectedRealmIds = Set(self.selectedRealmIds)
        let sources = Set((sourceScopes.compactMap { scope -> Source? in
            guard case let .document(source) = scope else { return nil }
            return source
        }) + sourceDocuments.compactMap { sourceDocument in
            selectedRealmIds.contains(sourceDocument.realmId) ? Source(sourceDocument) : nil
        })

        return sources.sorted {
            ($0.realm.rawValue, $0.document.rawValue) < ($1.realm.rawValue, $1.document.rawValue)
        }
    }
}

public extension CompendiumMetadata {

    static func live(_ database: Database) -> Self {
        let store = database.keyValueStore
        return CompendiumMetadata {
            try store.fetchAll(.keyPrefix(CompendiumSourceDocument.keyPrefix))
        } observeSourceDocuments: {
            store.observeAll(.keyPrefix(CompendiumSourceDocument.keyPrefix))
        } realms: {
            try store.fetchAll(.keyPrefix(CompendiumRealm.keyPrefix))
        } observeRealms: {
            store.observeAll(.keyPrefix(CompendiumRealm.keyPrefix))
        } putJob: { job in
            try store.put(job)
        } latestImportJob: { sourceId in
            let keyPrefix = CompendiumImportJob.keyPrefix + CompendiumImportJob.jobIdPrefix(sourceId: sourceId)
            let jobs: [CompendiumImportJob] = try store.fetchAll(.keyPrefix(keyPrefix))
            return jobs
                .filter { $0.sourceId == sourceId }
                .max { $0.timestamp < $1.timestamp }
        } createRealm: { realm in
            if try store.contains(realm.key) {
                throw CompendiumMetadataError.resourceAlreadyExists
            }

            try store.put(realm)
        } updateRealm: { id, displayName in
            if try !store.contains(CompendiumRealm.key(for: id)) {
                throw CompendiumMetadataError.resourceNotFound
            }

            try store.put(CompendiumRealm(id: id, displayName: displayName))
        } removeRealm: { id in
            let key = CompendiumRealm.key(for: id)
            if try !store.contains(key) {
                throw CompendiumMetadataError.resourceNotFound
            }

            if try store.count(.keyPrefix(CompendiumSourceDocument.keyPrefix(for: id).rawValue)) > 0 {
                throw CompendiumMetadataError.resourceNotEmpty
            }

            try store.remove(key)
        } createDocument: { doc in
            let documents: [CompendiumSourceDocument] = try store.fetchAll(.keyPrefix(CompendiumSourceDocument.keyPrefix))
            if documents.contains(where: { $0.id == doc.id }) {
                throw CompendiumMetadataError.resourceAlreadyExists
            }

            if try !store.contains(CompendiumRealm.key(for: doc.realmId)) {
                throw CompendiumMetadataError.invalidRealmId
            }

            try store.put(doc)
        } updateDocument: { doc, originalDocumentKey in
            try database.queue.inTransaction { db in
                let dbAccess = DirectDatabaseAccess(db: db)
                let store = DatabaseKeyValueStore(dbAccess)

                let originalKey = CompendiumSourceDocument.key(for: originalDocumentKey)
                if try !store.contains(originalKey) {
                    throw CompendiumMetadataError.resourceNotFound
                }

                if originalKey != doc.key && CompendiumSourceDocument.isDefaultDocument(id: originalDocumentKey.documentId) {
                    throw CompendiumMetadataError.cannotMoveDefaultResource
                }

                let documents: [CompendiumSourceDocument] = try store.fetchAll(.keyPrefix(CompendiumSourceDocument.keyPrefix))
                if doc.key != originalKey
                    && documents.contains(where: { $0.id == doc.id && $0.key != originalKey }) {
                    throw CompendiumMetadataError.resourceAlreadyExists
                }

                if try doc.realmId != originalDocumentKey.realmId && !store.contains(CompendiumRealm.key(for: doc.realmId)) {
                    throw CompendiumMetadataError.invalidRealmId
                }

                let moving: Set<CompendiumItemKey>?
                if doc.realmId != originalDocumentKey.realmId {
                    let compendium = DatabaseCompendium(databaseAccess: dbAccess)
                    moving = try Set(compendium.fetchKeys(filters: .init(
                        sourceScopes: [.document(.init(originalDocumentKey))]
                    )))
                } else {
                    moving = nil
                }

                let visitorManager = KeyValueStoreVisitorManager(databaseAccess: DirectDatabaseAccess(db: db))

                let updatedItemReference: ((CompendiumItemKey) -> CompendiumItemKey?)?
                if doc.realmId != originalDocumentKey.realmId, let moving {
                    updatedItemReference = { key -> CompendiumItemKey? in
                        guard moving.contains(key) else { return nil }
                        return CompendiumItemKey(
                            type: key.type,
                            realm: .init(doc.realmId),
                            identifier: key.identifier
                        )
                    }
                } else {
                    updatedItemReference = nil
                }

                let visitors = compendiumSourceDocumentUpdateVisitors(
                    originalDocumentKey: originalDocumentKey,
                    targetDocument: doc,
                    updatedItemReference: updatedItemReference
                )
                
                // Run all visitors in a single pass
                try visitorManager.run(
                    visitors: visitors,
                    conflictResolution: .rename(fallback: .remove)
                )

                if originalKey != doc.key {
                    // it's a move
                    try store.put(doc)
                    try store.remove(originalKey)
                } else {
                    try store.put(doc)
                }

                return .commit
            }
        } removeDocument: { documentKey in
            let key = CompendiumSourceDocument.key(for: documentKey)
            if try !store.contains(key) {
                throw CompendiumMetadataError.resourceNotFound
            }

            try store.transaction { store in
                try store.remove(key)

                _ = try store.removeAll(.init(
                    keyPrefix: CompendiumEntry.keyPrefix,
                    filters: [
                        SecondaryIndexFilter(
                            index: SecondaryIndexes.compendiumEntrySourceDocumentKey,
                            condition: .equals(key.rawValue)
                        )
                    ]
                ))
            }
        }
    }

}

@discardableResult
public func transfer(
    _ selection: CompendiumItemSelection,
    mode: TransferMode,
    target: CompendiumFilters.Source,
    conflictResolution: ConflictResolution,
    db: DatabaseAccess
) async throws -> [String] {
    var result: [String] = []
    let keyValueStore = DatabaseKeyValueStore(db)

    guard let targetDocument = try keyValueStore.get(CompendiumSourceDocument.key(for: target.documentKey)) else {

        throw CompendiumMetadataError.resourceNotFound
    }

    try db.inSavepoint { db in
        let visitorManager = KeyValueStoreVisitorManager(databaseAccess: DirectDatabaseAccess(db: db))

        // Step 1: transfer items
        let visitorConflictResolution: KeyValueStoreVisitorManager.ConflictResolution = switch conflictResolution {
            case .skip: .skip
            case .overwrite: .overwrite
            case .keepBoth: .rename(fallback: .skip)
        }

        let visitors: [KeyValueStoreEntityVisitor] = Array {
            AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateEntryDocumentGameModelsVisitor(
                originalDocumentKey: nil,
                targetDocument: targetDocument
            ))

// TODO: understand why past me wanted to add this logic (it was never committed)
//            if mode == .copy {
//                AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateOriginGameModelsVisitor())
//            }
        }

        var keyChangesAccum: [String: String] = [:]
        var successAccum: [String] = []

        let scope: KeyValueStoreRequest
        switch selection {
        case .single(let compendiumItemKey):
            scope = KeyValueStoreRequest(keys: [CompendiumEntry.key(for: compendiumItemKey).rawValue])
        case .multipleFetchRequest(let compendiumFetchRequest):
            scope = try DatabaseCompendium.toKeyValueStoreRequest(compendiumFetchRequest, using: keyValueStore)
        case .multipleKeys(let keys):
            scope = KeyValueStoreRequest(
                keys: keys.map { CompendiumEntry.key(for: $0).rawValue }
            )
        }

        let transferVisitorResult = try visitorManager.run(
            scope: scope,
            visitors: visitors,
            conflictResolution: visitorConflictResolution,
            removeOriginalEntityOnKeyChange: mode == .move,
            conflictWithOriginalEntity: mode == .copy
        )
        keyChangesAccum.merge(transferVisitorResult.keyChanges, uniquingKeysWith: { $1 })
        successAccum.append(contentsOf: transferVisitorResult.success)


        // Step 2: update references to transferred items (if moved)
        if mode == .move {
            let keyChanges = keyChangesAccum

            // update references to transferred items
            let referenceVisitor = UpdateItemReferenceGameModelsVisitor { key -> CompendiumItemKey? in
                let oldKeyString = CompendiumEntry.key(for: key).rawValue
                if let newKeyString = keyChanges[oldKeyString] {
                    return CompendiumItemKey(compendiumEntryKey: newKeyString)
                }
                return nil
            }
            try visitorManager.run(
                visitor: AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: referenceVisitor),
                conflictResolution: .skip
            )
        }
        result = successAccum

        return .commit
    }
    return result
}
