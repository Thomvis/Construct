//
//  Visitors.swift
//
//
//  Created by Thomas Visser on 13/12/2023.
//

import Foundation
import IdentifiedCollections

public func visitEach<Global, Element>(
    model: inout Global,
    toCollection: WritableKeyPath<Global, Array<Element>>,
    visit: (inout Element) -> Bool
) -> Bool {
    var result = false
    for idx in model[keyPath: toCollection].indices {
        result = visit(&model[keyPath: toCollection][idx]) || result
    }
    return result
}

public func optionalVisit<T>(_ val: inout T?, visit: (inout T) -> Bool) -> Bool {
    if var unwrapped = val {
        defer { val = unwrapped }
        return visit(&unwrapped)
    }
    return false
}

public func visitEach<Global, ID, Element>(
    model: inout Global,
    toCollection: WritableKeyPath<Global, IdentifiedArray<ID, Element>>,
    visit: (inout Element) -> Bool
) -> Bool {
    var result = false
    for idx in model[keyPath: toCollection].indices {
        result = visit(&model[keyPath: toCollection][idx]) || result
    }
    return result
}

/// Sets the property in obj denoted by keyPath to value, if it was not already
/// equal to value. Returns true if it did set the value.
public func visitValue<T, V>(
    _ obj: inout T,
    keyPath: WritableKeyPath<T, V>,
    value: V
) -> Bool where V: Equatable {
    if obj[keyPath: keyPath] != value {
        obj[keyPath: keyPath] = value
        return true
    }
    return false
}

@resultBuilder
public struct VisitorBuilder {
    public static func buildOptional(_ component: Bool?) -> Bool {
        component ?? false
    }

    public static func buildBlock(_ components: Bool...) -> Bool {
        return components.contains { $0 }
    }

    public static func buildPartialBlock(first: Bool) -> Bool {
        return first
    }

    public static func buildPartialBlock(first: Bool?) -> Bool {
        first ?? false
    }

    public static func buildPartialBlock(first: ()) -> Bool {
        false
    }

    public static func buildPartialBlock(accumulated: Bool, next: Bool) -> Bool {
        return accumulated || next
    }

    public static func buildPartialBlock(accumulated: Bool, next: ()) -> Bool {
        return accumulated
    }

    public static func buildArray(_ components: [Bool]) -> Bool {
        return components.contains { $0 }
    }

    public static func buildEither(first component: Bool) -> Bool {
        component
    }

    public static func buildEither(second component: Bool) -> Bool {
        component
    }
}
