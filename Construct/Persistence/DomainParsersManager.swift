//
//  DomainParsersManager.swift
//  Construct
//
//  Created by Thomas Visser on 14/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

class DomainParsersManager {
    let db: Database

    init(db: Database) {
        self.db = db
    }

    func run() throws {
        let decoder = db.keyValueStore.decoder
        let encoder = db.keyValueStore.encoder

        try db.queue.write { db in
            let metadata = try DomainParsersMetadata.get(db, decoder, key: DomainParsersMetadata.key)

            let cursor = try KeyValueStore.Record.fetchCursor(db)
            while var record = try cursor.next() {
                do {
                    if var entity = try record.decodeEntity(decoder) as? (HasParseableVisitor & KeyValueStoreEntity) {
                        entity.visit()
                        if let value = try entity.encodeEntity(encoder) {
                            record.value = value
                            try record.save(db)
                        }
                    }
                } catch {
                    print("Visiting of record \(record.key) failed with error \(error)")
                }
            }
        }
    }

}

struct DomainParsersMetadata: KeyValueStoreEntity {
    static let keyPrefix: KeyPrefix = .domainParsersMetadata
    static let key = keyPrefix.rawValue

    let lastRunVersions: [String:String]

    var key: String {
        Self.key
    }
}
