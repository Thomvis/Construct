//
//  KeyValueStoreVisitorManager.swift
//
//
//  Created by Thomas Visser on 12/12/2023.
//

import Foundation
import GRDB

public class KeyValueStoreVisitorManager {

    public init() {

    }

    public func run(
        visitor: KeyValueStoreEntityVisitor,
        store: KeyValueStore,
        conflictResolution: ConflictResolution
    ) throws {
        try run(visitors: [visitor], store: store, conflictResolution: conflictResolution)
    }

    public func run(
        visitors: [KeyValueStoreEntityVisitor],
        store: KeyValueStore,
        conflictResolution: ConflictResolution
    ) throws {

        let keys = try store.fetchKeys(.all)
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
                        try store.transaction { store in
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
                                } else {
                                    effectiveConflictResoluton = fallback
                                }
                            }

                            if !keyChanged || !newKeyHasConflict || effectiveConflictResoluton == .overwrite {
                                try store.put(entity, fts: fts, secondaryIndexValues: indexValues)
                            }

                            if keyChanged {
                                // delete the original record if the key changed
                                try store.remove(originalKey)
                            }
                        }
                    }
                } else {
                    print("Visiting of record \(key) skipped")
                }
            } catch {
                print("Visiting of record \(key) failed with error \(error)")
            }
        }
    }

    public enum ConflictResolution: Equatable {
        /// When an entity's key changes and is in conflict with an existing entity,
        /// the entity that had its key changed is removed (instead of updated)
        case remove
        /// When an entity's key changes and is in conflict with an existing entity,
        /// the existing entity is overwritten
        case overwrite

        /// When an entity's key changes and is in conflict with an existing entity,
        /// the entity that had its key changed gets a chance to change its key again.
        /// This requires the entity to implement the KeyConflictResolution protocol.
        /// Entities that do not implement that protocol use the fallback resolution
        indirect case rename(fallback: ConflictResolution)
    }

}

protocol KeyConflictResolution {
    mutating func updateKeyForConflictResolution()
}
