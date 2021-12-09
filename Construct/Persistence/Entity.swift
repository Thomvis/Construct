//
//  Entity.swift
//  Construct
//
//  Created by Thomas Visser on 18/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB

// Conforming types can be easily stored in the KV store
protocol KeyValueStoreEntity: Codable {
    typealias KeyPrefix = KeyValueStoreEntityKeyPrefix

    static var keyPrefix: KeyPrefix { get }
    var key: String { get }
}

/**
 All entities need to have a corresponding case in this enum.
 This lowers the chance of a key collision and makes it easier
 to reason about keys
 */
enum KeyValueStoreEntityKeyPrefix: String, CaseIterable {
    case encounter = "encounter"
    case runningEncounter = "running"
    case compendiumEntry = "compendium"
    case campaignNode = "cn_"
    case preferences = "Construct::Preferences"

    case any

    var entityType: KeyValueStoreEntity.Type {
        switch self {
        case .encounter: return Encounter.self
        case .runningEncounter: return RunningEncounter.self
        case .compendiumEntry: return CompendiumEntry.self
        case .campaignNode: return CampaignNode.self
        case .preferences: return Preferences.self
        case .any: return AnyKeyValueStoreEntity.self
        }
    }
}

extension KeyValueStore {
    func put<V>(_ entity: V, fts: FTSDocument? = nil, in db: GRDB.Database? = nil) throws where V: KeyValueStoreEntity {
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
        case .any: return try decoder.decode(AnyKeyValueStoreEntity.self, from: value)
        }
    }
}

extension KeyValueStoreEntity {
    func encodeEntity(_ encoder: JSONEncoder) throws -> Data? {
        return try encoder.encode(self)
    }
}
