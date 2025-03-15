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

                // if display name changed: update reference to doc from content items
                let visitor = PostDocumentMoveGameModelsVisitor(
                    updatedDocument: doc,
                    originalRealmId: originalRealmId,
                    originalDocumentId: originalDocumentId,
                    moving: moving
                )

                let visitorManager = KeyValueStoreVisitorManager(databaseQueue: database.queue)
                try visitorManager.run(
                    visitor: AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: visitor),
                    conflictResolution: .rename(fallback: .remove)
                )

                if originalKey != doc.key {
                    // it's a move

                    if CompendiumSourceDocument.isDefaultDocument(id: originalDocumentId) {
                        throw CompendiumMetadataError.cannotMoveDefaultResource
                    }

                    // if the doc id changed: update reference to doc from content items
                    // if the realm id changed: update realm of content items (i.e. move all items)

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
        
        return KeyValueStoreRequest(
            keyPrefixes: keyPrefixes,
            fullTextSearch: search,
            filters: filters?.secondaryIndexFilters ?? [],
            order: order.map(SecondaryIndexOrder.init).nonNilArray,
            range: range
        )
    }
}

struct CompendiumSourceDocumentKey: Hashable {
    let realmId: CompendiumRealm.Id
    let documentId: CompendiumSourceDocument.Id
}

func transfer(
    _ selection: CompendiumItemSelection,
    mode: TransferMode,
    target: CompendiumSourceDocumentKey,
    conflictResolution: ConflictResolution,
    db: DatabaseAccess
) async throws {
    let keyValueStore = DatabaseKeyValueStore(db)

    guard let targetDocument = try keyValueStore.get(CompendiumSourceDocument.key(forRealmId: target.realmId, documentId: target.documentId)) else {

        throw CompendiumMetadataError.resourceNotFound
    }

    try db.inSavepoint { db in
        let visitorManager = KeyValueStoreVisitorManager(databaseAccess: DirectDatabaseAccess(db: db))

        // Step 1: transfer items
        let visitorScope = switch selection {
        case .single(let compendiumItemKey):
            KeyValueStoreRequest(keyPrefix: CompendiumEntry.key(for: compendiumItemKey).rawValue)
        case .multiple(let compendiumFetchRequest):
            compendiumFetchRequest.toKeyValueStoreRequest()
        }

        let visitorConflictResolution: KeyValueStoreVisitorManager.ConflictResolution = switch conflictResolution {
            case .skip: .skip
            case .overwrite: .overwrite
            case .keepBoth: .rename(fallback: .skip)
        }

        let visitor = UpdateEntryDocumentGameModelsVisitor(targetDocument: targetDocument)
        let transferVisitorResult = try visitorManager.run(
            scope: visitorScope,
            visitor: AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: visitor),
            conflictResolution: visitorConflictResolution,
            removeOriginalEntityOnKeyChange: mode == .move
        )


        // Step 2: update references to transferred items (if moved)
        if mode == .move {
            let movedItemKeys = transferVisitorResult.success

            // update references to transferred items
            let referenceVisitor = UpdateItemReferenceGameModels { key -> CompendiumItemKey? in
                guard movedItemKeys.contains(CompendiumEntry.key(for: key).rawValue) else { return nil }
                return CompendiumItemKey(
                    type: key.type,
                    realm: .init(targetDocument.realmId),
                    identifier: key.identifier
                )
            }
            try visitorManager.run(
                visitor: AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: referenceVisitor),
                conflictResolution: .skip
            )
        }

        return .commit
    }

}

public class UpdateEntryDocumentGameModelsVisitor: AbstractGameModelsVisitor {

    let targetDocument: CompendiumSourceDocument

    public init(targetDocument: CompendiumSourceDocument) {
        self.targetDocument = targetDocument
    }

    @VisitorBuilder
    override public func visit(entry: inout CompendiumEntry) -> Bool {
        super.visit(entry: &entry)

        visitValue(&entry, keyPath: \.document.displayName, value: targetDocument.displayName)
        visitValue(&entry, keyPath: \.document.id, value: targetDocument.id)
        visitValue(&entry, keyPath: \.item.realm, value: .init(targetDocument.realmId))
    }

}

public class UpdateItemReferenceGameModels: AbstractGameModelsVisitor {

    let updatedKey: (CompendiumItemKey) -> CompendiumItemKey?

    public init(updatedKey: @escaping (CompendiumItemKey) -> CompendiumItemKey?) {
        self.updatedKey = updatedKey
    }

    @VisitorBuilder
    public override func visit(compendiumCombatantDefinition def: inout CompendiumCombatantDefinition) -> Bool {
        super.visit(compendiumCombatantDefinition: &def)

        if let key = updatedKey(def.item.key) {
            switch def.item {
            case var monster as Monster:
                visitValue(&monster, keyPath: \.key, value: key)
                def.item = monster
            case var character as Character:
                visitValue(&character, keyPath: \.key, value: key)
                def.item = character
            default:
                assertionFailure("Unexpected CompendiumCombatant in visitor")
            }
        }
    }

    @VisitorBuilder
    public override func visit(itemReference: inout CompendiumItemReference) -> Bool {
        super.visit(itemReference: &itemReference)

        if let key = updatedKey(itemReference.itemKey) {
            visitValue(&itemReference, keyPath: \.itemKey, value: key)
        }
    }

}
