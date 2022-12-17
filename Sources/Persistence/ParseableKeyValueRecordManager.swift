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

    public func run() async throws {
        let decoder = KeyValueStore.decoder
        let encoder = KeyValueStore.encoder

        let store = KeyValueStore(queue)

        let keys = try store.allKeys()
        for key in keys {
            let record = try await queue.read { db in
                try KeyValueStore.Record.fetchOne(db, key: key)
            }

            do {
                if var record, var entity = try record.decodeEntity(decoder) as? (any ParseableVisitable & KeyValueStoreEntity) {
                    let effect = entity.visitParseable()

                    let actions = await Array(effect.values).filter { $0 == .didParse }
                    // only save if we actually updated any parseable value
                    if !actions.isEmpty, let value = try entity.encodeEntity(encoder) {
                        record.value = value
                        try await queue.write { [record] db in
                            try record.save(db)
                        }
                    }
                } else {
                    print("Visiting of record \(key) skipped")
                }
            } catch {
                print("Visiting of record \(key) failed with error \(error)")
            }

            await Task.yield()
        }

        if try keys != store.allKeys() {
            // The keys changed in the meantime, so we run the parseables again, just to be sure
            try await run()
        }
    }
}
