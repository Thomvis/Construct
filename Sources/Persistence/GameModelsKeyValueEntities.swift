//
//  GameModels.swift
//  
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation
import GameModels

extension RunningEncounter: KeyValueStoreEntity {
    public static var keyPrefix: KeyPrefix = .runningEncounter

    public var key: String {
        return "\(Self.keyPrefix(for: base))\(id)"
    }

    public static func keyPrefix(for encounter: Encounter) -> String {
        keyPrefix(for: encounter.id)
    }

    public static func keyPrefix(for encounterId: Encounter.Id) -> String {
        "\(Self.keyPrefix).\(Encounter.key(encounterId))."
    }
}

extension Encounter: KeyValueStoreEntity {
    public static let keyPrefix: KeyPrefix = .encounter

    public var key: String {
        Self.key(id)
    }

    public static func key(_ id: Encounter.Id) -> String {
        return "\(Self.keyPrefix)_\(id)"
    }
}

extension CampaignNode: KeyValueStoreEntity {
    public static let root = CampaignNode(id: UUID(uuidString: "990EDB4B-90C7-452A-94AB-3857350B2FA6")!.tagged(), title: "ROOT", contents: nil, special: .root, parentKeyPrefix: nil)
    public static let scratchPadEncounter = CampaignNode(id: UUID(uuidString: "14A7E9D3-14B8-46DF-A7F2-3B5DCE16EEA5")!.tagged(), title: "Scratch pad", contents: CampaignNode.Contents(key: Encounter.key(Encounter.scratchPadEncounterId), type: .encounter), special: .scratchPadEncounter, parentKeyPrefix: CampaignNode.root.keyPrefixForChildren)

    public static let keyPrefix: KeyPrefix = .campaignNode

    public var key: String {
        if let parent = parentKeyPrefix {
            return "\(parent)/.\(id)"
        }
        return "\(Self.keyPrefix).\(id)"
    }

    public var keyPrefixForChildren: String {
        if let parent = parentKeyPrefix {
            return "\(parent)/\(id)"
        }
        return "cn_\(id)"
    }

    public var keyPrefixForFetchingDirectChildren: String {
        return "\(keyPrefixForChildren)/."
    }
}

extension Preferences: KeyValueStoreEntity {
    public static let keyPrefix: KeyPrefix = .preferences
    public static let key = keyPrefix.rawValue

    public var key: String {
        Self.key
    }
}

extension CompendiumEntry: KeyValueStoreEntity {
    static let keySeparator = CompendiumItemKey.keySeparator
    public static let keyPrefix: KeyPrefix = .compendiumEntry

    public var key: String {
        return Self.key(for: item.key)
    }

    static func keyPrefix(for type: CompendiumItemType? = nil) -> String {
        return [Self.keyPrefix.rawValue, type?.rawValue]
            .compactMap { $0 }
            .joined(separator: Self.keySeparator)
    }

    static func key(for itemKey: CompendiumItemKey) -> String {
        [Self.keyPrefix.rawValue, itemKey.type.rawValue, itemKey.realm.description, itemKey.identifier]
            .joined(separator: Self.keySeparator)
    }
}
