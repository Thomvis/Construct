//
//  Entity.swift
//  Construct
//
//  Created by Thomas Visser on 18/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB

// Conforming types can be easily stored in the KV store
protocol KeyValueStoreEntity: Codable {
    var key: String { get }
}

extension KeyValueStore {
    func put<V>(_ entity: V, fts: FTSDocument? = nil, in db: GRDB.Database? = nil) throws where V: KeyValueStoreEntity {
        try put(entity, at: entity.key, fts: fts, in: db)
    }
}
