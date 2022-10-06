//
//  ParseableKeyValueRecordManager.swift
//  Construct
//
//  Created by Thomas Visser on 14/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB
import Helpers

public class ParseableKeyValueRecordManager {
    let queue: DatabaseQueue

    init(_ queue: DatabaseQueue) {
        self.queue = queue
    }

    public func run() throws {
        let decoder = KeyValueStore.decoder
        let encoder = KeyValueStore.encoder

        try queue.write { db in
            let cursor = try KeyValueStore.Record.fetchCursor(db)
            while var record = try cursor.next() {
                do {
                    if var entity = try record.decodeEntity(decoder) as? (ParseableVisitable & KeyValueStoreEntity) {
                        entity.visitParseable()
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
