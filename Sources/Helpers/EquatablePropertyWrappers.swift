//
//  EquatablePropertyWrappers.swift
//  Construct
//
//  Created by Thomas Visser on 22/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

@propertyWrapper
public struct EqKey<Value, Key>: Equatable where Key: Equatable {
    let key: (Value) -> Key
    public var wrappedValue: Value

    public init(initialValue value: Value, _ key: @escaping (Value) -> Key) {
        self.key = key
        self.wrappedValue = value
    }

    public static func ==(lhs: EqKey<Value, Key>, rhs: EqKey<Value, Key>) -> Bool {
        lhs.key(lhs.wrappedValue) == rhs.key(rhs.wrappedValue)
    }
}

extension EqKey where Value: OptionalProtocol {
    public init(_ key: @escaping (Value) -> Key) {
        self.key = key
        self.wrappedValue = Value.emptyOptional()
    }
}

@propertyWrapper
public struct EqIgnore<Value>: Equatable {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public static func ==(lhs: EqIgnore<Value>, rhs: EqIgnore<Value>) -> Bool {
        true
    }
}

@propertyWrapper
public struct EqCompare<Value>: Equatable {
    public var wrappedValue: Value
    let compare: (Value, Value) -> Bool

    public init(wrappedValue: Value, compare: @escaping (Value, Value) -> Bool) {
        self.wrappedValue = wrappedValue
        self.compare = compare
    }

    public static func ==(lhs: EqCompare<Value>, rhs: EqCompare<Value>) -> Bool {
        lhs.compare(lhs.wrappedValue, rhs.wrappedValue)
    }
}
