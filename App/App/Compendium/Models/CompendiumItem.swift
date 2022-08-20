//
//  CompendiumItem.swift
//  Construct
//
//  Created by Thomas Visser on 05/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels

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

extension CompendiumItemType {
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
    func encode<K>(in container: inout KeyedEncodingContainer<K>, key: K) throws where K: CodingKey {
        try container.encode(self, forKey: key)
    }
}

// Convert CompendiumItemKey from and to a string that can be used in KeyValueStore
extension CompendiumItemKey: RawRepresentable {
    private static let prefix = KeyValueStoreEntityKeyPrefix.compendiumEntry.rawValue
    static let separator = "::"

    // compendium::monster::core::Aboleth
    public init?(rawValue: String) {
        let components = rawValue.components(separatedBy: Self.separator)
        guard components.count == 4, components[0] == Self.prefix, let type = CompendiumItemType(rawValue: components[1]) else { return nil }

        self.init(type: type, realm: Realm(components[2]), identifier: components[3])
    }

    public var rawValue: String {
        return Self.rawValue(from: [Self.prefix, type.rawValue, realm.description, identifier])
    }

    static func prefix(for type: CompendiumItemType? = nil) -> String {
        return rawValue(from: [Self.prefix, type?.rawValue].compactMap { $0 })
    }

    private static func rawValue(from components: [String]) -> String {
        components.joined(separator: Self.separator)
    }
}
