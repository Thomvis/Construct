//
//  CompendiumItemKey.swift
//  
//
//  Created by Thomas Visser on 19/08/2022.
//

import Foundation

public struct CompendiumItemKey: Codable, Hashable {
    public let type: CompendiumItemType
    public let realm: Realm
    public let identifier: String // unique per type

    public init(type: CompendiumItemType, realm: Realm, identifier: String) {
        self.type = type
        self.realm = realm
        self.identifier = identifier
    }

    public struct Realm: ExpressibleByStringLiteral, CustomStringConvertible, Codable, Hashable {
        let value: String

        public init(_ value: String) {
            self.value = value
        }

        public init(stringLiteral value: String) {
            self.value = value
        }

        public var description: String { value }

        public static let core = Realm("core")
        public static let homebrew = Realm("homebrew")
    }
}
