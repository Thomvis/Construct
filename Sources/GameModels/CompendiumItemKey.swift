//
//  CompendiumItemKey.swift
//  
//
//  Created by Thomas Visser on 19/08/2022.
//

import Foundation

public struct CompendiumItemKey: Codable, Hashable {
    /// Primarily used by CompendiumEntry, but here for legacy reasons
    public static let keySeparator = "::"

    public let type: CompendiumItemType
    public let realm: Realm // note: this could have been a CompendiumRealm.Id directly, but would require a complex migration
    public let identifier: String // unique per type

    public init(type: CompendiumItemType, realm: Realm, identifier: String) {
        self.type = type
        self.realm = realm
        self.identifier = identifier
    }

    /// This is here for legacy reasons. The item key and entry key used to be intertwined.
    /// Strictly speaking "compendium entries" are a layer above item keys and therefore we
    /// should not know about compendium entries. But CompendiumItemKey were persisted with
    /// the entry
    public init?(compendiumEntryKey string: String) {
        let components = string.components(separatedBy: Self.keySeparator)
        // we don't care about the first component, it's `CompendiumEntry.keyPrefix`
        guard components.count == 4, let type = CompendiumItemType(rawValue: components[1]) else { return nil }

        self.init(type: type, realm: Realm(.init(rawValue: components[2])), identifier: components[3])
    }

    /// monster::core::Aboleth
    public var keyString: String {
        [type.rawValue, realm.description, identifier].joined(separator: Self.keySeparator)
    }

    public struct Realm: CustomStringConvertible, Codable, Hashable {
        public let value: CompendiumRealm.Id

        public init(_ id: CompendiumRealm.Id) {
            self.value = id
        }

        public var description: String { value.rawValue }
    }
}
