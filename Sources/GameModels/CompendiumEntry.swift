//
//  CompendiumEntry.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers

// An entry in the compendium. Contains the actual item with some metadata
// Suitable for persistence
public struct CompendiumEntry: Equatable {
    @EqCompare public var item: CompendiumItem
    public let itemType: CompendiumItemType

    public let source: Source?

    public init(_ item: CompendiumItem, source: Source? = nil) {
        _item = EqCompare(wrappedValue: item, compare: { $0.isEqual(to: $1) })
        self.itemType = item.key.type
        self.source = source
    }

    public struct Source: Codable, Equatable {
        public var readerName: String

        public var sourceName: String
        public var bookmark: Data?

        public var displayName: String?

        public init(readerName: String, sourceName: String, bookmark: Data? = nil, displayName: String? = nil) {
            self.readerName = readerName
            self.sourceName = sourceName
            self.bookmark = bookmark
            self.displayName = displayName
        }
    }
}

extension CompendiumEntry: Codable {
    enum CodingKeys: CodingKey {
        case item, itemType, source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let itemType = try container.decode(CompendiumItemType.self, forKey: .itemType)

        self.init(try itemType.decodeItem(from: container, key: .item), source: try container.decode(Source?.self, forKey: .source))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try item.encode(in: &container, key: .item)
        try container.encode(itemType, forKey: .itemType)
        try container.encode(source, forKey: .source)
    }
}

extension CompendiumEntry {
    public static let nullInstance = CompendiumEntry(Monster(realm: .core, stats: StatBlock.default, challengeRating: .init(integer: 1)))
}
