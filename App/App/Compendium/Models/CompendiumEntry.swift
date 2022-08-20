//
//  CompendiumEntry.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels
import Helpers

// An entry in the compendium. Contains the actual item with some metadata
// Suitable for persistence
struct CompendiumEntry: Equatable {
    @EqCompare var item: CompendiumItem
    let itemType: CompendiumItemType

    let source: Source?

    init(_ item: CompendiumItem, source: Source? = nil) {
        _item = EqCompare(wrappedValue: item, compare: { $0.isEqual(to: $1) })
        self.itemType = item.key.type
        self.source = source
    }

    struct Source: Codable, Equatable {
        var readerName: String

        var sourceName: String
        var bookmark: Data?

        var displayName: String?
    }
}

extension CompendiumEntry: Codable {
    enum CodingKeys: CodingKey {
        case item, itemType, source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let itemType = try container.decode(CompendiumItemType.self, forKey: .itemType)

        self.init(try itemType.decodeItem(from: container, key: .item), source: try container.decode(Source?.self, forKey: .source))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try item.encode(in: &container, key: .item)
        try container.encode(itemType, forKey: .itemType)
        try container.encode(source, forKey: .source)
    }
}

extension CompendiumEntry: KeyValueStoreEntity {
    static let keyPrefix: KeyPrefix = .compendiumEntry

    var key: String {
        return item.key.rawValue
    }
}

extension KeyValueStore {
    func get(_ itemKey: CompendiumItemKey) throws -> CompendiumEntry? {
        return try get(itemKey.rawValue)
    }

    @discardableResult
    func remove(_ itemKey: CompendiumItemKey) throws -> Bool {
        try remove(itemKey.rawValue)
    }
}

extension CompendiumEntry {
    static let nullInstance = CompendiumEntry(Monster(realm: .core, stats: StatBlock.default, challengeRating: .init(integer: 1)))
}
