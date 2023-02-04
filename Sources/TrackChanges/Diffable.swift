//
//  Diffable.swift
//  
//
//  Created by Thomas Visser on 01/02/2023.
//

import Foundation
import Helpers

public protocol Diffable {
    static var diffableKeys: [String] { get }

    func value(forDiffableKey: String) throws -> Any
}

public struct Change: Equatable {
    let path: [String]
    let action: Action

    public init(path: [String], action: Action) {
        self.path = path
        self.action = action
    }

    public enum Action: Equatable {
        case set(from: any DiffableValue)
        case insert(offset: Int)
        case remove(offset: Int, value: any DiffableValue)
    }

    func pullback(pathPrefix: String) -> Self {
        Change(path: [pathPrefix] + path, action: action)
    }
}

public struct DiffableError: Swift.Error {
    public init() { }
}

public extension Diffable {
    func difference(from other: Self) throws -> [Change] {
        var result: [Change] = []
        for key in Self.diffableKeys {
            let lhs = try value(forDiffableKey: key)
            let rhs = try other.value(forDiffableKey: key)

            let differences = try diffAny(lhs: lhs, rhs: rhs)
            result.append(contentsOf: differences.map { $0.pullback(pathPrefix: key) })
        }
        return result
    }
}

public typealias DiffableValue = Equatable & Codable

private func diffAny<A>(lhs: A, rhs: Any) throws -> [Change] {
    if let lhsDiffable = lhs as? Diffable, let rhsDiffable = rhs as? Diffable {
        return try diff(lhs: lhsDiffable, rhs: rhsDiffable)
    } else if !(lhs is String), let lhsCollection = lhs as? any BidirectionalCollection, let rhsCollection = rhs as? any BidirectionalCollection {
        return try diff(lhs: lhsCollection, rhs: rhsCollection)
    } else if let lhsD = lhs as? any DynamicDiffable, let rhsD = rhs as? any DynamicDiffable {
        return try diff(lhs: lhsD, rhs: rhsD)
    } else if let lhsValue = lhs as? any DiffableValue, let rhsValue = rhs as? any DiffableValue {
        return try diff(lhs: lhsValue, rhs: rhsValue).map {
            [Change(path: [], action: $0)]
        } ?? []
    } else if let lhsOptional = lhs as? any OptionalProtocol, let rhsOptional = rhs as? any OptionalProtocol {
        return try diff(lhs: lhsOptional, rhs: rhsOptional)
    } else {
        throw DiffableError()
    }
}

private func diff<D: Diffable>(lhs: D, rhs: any Diffable) throws -> [Change] {
    guard let rhs = rhs as? D else { throw DiffableError() }
    return try lhs.difference(from: rhs)
}

private func diff<C: BidirectionalCollection>(lhs: C, rhs: any BidirectionalCollection) throws -> [Change] {
    guard let rhs = rhs as? C else { throw DiffableError() }

    let differences = lhs.difference(from: rhs) { lhsE, rhsE in
        if let lhsI = lhsE as? any Identifiable, let rhsI = rhsE as? any Identifiable {
            return elementsAreEqual(lhs: lhsI, rhs: rhsI)
        } else if let lhsE = lhsE as? any Equatable, let rhsE = rhsE as? any Equatable {
            return elementsAreEqual(lhs: lhsE, rhs: rhsE)
        } else {
            return false
        }
    }

    var lhsOffset = 0
    var rhsOffset = 0

    var result: [Change] = []
    while lhsOffset < lhs.count || rhsOffset < rhs.count {
        let isInsertion = differences.insertions.contains { $0.offset == lhsOffset }
        let isRemoval = differences.removals.contains { $0.offset == rhsOffset }

        let offsetPath = String(lhsOffset)

        switch (isInsertion, isRemoval) {
        case (false, false):
            let lhsE = lhs[lhs.index(lhs.startIndex, offsetBy: lhsOffset)]
            let rhsE = rhs[rhs.index(rhs.startIndex, offsetBy: rhsOffset)]

            let differences = try diffAny(lhs: lhsE, rhs: rhsE).map { $0.pullback(pathPrefix: offsetPath) }
            result.append(contentsOf: differences)

            lhsOffset += 1
            rhsOffset += 1
        case (true, true):
            if let removed = rhs[rhs.index(rhs.startIndex, offsetBy: rhsOffset)] as? any DiffableValue {
                result.append(Change(path: [], action: .remove(offset: rhsOffset, value: removed)))
                result.append(Change(path: [], action: .insert(offset: lhsOffset)))
            } else {
                throw DiffableError()
            }

            lhsOffset += 1
            rhsOffset += 1
        case (false, true):
            if let removed = rhs[rhs.index(rhs.startIndex, offsetBy: rhsOffset)] as? any DiffableValue {
                result.append(Change(path: [], action: .remove(offset: rhsOffset, value: removed)))
            } else {
                throw DiffableError()
            }
            rhsOffset += 1
        case (true, false):
            result.append(Change(path: [], action: .insert(offset: lhsOffset)))
            lhsOffset += 1
        }
    }
    return result
}

