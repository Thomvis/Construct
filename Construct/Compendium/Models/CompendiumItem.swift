//
//  CompendiumItem.swift
//  Construct
//
//  Created by Thomas Visser on 05/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

protocol CompendiumItem: Codable {
    var key: CompendiumItemKey { get }
    var realm: CompendiumItemKey.Realm { get }
    var title: String { get }

    func isEqual(to: CompendiumItem) -> Bool
}

extension CompendiumItem where Self: Equatable {
    func isEqual(to other: CompendiumItem) -> Bool {
        if let other = other as? Self {
            return self == other
        }
        return false
    }
}

struct CompendiumItemKey: Codable, Hashable {
    let type: CompendiumItemType
    let realm: Realm
    let identifier: String // unique per type

    struct Realm: ExpressibleByStringLiteral, CustomStringConvertible, Codable, Hashable {
        let value: String

        init(_ value: String) {
            self.value = value
        }

        init(stringLiteral value: String) {
            self.value = value
        }

        var description: String { value }

        static let core = Realm("core")
        static let homebrew = Realm("homebrew")
    }
}

enum CompendiumItemType: String, CaseIterable, Codable {
    case monster
    case character
    case spell
    case group

    func decodeItem<K>(from container: KeyedDecodingContainer<K>, key: K) throws -> CompendiumItem where K: CodingKey {
        switch self {
        case .monster: return try container.decode(Monster.self, forKey: key)
        case .character: return try container.decode(Character.self, forKey: key)
        case .spell: return try container.decode(Spell.self, forKey: key)
        case .group: return try container.decode(CompendiumItemGroup.self, forKey: key)
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .monster: return NSLocalizedString("monster", comment: "Compendium item type monster")
        case .character: return NSLocalizedString("character", comment: "Compendium item type character")
        case .spell: return NSLocalizedString("spell", comment: "Compendium item type spell")
        case .group: return NSLocalizedString("group", comment: "Compendium item type group")
        }
    }

    var localizedScreenDisplayName: String {
        switch self {
        case .monster: return NSLocalizedString("Monsters", comment: "Compendium item type monster")
        case .character: return NSLocalizedString("Characters", comment: "Compendium item type character")
        case .spell: return NSLocalizedString("Spells", comment: "Compendium item type spell")
        case .group: return NSLocalizedString("Adventuring Parties", comment: "Compendium item type group")
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
    init?(rawValue: String) {
        let components = rawValue.components(separatedBy: Self.separator)
        guard components.count == 4, components[0] == Self.prefix, let type = CompendiumItemType(rawValue: components[1]) else { return nil }

        self.type = type
        self.realm = Realm(components[2])
        self.identifier = components[3]
    }

    var rawValue: String {
        return Self.rawValue(from: [Self.prefix, type.rawValue, realm.description, identifier])
    }

    static func prefix(for type: CompendiumItemType? = nil) -> String {
        return rawValue(from: [Self.prefix, type?.rawValue].compactMap { $0 })
    }

    private static func rawValue(from components: [String]) -> String {
        components.joined(separator: Self.separator)
    }
}
