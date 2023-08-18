//
//  GameModels.swift
//  
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation
import GameModels
import Tagged

extension RunningEncounter: KeyValueStoreEntity {
    public static var keyPrefix: String = "runningEncounter"

    public var key: Key {
        return Self.keyPrefix(for: base) + id.uuidString
    }

    public static func keyPrefix(for encounter: Encounter) -> Key {
        keyPrefix(for: encounter.id)
    }

    public static func keyPrefix(for encounterId: Encounter.Id) -> Key {
        Key(id: Encounter.key(encounterId).rawValue + ".", separator: ".")
    }
}

extension Encounter: KeyValueStoreEntity {
    public static let keyPrefix: String = "encounter"

    public var key: Key {
        Self.key(id)
    }

    public static func key(_ id: Encounter.Id) -> Key {
        Key(id: id.uuidString, separator: "_")
    }
}

extension CampaignNode: KeyValueStoreEntity {
    public static let root = CampaignNode(id: UUID(uuidString: "990EDB4B-90C7-452A-94AB-3857350B2FA6")!.tagged(), title: "ROOT", contents: nil, special: .root, parentKeyPrefix: nil)
    public static let scratchPadEncounter = CampaignNode(id: UUID(uuidString: "14A7E9D3-14B8-46DF-A7F2-3B5DCE16EEA5")!.tagged(), title: "Scratch pad", contents: CampaignNode.Contents(key: Encounter.key(Encounter.scratchPadEncounterId).rawValue, type: .encounter), special: .scratchPadEncounter, parentKeyPrefix: CampaignNode.root.keyPrefixForChildren.rawValue)

    public static let keyPrefix: String = "cn_"

    public var key: Key {
        if let parent = parentKeyPrefix.flatMap(Key.init(rawKey:)) {
            return parent + "/." + id.uuidString
        }
        return Key(id: "/." + id.uuidString)
    }

    public var keyPrefixForChildren: Key {
        if let parent = parentKeyPrefix.flatMap(Key.init(rawKey:)) {
            return parent + "/" + id.uuidString
        }
        return Key(id: id.uuidString)
    }

    public var keyPrefixForFetchingDirectChildren: String {
        return "\(keyPrefixForChildren.rawValue)/."
    }
}

/// Preferences is a singleton entity
extension Preferences: KeyValueStoreEntity {
    public static let keyPrefix: String = "Construct::Preferences"
    public static let key: Key = Key(id: "")

    public var key: Key {
        Self.key
    }
}

extension CompendiumEntry: KeyValueStoreEntity {
    static let keySeparator = CompendiumItemKey.keySeparator
    public static let keyPrefix: String = "compendium"

    public var key: Key {
        return Self.key(for: item.key)
    }

    static func keyPrefix(for type: CompendiumItemType? = nil) -> String {
        return [Self.keyPrefix, type?.rawValue]
            .compactMap { $0 }
            .joined(separator: Self.keySeparator)
    }

    static func key(for itemKey: CompendiumItemKey) -> Key {
        let id = [itemKey.type.rawValue, itemKey.realm.description, itemKey.identifier]
            .joined(separator: Self.keySeparator)
        return Key(
            id: id,
            separator: Self.keySeparator
        )
    }
}

extension CompendiumSourceDocument: KeyValueStoreEntity {
    public static var keyPrefix: String = "sourceDoc"
    public var key: Key {
        Key(id: realm.rawValue + id.rawValue)
    }
}

extension CompendiumRealm: KeyValueStoreEntity {
    public static var keyPrefix: String = "realm"
    public var key: Key {
        Key(id: id.rawValue)
    }
}

extension CompendiumImportJob: KeyValueStoreEntity {
    public static var keyPrefix: String = "importjob"
    public var key: Key {
        Key(id: id.rawValue)
    }
}
