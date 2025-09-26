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
        try keyValueStore.fetchAll(request.toKeyValueStoreRequest())
    }

    public func fetchCatching(_ request: CompendiumFetchRequest) throws -> [Result<CompendiumEntry, any Error>] {
        try keyValueStore.fetchAllCatching(request.toKeyValueStoreRequest())
    }

    public func fetchKeys(_ request: CompendiumFetchRequest) throws -> [CompendiumItemKey] {
        let keys = try keyValueStore.fetchKeys(request.toKeyValueStoreRequest())
        return keys.compactMap {
            let res = CompendiumItemKey(compendiumEntryKey: $0)
            assert(res != nil)
            return res
        }
    }

    public func count(_ request: CompendiumFetchRequest) throws -> Int {
        try keyValueStore.count(request.toKeyValueStoreRequest())
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
            SecondaryIndexes.compendiumEntrySourceDocumentId: document.id.rawValue
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
    var secondaryIndexFilters: [SecondaryIndexFilter] {
        Array(builder: {
            if let source {
                SecondaryIndexFilter(
                    index: SecondaryIndexes.compendiumEntrySourceDocumentId,
                    condition: .equals(source.document.rawValue)
                )
            }

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
            if try store.contains(doc.key) {
                throw CompendiumMetadataError.resourceAlreadyExists
            }

            if try !store.contains(CompendiumRealm.key(for: doc.realmId)) {
                throw CompendiumMetadataError.invalidRealmId
            }

            try store.put(doc)
        } updateDocument: { doc, originalRealmId, originalDocumentId in
            try database.queue.inTransaction { db in
                let dbAccess = DirectDatabaseAccess(db: db)
                let store = DatabaseKeyValueStore(dbAccess)

                let originalKey = CompendiumSourceDocument.key(forRealmId: originalRealmId, documentId: originalDocumentId)
                if try !store.contains(originalKey) {
                    throw CompendiumMetadataError.resourceNotFound
                }

                if try doc.realmId != originalRealmId && !store.contains(CompendiumRealm.key(for: doc.realmId)) {
                    throw CompendiumMetadataError.invalidRealmId
                }

                let moving: Set<CompendiumItemKey>?
                if doc.realmId != originalRealmId {
                    let compendium = DatabaseCompendium(databaseAccess: dbAccess)
                    moving = try Set(compendium.fetchKeys(filters: .init(
                        source: .init(
                            realm: originalRealmId,
                            document: originalDocumentId
                        )
                    )))
                } else {
                    moving = nil
                }

                let visitorManager = KeyValueStoreVisitorManager(databaseAccess: DirectDatabaseAccess(db: db))

                // Create all necessary visitors
                let visitors: [KeyValueStoreEntityVisitor] = Array {
                    // Updates entries with new document info
                    AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateEntryDocumentGameModelsVisitor(
                        originalDocumentId: originalDocumentId,
                        targetDocument: doc
                    ))

                    // Updates document id in import job(s)
                    if doc.id != originalDocumentId {
                        AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateImportJobDocumentGameModelsVisitor(
                            originalDocumentId: originalDocumentId,
                            updatedDocumentId: doc.id
                        ))
                    }

                    // Updates compendium item references if realm changed
                    if doc.realmId != originalRealmId, let moving = moving {
                        AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateItemReferenceGameModelsVisitor { key -> CompendiumItemKey? in
                            guard moving.contains(key) else { return nil }
                            return CompendiumItemKey(
                                type: key.type,
                                realm: .init(doc.realmId),
                                identifier: key.identifier
                            )
                        })
                    }
                }
                
                // Run all visitors in a single pass
                try visitorManager.run(
                    visitors: visitors,
                    conflictResolution: .rename(fallback: .remove)
                )

                if originalKey != doc.key {
                    // it's a move
                    if CompendiumSourceDocument.isDefaultDocument(id: originalDocumentId) {
                        throw CompendiumMetadataError.cannotMoveDefaultResource
                    }

                    try store.put(doc)
                    try store.remove(originalKey)
                } else {
                    try store.put(doc)
                }

                return .commit
            }
        } removeDocument: { realmId, documentId in
            let key = CompendiumSourceDocument.key(forRealmId: realmId, documentId: documentId)
            if try !store.contains(key) {
                throw CompendiumMetadataError.resourceNotFound
            }

            try store.transaction { store in
                try store.remove(key)

                _ = try store.removeAll(.init(
                    keyPrefix: CompendiumEntry.keyPrefix,
                    filters: [
                        SecondaryIndexFilter(
                            index: SecondaryIndexes.compendiumEntrySourceDocumentId,
                            condition: .equals(documentId.rawValue)
                        )
                    ]
                ))
            }
        }
    }

}

