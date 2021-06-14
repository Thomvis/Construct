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

class Compendium {
    let database: Database

    init(_ database: Database) {
        self.database = database
    }

    func get(_ key: CompendiumItemKey) throws -> CompendiumEntry? {
        try database.keyValueStore.get(key)
    }

    func put(_ entry: CompendiumEntry, in db: GRDB.Database? = nil) throws {
        try database.keyValueStore.put(entry, fts: FTSDocument(title: entry.item.title, subtitle: nil, body: nil), in: db)
    }

    func fetchAll(query: String?, types: [CompendiumItemType]? = []) -> AnyPublisher<[CompendiumEntry], Error> {
        return Deferred { () -> AnyPublisher<[CompendiumEntry], Error> in
            do {
                let entries: [CompendiumEntry]
                let typeKeyPrefixes = types.map { $0.map { CompendiumItemKey.prefix(for: $0) } } ?? [CompendiumItemKey.prefix(for: nil)]
                if let query = query {
                    entries = try self.database.keyValueStore.match("\(query)*", keyPrefixes: typeKeyPrefixes)
                } else {
                    entries = try self.database.keyValueStore.fetchAll(typeKeyPrefixes)
                }
                return Just(entries).setFailureType(to: Error.self).eraseToAnyPublisher()
            } catch {
                return Fail(error: error).eraseToAnyPublisher()
            }
        }.eraseToAnyPublisher()
    }

}
