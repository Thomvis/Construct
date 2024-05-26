//
//  KeyValueStoreRequest.swift
//
//
//  Created by Thomas Visser on 11/02/2024.
//

import Foundation

public struct KeyValueStoreRequest {
    public var keyPrefixes: [String]? = nil
    public var fullTextSearch: String? = nil
    public var filters: [SecondaryIndexFilter]? = nil
    public var order: [SecondaryIndexOrder]? = nil
    public var range: Range<Int>? = nil

    public init(keyPrefixes: [String]? = nil, fullTextSearch: String? = nil, filters: [SecondaryIndexFilter]? = nil, order: [SecondaryIndexOrder]? = nil, range: Range<Int>? = nil) {
        self.keyPrefixes = keyPrefixes
        self.fullTextSearch = fullTextSearch
        self.filters = filters
        self.order = order
        self.range = range
    }

    public init(keyPrefix: String, fullTextSearch: String? = nil, filters: [SecondaryIndexFilter]? = nil, order: [SecondaryIndexOrder]? = nil, range: Range<Int>? = nil) {
        self.init(
            keyPrefixes: [keyPrefix],
            fullTextSearch: fullTextSearch,
            filters: filters,
            order: order,
            range: range
        )
    }
}

extension KeyValueStoreRequest {
    public static let all = KeyValueStoreRequest()
    public static func keyPrefix(_ prefix: String) -> Self {
        return KeyValueStoreRequest(keyPrefixes: [prefix])
    }
}
