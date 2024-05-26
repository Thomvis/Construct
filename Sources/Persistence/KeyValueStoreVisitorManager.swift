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
        store: KeyValueStore
    ) throws {
        try run(visitors: [visitor], store: store)
    }

    public func run(
        visitors: [KeyValueStoreEntityVisitor],
        store: KeyValueStore
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
                            try store.put(entity, fts: fts, secondaryIndexValues: indexValues)

                            if originalKey != entity.rawKey {
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

}
