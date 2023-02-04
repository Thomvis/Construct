//
//  Tracked.swift
//  
//
//  Created by Thomas Visser on 02/02/2023.
//

import Foundation
import ULID

public struct Tracked<Value> where Value: Diffable & Patchable {
    public private(set) var wrapped: Value
    /// all changes, most recent first
    public private(set) var history: [Commit]  = []

    public init(_ wrapped: Value) {
        self.wrapped = wrapped
    }

    public mutating func change(message: String? = nil, operation: (inout Value) -> Void) throws {
        var newValue = wrapped
        operation(&newValue)
        try set(newValue: newValue, message: message)
    }

    @discardableResult
    public mutating func set(newValue: Value, message: String? = nil) throws -> Commit {
        try _set(newValue: newValue, message: message)
    }

    @discardableResult
    private mutating func _set(newValue: Value, message: String? = nil, undo: ULID? = nil) throws -> Commit {
        let changes = try newValue.difference(from: wrapped)

        let changeSet = ChangeSet(
            id: ULID(),
            message: message,
            baseHash: try calculateHash(value: wrapped),
            changes: changes
        )
        let commit = Commit(set: changeSet, undo: undo)

        wrapped = newValue
        history.insert(commit, at: 0)

        return commit
    }

    public func canUndo() -> Bool {
        firstUndoableCommit != nil
    }

    public mutating func undo() throws {
        guard let commitToUndo = firstUndoableCommit else { throw TrackedError() }

        var newValue = wrapped
        try newValue.rollback(commitToUndo.set)
        try _set(newValue: newValue, undo: commitToUndo.set.id)
    }

    private var firstUndoableCommit: Commit? {
        let undoIds = history.prefix { $0.undo != nil }.compactMap(\.undo)
        return history[undoIds.count...].first { !undoIds.contains($0.set.id) }
    }

    public func canRedo() -> Bool {
        firstRedoableCommit != nil
    }

    public mutating func redo() throws {
        guard let commit = firstRedoableCommit else { throw TrackedError() }

        try wrapped.rollback(commit.set)
        history.remove(at: 0)
    }

    private var firstRedoableCommit: Commit? {
        if let latest = history.first, latest.undo != nil {
            return latest
        }
        return nil
    }

}

public struct TrackedError: Swift.Error {

}

public struct Commit {
    public let set: ChangeSet
    public let undo: ULID? // the id of the changeset it is undoing (if so)
}
