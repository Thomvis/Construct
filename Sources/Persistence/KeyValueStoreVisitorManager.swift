//
//  KeyValueStoreVisitorManager.swift
//
//
//  Created by Thomas Visser on 12/12/2023.
//

import Foundation
import GRDB

public class KeyValueStoreVisitorManager {

    let databaseAccess: DatabaseAccess

    public convenience init(databaseQueue: DatabaseQueue) {
        self.init(databaseAccess: DatabaseQueueAccess(queue: databaseQueue))
    }

    public init(databaseAccess: DatabaseAccess) {
        self.databaseAccess = databaseAccess
    }

    @discardableResult
    public func run(
        scope: KeyValueStoreRequest = .all,
        visitor: KeyValueStoreEntityVisitor,
        conflictResolution: ConflictResolution,
        removeOriginalEntityOnKeyChange: Bool = true
    ) throws -> Result {
        return try run(
            scope: scope,
            visitors: [visitor],
            conflictResolution: conflictResolution,
            removeOriginalEntityOnKeyChange: removeOriginalEntityOnKeyChange
        )
    }

    @discardableResult
    public func run(
        scope: KeyValueStoreRequest = .all,
        visitors: [KeyValueStoreEntityVisitor],
        conflictResolution: ConflictResolution,
        removeOriginalEntityOnKeyChange: Bool = true
    ) throws -> Result {
        var result = Result()
        try databaseAccess.inSavepoint { db in
            let store = DatabaseKeyValueStore(DirectDatabaseAccess(db: db))

            let keys = try store.fetchKeys(scope)
            for key in keys {
                do {
                    if var entity = try store.getAny(key) {
                        let originalKey = entity.rawKey

                        var entityDidChange = false
                        for visitor in visitors {
                            entityDidChange = visitor.visit(entity: &entity) || entityDidChange
                        }

                        // only save if we actually updated any parseable value
                        if entityDidChange {
                            try db.inSavepoint {
                                let fts = (entity as? FTSDocumentConvertible)?.ftsDocument
                                let indexValues = (entity as? SecondaryIndexValueRepresentable)?.secondaryIndexValues

                                let keyChanged = originalKey != entity.rawKey
                                var newKeyHasConflict = keys.contains(entity.rawKey)
                                var effectiveConflictResoluton = conflictResolution

                                if keyChanged && newKeyHasConflict, case .rename(let fallback) = conflictResolution {
                                    if var entityForConflictResolution = entity as? any KeyValueStoreEntity & KeyConflictResolution {
                                        var triesLeft = 3
                                        while newKeyHasConflict && triesLeft > 0 {
                                            entityForConflictResolution.updateKeyForConflictResolution()

                                            triesLeft -= 1
                                            newKeyHasConflict = keys.contains(entityForConflictResolution.rawKey)
                                        }

                                        entity = entityForConflictResolution
                                        if newKeyHasConflict {
                                            // conflict was not resolved
                                            effectiveConflictResoluton = fallback
                                        }
                                    } else {
                                        effectiveConflictResoluton = fallback
                                    }
                                }

                                if keyChanged {
                                    if newKeyHasConflict {
                                        switch effectiveConflictResoluton {
                                        case .remove:
                                            try store.remove(originalKey)
                                        case .overwrite:
                                            try store.put(entity, fts: fts, secondaryIndexValues: indexValues)
                                            if removeOriginalEntityOnKeyChange {
                                                try store.remove(originalKey)
                                            }
                                            result.success.append(key)
                                        case .skip:
                                            // no-op
                                            break
                                        case .rename:
                                            assertionFailure("The fallback conflict resolution should not be rename.")
                                            break
                                        }
                                    } else {
                                        try store.put(entity, fts: fts, secondaryIndexValues: indexValues)
                                        if removeOriginalEntityOnKeyChange {
                                            try store.remove(originalKey)
                                        }
                                        result.success.append(key)
                                    }
                                } else {
                                    try store.put(entity, fts: fts, secondaryIndexValues: indexValues)
                                    result.success.append(key)
                                }

                                return .commit
                            }
                        }
                    } else {
                        print("Visiting of record \(key) skipped")
                    }
                } catch {
                    print("Visiting of record \(key) failed with error \(error)")
                }
            }

            return .commit
        }
        return result
    }

    public enum ConflictResolution: Equatable {
        /// The visited entity is removed (instead of updated)
        case remove
        /// The conflicting entity is overwritten
        case overwrite
        /// The visited entity is skipped (instead of updated)
        case skip

        /// When an entity's key changes and is in conflict with an existing entity,
        /// the entity that had its key changed gets a chance to change its key again.
        /// This requires the entity to implement the KeyConflictResolution protocol.
        /// Entities that do not implement that protocol use the fallback resolution
        indirect case rename(fallback: ConflictResolution)
    }

    public struct Result {
        // All entities that were changed by the visitor(s) and subseqently saved to the database (not skipped or removed)
        var success: [String] = []
    }

}

protocol KeyConflictResolution {
    mutating func updateKeyForConflictResolution()
}
