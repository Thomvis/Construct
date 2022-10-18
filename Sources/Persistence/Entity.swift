//
//  Entity.swift
//  Construct
//
//  Created by Thomas Visser on 18/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB
import GameModels
import Compendium

// Conforming types can be easily stored in the KV store
public protocol KeyValueStoreEntity: Codable {
    typealias KeyPrefix = KeyValueStoreEntityKeyPrefix

    static var keyPrefix: KeyPrefix { get }
    var key: String { get }
}

/**
 All entities need to have a corresponding case in this enum.
 This lowers the chance of a key collision and makes it easier
 to reason about keys
 */
public enum KeyValueStoreEntityKeyPrefix: String, CaseIterable {
    case encounter = "encounter"
    case runningEncounter = "running"
    case compendiumEntry = "compendium"
    case campaignNode = "cn_"
    case preferences = "Construct::Preferences"
    case defaultContentVersions = "Construct::DefaultContentVersions"

    case any
}

public extension KeyValueStore {
    func put<V>(_ entity: V, fts: FTSDocument? = nil, in db: GRDB.Database? = nil) throws where V: KeyValueStoreEntity {
        try put(entity, at: entity.key, fts: fts, in: db)
    }

    static func put<V>(_ entity: V, fts: FTSDocument? = nil, in db: GRDB.Database) throws where V: KeyValueStoreEntity {
        try put(entity, at: entity.key, fts: fts, in: db)
    }
}

extension KeyValueStore.Record {
    func decodeEntity(_ decoder: JSONDecoder) throws -> KeyValueStoreEntity? {
        guard let prefix = KeyValueStoreEntityKeyPrefix.allCases
            .first(where: { key.hasPrefix($0.rawValue )}) else { return nil}

        switch prefix {
        case .encounter: return try decoder.decode(Encounter.self, from: value)
        case .runningEncounter: return try decoder.decode(RunningEncounter.self, from: value)
        case .compendiumEntry: return try decoder.decode(CompendiumEntry.self, from: value)
        case .campaignNode: return try decoder.decode(CampaignNode.self, from: value)
        case .preferences: return try decoder.decode(Preferences.self, from: value)
        case .defaultContentVersions: return try decoder.decode(DefaultContentVersions.self, from: value)
        case .any: return try decoder.decode(AnyKeyValueStoreEntity.self, from: value)
        }
    }
}

public extension KeyValueStoreEntity {
    func encodeEntity(_ encoder: JSONEncoder) throws -> Data? {
        return try encoder.encode(self)
    }
}
