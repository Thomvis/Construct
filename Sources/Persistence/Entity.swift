//
//  Entity.swift
//  Construct
//
//  Created by Thomas Visser on 18/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB
import GameModels
import Compendium
import Tagged
import Helpers

// Conforming types can be easily stored in the KV store
public protocol KeyValueStoreEntity: Codable {
    typealias Key = KeyValueStoreEntityKey<Self>

    static var keyPrefix: String { get }
    var key: Key { get }
}

public extension KeyValueStoreEntity {
    /// Needed because `key` cannot be invoked on `any KeyValueStoreEntity`
    var rawKey: String {
        key.rawValue
    }
}

public struct KeyValueStoreEntityKey<E>: Hashable where E: KeyValueStoreEntity {
    public let rawValue: String

    public init?(rawKey: String) {
        guard rawKey.hasPrefix(E.keyPrefix) else {
            return nil
        }
        self.rawValue = rawKey
    }

    /// Creates a Key by joining the prefix with the id
    public init(id: String, separator: String = "") {
        self.rawValue = E.keyPrefix + separator + id
    }

    public static func +(lhs: Self, rhs: String) -> Self {
        Self(rawKey: lhs.rawValue + rhs)!
    }
}

/// Convenience methods for working with KeyValueStore
public extension KeyValueStore {
    func get<E>(_ key: E.Key) throws -> E? where E: KeyValueStoreEntity {
        try get(key.rawValue)
    }

    func get<E>(_ key: E.Key, crashReporter: CrashReporter) throws -> E? where E: KeyValueStoreEntity {
        try get(key.rawValue, crashReporter: crashReporter)
    }

    func getAny(_ key: String) throws -> (any KeyValueStoreEntity)? {
        guard let type = keyValueStoreEntities.first(where: { key.hasPrefix($0.keyPrefix) }) else { return nil }
        return try get(type.self, key: key)
    }

    func observe<E>(_ key: E.Key) -> AsyncThrowingStream<E?, any Error> where E: KeyValueStoreEntity & Equatable {
        observe(key.rawValue)
    }

    func put<E>(_ value: E, fts: FTSDocument? = nil, secondaryIndexValues: [Int: String]? = nil) throws where E: KeyValueStoreEntity {
        try put(value, at: value.key.rawValue, fts: fts, secondaryIndexValues: secondaryIndexValues)
    }

    func contains<E>(_ key: E.Key) throws -> Bool where E: KeyValueStoreEntity {
        try contains(key.rawValue)
    }

    @discardableResult
    func remove<E>(_ key: E.Key) throws -> Bool where E: KeyValueStoreEntity {
        try remove(key.rawValue)
    }
}

//public extension String {
//    /// Checks if the string begins with the entity's key prefix
//    func toCheckedKey<E>() -> E.Key? where E: KeyValueStoreEntity {
//        return E.Key(rawKey: self)
//    }
//}
//
//extension DatabaseKeyValueStore.Record {
//    func decodeEntity(_ decoder: JSONDecoder) throws -> (any KeyValueStoreEntity)? {
//        guard let type = keyValueStoreEntities.first(where: { key.hasPrefix($0.keyPrefix) }) else { return nil }
//        return try decoder.decode(type, from: value)
//    }
//}
//
//public extension KeyValueStoreEntity {
//    func encodeEntity(_ encoder: JSONEncoder) throws -> Data? {
//        return try encoder.encode(self)
//    }
//}