extension CompendiumFetchRequest {
    func toKeyValueStoreRequest() -> KeyValueStoreRequest {
        let keyPrefixes = filters?.types.map { $0.map { CompendiumEntry.keyPrefix(for: $0) } } ?? [CompendiumEntry.keyPrefix]

        // Ensure we order on title, either as first or fallback order
        let effectiveOrder: [SecondaryIndexOrder]
        if let order, order.key == .title {
            effectiveOrder = [SecondaryIndexOrder(order)]
        } else {
            effectiveOrder = order.map(SecondaryIndexOrder.init).nonNilArray + [SecondaryIndexOrder(.title)]
        }

        return KeyValueStoreRequest(
            keyPrefixes: keyPrefixes,
            fullTextSearch: search,
            filters: filters?.secondaryIndexFilters ?? [],
            order: effectiveOrder,
            range: range
        )
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

    guard let targetDocument = try keyValueStore.get(CompendiumSourceDocument.key(forRealmId: target.realm, documentId: target.document)) else {

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
                originalDocumentId: nil,
                targetDocument: targetDocument
            ))

// TODO: understand why past me wanted to add this logic (it was never committed)
//            if mode == .copy {
//                AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateOriginGameModelsVisitor())
//            }
        }

        var keyChangesAccum: [String: String] = [:]
        var successAccum: [String] = []

        switch selection {
        case .single(let compendiumItemKey):
            let scope = KeyValueStoreRequest(keys: [CompendiumEntry.key(for: compendiumItemKey).rawValue])
            let transferVisitorResult = try visitorManager.run(
                scope: scope,
                visitors: visitors,
                conflictResolution: visitorConflictResolution,
                removeOriginalEntityOnKeyChange: mode == .move,
                conflictWithOriginalEntity: true
            )
            keyChangesAccum.merge(transferVisitorResult.keyChanges, uniquingKeysWith: { $1 })
            successAccum.append(contentsOf: transferVisitorResult.success)
        case .multipleFetchRequest(let compendiumFetchRequest):
            let scope = compendiumFetchRequest.toKeyValueStoreRequest()
            let transferVisitorResult = try visitorManager.run(
                scope: scope,
                visitors: visitors,
                conflictResolution: visitorConflictResolution,
                removeOriginalEntityOnKeyChange: mode == .move,
                conflictWithOriginalEntity: true
            )
            keyChangesAccum.merge(transferVisitorResult.keyChanges, uniquingKeysWith: { $1 })
            successAccum.append(contentsOf: transferVisitorResult.success)
        case .multipleKeys(let keys):
            let scope = KeyValueStoreRequest(
                keys: keys.map { CompendiumEntry.key(for: $0).rawValue }
            )

            let transferVisitorResult = try visitorManager.run(
                scope: scope,
                visitors: visitors,
                conflictResolution: visitorConflictResolution,
                removeOriginalEntityOnKeyChange: mode == .move,
                conflictWithOriginalEntity: true
            )
            keyChangesAccum.merge(transferVisitorResult.keyChanges, uniquingKeysWith: { $1 })
            successAccum.append(contentsOf: transferVisitorResult.success)
        }

        

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
