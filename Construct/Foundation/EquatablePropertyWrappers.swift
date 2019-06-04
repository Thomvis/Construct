//
//  EquatablePropertyWrappers.swift
//  Construct
//
//  Created by Thomas Visser on 22/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

@propertyWrapper
struct EqKey<Value, Key>: Equatable where Key: Equatable {
    let key: (Value) -> Key
    var wrappedValue: Value

    init(initialValue value: Value, _ key: @escaping (Value) -> Key) {
        self.key = key
        self.wrappedValue = value
    }

    static func ==(lhs: EqKey<Value, Key>, rhs: EqKey<Value, Key>) -> Bool {
        lhs.key(lhs.wrappedValue) == rhs.key(rhs.wrappedValue)
    }
}

extension EqKey where Value: OptionalProtocol {
    init(_ key: @escaping (Value) -> Key) {
        self.key = key
        self.wrappedValue = Value.emptyOptional()
    }
}

@propertyWrapper
struct EqIgnore<Value>: Equatable {
    var wrappedValue: Value

    static func ==(lhs: EqIgnore<Value>, rhs: EqIgnore<Value>) -> Bool {
        true
    }
}

@propertyWrapper
struct EqCompare<Value>: Equatable {
    var wrappedValue: Value
    let compare: (Value, Value) -> Bool

    static func ==(lhs: EqCompare<Value>, rhs: EqCompare<Value>) -> Bool {
        lhs.compare(lhs.wrappedValue, rhs.wrappedValue)
    }
}
