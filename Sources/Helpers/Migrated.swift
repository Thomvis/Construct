//
//  Migrated.swift
//  Construct
//
//  Created by Thomas Visser on 15/04/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

public protocol MigrationTarget {
    associatedtype Source

    init(migrateFrom source: Source) throws
}

public protocol MigratedWrapper {
    associatedtype OldValue
    associatedtype Value: MigrationTarget where Value.Source == OldValue

    init(_ wrappedValue: Value)
}

@propertyWrapper
public struct Migrated<OldValue, Value>: MigratedWrapper, Codable where Value: Codable, OldValue: Codable, Value: MigrationTarget, Value.Source == OldValue {
    public var wrappedValue: Value

    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        do {
            // try to decode a value of the new type
            var container = try decoder.unkeyedContainer()
            self.wrappedValue = try container.decode(Value.self)
            return
        } catch let newError {
            // if that fails, we try to decode a value of the old type and migrate
            let old: OldValue
            do {
                old = try OldValue(from: decoder)
            } catch let oldError {
                // try to decode the new value without it being inside a unkeyed container
                // this is the case when the @Migrated wrapper was added later
                do {
                    self.wrappedValue = try Value(from: decoder)
                    return
                } catch { }

                throw Error.decodingFailed(newError, oldError)
            }

            do {
                self.wrappedValue = try Value(migrateFrom: old)
                return
            } catch {
                throw Error.migrationFailed(error)
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        // We need to store the new value wrapped in a container otherwise the decoder might
        // not be able to distinguish between values of Value and OldValue that look identical
        // when encoded (e.g. if they're both optional and nil)
        var container = encoder.unkeyedContainer()
        try container.encode(wrappedValue)
    }

    enum Error: Swift.Error {
        case decodingFailed(Swift.Error, Swift.Error)
        case migrationFailed(Swift.Error)
    }
}

// from https://forums.swift.org/t/using-property-wrappers-with-codable/29804/12
extension KeyedDecodingContainer {
    // This is used to override the default decoding behavior for OptionalCodingWrapper to allow a value to avoid a missing key Error
    func decode<T>(_ type: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> T where T: Decodable, T: MigratedWrapper, T.OldValue: OptionalProtocol {
        return try decodeIfPresent(T.self, forKey: key) ?? T(T.Value(migrateFrom: T.OldValue.emptyOptional()))
    }
}

extension Migrated: Equatable where Value: Equatable {

}

extension Migrated: Hashable where Value: Hashable {

}
