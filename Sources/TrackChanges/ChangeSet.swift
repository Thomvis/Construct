//
//  ChangeSet.swift
//  
//
//  Created by Thomas Visser on 02/02/2023.
//

import Foundation
import ULID
import CryptoKit

public struct ChangeSet: Equatable {
    public let id: ULID
    public let message: String?
    /// A hash of the document that these changes were applied to
    public let baseHash: String

    public let changes: [Change]
}

public extension Patchable {
    mutating func rollback(_ changeSet: ChangeSet) throws {
        for change in changeSet.changes.reversed() {
            try rollback(change)
        }
    }
}

func calculateHash<D: Diffable>(value: D) throws -> String {
    var hashFunction: any HashFunction = Insecure.SHA1()
    try hashDiffable(value: value, into: &hashFunction)
    return hashFunction.finalize().compactMap { String(format: "%02x", $0) }.joined()
}

private func hashAny(value: Any, into hashFunction: inout any HashFunction) throws {
    if let diffable = value as? Diffable {
        try hashDiffable(value: diffable, into: &hashFunction)
    } else if !(value is String), let collection = value as? any BidirectionalCollection {
        try hashCollection(value: collection, into: &hashFunction)
    } else if let dynamic = value as? DynamicDiffable {
        try hashDynamicDiffable(value: dynamic, into: &hashFunction)
    } else if let value = value as? any DiffableValue {
        let data = try JSONEncoder().encode(value) // fixme: standardize encoder
        hashFunction.update(data: data)
    } else {
        throw DiffableError()
    }
}

private func hashDiffable<D: Diffable>(value: D, into hashFunction: inout any HashFunction) throws {
    for key in D.diffableKeys {
        let child = try value.value(forDiffableKey: key)
        try hashAny(value: child, into: &hashFunction)
    }
}

private func hashDynamicDiffable<D: DynamicDiffable>(value: D, into hashFunction: inout any HashFunction) throws {
    for key in value.diffableKeys {
        if let child = try value.value(forDiffableKey: key) {
            try hashAny(value: child, into: &hashFunction)
        } else {
            hashFunction.update(data: Data([0x12])) // add something to make a nil value significant
        }
    }
}

private func hashCollection<C: BidirectionalCollection>(value: C, into hashFunction: inout any HashFunction) throws {
    for element in value {
        try hashAny(value: element, into: &hashFunction)
    }
}