private func diff<D: DynamicDiffable>(lhs: D, rhs: any DynamicDiffable) throws -> [Change] {
    guard let rhs = rhs as? D else { throw DiffableError() }

    var result: [Change] = []

    let newKeys = lhs.diffableKeys
    // removals
    for key in rhs.diffableKeys {
        guard try lhs.value(forDiffableKey: key) == nil else { continue }
        if let oldValue = try rhs.value(forDiffableKey: key) as? any DiffableValue {
            result.append(Change(path: [key.description], action: .set(from: oldValue))) // using set for removing/nilling is weird
        } else {
            throw DiffableError()
        }
    }

    // insertions and changes
    for key in newKeys {
        if let newValue = try lhs.value(forDiffableKey: key), let oldValue = try rhs.value(forDiffableKey: key) {
            // changes
            result.append(contentsOf: try diffAny(lhs: newValue, rhs: oldValue).map { $0.pullback(pathPrefix: key.description)})
        } else {
            // insert
            result.append(Change(path: [key.description], action: .set(from: Optional<String>.none))) // using Optional<String> here is wrong
        }
    }
    return result.sorted { (a, b) in a.path.joined() < b.path.joined() }
}

extension CollectionDifference.Change {
    var offset: Int {
        switch self {
        case let .insert(offset, _, _), let .remove(offset, _, _):
            return offset
        }
    }
}

private func elementsAreEqual<I: Identifiable>(lhs: I, rhs: any Identifiable) -> Bool {
    guard let rhs = rhs as? I else { return false }
    return lhs.id == rhs.id
}

private func elementsAreEqual<E: Equatable>(lhs: E, rhs: any Equatable) -> Bool {
    guard let rhs = rhs as? E else { return false }
    return lhs == rhs
}

private func diff<D: DiffableValue>(lhs: D, rhs: any DiffableValue) throws -> Change.Action? {
    guard let rhs = rhs as? D else { throw DiffableError() }

    guard rhs != lhs else { return nil }
    return .set(from: rhs)
}

private func diff<O: OptionalProtocol>(lhs: O, rhs: any OptionalProtocol) throws -> [Change] {
    guard let rhs = rhs as? O else { throw DiffableError() }

    if let lhs = lhs.optional, let rhs = rhs.optional {
        return try diffAny(lhs: lhs, rhs: rhs)
    } else if lhs.optional == nil && rhs.optional == nil {
        return []
    } else if let rhs = rhs as? any DiffableValue {
        return [Change(path: [], action: .set(from: rhs))]
    } else {
        throw DiffableError()
    }
}

public extension Change.Action {
    static func == (lhs: Change.Action, rhs: Change.Action) -> Bool {
        func compareValue<V: DiffableValue>(lhs: V, rhs: any DiffableValue) -> Bool {
            guard let rhs = rhs as? V else { return false }
            return lhs == rhs
        }

        switch (lhs, rhs) {
        case (.set(from: let lhsV), .set(from: let rhsV)): return compareValue(lhs: lhsV, rhs: rhsV)
        case (.insert(offset: let lhsI), .insert(offset: let rhsI)): return lhsI == rhsI
        case (.remove(offset: let lhsI, value: let lhsV), .remove(offset: let rhsI, value: let rhsV)): return lhsI == rhsI && compareValue(lhs: lhsV, rhs: rhsV)
        default: return false
        }
    }
}

public protocol DynamicDiffable {
    var diffableKeys: [String] { get }

    func value(forDiffableKey: String) throws -> Any?
}

public extension DynamicDiffable where Self: Diffable {
    var diffableKeys: [String] { Self.diffableKeys }

    func value(forDiffableKey key: String) throws -> Any? {
        let res: Any = try value(forDiffableKey: key)
        return res
    }
}

extension Dictionary: DynamicDiffable where Key == String {

    public var diffableKeys: [String] {
        Array(keys) // todo: sort
    }

    public func value(forDiffableKey key: String) -> Any? {
        self[key]
    }

}
