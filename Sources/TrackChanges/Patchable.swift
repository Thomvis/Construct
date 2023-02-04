//
//  Patchable.swift
//  
//
//  Created by Thomas Visser on 02/02/2023.
//

import Foundation

public protocol Patchable: DynamicDiffable {
    mutating func setValue(_ value: Any, forDiffableKey: String) throws
}

public struct PatchableError: Swift.Error {
    public init() { }
}

public extension Patchable {
    mutating func rollback(_ difference: Change) throws {
        if let key = difference.path.single {
            if var child = try value(forDiffableKey: key) {
                if !(child is String), var collectionChild = child as? Array<Any> {
                    try rollbackAction(difference.action, value: &collectionChild)
                    child = collectionChild
                } else {
                    try rollbackAction(difference.action, value: &child)
                }
                try setValue(child, forDiffableKey: key)
            } else {
                // child is nil
                try setValue(rollbackActionValue(difference.action), forDiffableKey: key)
            }
        } else if let nextKey = difference.path.first {
            if var child = try value(forDiffableKey: nextKey) as? Patchable {
                try child.rollback(difference.scope(key: nextKey))
                try setValue(child, forDiffableKey: nextKey)
            } else {
                throw PatchableError()
            }
        }
    }
}

private func rollbackAction(_ action: Change.Action, value: inout Any) throws {
    value = try rollbackActionValue(action)
}

private func rollbackAction(_ action: Change.Action, value: inout Array<Any>) throws {
    switch action {
    case .insert(offset: let offset): value.remove(at: offset)
    case .remove(offset: let offset, value: let oldValue): value.insert(oldValue, at: offset)
    case .set: throw PatchableError()
    }
}

private func rollbackActionValue(_ action: Change.Action) throws -> Any {
    switch action {
    case .set(from: let oldValue): return oldValue
    case .remove, .insert: throw PatchableError()
    }
}

extension Change {
    func scope(key: String) throws -> Self {
        guard path.first == key else { throw PatchableError() }
        return Change(path: Array(path.dropFirst()), action: action)
    }
}

// sourcery: skipPatchable
extension Array: Patchable {
    public mutating func setValue(_ value: Any, forDiffableKey key: String) throws {
        guard let idx = Int(key) else { throw PatchableError() }
        guard let element = value as? Element else { throw PatchableError() }
        self[idx] = element
    }

    public var diffableKeys: [String] {
        indices.map { String($0) }
    }

    public func value(forDiffableKey key: String) -> Any? {
        guard let idx = Int(key) else { return nil }
        return self[idx]
    }
}

// sourcery: skipPatchable
extension Dictionary: Patchable where Key == String {
    public mutating func setValue(_ value: Any, forDiffableKey key: String) throws {
        guard let value = value as? Value? else {
            throw PatchableError()
        }

        self[key] = value
    }

    public static var diffableKeys: [String] {
        fatalError() // fixme
    }

    public func value(forDiffableKey key: String) throws -> Any {
        return self[key] as Any // fixme: return Any?
    }

}
