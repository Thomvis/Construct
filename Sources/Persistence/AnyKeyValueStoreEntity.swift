//
//  AnyKeyValueStoreEntity.swift
//  
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation

public struct AnyKeyValueStoreEntity: KeyValueStoreEntity {
    public static let keyPrefix: KeyPrefix = .any

    let e: KeyValueStoreEntity
    let _encode: (Encoder) throws -> Void

    public init<E: KeyValueStoreEntity>(_ e: E) {
        self.e = e
        self._encode = { try e.encode(to: $0) }
    }

    public init(from decoder: Decoder) throws {
        fatalError("Not supported")
    }

    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }

    public var key: String { e.key }

}

extension AnyKeyValueStoreEntity {
    public init?<E: KeyValueStoreEntity>(_ e: E?) {
        guard let e = e else { return nil }
        self.init(e)
    }
}
