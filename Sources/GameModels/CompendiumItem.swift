//
//  CompendiumItem.swift
//  Construct
//
//  Created by Thomas Visser on 05/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

public protocol CompendiumItem: Codable {
    var key: CompendiumItemKey { get }
    var realm: CompendiumItemKey.Realm { get }
    var title: String { get }

    func isEqual(to: CompendiumItem) -> Bool
}

extension CompendiumItem where Self: Equatable {
    public func isEqual(to other: CompendiumItem) -> Bool {
        if let other = other as? Self {
            return self == other
        }
        return false
    }
}

public extension CompendiumItemType {
    func decodeItem<K>(from container: KeyedDecodingContainer<K>, key: K) throws -> CompendiumItem where K: CodingKey {
        switch self {
        case .monster: return try container.decode(Monster.self, forKey: key)
        case .character: return try container.decode(Character.self, forKey: key)
        case .spell: return try container.decode(Spell.self, forKey: key)
        case .group: return try container.decode(CompendiumItemGroup.self, forKey: key)
        }
    }
}

extension CompendiumItem {
    public func encode<K>(in container: inout KeyedEncodingContainer<K>, key: K) throws where K: CodingKey {
        try container.encode(self, forKey: key)
    }
}
