//
//  CompendiumItemReference.swift
//  
//
//  Created by Thomas Visser on 19/08/2022.
//

import Foundation
import Helpers

public struct CompendiumItemReference: Codable, Hashable {
    public var itemTitle: String
    @Migrated public var itemKey: CompendiumItemKey

    public init(itemTitle: String, itemKey: CompendiumItemKey) {
        self.itemTitle = itemTitle
        self._itemKey = Migrated(itemKey)
    }

    public init(_ item: CompendiumItem) {
        self.init(itemTitle: item.title, itemKey: item.key)
    }
}

extension CompendiumItemKey: MigrationTarget {
    public init(migrateFrom source: String) throws {
        guard let key = CompendiumItemKey(compendiumEntryKey: source) else {
            throw MigrationFailedError()
        }

        self = key
    }

    struct MigrationFailedError: Swift.Error { }
}
