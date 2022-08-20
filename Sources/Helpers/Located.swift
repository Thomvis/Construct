//
//  Located.swift
//  Construct
//
//  Created by Thomas Visser on 09/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

public struct Located<V> {
    public var value: V
    public var range: Range<Int>

    public init(value: V, range: Range<Int>) {
        self.value = value
        self.range = range
    }
}

extension Located: Codable where V: Codable { }

extension Located: Equatable where V: Equatable { }
extension Located: Hashable where V: Hashable { }

public extension Located {
    func map<T>(_ f: (V) -> T) -> Located<T> {
        Located<T>(value: f(value), range: range)
    }

    func flatMap<T>(_ f: (V) -> T?) -> Located<T>? {
        f(value).map { Located<T>(value: $0, range: range) }
    }
}
